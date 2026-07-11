import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/ai/providers/ai_provider_config.dart';

/// 全局 audio_mode：枚举编解码与默认值。
void main() {
  group('AIAudioModeCodec', () {
    test('默认/未知值兜底 transcription', () {
      expect(AIAudioModeCodec.fromStorage(null), AIAudioMode.transcription);
      expect(AIAudioModeCodec.fromStorage('weird'), AIAudioMode.transcription);
    });

    test('multimodal_chat 往返一致', () {
      expect(
        AIAudioModeCodec.fromStorage(AIAudioMode.multimodalChat.storageValue),
        AIAudioMode.multimodalChat,
      );
      expect(AIAudioMode.transcription.storageValue, 'transcription');
      expect(AIAudioMode.multimodalChat.storageValue, 'multimodal_chat');
    });
  });
}
