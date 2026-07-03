import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/ai/providers/ai_provider_config.dart';

/// #357：服务商配置新增 audioMode（语音识别模式）。
/// 验证默认值、JSON 兼容（旧配置无该字段）、序列化往返与 copyWith。
void main() {
  group('AIServiceProviderConfig.audioMode', () {
    test('默认值为 transcription，保证存量行为不变', () {
      final cfg = AIServiceProviderConfig(
        id: 'x',
        name: 'x',
        createdAt: DateTime(2024),
      );
      expect(cfg.audioMode, AIAudioMode.transcription);
    });

    test('旧 JSON（无 audioMode 字段）反序列化兜底为 transcription', () {
      final cfg = AIServiceProviderConfig.fromJson({
        'id': 'legacy',
        'name': '旧服务商',
        'apiKey': 'k',
        'baseUrl': 'https://example.com/v1',
        'audioModel': 'whisper-1',
      });
      expect(cfg.audioMode, AIAudioMode.transcription);
    });

    test('toJson / fromJson 往返保持 multimodalChat', () {
      final cfg = AIServiceProviderConfig(
        id: 'm',
        name: '多模态',
        apiKey: 'k',
        audioModel: 'glm-4-voice',
        audioMode: AIAudioMode.multimodalChat,
        createdAt: DateTime(2024),
      );
      final restored = AIServiceProviderConfig.fromJson(cfg.toJson());
      expect(restored.audioMode, AIAudioMode.multimodalChat);
    });

    test('copyWith 可单独修改 audioMode', () {
      final cfg = AIServiceProviderConfig(
        id: 'c',
        name: 'c',
        createdAt: DateTime(2024),
      );
      final updated = cfg.copyWith(audioMode: AIAudioMode.multimodalChat);
      expect(updated.audioMode, AIAudioMode.multimodalChat);
      // 其它字段不变
      expect(updated.id, 'c');
    });

    test('AIAudioModeCodec：未知/空值兜底 transcription，往返一致', () {
      expect(AIAudioModeCodec.fromStorage(null), AIAudioMode.transcription);
      expect(AIAudioModeCodec.fromStorage('weird'), AIAudioMode.transcription);
      expect(
        AIAudioModeCodec.fromStorage(AIAudioMode.multimodalChat.storageValue),
        AIAudioMode.multimodalChat,
      );
    });
  });
}
