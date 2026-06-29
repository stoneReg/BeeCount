# 语音记账 #252 / #357 · 三 PR 拆分实施方案

> 依据维护者 [PR #361 Review](https://github.com/TNT-Likely/BeeCount/pull/361)（`CHANGES_REQUESTED`）将原单体 PR 拆为 **3 个独立 PR**，降低评审与回滚成本。  
> 关联 Issue：[#252](https://github.com/TNT-Likely/BeeCount/issues/252)（VAD / 按住说话）、[#357](https://github.com/TNT-Likely/BeeCount/issues/357)（多模态音频）。  
> 原方案评审见 [voice-billing-357-252-review.md](./voice-billing-357-252-review.md)。  
> **BeeCount-Cloud 配套改动不在本仓库**，将在独立会话中提交 PR（见 [§6](#6-beeCount-cloud-配套范围仅文档指引)）。

---

## 1. 总览

| PR | 分支名（建议） | Issue | 依赖 | 目标 |
|----|----------------|-------|------|------|
| **A** | `cursor/voice-252-silence-vad-aad3` | #252 | 无（基于 `main`） | 仅静音阈值优化：默认 1500ms、可调、60s 上限、云同步 |
| **B** | `cursor/voice-252-hold-trigger-aad3` | #252 | **A 合并后** | 触发方式共存（自动 / 按住说话）、竞态修复、触发方式云同步 |
| **C** | `cursor/voice-357-multimodal-aad3` | #357 | 无（基于 `main`，可与 A/B 并行评审） | `audioMode`、多模态一步式、m4a **仅多模态**、传统 STT 保持 WAV |

**合并顺序**：`A → B`；`C` 可与 `A` 并行，但与 `B` 无硬依赖。

**原 PR #361**：三 PR 就绪后关闭或改为 Draft，附链接指向 A/B/C。

---

## 2. 维护者评审意见 · 归属映射

| 级别 | 评审项 | 归属 PR | 落地要点 |
|------|--------|---------|----------|
| 🔴 | 录音全局 m4a 影响传统 STT | **C** | 按 `audioMode` 选格式：`transcription` → **WAV**（与 main 一致）；`multimodalChat` → **m4a (AAC-LC)** |
| 🔴 | Web/Cloud 编辑服务商丢 `providers[].audioMode` | **Cloud 独立 PR** | 本仓库 C 已序列化 `audioMode`；Cloud 端补字段与保存逻辑（见 §6） |
| 🟠 | 静音滑块 `onChanged` 每次 tick 触发云同步 | **A** | 改为 `onChangeEnd`（或 debounce）；拖动过程仅更新本地 state |
| 🟠 | `_audioChatOpenAI` 响应解析脆弱 | **C** | 对 `choices` / `message` / `content` 做 null/类型 guard，失败抛 `AIException` |
| 🟡 | 按住说话：`await _startRecording()` 期间松手导致 orphan 录音 | **B** | `_startRecording` 返回后若 `!_isHolding` 则 `_discardRecording()` |
| 🟢 | `_notifyConfigChanged` 空 catch | **A 或 B** | 改为 `logger.warning`（顺手修） |
| 🟢 | 补多模态单测 | **C** | mock `audioChat` 分支、响应解析异常路径 |

---

## 3. PR A — 静音阈值 / VAD 优化（#252 第一部分）

### 3.1 范围（只做这些）

- 默认静音判定 **800ms → 1500ms**（[`VoiceBillingSettings.defaultSilenceTimeoutMs`](../../lib/providers/voice_billing_providers.dart)）。
- 用户可调滑块 **500ms ~ 4000ms**（步进 100ms）。
- **60s** 最长录音保护（静音检测失效时强制结束）。
- 设置页 **仅** 展示「静音判定时长」滑块（**不出现**触发方式选择）。
- 多设备同步 **仅** `voice_silence_timeout_ms`（**不含** `voice_trigger_mode`）。
- 录音交互保持 main 行为：**弹窗打开即自动录音**，**WAV** 格式，无按住说话 UI。

### 3.2 明确不做

- ❌ `VoiceTriggerMode` / 按住说话 UI / `_isHolding` 竞态逻辑  
- ❌ `voice_trigger_mode` 同步 key  
- ❌ `audioMode` / 多模态 / m4a  
- ❌ 智能记账页「语音触发方式」入口  

### 3.3 改动文件

| 文件 | 改动 |
|------|------|
| [lib/providers/voice_billing_providers.dart](../../lib/providers/voice_billing_providers.dart) | **新建（瘦身版）**：仅 `silenceTimeoutMs` + `VoiceBillingSettingsNotifier.setSilenceTimeoutMs`；**无** `VoiceTriggerMode` |
| [lib/ai/providers/ai_constants.dart](../../lib/ai/providers/ai_constants.dart) | 仅 `keyVoiceSilenceTimeoutMs` |
| [lib/ai/providers/ai_provider_manager.dart](../../lib/ai/providers/ai_provider_manager.dart) | `snapshotForSync` / `applyFromServer` 仅处理 `voice_silence_timeout_ms` |
| [lib/utils/voice_billing_helper.dart](../../lib/utils/voice_billing_helper.dart) | 读 `silenceTimeoutMs`；60s 上限；**保留 WAV**；静音检测用可配置阈值；结构接近 main（无 hold 分支） |
| [lib/pages/settings/smart_billing_page.dart](../../lib/pages/settings/smart_billing_page.dart) | 新增「静音判定时长」区块；滑块 **`onChangeEnd`** 写持久化 + 触发同步 |
| [lib/providers/sync_providers.dart](../../lib/providers/sync_providers.dart) | 若需 invalidate `voiceBillingSettingsProvider`（与现实现一致） |
| [lib/l10n/app_*.arb](../../lib/l10n/) | 仅静音相关文案（`smartBillingVoiceSilenceTimeout` 等） |
| [test/providers/voice_billing_settings_test.dart](../../test/providers/voice_billing_settings_test.dart) | 仅静音阈值 clamp / 默认值 / notifier |
| [test/ai/providers/ai_provider_manager_voice_sync_test.dart](../../test/ai/providers/ai_provider_manager_voice_sync_test.dart) | 仅 `voice_silence_timeout_ms` 同步用例 |

### 3.4 Commit 建议（单 PR 内 1~2 commit）

```
feat(voice): #252 静音阈值默认1500ms、可调滑块与60s录音上限
feat(voice): #252 静音阈值纳入多设备同步快照
test(voice): #252 静音设置与云同步单测
```

### 3.5 验收

- [ ] 自然停顿句不被 800ms 误截断（默认 1.5s）。  
- [ ] 滑块拖动中**不**频繁触发云同步；松手后一次同步。  
- [ ] 录音格式仍为 **`.wav`** + `AudioEncoder.wav`。  
- [ ] 升级用户无 `voice_silence_timeout_ms` 时行为为 1500ms。  
- [ ] `flutter test` 相关用例通过。

---

## 4. PR B — 触发方式共存 + 按住说话（#252 第二部分）

### 4.1 范围（在 A 之上增量）

- `VoiceTriggerMode`：`auto` / `holdToTalk`，设置页可选。  
- [`voice_billing_helper.dart`](../../lib/utils/voice_billing_helper.dart)：自动检测 vs 按住说话双 UI；按住说话长按/松手/过短丢弃。  
- **竞态修复**：`_onHoldStart` → `await _startRecording()` 完成后，若 `!_isHolding` → `_discardRecording()`。  
- 云同步增补 `voice_trigger_mode`（与 A 的 `voice_silence_timeout_ms` 并存）。  
- 自动模式下静音滑块逻辑继承 A（`onChangeEnd` 已修）。  
- **录音格式仍为 WAV**（m4a 留给 C）。

### 4.2 明确不做

- ❌ `audioMode`、多模态、`audioChat`  
- ❌ 按模式切换录音编码  

### 4.3 改动文件

| 文件 | 改动 |
|------|------|
| [lib/providers/voice_billing_providers.dart](../../lib/providers/voice_billing_providers.dart) | 扩展 `VoiceTriggerMode`、`setTriggerMode`、加载 `triggerMode` |
| [lib/ai/providers/ai_constants.dart](../../lib/ai/providers/ai_constants.dart) | `keyVoiceTriggerMode` |
| [lib/ai/providers/ai_provider_manager.dart](../../lib/ai/providers/ai_provider_manager.dart) | 同步 `voice_trigger_mode` |
| [lib/utils/voice_billing_helper.dart](../../lib/utils/voice_billing_helper.dart) | 按住说话 UI、`Listener`、`_onHoldStart/End`、竞态修复、双模式分支 |
| [lib/pages/settings/smart_billing_page.dart](../../lib/pages/settings/smart_billing_page.dart) | 触发方式选择；仅 `auto` 时展示静音滑块 |
| [lib/l10n/app_*.arb](../../lib/l10n/) | `voiceTriggerMode*`、`voiceRecordingHoldToTalk` 等 |
| [test/providers/voice_billing_settings_test.dart](../../test/providers/voice_billing_settings_test.dart) | `triggerMode` 读写 |
| [test/ai/providers/ai_provider_manager_voice_sync_test.dart](../../test/ai/providers/ai_provider_manager_voice_sync_test.dart) | 双 key 同步 |

### 4.4 Commit 建议

```
feat(voice): #252 语音触发方式共存(自动检测/按住说话)
feat(voice): #252 触发方式纳入多设备同步
fix(voice): #252 按住说话启动录音期间松手丢弃 orphan 录音
test(voice): #252 触发方式设置与云同步单测
```

### 4.5 验收

- [ ] 自动模式：与 A 行为一致 + 可切按住模式。  
- [ ] 按住说话：长按录、松手识别、&lt;500ms 丢弃。  
- [ ] **竞态**：快速点按不在后台残留录音。  
- [ ] 双设备同步触发方式 + 静音阈值一致。  
- [ ] 仍为 **WAV** 录音。

---

## 5. PR C — 多模态音频输入（#357）

### 5.1 范围

- `AIAudioMode`：`transcription`（默认）/ `multimodalChat`（[`ai_provider_config.dart`](../../lib/ai/providers/ai_provider_config.dart)）。  
- [`ai_extraction_engine.dart`](../../lib/ai/core/ai_extraction_engine.dart)：多模态分支 `audioChat` + `PromptBuilder` 一步直出账单。  
- [`ai_provider_factory.dart`](../../lib/ai/providers/ai_provider_factory.dart)：`audioChat`、`_audioChatOpenAI` / `_audioChatZhipu`；`validateSpeechCapability` 按 `audioMode` 分流。  
- [`ai_settings_page.dart`](../../lib/pages/ai/ai_settings_page.dart)：识别模式 UI。  
- [`ai_provider_manage_page.dart`](../../lib/pages/ai/ai_provider_manage_page.dart)：保存时保留 `audioMode`。  
- **录音格式按模式分流**（🔴 评审必改）：

```dart
// voice_billing_helper.startVoiceBilling 内伪代码
final speechProvider = await AIProviderManager.getProviderForCapability(AICapabilityType.speech);
final useM4a = speechProvider?.audioMode == AIAudioMode.multimodalChat;
final ext = useM4a ? 'm4a' : 'wav';
final encoder = useM4a ? AudioEncoder.aacLc : AudioEncoder.wav;
```

- `_audioChatOpenAI`：响应结构 guard（🟠）。  
- `audioMode` 随 `providers[]` JSON **自动**多设备同步（无需额外 snapshot key）。  
- 多模态能力验证：测试音频可用 m4a；传统 STT 验证仍用 WAV。

### 5.2 明确不做

- ❌ `voice_trigger_mode` / `voice_silence_timeout_ms`（属 A/B）  
- ❌ 按住说话 UI 改动（属 B）  
- ❌ BeeCount-Cloud 代码（独立仓库）

### 5.3 改动文件

| 文件 | 改动 |
|------|------|
| [lib/ai/providers/ai_provider_config.dart](../../lib/ai/providers/ai_provider_config.dart) | `AIAudioMode` 枚举与序列化 |
| [lib/ai/providers/ai_provider_factory.dart](../../lib/ai/providers/ai_provider_factory.dart) | `audioChat`、`resolveAudioMode`、分流验证、OpenAI 响应 guard |
| [lib/ai/core/ai_extraction_engine.dart](../../lib/ai/core/ai_extraction_engine.dart) | `_extractFromAudioMultimodal` |
| [lib/utils/voice_billing_helper.dart](../../lib/utils/voice_billing_helper.dart) | **仅** 按 `audioMode` 选路径/编码（若 B 未合，C 分支基于 main 时此处只改格式逻辑；**推荐 B 合并后再合 C**，减少 helper 冲突） |
| [lib/pages/ai/ai_settings_page.dart](../../lib/pages/ai/ai_settings_page.dart) | 识别模式选择 |
| [lib/pages/ai/ai_provider_manage_page.dart](../../lib/pages/ai/ai_provider_manage_page.dart) | 保留 `audioMode` |
| [lib/l10n/app_*.arb](../../lib/l10n/) | 多模态相关文案 |
| [test/ai/providers/ai_provider_config_audio_mode_test.dart](../../test/ai/providers/ai_provider_config_audio_mode_test.dart) | 序列化默认值 |
| 新增/扩展 factory 单测 | `_audioChatOpenAI` 异常响应、多模态验证分支 |

### 5.4 Commit 建议

```
feat(ai): #357 audioMode 枚举与配置序列化
feat(ai): #357 多模态 audioChat 与一步直出账单
feat(voice): #357 多模态录音使用 m4a，传统 STT 保持 wav
fix(ai): #357 加固多模态 OpenAI 响应解析与能力验证分流
test(ai): #357 audioMode 与多模态路径单测
```

### 5.5 验收

- [ ] 传统模式：Whisper 路径 **WAV**，与 main 兼容（硅基流动等）。  
- [ ] 多模态模式：**m4a**，`input_audio.format` 正确。  
- [ ] 设置页切换模式后多设备 `providers[].audioMode` 一致。  
- [ ] 不支持多模态的服务商有清晰报错。  
- [ ] 四组合冒烟：自动+传统、自动+多模态、按住+传统、按住+多模态（后两者需 B+C 均合入）。

---

## 6. BeeCount-Cloud 配套范围（仅文档指引）

> 将在**新仓库新会话**提交 PR，本方案只列契约，避免客户端合了、Cloud 丢字段。

| 项 | 说明 |
|----|------|
| 模型 | `AIProvider`（或等价 DTO）增加 `audioMode: string`（`transcription` / `multimodalChat`） |
| 读取 | 解析 `ai_config.providers[]` 时保留 `audioMode`，缺省 `transcription` |
| 写入 | Web 编辑服务商保存时**合并**已有 `audioMode`，禁止整对象覆盖丢字段 |
| 校验 | 若 server 有 schema 白名单，放行 `audioMode` 与 `voice_silence_timeout_ms`、`voice_trigger_mode` |
| 无关 | Cloud **不需要**理解 m4a/wav；音频格式纯客户端决策 |

客户端 A/B 的 `voice_*` 字段已在 [`ai_provider_manager.snapshotForSync`](../../lib/ai/providers/ai_provider_manager.dart) 顶层；Cloud 若对 `ai_config` 做结构化编辑，需一并透传这两个 key。

---

## 7. 代码重组策略（从当前单体分支拆分）

当前分支 `cursor/voice-billing-multimodal-vad-review-aad3`（7 commits，+1606 行）需**按文件职责回拆**，而非简单 cherry-pick 原 commit（原 commit 将 A/B 混在 `196a987`）。

### 7.1 推荐流程

```
main (f417fc0+)
  │
  ├─► 分支 A：从 main 检出，仅实现 §3 文件子集
  │     → PR A → merge
  │
  ├─► 分支 B：从 main  rebase onto A（或 A merge 后从 main 合并 A 再叠 B）
  │     → PR B（base: main，依赖 A 已合）
  │
  └─► 分支 C：从 main 检出，仅实现 §5（helper 格式逻辑与 B 可能冲突 → C 在 B 合并后 rebase 更稳）
        → PR C
```

### 7.2 `voice_billing_helper.dart` 分阶段形态

| 阶段 | 录音格式 | 交互 | 配置来源 |
|------|----------|------|----------|
| main | WAV | 仅自动 VAD | 硬编码 800ms |
| **A** | WAV | 仅自动 VAD | `silenceTimeoutMs` + 60s |
| **B** | WAV | 自动 + 按住 | + `triggerMode`、竞态修复 |
| **C** | 按 `audioMode` | 继承 B | + 读 speech provider `audioMode` |

### 7.3 `voice_billing_providers.dart` 分阶段形态

| 阶段 | 字段 | Notifier 方法 |
|------|------|---------------|
| **A** | `silenceTimeoutMs` | `setSilenceTimeoutMs` |
| **B** | + `triggerMode` | + `setTriggerMode` |

避免 A 引入 `VoiceTriggerMode` 枚举，减少 B 的 diff 噪音。

### 7.4 冲突热点

1. **`voice_billing_helper.dart`** — 三 PR 均可能触及；严格按 §3→§4→§5 顺序开发/合并。  
2. **`smart_billing_page.dart`** — A 加滑块，B 加触发方式；C 不改。  
3. **`ai_provider_manager.dart`** — A 加一个 sync key，B 再加一个；C 不改 snapshot 顶层（`audioMode` 在 providers 内）。

---

## 8. PR 描述模板（提交时用）

### PR A

- Closes / Ref #252（部分）  
- 静音阈值 1500ms 默认、可调、60s 上限、云同步  
- **不含**按住说话、不含多模态  
- 录音仍为 WAV  

### PR B

- Ref #252  
- **Depends on #\<PR-A-number\>**  
- 触发方式共存 + 按住说话 + 竞态修复 + `voice_trigger_mode` 同步  

### PR C

- Closes / Ref #357  
- `audioMode`、多模态一步式、m4a 仅多模态、STT 保持 WAV  
- Cloud 配套见 BeeCount-Cloud 独立 PR  

---

## 9. 测试矩阵

| 场景 | A | B | C | A+B | A+B+C |
|------|---|---|---|-----|-------|
| 静音阈值默认/可调 | ✅ | | | ✅ | ✅ |
| 滑块不频繁同步 | ✅ | | | ✅ | ✅ |
| 60s 强制结束 | ✅ | | | ✅ | ✅ |
| 按住说话 | | ✅ | | ✅ | ✅ |
| 竞态松手丢弃 | | ✅ | | ✅ | ✅ |
| 触发方式同步 | | ✅ | | ✅ | ✅ |
| 传统 STT + WAV | ✅ | ✅ | | ✅ | ✅ |
| 多模态 + m4a | | | ✅ | | ✅ |
| audioMode 同步 | | | ✅ | | ✅ |
| 四组合交互 | | | | | ✅ |

---

## 10. 与原方案文档的差异说明

[voice-billing-357-252-review.md](./voice-billing-357-252-review.md) §9.5 写「默认 m4a」、§9.6 写「单一 PR」——均以**维护者最新 Review** 为准：

- **m4a 仅多模态**（传统 STT 保持 WAV）；  
- **三 PR 分交付**（本文档）；  
- 决策 9.1~9.4 内容仍有效，仅实施节奏调整。

---

## 11. 质量自检（落地后）

- [ ] 边界：空录音、超短按住、权限拒绝、服务商不支持多模态、旧 JSON 无新字段  
- [ ] 资源：`dispose`、Timer cancel、临时文件 `finally` 删除  
- [ ] 并发：按住说话竞态、同步幂等（仅当不同才写 prefs）  
- [ ] 路径：传统/多模态 × 自动/按住 主路径与失败路径  
- [ ] 回归：传统 STT 服务商（Whisper 兼容）不受 m4a 影响  

---

## 12. 下一步

1. 确认本拆分方案（当前文档）。  
2. 从 `main` 创建分支 A，按 §3 实现并提 PR。  
3. A 合并后创建分支 B，按 §4 实现并提 PR。  
4. 从 `main`（或 B 合并后 rebase）创建分支 C，按 §5 实现并提 PR。  
5. 关闭/替换原 #361，BeeCount-Cloud 在独立仓库跟 C 对齐。
