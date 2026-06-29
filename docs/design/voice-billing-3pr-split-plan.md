# 语音记账 #252 / #357 · 拆分与交付方案（定稿）

> 依据维护者 [PR #361 Review](https://github.com/TNT-Likely/BeeCount/pull/361)（`CHANGES_REQUESTED`）将原单体 PR 拆分交付。  
> 关联 Issue：[#252](https://github.com/TNT-Likely/BeeCount/issues/252)（VAD / 按住说话）、[#357](https://github.com/TNT-Likely/BeeCount/issues/357)（多模态音频）。  
> 原功能方案见 [voice-billing-357-252-review.md](./voice-billing-357-252-review.md)。  
> **#252 测试交付**见 [voice-billing-252-test-delivery.md](./voice-billing-252-test-delivery.md)。

---

## 1. 定稿策略（2026-06 更新）

| 交付物 | 分支 | 基线 | Issue | 说明 |
|--------|------|------|-------|------|
| **PR #252（A+B 合并）** | `cursor/voice-252-vad-trigger-aad3` | **上游 `main` 最新** | #252 | 静音/VAD + 触发方式/按住说话，**一个 PR、两个 commit** |
| **PR #357（C，后续）** | 待 A+B 合并后从 **最新 `main`** 重拉 | 合入 #252 后的 `main` | #357 | 多模态 `audioMode` 等，**不叠在 #252 分支上** |

**为何 A+B 合并为一个 PR**

- B 强依赖 A（共用 `VoiceBillingSettings`、云同步、`voice_billing_helper`），分支栈会导致 B/C 的 PR diff 含前置改动，不利于评审。
- 维护者关注的是 **#252 整体体验**，拆成两个 PR 收益有限、往返成本高。
- PR 内保留 **2 个清晰 commit**，便于按 commit review 与 `git revert`。

**为何 C 必须基于合入 #252 后的 `main` 单独开分支**

- #357 与 #252 代码域不同（AI 配置 vs 录音交互），独立 PR diff 约 **~460 行**，可审。
- 若 C 叠在 B 上，PR 会显示 **A+B+C 全量（~1600+ 行）**，无法聚焦多模态问题。

---

## 2. PR #252（A+B 合并）范围

### 2.1 包含（全部 #252）

| 能力 | 说明 |
|------|------|
| 静音阈值 | 默认 **800ms → 1500ms**；滑块 **500–4000ms**；**60s** 录音上限 |
| 云同步 | `voice_silence_timeout_ms`、`voice_trigger_mode` 纳入 `snapshotForSync` / `applyFromServer` |
| 触发方式 | `VoiceTriggerMode`：自动检测 / 按住说话，设置页可选 |
| 按住说话 | 长按录、松手识别、&lt;500ms 丢弃 |
| 录音格式 | **全程 WAV**（`AudioEncoder.wav`），与合入前 `main` 一致 |

### 2.2 明确不含（留给 #357 / Cloud）

- ❌ `AIAudioMode` / `audioMode` 字段  
- ❌ `audioChat`、多模态一步式、`ai_extraction_engine` 多模态分支  
- ❌ AI 设置页「语音识别模式」  
- ❌ m4a 录音  
- ❌ BeeCount-Cloud `providers[].audioMode`（独立仓库 PR）

### 2.3 维护者 Review 必改项（本 PR 已覆盖）

| 级别 | 项 | 落地 |
|------|-----|------|
| 🟠 | 静音滑块拖动频繁云同步 | [`smart_billing_page.dart`](../../lib/pages/settings/smart_billing_page.dart) 滑块 **`onChangeEnd`** 持久化 |
| 🟡 | 按住说话启动录音期间松手 orphan | [`voice_billing_helper.dart`](../../lib/utils/voice_billing_helper.dart) `_startRecording` 后 `!_isHolding` → `_discardRecording` |
| 🟢 | `_notifyConfigChanged` 空 catch | [`voice_billing_providers.dart`](../../lib/providers/voice_billing_providers.dart) 改为 `logger.warning` |

### 2.4 改动文件（15 个，+1214 / -116 行，相对上游 main）

| 文件 | 改动 |
|------|------|
| [lib/providers/voice_billing_providers.dart](../../lib/providers/voice_billing_providers.dart) | 新建：`VoiceTriggerMode` + 静音阈值 |
| [lib/ai/providers/ai_constants.dart](../../lib/ai/providers/ai_constants.dart) | `voice_*` key |
| [lib/ai/providers/ai_provider_manager.dart](../../lib/ai/providers/ai_provider_manager.dart) | 语音设置进同步快照 |
| [lib/utils/voice_billing_helper.dart](../../lib/utils/voice_billing_helper.dart) | VAD 可调、60s、按住说话、竞态修复、**WAV** |
| [lib/pages/settings/smart_billing_page.dart](../../lib/pages/settings/smart_billing_page.dart) | 触发方式 + 静音滑块 |
| [lib/providers/sync_providers.dart](../../lib/providers/sync_providers.dart) | 同步后 invalidate 语音设置 |
| [lib/l10n/app_*.arb](../../lib/l10n/) + 生成文件 | #252 文案 |
| [test/providers/voice_billing_settings_test.dart](../../test/providers/voice_billing_settings_test.dart) | 设置读写 |
| [test/ai/providers/ai_provider_manager_voice_sync_test.dart](../../test/ai/providers/ai_provider_manager_voice_sync_test.dart) | 云同步 |

### 2.5 Commit 结构（本 PR 内）

```
docs: 语音记账拆分方案（#252 A+B 合并 / #357 后续独立）
feat(voice): #252 静音阈值默认1500ms、可调、60s上限与云同步     ← 原 A
feat(voice): #252 触发方式共存/按住说话 + 竞态修复 + 触发方式同步  ← 原 B
```

> 当前实现可能将 docs 与第一次 feat 合在一个 commit；推送前可按上表 `git rebase -i` 整理，非硬性要求。

---

## 3. PR #357（C，后续独立）范围概要

> **不在本 PR 提交**；待 #252 合并到 `main` 后，从 **最新 `main`** 开分支实现。

| 能力 | 说明 |
|------|------|
| `audioMode` | `transcription` / `multimodalChat`，随 `providers[]` 同步 |
| 多模态链路 | `audioChat`、一步直出账单 |
| 录音格式 | **仅多模态** m4a；传统 STT **保持 WAV** |
| OpenAI 解析 | `_audioChatOpenAI` 响应 guard |
| Cloud | BeeCount-Cloud 保留 `audioMode`（独立仓库） |

详见本文档旧版 §5–§6 技术要点；实现时以合入 #252 后的 `main` 为基线，避免重复携带 #252 diff。

---

## 4. 合并与评审顺序

```
上游 main
    │
    ▼
PR #252（A+B 合并）─── merge ───► main'
    │
    ▼
从 main' 拉 #357 分支 ─── PR #357 ─── merge
```

- 评审 #252 时：diff = **仅 #252**（相对合入前 main）。  
- 评审 #357 时：diff = **仅 #357**（相对合入 #252 后 main）。

---

## 5. 与旧版三 PR 方案差异

| 旧方案 | 定稿 |
|--------|------|
| A、B、C 三个独立 PR，分支栈叠放 | **#252 一个 PR（A+B）**；**#357 单独 PR** |
| C 可与 A 并行、叠在 B 上 | C **必须在 #252 合入后**从最新 main 开发 |
| B 的 PR 含 A 的 diff | 已消除（A+B 合并） |

---

## 6. 质量自检（#252 PR）

- [x] 无 `audioMode` / 多模态 / m4a 代码与测试  
- [x] 静音 `onChangeEnd`、按住竞态修复、logger.warning  
- [x] 单测 8 项通过（见 [测试交付文档](./voice-billing-252-test-delivery.md)）  
- [x] 录音格式保持 WAV，不影响现有 STT 路径  
