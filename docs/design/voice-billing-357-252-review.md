# 语音记账优化 · 修改方案评审

> 关联 Issue：
> - [#357 语音记账新增大模型调用协议（多模态音频输入）](https://github.com/TNT-Likely/BeeCount/issues/357)
> - [#252 语音记账时容易话没说完就停止检测的优化](https://github.com/TNT-Likely/BeeCount/issues/252)
>
> 评审结论：两个 Issue 建议**合并为一个特性**统一优化。理由见 [§1 背景](#1-背景与目标)。
> 本文档仅为**方案评审**，不含落地代码；落地前仍需就 [§9 待确认问题](#9-待确认问题) 与维护者对齐。

---

## 1. 背景与目标

| Issue | 诉求 | 关键约束 |
|---|---|---|
| #357 | 语音记账除现有「STT 转写」外，新增**多模态大模型协议**：直接把音频喂给 Chat 模型（`/v1/chat/completions` + `input_audio`），让模型「听 + 推理」，对不标准普通话更鲁棒。用户可在 AI 配置中选「传统模式（便宜、不推理）/ 多模态模式（贵、可推理）」 | 改造请求 URL 与 body 即可；要可由用户切换 |
| #252 | 自动静音检测过于敏感，一句话还没说完就停止录音，导致误识别 / 反复重试。期望**更宽松的静音判定**，或改为**微信式按住说话（长按说话、抬手停止）** | 不希望增加用户点击次数 |

**Issue 作者在 #357 评论区已明确**（[评论链接](https://github.com/TNT-Likely/BeeCount/issues/357)）：

1. 多模态后用户会一次说更多（如把一天的账一次说完），现有的"自动检测停止说话"会成为更大的问题——说话必然有停顿，所以倾向**微信式按住说话**；
2. 多模态模式下，**理论上无需先转文字再交给文本模型**，直接把音频 + Prompt 给到模型即可一步得到账单信息。

> 结论：#252 与 #357 强相关，且都集中在语音记账链路 [lib/utils/voice_billing_helper.dart](../../lib/utils/voice_billing_helper.dart)，建议同一特性分支统一实现。

---

## 2. 现状分析（以实际代码为准）

### 2.1 语音记账三层链路

代码遵循 [lib/ai/README.md](../../lib/ai/README.md) 描述的三层架构：

```
Layer 3 渠道入口  voice_billing_helper.dart   录音 + 静音检测 + 弹窗 UI
        ↓
Layer 2 应用层    ai_bookkeeper.dart           fromAudio() 编排：提取→落库→聚合
        ↓
Layer 1 底座      ai_extraction_engine.dart    extractFromAudio()：STT→文本提取
                  ai_provider_factory.dart     speechToText()：实际调服务商 API
```

关键文件与职责：

- [lib/utils/voice_billing_helper.dart](../../lib/utils/voice_billing_helper.dart)：录音器、权限、**静音检测**、录音弹窗 UI。
- [lib/services/ai/ai_bookkeeper.dart](../../lib/services/ai/ai_bookkeeper.dart) `fromAudio()`：调底座拿 `AudioExtractionResult`，逐笔落库。
- [lib/ai/core/ai_extraction_engine.dart](../../lib/ai/core/ai_extraction_engine.dart) `extractFromAudio()`：**先 `speechToText` 转文字，再 `extractFromText` 提取账单**（两次模型调用）。
- [lib/ai/providers/ai_provider_factory.dart](../../lib/ai/providers/ai_provider_factory.dart)：
  - `speechToText()` → 内置走 `_speechToTextZhipu`（GLM-4-Voice，**已经是 chat/completions + input_audio 多模态**），非内置走 `_speechToTextOpenAI`（**Whisper 风格 `/audio/transcriptions` multipart**）。
- [lib/ai/providers/ai_provider_config.dart](../../lib/ai/providers/ai_provider_config.dart)：`AIServiceProviderConfig`（含 `textModel/visionModel/audioModel`）、`AICapabilityBinding`（text/vision/speech 三能力绑定）、`AICapabilityType`。
- [lib/ai/providers/ai_provider_manager.dart](../../lib/ai/providers/ai_provider_manager.dart)：配置 SharedPreferences 存取 + 同步快照 `snapshotForSync` / `applyFromServer`。
- [lib/pages/ai/ai_settings_page.dart](../../lib/pages/ai/ai_settings_page.dart)：AI 设置页（能力绑定、高级设置）。

> 重要发现：**内置智谱 GLM 路径其实已经是「多模态音频输入」**——[zhipu_glm_provider.dart](../../packages/flutter_ai_kit_zhipu/lib/src/zhipu_glm_provider.dart) 的 `_prepareMessageContent` 已用 `input_audio`（base64 + format）通过 `chat/completions` 发送。#357 的核心缺口是**OpenAI 兼容（自定义）服务商缺多模态音频路径**，且当前架构是"STT 转文字 → 再提取"两步，未提供"音频直出账单"一步式能力。

### 2.2 静音检测机制（#252 根因）

见 [voice_billing_helper.dart](../../lib/utils/voice_billing_helper.dart) `_VoiceRecordingDialog`：

- 弹窗打开即自动录音（WAV），无"按住说话"交互。
- 振幅监测每 100ms 一次，`soundThreshold = 0.58`（≈ −25dB），需**连续 5 帧（约 500ms）超阈**才算"在说话"，并刷新 `_lastSoundTime`。
- 静音判定：
  - 尚未说话：开场 **3s** 无语音 → 取消并提示"未检测到语音输入"。
  - 已说话：`now - _lastSoundTime >= 800ms` → **立即停止并送识别**。

**根因定位**：

1. **800ms 静音阈值过短**：自然语句间停顿（"今天中午吃饭花了20.5元……吃了泡面和火腿肠"）极易超 800ms，触发提前截断。
2. **0.58（−25dB）阈值偏高**：小声 / 不标准发音 / 安静环境下，正常说话帧常低于阈值，导致 `_consecutiveSoundCount` 频繁清零，把"在说话"误判为"静音"。
3. **缺少按住说话**：仅自动 VAD + 手动「完成 / 取消」按钮；多模态后一次说很多时，自动 VAD 几乎必然误截断。

### 2.3 入口与触发

语音记账由 [lib/app.dart](../../lib/app.dart) 的 SpeedDial（长按底部 + 浮起的菜单项，**抬手命中"语音"即触发**）以及深链 `AppLinkAction.voice` 调起 `VoiceBillingHelper.startVoiceBilling`。即"按住 FAB → 浮起菜单 → 抬手落到语音项 → 弹出录音框自动录音"。

---

## 3. Issue #252 方案

### 3.1 设计目标

- 默认更宽松、对自然停顿更友好；
- 提供**按住说话（push-to-talk）**作为更确定的交互；
- 用户可选触发方式，且默认行为不增加点击次数。

### 3.2 方案对比

| 方案 | 描述 | 优点 | 缺点 |
|---|---|---|---|
| A. VAD 参数优化 | 静音阈值 800ms → 可配置（默认 1500–2000ms）；降低/自适应音量阈值；加入最长录音时长上限 | 改动小、零交互变化 | 仍是启发式，长停顿场景无法根治 |
| B. 按住说话（推荐主选） | 录音弹窗改"按住录音、抬手结束并识别"；松手即停，不依赖静音检测 | 彻底解决误截断，符合作者诉求与多模态长语音场景 | 交互习惯变化，需做空录音/误触防抖 |
| C. 点击开始/点击结束 | 备选交互 | 简单 | 增加点击次数，作者明确不偏好 |

### 3.3 推荐方案：A + B 组合，提供"语音触发方式"开关

在智能记账设置中新增"语音触发方式"：

- **自动检测（默认，方案 A 调优版）**：保留 VAD，但把静音超时改为可配置常量（建议默认 **1500ms**），并加最长录音上限（如 60s）防止永不停止；适度下调或自适应音量阈值。
- **按住说话（方案 B）**：录音弹窗主按钮改为 `GestureDetector` 长按手势：`onLongPressStart` 开始录音、`onLongPressEnd` 停止并识别；松手即结束，不跑静音检测；增加"录音过短（<0.5s）则丢弃"的防误触。

### 3.4 #252 改动点

- [lib/utils/voice_billing_helper.dart](../../lib/utils/voice_billing_helper.dart)：
  - 静音超时 `800ms`、起始静音 `3s`、音量阈值 `0.58`、连续帧 `5` 等魔法值抽为可配置常量；
  - `_VoiceRecordingDialog` 支持两种模式：自动 VAD（现状调优）/ 按住说话（新增长按手势、隐藏自动检测计时、抬手即 `_stopAndProcess`）。
- 新增设置项（参考 [lib/providers/smart_billing_providers.dart](../../lib/providers/smart_billing_providers.dart) 的持久化范式）：`voiceTriggerMode`（auto/holdToTalk）+（可选）`voiceSilenceTimeoutMs`。
- 设置 UI：[lib/pages/settings/smart_billing_page.dart](../../lib/pages/settings/smart_billing_page.dart) 通用设置区新增选择项。
- 文案：[lib/l10n/app_zh.arb](../../lib/l10n/app_zh.arb) / [app_en.arb](../../lib/l10n/app_en.arb) / [app_zh_TW.arb](../../lib/l10n/app_zh_TW.arb) 新增触发方式、"按住说话""松开结束"等 key。

---

## 4. Issue #357 方案

### 4.1 设计目标

新增"语音识别模式"，由用户切换：

- **传统模式（STT，默认）**：维持现状 `/audio/transcriptions` → 文本 → 提取，成本低。
- **多模态模式（Chat + input_audio）**：把音频直接经 `chat/completions` 的 `input_audio` 内容块发给可推理模型，**一步直出账单 JSON**（与作者评论一致），对不标准发音更鲁棒。

### 4.2 关键技术点

1. **OpenAI 兼容路径补齐多模态音频**：当前 [ai_provider_factory.dart](../../lib/ai/providers/ai_provider_factory.dart) 仅 `_speechToTextOpenAI`（multipart Whisper）。需新增 `_audioChatOpenAI`：构造
   ```jsonc
   {
     "model": "<audioModel/multimodal模型>",
     "messages": [{
       "role": "user",
       "content": [
         {"type": "text", "text": "<账单提取 Prompt>"},
         {"type": "input_audio", "input_audio": {"data": "<base64>", "format": "wav"}}
       ]
     }]
   }
   ```
   智谱内置路径已有等价实现，可作为参照（[zhipu_glm_provider.dart](../../packages/flutter_ai_kit_zhipu/lib/src/zhipu_glm_provider.dart) `_prepareMessageContent`）。

2. **一步式"音频直出账单"**：在底座 [ai_extraction_engine.dart](../../lib/ai/core/ai_extraction_engine.dart) 新增 `extractFromAudio` 的多模态分支——直接用 [prompt_builder.dart](../../lib/ai/core/prompt_builder.dart) 构造提取 Prompt + 音频，单次调用后用现有 [json_response_parser.dart](../../lib/ai/core/json_response_parser.dart) 解析为 `List<BillInfo>`，省掉"先 STT 再 chat"两次调用。`recognizedText` 可由模型附带返回或留空。

3. **配置模型**：[ai_provider_config.dart](../../lib/ai/providers/ai_provider_config.dart) `AIServiceProviderConfig` 需表达"语音用哪种模式 + 多模态用哪个模型"。两种取向：
   - 轻量：复用 `audioModel` 字段 + 新增枚举 `audioMode`（transcription / multimodalChat）；
   - 显式：新增 `audioChatModel` 字段，与 `audioModel`（STT）分列。
   - 同步链路 `snapshotForSync` / `applyFromServer` / `fromJson` / `toJson` 需同步加字段并保证旧配置反序列化兼容（默认 transcription）。

4. **录音格式与体积**：现录 WAV（[voice_billing_helper.dart](../../lib/utils/voice_billing_helper.dart) `RecordConfig(encoder: AudioEncoder.wav)`）。多模态走 base64 内联，长语音 WAV 体积大、上传慢。需评估：是否对多模态模式改用压缩格式（如 m4a/opus），并设置发送/接收超时（参考内置路径 120s）。

### 4.3 #357 改动点

- [lib/ai/providers/ai_provider_config.dart](../../lib/ai/providers/ai_provider_config.dart)：新增音频模式（与可选 `audioChatModel`）字段 + JSON 兼容 + `copyWith`。
- [lib/ai/providers/ai_provider_factory.dart](../../lib/ai/providers/ai_provider_factory.dart)：`speechToText`/新增 `audioToBills` 按模式分流；新增 `_audioChatOpenAI`。
- [lib/ai/core/ai_extraction_engine.dart](../../lib/ai/core/ai_extraction_engine.dart)：`extractFromAudio` 增加多模态一步式分支。
- [lib/ai/providers/ai_provider_manager.dart](../../lib/ai/providers/ai_provider_manager.dart)：`snapshotForSync` / `applyFromServer` 带上新字段。
- [lib/pages/ai/ai_settings_page.dart](../../lib/pages/ai/ai_settings_page.dart) 与 [lib/pages/ai/ai_provider_manage_page.dart](../../lib/pages/ai/ai_provider_manage_page.dart)：语音能力下新增"识别模式"选择与（可选）多模态模型输入。
- 文案：三套 arb 新增"传统模式/多模态模式"及说明（含成本提示）。
- 测试：扩展 [test/services/ai/ai_bookkeeper_test.dart](../../test/services/ai/ai_bookkeeper_test.dart) 覆盖多模态分支。

---

## 5. 联合优化建议（#252 × #357）

多模态一次性长语音是显式诉求，**自动 VAD 在此场景几乎必然误截断**。因此：

- 当用户选择**多模态模式**时，建议默认引导/联动为**按住说话**触发方式，避免长语音被截断。
- 两个 Issue 共用一个特性分支与 PR，分两个 commit（VAD/交互、多模态协议）便于在 main 上看清真实差异。

---

## 6. 改动文件清单汇总

| 文件 | #252 | #357 |
|---|:--:|:--:|
| [lib/utils/voice_billing_helper.dart](../../lib/utils/voice_billing_helper.dart) | ✅ 录音交互/VAD | ⬜ 录音格式可能调整 |
| [lib/providers/smart_billing_providers.dart](../../lib/providers/smart_billing_providers.dart) | ✅ 触发方式开关 | ⬜ |
| [lib/pages/settings/smart_billing_page.dart](../../lib/pages/settings/smart_billing_page.dart) | ✅ 设置项 UI | ⬜ |
| [lib/ai/providers/ai_provider_config.dart](../../lib/ai/providers/ai_provider_config.dart) | ⬜ | ✅ 音频模式字段 |
| [lib/ai/providers/ai_provider_factory.dart](../../lib/ai/providers/ai_provider_factory.dart) | ⬜ | ✅ 多模态音频请求 |
| [lib/ai/core/ai_extraction_engine.dart](../../lib/ai/core/ai_extraction_engine.dart) | ⬜ | ✅ 一步式分支 |
| [lib/ai/providers/ai_provider_manager.dart](../../lib/ai/providers/ai_provider_manager.dart) | ⬜ | ✅ 同步快照字段 |
| [lib/pages/ai/ai_settings_page.dart](../../lib/pages/ai/ai_settings_page.dart) | ⬜ | ✅ 模式选择 UI |
| [lib/l10n/app_zh.arb](../../lib/l10n/app_zh.arb) / [app_en.arb](../../lib/l10n/app_en.arb) / [app_zh_TW.arb](../../lib/l10n/app_zh_TW.arb) | ✅ | ✅ |
| [test/services/ai/ai_bookkeeper_test.dart](../../test/services/ai/ai_bookkeeper_test.dart) | ⬜ | ✅ |

---

## 7. 风险与兼容性

- **配置兼容**：新增字段必须保证旧 JSON 反序列化默认值（音频模式默认 `transcription`、触发方式默认 `auto`），避免存量用户行为突变；同步链路双端字段需对齐。
- **成本/体积**：多模态长音频 base64 体积大、按 token 计费贵，UI 需明确成本提示；超时需放宽（参考 120s）。
- **服务商差异**：并非所有 OpenAI 兼容服务商都支持 `input_audio`；模式切到多模态但模型不支持时要有清晰报错（复用 `validateSpeechCapability` 范式）。
- **按住说话边界**：极短录音、长按中途取消、权限拒绝、录音文件未生成等需兜底，避免空文件送识别。
- **平台权限**：交互改造不应影响既有麦克风权限申请流程（[voice_billing_helper.dart](../../lib/utils/voice_billing_helper.dart) 已有完整处理）。

---

## 8. 测试计划

- 单测：`flutter test test/ai/ test/services/ai/`，新增多模态分支断言（mock factory）。
- 手测（需真机麦克风）：
  - #252：自然停顿长句不被截断；按住说话松手即识别；超短录音丢弃；3s 无声提示。
  - #357：传统/多模态模式切换；多模态一步直出账单；不标准普通话鲁棒性；不支持服务商报错友好。
- 兼容：升级存量配置（旧 JSON）后默认行为不变；多端同步字段一致。

---

## 9. 待确认问题

> 按"需求清晰才写代码"原则，落地前需与维护者确认：

1. **音频模式配置形态**：复用 `audioModel` + `audioMode` 枚举，还是新增独立 `audioChatModel` 字段？
2. **多模态是否一步直出账单**：采用"音频+Prompt 单次出 BillInfo"（作者倾向），还是"音频→精准转写文本→再走文本提取"两步？两者成本/可控性不同。
3. **触发方式默认值**：默认仍"自动检测"，仅多模态时引导按住说话；还是全局默认改"按住说话"？
4. **VAD 默认静音超时**：建议默认值（1500ms？是否暴露给用户可调）。
5. **多模态录音格式**：是否为减小体积改用压缩格式（m4a/opus），需确认目标服务商对 `input_audio` 的格式支持矩阵。
6. **范围**：是否两 Issue 合并为单一 PR 实现，分 commit 提交。

---

## 10. 方案级质量自检

- [x] 边界条件：空/超短录音、长停顿、权限拒绝、服务商不支持多模态、旧配置反序列化——均已在 [§7](#7-风险与兼容性) 列出兜底要求。
- [x] 资源清理：录音器 `dispose`、定时器 cancel、临时音频文件删除在现有实现已具备，改造需保持（[voice_billing_helper.dart](../../lib/utils/voice_billing_helper.dart) `dispose` / `finally delete`）。
- [x] 并发/时序：按住说话需处理"未开始录音即松手""录音中切后台"等时序；多模态超时需放宽。
- [x] 主要路径覆盖：传统/多模态、自动/按住四组合的主路径与失败路径已在 [§8](#8-测试计划) 规划。
