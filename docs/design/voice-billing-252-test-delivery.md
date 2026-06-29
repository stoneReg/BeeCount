# 语音记账 #252 · 测试交付说明（PR A+B 合并）

> 对应分支：`cursor/voice-252-vad-trigger-aad3`  
> 对应 Issue：[#252](https://github.com/TNT-Likely/BeeCount/issues/252)  
> **不含 #357 多模态**；`audioMode` / m4a / `audioChat` 相关用例不在本交付范围。  
> 拆分策略见 [voice-billing-3pr-split-plan.md](./voice-billing-3pr-split-plan.md)。

---

## 1. 交付摘要

| 项 | 内容 |
|----|------|
| 单测文件 | 2 个 |
| 单测用例 | **8** 项 |
| 执行命令 | 见 §2 |
| 最近执行结果 | **8/8 通过**（Flutter 3.29.3 / Dart 3.7.2） |
| 覆盖模块 | 语音设置 Provider、云同步快照、编解码与边界 |

---

## 2. 自动化测试

### 2.1 执行命令

在仓库根目录：

```bash
flutter test test/providers/voice_billing_settings_test.dart \
             test/ai/providers/ai_provider_manager_voice_sync_test.dart
```

仅跑 #252 相关（**不要**包含 `ai_provider_config_audio_mode_test.dart`，该文件属 #357）。

### 2.2 用例清单

#### [test/providers/voice_billing_settings_test.dart](../../test/providers/voice_billing_settings_test.dart)（5 项）

| # | 用例 | 验证点 |
|---|------|--------|
| 1 | `VoiceTriggerModeCodec` 往返一致 | `auto` / `hold_to_talk` 存储值编解码 |
| 2 | `VoiceTriggerModeCodec` 未知/空值兜底 | 非法字符串 → `VoiceTriggerMode.auto` |
| 3 | `VoiceBillingSettings` 默认值 | `triggerMode=auto`，`silenceTimeoutMs=1500` |
| 4 | 阈值越界自动夹取并持久化 | &gt;4000 → 4000；&lt;500 → 500；写入 SharedPreferences |
| 5 | 设置触发方式后重建可读 | `holdToTalk` 跨 Provider 容器持久化 |

#### [test/ai/providers/ai_provider_manager_voice_sync_test.dart](../../test/ai/providers/ai_provider_manager_voice_sync_test.dart)（3 项）

| # | 用例 | 验证点 |
|---|------|--------|
| 6 | `snapshotForSync` 带语音 key | 含 `voice_trigger_mode`、`voice_silence_timeout_ms` |
| 7 | `applyFromServer` 落地语音设置 | server 下发写入 prefs |
| 8 | `applyFromServer` 缺省不覆盖本地 | 无语音字段时保留本地 `auto` / 1500 |

### 2.3 刻意未覆盖（非本 PR 范围）

| 模块 | 原因 |
|------|------|
| `AIAudioMode` / `audioMode` 序列化 | 属 #357 |
| `audioChat` / 多模态提取 | 属 #357 |
| 录音 m4a 编码 | 本 PR 固定 WAV |
| `voice_billing_helper` Widget 集成测试 | 需麦克风/真机；见 §3 手测 |

---

## 3. 手动测试清单（建议真机）

### 3.1 静音 / VAD（自动检测模式）

- [ ] 默认停顿约 **1.5s** 后自动结束（不再 800ms 误截断）  
- [ ] 智能记账 → 停顿结束时长滑块：**拖动中不同步**；**松手后**生效并触发云同步（若已登录云账号）  
- [ ] 滑块调到 0.5s / 4.0s 边界，行为符合夹取  
- [ ] 连续说话超过 **60s** 强制结束（需已检测到「开始说话」）  
- [ ] 开场 3s 无语音 → 提示「未检测到语音输入」  

### 3.2 触发方式 / 按住说话

- [ ] 设置页可切换「自动检测停顿」↔「按住说话」  
- [ ] 自动模式：弹窗打开即录；按住模式：需长按麦克风区域  
- [ ] 按住说话：松手送识别；**快速点按 &lt;0.5s** 丢弃并提示过短  
- [ ] **竞态**：按住后极快松手，无后台残留录音、无 orphan 文件  
- [ ] 按住模式不显示静音滑块；自动模式显示  

### 3.3 录音格式与 STT（回归）

- [ ] 临时文件扩展名为 **`.wav`**（传统 STT 路径不受影响）  
- [ ] 内置智谱 / 自定义 Whisper 兼容服务商语音记账成功  

### 3.4 多设备同步

- [ ] 设备 A 修改触发方式或静音阈值 → 设备 B 拉取后一致  
- [ ] 拖动滑块过程中另一设备不应收到中间值风暴（`onChangeEnd` 单次同步）  

---

## 4. 维护者 Review 项 · 测试映射

| Review 项 | 单测 | 手测 |
|-----------|------|------|
| 滑块 `onChangeEnd` 防频繁同步 | — | §3.1 滑块、§3.4 |
| 按住说话竞态 orphan | — | §3.2 竞态 |
| 传统 STT 保持 WAV（非 m4a） | — | §3.3 |
| 语音设置云同步 | 用例 6–8 | §3.4 |
| 静音默认 1500 / 可调 | 用例 3–4 | §3.1 |

---

## 5. 代码质量自检

- [x] 边界：阈值 clamp、触发方式非法存储值、server 缺字段不覆盖  
- [x] 资源：`dispose` 取消 Timer、临时 wav 文件 `finally` 删除  
- [x] 并发：按住说话竞态丢弃；同步幂等（仅不同才写 prefs）  
- [x] 范围隔离：无 #357 字段、无 m4a、无 `audioMode` 断言  

---

## 6. CI 建议

在 PR 描述或 CI 中固定执行：

```bash
flutter analyze
flutter test test/providers/voice_billing_settings_test.dart \
             test/ai/providers/ai_provider_manager_voice_sync_test.dart
```

#357 合入后再追加 `test/ai/providers/ai_provider_config_audio_mode_test.dart` 等用例。
