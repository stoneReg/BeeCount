# 语音记账优化 · 修改方案评审

> 关联 Issue：
> - [#357 语音记账新增大模型调用协议（多模态音频输入）](https://github.com/TNT-Likely/BeeCount/issues/357)
> - [#252 语音记账时容易话没说完就停止检测的优化](https://github.com/TNT-Likely/BeeCount/issues/252)
>
> 评审结论：两个 Issue 建议**合并为一个特性**统一优化。理由见 [§1 背景](#1-背景与目标)。
> 本文档为**方案评审**，不含落地代码。维护者已就 [§9 已确认决策](#9-已确认决策) 给出结论，本文档据此定稿。
>
> **本轮评审补充的两条横切要求（贯穿 #252 / #357）**：
> 1. **多模态音频输入的配置**（识别模式、多模态相关模型）必须支持**多设备自动同步**；
> 2. **自动静音检测与按住说话二者共存**、由用户选择，且**静音检测阈值等配置也必须支持多设备自动同步**。

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
- [lib/ai/providers/ai_provider_manager.dart](../../lib/ai/providers/ai_provider_manager.dart)：配置 SharedPreferences 存取 + **多设备同步快照** `snapshotForSync` / `applyFromServer`。当前快照仅含 `providers / binding / custom_prompt / strategy / bill_extraction_enabled / use_vision`，任何改动经 `onConfigChanged` 推送到 server，另一端 `applyFromServer` 落地。
- [lib/providers/smart_billing_providers.dart](../../lib/providers/smart_billing_providers.dart)：智能记账通用开关（自动标签、自动附件）走**本地 SharedPreferences，未接入上述同步快照**。
- [lib/pages/ai/ai_settings_page.dart](../../lib/pages/ai/ai_settings_page.dart)：AI 设置页（能力绑定、高级设置）。

> **同步现状结论**：#357 的"识别模式 / 多模态模型"应放进 `AIServiceProviderConfig`，天然随 `providers` 快照同步；而 #252 的"触发方式 / 静音阈值"当前范式（`smart_billing_providers`）**不会同步**——要满足"多设备自动同步"，必须把这些 key 纳入 `snapshotForSync` / `applyFromServer`（详见 [§3.5](#35-252-配置的多设备同步)）。

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

### 3.3 推荐方案：A + B **共存**，由用户选择触发方式

两种触发方式**同时保留、由用户在设置中切换**（不二选一删除其一）：

- **自动检测（方案 A 调优版）**：保留 VAD，但把静音超时改为**用户可调阈值**（建议默认 **1500ms**），并加最长录音上限（如 60s）防止永不停止；适度下调或自适应音量阈值。
- **按住说话（方案 B）**：录音弹窗主按钮改为 `GestureDetector` 长按手势：`onLongPressStart` 开始录音、`onLongPressEnd` 停止并识别；松手即结束，不跑静音检测；增加"录音过短（<0.5s）则丢弃"的防误触。

默认触发方式由配置决定（见 [§9 决策 9.3](#9-已确认决策)）：不同配置在 UI 上有不同体现——选"自动检测"时录音弹窗显示音量/计时与"说完停顿即识别"提示并额外展示静音阈值可调项；选"按住说话"时弹窗显示"按住说话、松开结束"的长按按钮、不展示静音阈值项。

### 3.4 #252 改动点

- [lib/utils/voice_billing_helper.dart](../../lib/utils/voice_billing_helper.dart)：
  - 静音超时 `800ms`、起始静音 `3s`、音量阈值 `0.58`、连续帧 `5` 等魔法值抽为常量/可配置项；静音超时改为读取用户配置（默认 1500ms）；
  - `_VoiceRecordingDialog` 支持两种模式：自动 VAD（现状调优）/ 按住说话（新增长按手势、隐藏自动检测计时、抬手即 `_stopAndProcess`），UI 按当前触发方式区分呈现。
- 新增设置项：`voiceTriggerMode`（`auto` / `holdToTalk`）、`voiceSilenceTimeoutMs`（默认 1500）。**注意：不沿用 [smart_billing_providers.dart](../../lib/providers/smart_billing_providers.dart) 的"纯本地"范式**，而要接入同步（见 [§3.5](#35-252-配置的多设备同步)）。
- 设置 UI：[lib/pages/settings/smart_billing_page.dart](../../lib/pages/settings/smart_billing_page.dart) 通用设置区新增"语音触发方式"选择 + 自动检测下的"静音灵敏度/停顿时长"滑块（仅在自动检测模式可见可调）。
- 文案：[lib/l10n/app_zh.arb](../../lib/l10n/app_zh.arb) / [app_en.arb](../../lib/l10n/app_en.arb) / [app_zh_TW.arb](../../lib/l10n/app_zh_TW.arb) 新增触发方式、"按住说话""松开结束"、停顿时长等 key。

### 3.5 #252 配置的多设备同步

要求"静音检测阈值等配置支持多设备自动同步"。由于 [§2.1](#21-语音记账三层链路) 指出 `smart_billing_providers` 不进同步快照，方案为**把语音触发配置纳入 AI 配置同步链路**：

- 在 [ai_provider_manager.dart](../../lib/ai/providers/ai_provider_manager.dart) 的 `snapshotForSync()` 增补 `voice_trigger_mode`、`voice_silence_timeout_ms`（与现有 `strategy` 等同级，从 SharedPreferences 读取）；
- 在 `applyFromServer()` 增补对应字段落地（保持"仅当与本地不同才写"的幂等范式，避免回调死循环）；
- 修改这两个 key 的写入处需触发 `onConfigChanged`（与 `saveCustomPrompt` 同款 fire-and-forget），保证变更即时推送到 server，另一端拉取生效。

> 备选：若维护者希望语音设置独立于"AI 配置"语义，可新增独立同步段落；但复用现有 AI 同步链路改动最小、与既有机制一致，推荐之。

---

## 4. Issue #357 方案

### 4.1 设计目标

新增"语音识别模式"，由用户切换（默认仍为传统 STT，保证存量行为不变）：

- **传统模式（STT，默认）**：维持现状 `/audio/transcriptions` → 文本 → 提取，成本低。
- **多模态模式（Chat + input_audio）**：把音频直接经 `chat/completions` 的 `input_audio` 内容块发给可推理模型，**音频 + Prompt 单次直出账单 JSON**（见 [§9 决策 9.2](#9-已确认决策)，与作者评论一致），对不标准发音更鲁棒。

> 配置形态采用**复用枚举**（见 [§9 决策 9.1](#9-已确认决策)）：复用既有 `audioModel` 字段承载模型名，新增 `audioMode` 枚举区分 `transcription`（默认）/ `multimodalChat`，不额外引入独立的多模态模型字段。该枚举随 `AIServiceProviderConfig` 进入 `providers` 同步快照，**天然支持多设备自动同步**。

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

2. **一步式"音频直出账单"**（决策 9.2 已定）：在底座 [ai_extraction_engine.dart](../../lib/ai/core/ai_extraction_engine.dart) 新增 `extractFromAudio` 的多模态分支——直接用 [prompt_builder.dart](../../lib/ai/core/prompt_builder.dart) 构造提取 Prompt + 音频，单次调用后用现有 [json_response_parser.dart](../../lib/ai/core/json_response_parser.dart) 解析为 `List<BillInfo>`，省掉"先 STT 再 chat"两次调用。`recognizedText` 可由模型附带返回或留空。

3. **配置模型**（决策 9.1 已定：**复用枚举**）：在 [ai_provider_config.dart](../../lib/ai/providers/ai_provider_config.dart) `AIServiceProviderConfig` 复用 `audioModel` 字段 + 新增 `audioMode` 枚举（`transcription` 默认 / `multimodalChat`）。
   - `fromJson` / `toJson` / `copyWith` 同步加字段；`fromJson` 对缺省值兜底为 `transcription`，保证旧配置反序列化兼容、行为不变。
   - 因字段落在 `AIServiceProviderConfig` 内，随 `providers` 进入 `snapshotForSync` / `applyFromServer`，**多设备自动同步零额外成本**（满足本轮要求 1）。

4. **录音格式与体积**（决策 9.5 已定：**默认 m4a**）：现录 WAV（[voice_billing_helper.dart](../../lib/utils/voice_billing_helper.dart) `RecordConfig(encoder: AudioEncoder.wav)`）。多模态走 base64 内联，长语音 WAV 体积大、上传慢，故**默认改用压缩格式 m4a**（`AudioEncoder.aacLc`，`record` 包跨平台支持较好），显著减小 base64 体积。
   - `input_audio.format` 需随编码格式正确填写（m4a/aac → 上游多按 `mp3`/`m4a` 处理，参考内置 [zhipu_glm_provider.dart](../../packages/flutter_ai_kit_zhipu/lib/src/zhipu_glm_provider.dart) 对扩展名→format 的映射）；
   - 同步放宽多模态发送/接收超时（参考内置路径 120s）；
   - 需回归验证传统 STT 路径在 m4a 下的兼容性（部分服务商 `/audio/transcriptions` 对 m4a 支持良好，若个别不支持可按模式选择编码格式）。

### 4.3 #357 改动点

- [lib/ai/providers/ai_provider_config.dart](../../lib/ai/providers/ai_provider_config.dart)：复用 `audioModel` + 新增 `audioMode` 枚举字段 + JSON 兼容（默认 `transcription`）+ `copyWith`。
- [lib/ai/providers/ai_provider_factory.dart](../../lib/ai/providers/ai_provider_factory.dart)：新增 `audioToBills`（多模态一步式）/ 按 `audioMode` 分流；新增 `_audioChatOpenAI`（OpenAI 兼容 `chat/completions` + `input_audio`）。
- [lib/ai/core/ai_extraction_engine.dart](../../lib/ai/core/ai_extraction_engine.dart)：`extractFromAudio` 增加多模态一步式分支（音频 + Prompt 单次出 `List<BillInfo>`）。
- [lib/ai/providers/ai_provider_manager.dart](../../lib/ai/providers/ai_provider_manager.dart)：`audioMode` 随 `providers` 已同步，无需额外改动；本文件的改动主要服务于 [§3.5](#35-252-配置的多设备同步) 的 #252 语音设置同步。
- [lib/pages/ai/ai_settings_page.dart](../../lib/pages/ai/ai_settings_page.dart) 与 [lib/pages/ai/ai_provider_manage_page.dart](../../lib/pages/ai/ai_provider_manage_page.dart)：语音能力下新增"识别模式（传统 STT / 多模态）"选择。
- 文案：三套 arb 新增"传统模式/多模态模式"及说明（含成本提示）。
- 测试：扩展 [test/services/ai/ai_bookkeeper_test.dart](../../test/services/ai/ai_bookkeeper_test.dart) 覆盖多模态一步式分支。

---

## 5. 联合优化建议（#252 × #357）

多模态一次性长语音是显式诉求，**自动 VAD 在此场景几乎必然误截断**。因此：

- 触发方式（自动检测 / 按住说话）**二者共存、由配置决定默认值**（决策 9.3）；当用户选择**多模态模式**时，建议默认引导/联动为**按住说话**以避免长语音被截断，UI 对两种配置给出不同呈现（[§3.3](#33-推荐方案a--b-共存由用户选择触发方式)）。
- 两个 Issue **合并为单一 PR**（决策 9.6），但**分 commit 提交**：建议拆为 ①#252 触发方式/VAD 调优、②#252 语音设置多设备同步、③#357 多模态协议与一步式提取、④文案与测试，便于在 main 上看清真实差异。

---

## 6. 改动文件清单汇总

| 文件 | #252 | #357 |
|---|:--:|:--:|
| [lib/utils/voice_billing_helper.dart](../../lib/utils/voice_billing_helper.dart) | ✅ 触发方式共存/VAD 阈值可调 | ✅ 录音默认改 m4a |
| [lib/providers/smart_billing_providers.dart](../../lib/providers/smart_billing_providers.dart) 或新增 voice 设置 provider | ✅ 触发方式/静音阈值状态 | ⬜ |
| [lib/pages/settings/smart_billing_page.dart](../../lib/pages/settings/smart_billing_page.dart) | ✅ 触发方式选择 + 静音阈值滑块 | ⬜ |
| [lib/ai/providers/ai_provider_config.dart](../../lib/ai/providers/ai_provider_config.dart) | ⬜ | ✅ `audioMode` 枚举字段 |
| [lib/ai/providers/ai_provider_factory.dart](../../lib/ai/providers/ai_provider_factory.dart) | ⬜ | ✅ 多模态音频请求/分流 |
| [lib/ai/core/ai_extraction_engine.dart](../../lib/ai/core/ai_extraction_engine.dart) | ⬜ | ✅ 一步式分支 |
| [lib/ai/providers/ai_provider_manager.dart](../../lib/ai/providers/ai_provider_manager.dart) | ✅ 语音设置纳入同步快照 | ✅（`audioMode` 随 providers 自动同步） |
| [lib/pages/ai/ai_settings_page.dart](../../lib/pages/ai/ai_settings_page.dart) | ⬜ | ✅ 识别模式选择 UI |
| [lib/l10n/app_zh.arb](../../lib/l10n/app_zh.arb) / [app_en.arb](../../lib/l10n/app_en.arb) / [app_zh_TW.arb](../../lib/l10n/app_zh_TW.arb) | ✅ | ✅ |
| [test/services/ai/ai_bookkeeper_test.dart](../../test/services/ai/ai_bookkeeper_test.dart) | ⬜ | ✅ |

---

## 7. 风险与兼容性

- **配置兼容**：新增字段必须保证旧 JSON 反序列化默认值（`audioMode` 默认 `transcription`、触发方式默认按配置、静音阈值默认 1500ms），避免存量用户行为突变；同步链路双端字段需对齐。
- **多设备同步一致性**：
  - `audioMode` 随 `AIServiceProviderConfig`（`providers`）同步，零额外成本；
  - #252 的 `voice_trigger_mode` / `voice_silence_timeout_ms` 需新增进 `snapshotForSync` / `applyFromServer`，并在写入处触发 `onConfigChanged`；务必沿用"仅当与本地不同才写"的幂等逻辑，**避免 onConfigChanged → 写入 → 再 onConfigChanged 的同步回环**。
  - server 端 `ai_config` 若有 schema/白名单校验，需确认能接纳新增 key（否则字段会被丢弃，表现为"同步无效"）。
- **成本/体积**：多模态长音频按 token 计费贵且 base64 体积大，已用 m4a 压缩缓解；UI 需明确成本提示；超时需放宽（参考 120s）。
- **录音格式回归**：默认改 m4a 后，需回归传统 STT 路径在各服务商 `/audio/transcriptions` 对 m4a 的兼容性；必要时按模式选择编码（多模态 m4a，个别不支持 m4a 的 STT 服务商回退 wav）。
- **服务商差异**：并非所有 OpenAI 兼容服务商都支持 `input_audio`；模式切到多模态但模型不支持时要有清晰报错（复用 `validateSpeechCapability` 范式）。
- **按住说话边界**：极短录音、长按中途取消、权限拒绝、录音文件未生成等需兜底，避免空文件送识别。
- **平台权限**：交互改造不应影响既有麦克风权限申请流程（[voice_billing_helper.dart](../../lib/utils/voice_billing_helper.dart) 已有完整处理）。

---

## 8. 测试计划

- 单测：`flutter test test/ai/ test/services/ai/`，新增多模态分支断言（mock factory）。
- 手测（需真机麦克风）：
  - #252：自然停顿长句不被截断；按住说话松手即识别；超短录音丢弃；3s 无声提示；自动/按住两种配置 UI 呈现正确；静音阈值滑块即时生效。
  - #357：传统/多模态模式切换；多模态一步直出账单；不标准普通话鲁棒性；不支持服务商报错友好；m4a 录音在传统 STT 与多模态两路径均可用。
- 多设备同步：A 设备改"识别模式 / 触发方式 / 静音阈值"后，B 设备拉取后一致；验证无同步回环（不会反复互推）。
- 兼容：升级存量配置（旧 JSON）后默认行为不变；多端同步字段一致。

---

## 9. 已确认决策

> 维护者于本轮评审给出以下结论，方案据此定稿：

| 编号 | 议题 | 结论 |
|---|---|---|
| 9.1 | 音频模式配置形态 | **复用枚举**：复用 `audioModel` 字段 + 新增 `audioMode` 枚举（`transcription` 默认 / `multimodalChat`），不新增独立模型字段。随 `providers` 自动多设备同步。 |
| 9.2 | 多模态提取方式 | 采用 **"音频 + Prompt 单次直出 BillInfo"** 一步式，不再先转文字再提取。 |
| 9.3 | 触发方式默认值 | 自动检测 / 按住说话**共存**，默认值**由配置决定**；不同配置在 UI 上有不同体现（[§3.3](#33-推荐方案a--b-共存由用户选择触发方式)）。 |
| 9.4 | 静音超时阈值 | **需暴露给用户可调**（默认 1500ms），并纳入多设备同步（[§3.5](#35-252-配置的多设备同步)）。 |
| 9.5 | 录音格式 | **默认使用 m4a** 压缩格式以减小体积（`AudioEncoder.aacLc`），`input_audio.format` 相应填写。 |
| 9.6 | 实施范围 | **合并为单一 PR**，**分 commit 提交**（建议拆分见 [§5](#5-联合优化建议252--357)）。 |

> 横切要求（本轮新增、已纳入方案）：① 多模态音频配置支持多设备自动同步（决策 9.1 天然满足）；② 自动检测与按住说话共存且静音阈值支持多设备同步（[§3.5](#35-252-配置的多设备同步)）。

---

## 10. 方案级质量自检

- [x] 边界条件：空/超短录音、长停顿、权限拒绝、服务商不支持多模态、旧配置反序列化、m4a 在 STT 路径的兼容回退——均已在 [§7](#7-风险与兼容性) 列出兜底要求。
- [x] 资源清理：录音器 `dispose`、定时器 cancel、临时音频文件删除在现有实现已具备，改造需保持（[voice_billing_helper.dart](../../lib/utils/voice_billing_helper.dart) `dispose` / `finally delete`）。
- [x] 并发/时序：按住说话需处理"未开始录音即松手""录音中切后台"等时序；多模态超时需放宽；**多设备同步需用幂等写入避免 `onConfigChanged` 回环**（[§7](#7-风险与兼容性)）。
- [x] 主要路径覆盖：传统/多模态、自动/按住四组合的主路径与失败路径、双设备同步一致性已在 [§8](#8-测试计划) 规划。
