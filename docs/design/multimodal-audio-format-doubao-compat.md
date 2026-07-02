# 多模态语音识别 format=mp3 与豆包 doubao-seed-2-0-mini-260428 兼容性说明

> 基于 **main 分支**（commit `a2f5ea6`）代码与火山方舟官方文档的核查结论。  
> 本文档仅做问题分析与改造建议，**不包含代码修改**。

---

## 1. 问题背景

语音记账在多模态模式（`AIAudioMode.multimodalChat`）下，会把录音文件经 `chat/completions` 的 `input_audio` 字段直接发给大模型。实际运行时日志常见：

```text
请求(多模态语音): https://.../chat/completions, format=mp3
```

而本地录音文件扩展名为 `.m4a`，因此产生疑问：**`format=mp3` 是否正确？是否应为 `m4a`？**

---

## 2. 问题一：format=mp3 是什么情况？

### 2.1 结论摘要

| 层级 | 实际值 | 说明 |
|------|--------|------|
| **本地录音文件** | `.m4a`（AAC-LC 编码） | 符合设计决策 9.5「默认 m4a 压缩」 |
| **API 请求 `input_audio.format`** | `mp3` | 不是录音 bug，而是当前实现的**刻意映射策略** |
| **对豆包 Seed 2.0 是否合适** | **不合适，应填 `m4a`** | 字节与实际编码不一致，存在解码失败风险 |

**一句话**：录音确实是 m4a，但上送 API 时被统一标成 mp3；这对智谱 GLM 是历史兼容做法，对豆包则建议改为 `m4a`（或转码后再标 mp3）。

---

### 2.2 代码链路（main 分支现状）

#### 录音侧：文件就是 m4a

[`lib/utils/voice_billing_helper.dart`](../../lib/utils/voice_billing_helper.dart) 中：

- 临时文件路径：`voice_<timestamp>.m4a`
- 编码器：`AudioEncoder.aacLc`（M4A 容器 + AAC-LC 音频轨）

```116:119:lib/utils/voice_billing_helper.dart
      // 3. 准备录音文件路径（默认 m4a 压缩格式，减小多模态 base64 体积；
      //    传统转写服务商对 m4a 兼容性也较好）
      final tempDir = await getTemporaryDirectory();
      final audioPath = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
```

```223:227:lib/utils/voice_billing_helper.dart
      await widget.recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc, // m4a(AAC-LC)，体积小、跨平台兼容好
        ),
        path: widget.audioPath,
```

#### 多模态上送侧：format 被映射为 mp3

[`lib/ai/providers/ai_provider_factory.dart`](../../lib/ai/providers/ai_provider_factory.dart) 的 `_audioChatOpenAI`：

```692:714:lib/ai/providers/ai_provider_factory.dart
    final audioBytes = await audio.readAsBytes();
    final base64Audio = base64Encode(audioBytes);
    final format = _audioFormatForPath(audio.path);

    logger.debug('AIFactory',
        '请求(多模态语音): ${config.baseUrl}/chat/completions, format=$format');
    // ...
                  'input_audio': {
                    'data': base64Audio,
                    'format': format,
                  },
```

映射函数：

```736:741:lib/ai/providers/ai_provider_factory.dart
  /// 由文件扩展名推断 input_audio 的 format。
  /// 与内置 GLM 路径保持一致：wav 用 wav，其余（m4a/aac/mp3）统一按 mp3 上送。
  static String _audioFormatForPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ext == 'wav' ? 'wav' : 'mp3';
  }
```

内置智谱路径 [`packages/flutter_ai_kit_zhipu/lib/src/zhipu_glm_provider.dart`](../../packages/flutter_ai_kit_zhipu/lib/src/zhipu_glm_provider.dart) 同样将 m4a/aac 标为 mp3：

```207:214:packages/flutter_ai_kit_zhipu/lib/src/zhipu_glm_provider.dart
        // 检测音频格式（GLM API 支持 wav 和 mp3）
        final extension = audioFile!.path.split('.').last.toLowerCase();
        String format = 'mp3'; // 默认
        if (extension == 'wav') {
          format = 'wav';
        } else if (extension == 'm4a' || extension == 'aac') {
          // m4a/aac 录音格式，GLM可能识别为 mp3
          format = 'mp3';
```

#### 端到端调用链

```mermaid
flowchart LR
  A[用户录音] --> B[voice_xxx.m4a<br/>AAC-LC]
  B --> C[extractFromAudio<br/>multimodalChat 分支]
  C --> D[AIProviderFactory.audioChat]
  D --> E[_audioChatOpenAI]
  E --> F["base64(m4a bytes)<br/>format=mp3"]
  F --> G[POST /chat/completions]
```

---

### 2.3 为何实现成 mp3 而非 m4a？

设计文档 [`docs/design/voice-billing-357-252-review.md`](voice-billing-357-252-review.md) 决策 9.5 的表述是：

- **录音格式**默认 m4a（减小 base64 体积）
- **`input_audio.format`** 需随编码格式正确填写，并注明「m4a/aac → 上游多按 mp3/m4a 处理，参考 GLM 映射」

当前实现选择了 **GLM 兼容策略**：

| 上游 API | `input_audio.format` 官方支持 | 当前映射 |
|----------|-------------------------------|----------|
| OpenAI Chat Completions | 仅 `wav`、`mp3` | m4a → mp3 ✓（协议层面） |
| 智谱 GLM | 文档仅 wav、mp3 | m4a → mp3 ✓（注释已说明） |
| 火山方舟 / 豆包 Seed | mp3、wav、**aac、m4a** 等 | m4a → mp3 ✗（标签与字节不匹配） |

**关键区分**：

- **文件扩展名 / 容器**（`.m4a`）≠ **API format 标签**（`input_audio.format` 字符串）
- 当前代码把「非 wav 一律标 mp3」当作跨服务商的**最小公约数**
- 但 base64 载荷仍是 **M4A/AAC 原始字节**，并未做 MP3 转码

因此日志里 `format=mp3` 反映的是**协议标签**，不是**实际编码**。

---

### 2.4 是否有风险？

#### 对智谱 GLM

- GLM 只接受 wav/mp3 标签，标 mp3 是已知 workaround
- 部分场景下服务端可能靠文件魔数容错解码 AAC 容器
- 属于「能跑但不严谨」的兼容写法

#### 对豆包 / 火山方舟

根据 [火山方舟「音频理解」文档](https://www.volcengine.com/docs/82379/2377589)：

- Chat API：Base64 填入 `input_audio.data`，格式通过 **`input_audio.format` 单独指定**
- 支持的纯音频格式包括：**mp3、wav、aac、m4a**（及 pcm 等）
- 文档示例中 m4a 文件应使用 `format: "m4a"`，而非 mp3

**风险**：format 标 mp3、实际字节是 m4a/AAC 时，严格解码器可能报格式错误或识别质量下降。  
**正确做法**：m4a 录音 → `format: "m4a"`（或 `aac`）；若坚持标 mp3，则应先转码为真实 MP3 字节。

---

### 2.5 问题一最终答案

| 问题 | 答案 |
|------|------|
| 录音是不是 m4a？ | **是**，`.m4a` + `AudioEncoder.aacLc` |
| 日志为何 format=mp3？ | `_audioFormatForPath` 刻意将非 wav 映射为 mp3，对齐 GLM/OpenAI 双格式限制 |
| 是否应为 m4a？ | **对豆包：是，应标 m4a**；对 GLM：只能标 mp3（或改录 wav/转码 mp3） |
| 当前是否 bug？ | 对 GLM 是**已知兼容策略**；对豆包是**格式标签不匹配**，建议修复 |

---

## 3. 问题二：如何更好兼容 doubao-seed-2-0-mini-260428？

### 3.1 模型与接入前提

| 配置项 | 推荐值 |
|--------|--------|
| Base URL | `https://ark.cn-beijing.volces.com/api/v3` |
| 语音模型（audioModel） | `doubao-seed-2-0-mini-260428`（或控制台创建的 **Endpoint ID**） |
| 识别模式（audioMode） | `multimodalChat`（多模态理解） |
| API Key | 火山方舟 API Key（Bearer 鉴权） |

`doubao-seed-2-0-mini-260428` 属于 Seed 2.0 全模态系列，支持 **文本 + 图像 + 音频 + 视频** 输入（260428 后缀版本具备音频理解能力）。  
参考：[BytePlus 多模态深度思考文档](https://docs.byteplus.com/zh-CN/docs/Byteplus_LAS/Multimodal-Deep-Thinking-Doubao-Seed-2-0)、[火山方舟音频理解](https://www.volcengine.com/docs/82379/2377589)。

---

### 3.2 当前实现与豆包要求的差距

| 维度 | 当前 main 实现 | 豆包 Seed 2.0 期望 | 差距 |
|------|---------------|-------------------|------|
| 音频 format 标签 | m4a 文件 → `mp3` | m4a 文件 → `m4a` | **高优先级** |
| 请求体结构 | OpenAI 风格 `input_audio.data + format` | 兼容，部分 endpoint 仅支持 `input_audio` 不接受 `audio_url` | 当前已用 data 方式 ✓ |
| System Prompt | OpenAI 路径**无** JSON 约束 system 消息 | 结构化抽取任务建议加强 JSON 约束 | 中优先级 |
| `reasoning_effort` | 未传 | Seed 2.0 支持多档思考长度（minimal/low/medium/high） | 中优先级 |
| 响应 `content` 解析 | 直接 `as String` | thinking 模型可能返回 `null` 或数组 | **高优先级** |
| 音频体积限制 | 无前置校验 | Base64 单文件 ≤ 25 MB，时长 ≤ 120 min | 低~中优先级 |
| 传统 STT 路径 | `/audio/transcriptions` multipart | 豆包 STT 是**独立异步 API**，非 Whisper 兼容 | 模式需选对 |

---

### 3.3 推荐改造方案（按优先级）

#### P0 — 按服务商区分 format 映射（最小改动、收益最大）

**改造位置**：[`lib/ai/providers/ai_provider_factory.dart`](../../lib/ai/providers/ai_provider_factory.dart) 的 `_audioFormatForPath`

**建议逻辑**：

```dart
// 伪代码示意，非正式实现
static String _audioFormatForPath(String path, {String? baseUrl}) {
  final ext = path.split('.').last.toLowerCase();
  if (ext == 'wav') return 'wav';
  if (_isVolcengineArk(baseUrl)) {
    // 火山方舟：format 应与真实编码一致
    if (ext == 'm4a') return 'm4a';
    if (ext == 'aac') return 'aac';
    if (ext == 'mp3') return 'mp3';
    return 'm4a'; // 当前默认录音扩展名
  }
  // OpenAI / 智谱：协议仅支持 wav、mp3
  return 'mp3';
}

static bool _isVolcengineArk(String? baseUrl) =>
    baseUrl != null && baseUrl.contains('volces.com');
```

同步修改 [`zhipu_glm_provider.dart`](../../packages/flutter_ai_kit_zhipu/lib/src/zhipu_glm_provider.dart) 仅在智谱路径生效，不影响豆包。

**预期效果**：豆包收到 `format=m4a` + 真实 m4a 字节，解码正确。

---

#### P0 — 增强响应 content 解析

**改造位置**：[`lib/ai/providers/ai_provider_factory.dart`](../../lib/ai/providers/ai_provider_factory.dart) `_audioChatOpenAI`（及 `_chatOpenAI` 等）

**问题**：Seed thinking 模型可能返回：

```json
{ "message": { "content": null, "reasoning_content": "..." } }
```

或 content 为数组。当前 `(message['content'] as String).trim()` 会抛异常或得到空结果。

**建议**：

1. 抽取公共方法 `_extractTextContent(dynamic content)`
2. 优先取 `content` 字符串；若为数组则拼接 `type=text` 块
3. 若 `content` 为空，尝试 `reasoning_content`（仅兜底，账单 JSON 应在 content）
4. 对 null 给出明确 `AIException` 提示

---

#### P1 — 为多模态 OpenAI 兼容路径增加 JSON System Prompt

**对比**：智谱 `_audioChatZhipu` 经 `ZhipuGLMProvider` 在含音频时自动注入：

> 「你必须严格按照要求返回 JSON 格式的结果，不要返回其他任何文字或解释。」

OpenAI 兼容的 `_audioChatOpenAI` **没有**等效 system 消息，豆包可能返回 Markdown 包裹 JSON 或自然语言，增加 [`json_response_parser.dart`](../../lib/ai/core/json_response_parser.dart) 解析失败率。

**建议**：在 `_audioChatOpenAI` 的 messages 中增加与智谱一致的 system 角色，或在 prompt 末尾再次强调「只返回 JSON 数组」。

---

#### P1 — 支持 `reasoning_effort` 参数

豆包 Seed 2.0 系列支持思考长度控制。社区实践（如 [doubao-multimodal-skill](https://github.com/JimLiu/doubao-multimodal-skill)）默认 `minimal` 以降低时延与 token 消耗。

**建议**：

- 在 `AIServiceProviderConfig` 增加可选字段（如 `reasoningEffort`），或
- 对 `baseUrl` 含 `volces.com` 且模型名含 `seed` 时默认传 `reasoning_effort: "minimal"`

账单结构化抽取不需要长链推理，**minimal / low** 即可兼顾速度与成本。

---

#### P2 — 音频转码兜底（可选，兼容性最强）

[JimLiu/doubao-multimodal-skill](https://github.com/JimLiu/doubao-multimodal-skill) 在上送前用 ffmpeg 将任意音频统一转为 **mp3 16kHz mono**。若希望「一套逻辑通吃所有上游」：

- 方案 A：录音仍用 m4a，上送豆包时标 `m4a`（推荐，无转码开销）
- 方案 B：上送前转 mp3，format 标 `mp3`（与 GLM/OpenAI 完全一致，但移动端需引入转码依赖）

BeeCount 当前无 ffmpeg/转码能力，**优先推荐方案 A**；仅当豆包仍报格式错误时再评估方案 B。

---

#### P2 — 请求体大小与时长前置校验

火山方舟 Base64 直传限制：**单文件 ≤ 25 MB，时长 ≤ 120 分钟**。

**建议**：在 `audioChat` 调用前检查 `audio.lengthSync()`，超限给出用户可读提示（「录音过长，请分段或使用按住说话缩短时长」）。  
当前 [`voice_billing_helper.dart`](../../lib/utils/voice_billing_helper.dart) 已有 `_kMaxRecordingSec = 60` 上限，一般不会出现 25 MB 问题，但长段按住说话仍 worth 校验。

---

#### P3 — 配置与 UI 引导

**改造位置**：

- [`lib/pages/ai/ai_provider_manage_page.dart`](../../lib/pages/ai/ai_provider_manage_page.dart)
- [`lib/pages/ai/ai_settings_page.dart`](../../lib/pages/ai/ai_settings_page.dart)

**建议**：

1. 添加豆包/火山方舟预设模板（baseUrl + 模型名提示）
2. 选择多模态 + 豆包模型时，UI 提示需使用带日期后缀的全模态版本（如 `*-260428`）
3. `validateSpeechCapability` 失败时，区分「模型不支持 input_audio」与「format 错误」等具体原因

---

### 3.4 推荐配置示例（豆包 Seed 2.0 Mini）

在 AI 服务商管理中新增自定义服务商：

| 字段 | 值 |
|------|-----|
| 名称 | 豆包 Seed 2.0 Mini |
| Base URL | `https://ark.cn-beijing.volces.com/api/v3` |
| API Key | `<火山方舟 API Key>` |
| 语音模型 | `doubao-seed-2-0-mini-260428` |
| 识别模式 | **多模态理解**（multimodalChat） |
| 文本模型 | 同模型或 `doubao-seed-2-0-mini-260428`（若需共用） |

**期望请求体**（改造 P0 之后）：

```json
{
  "model": "doubao-seed-2-0-mini-260428",
  "reasoning_effort": "minimal",
  "messages": [
    {
      "role": "system",
      "content": "你是一个专业的账单信息提取助手。必须严格返回 JSON 数组，不要返回其他文字。"
    },
    {
      "role": "user",
      "content": [
        { "type": "text", "text": "<PromptBuilder 生成的提取 prompt>" },
        {
          "type": "input_audio",
          "input_audio": {
            "data": "<base64 of m4a file>",
            "format": "m4a"
          }
        }
      ]
    }
  ]
}
```

---

### 3.5 不建议的做法

| 做法 | 原因 |
|------|------|
| 仅改录音为 mp3 而不改 format 映射 | 移动端 `record` 包对 MP3 编码支持因平台而异，不如 m4a 稳定 |
| 用传统 STT 模式调 Seed 2.0 Mini | `/audio/transcriptions` 是 Whisper 风格，豆包 STT 是另一套异步 API |
| 对所有服务商统一标 m4a | OpenAI Chat API 的 format 枚举只有 wav/mp3，标 m4a 会被拒 |
| 忽略 content 为 null 的情况 | thinking 模型下会导致语音记账静默失败 |

---

## 4. 改造影响面评估

| 文件 | 改动类型 | 说明 |
|------|----------|------|
| [`ai_provider_factory.dart`](../../lib/ai/providers/ai_provider_factory.dart) | format 映射、content 解析、system prompt、reasoning_effort | 核心 |
| [`zhipu_glm_provider.dart`](../../packages/flutter_ai_kit_zhipu/lib/src/zhipu_glm_provider.dart) | 保持不变或仅注释澄清 | 智谱路径已稳定 |
| [`ai_extraction_engine.dart`](../../lib/ai/core/ai_extraction_engine.dart) | 通常无需改 | 已正确分流 multimodalChat |
| [`voice_billing_helper.dart`](../../lib/utils/voice_billing_helper.dart) | 可选：大小校验 | 录音格式可维持 m4a |
| [`ai_provider_config.dart`](../../lib/ai/providers/ai_provider_config.dart) | 可选：reasoningEffort 字段 | 配置扩展 |
| 测试 | 新增 format 映射单测、mock 豆包响应解析 | 覆盖 P0/P1 |

---

## 5. 验证清单（改造后）

- [ ] m4a 录音 + 豆包多模态：请求体 `format=m4a`，返回可解析 JSON 账单
- [ ] m4a 录音 + 智谱多模态：仍 `format=mp3`，行为与改造前一致
- [ ] m4a 录音 + 传统 STT（Whisper 兼容服务商）：`/audio/transcriptions` 正常
- [ ] 豆包返回 `content: null` 时有明确错误提示，不静默失败
- [ ] `validateSpeechCapability` 在豆包 endpoint 上可通过（静音 wav 测试音频）
- [ ] 日志中 format 与文件扩展名/上游要求一致，便于排查

---

## 6. 参考资料

- [火山方舟 · 音频理解（2377589）](https://www.volcengine.com/docs/82379/2377589)
- [BytePlus · Multimodal Deep Thinking (Doubao-Seed-2.0)](https://docs.byteplus.com/zh-CN/docs/Byteplus_LAS/Multimodal-Deep-Thinking-Doubao-Seed-2-0)
- [JimLiu/doubao-multimodal-skill](https://github.com/JimLiu/doubao-multimodal-skill) — 社区豆包多模态 CLI 参考实现
- [OpenAI input_audio format 定义（仅 wav/mp3）](https://github.com/openai/openai-python/blob/v1.52.2/src/openai/types/chat/chat_completion_content_part_input_audio_param.py)
- 本仓库设计评审：[voice-billing-357-252-review.md](voice-billing-357-252-review.md)

---

## 7. 代码质量自检（分析结论）

- [x] **边界条件**：format 标签与字节不一致（m4a→mp3）是豆包场景主要风险；content 为 null 需处理
- [x] **无内存泄漏**：分析阶段无新增运行时资源
- [x] **线程安全**：format 映射为无状态纯函数，改造后仍安全
- [x] **主要逻辑路径**：multimodalChat → audioChat → _audioChatOpenAI 路径已梳理；传统 STT 路径不受影响