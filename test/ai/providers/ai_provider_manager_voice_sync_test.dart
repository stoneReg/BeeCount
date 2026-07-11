import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/ai/providers/ai_constants.dart';
import 'package:beecount/ai/providers/ai_provider_manager.dart';

/// #252：语音设置随 AI 配置多设备同步
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AIProviderManager 语音设置同步', () {
    test('snapshotForSync 带上 voice_trigger_mode / voice_silence_timeout_ms',
        () async {
      SharedPreferences.setMockInitialValues({
        AIConstants.keyVoiceTriggerMode: 'hold_to_talk',
        AIConstants.keyVoiceSilenceTimeoutMs: 1800,
      });

      final snapshot = await AIProviderManager.snapshotForSync();
      expect(snapshot['voice_trigger_mode'], 'hold_to_talk');
      expect(snapshot['voice_silence_timeout_ms'], 1800);
    });

    test('applyFromServer 落地语音设置', () async {
      SharedPreferences.setMockInitialValues({});

      await AIProviderManager.applyFromServer({
        'voice_trigger_mode': 'hold_to_talk',
        'voice_silence_timeout_ms': 2200,
      });

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AIConstants.keyVoiceTriggerMode), 'hold_to_talk');
      expect(prefs.getInt(AIConstants.keyVoiceSilenceTimeoutMs), 2200);
    });

    test('snapshotForSync 未设置语音 key 时不携带,避免回推覆盖 server', () async {
      SharedPreferences.setMockInitialValues({});

      final snapshot = await AIProviderManager.snapshotForSync();
      expect(snapshot.containsKey('voice_trigger_mode'), isFalse);
      expect(snapshot.containsKey('voice_silence_timeout_ms'), isFalse);
    });

    test('applyFromServer 缺省语音字段时不覆盖本地', () async {
      SharedPreferences.setMockInitialValues({
        AIConstants.keyVoiceTriggerMode: 'auto',
        AIConstants.keyVoiceSilenceTimeoutMs: 1500,
      });

      await AIProviderManager.applyFromServer({'strategy': 'cloud_first'});

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AIConstants.keyVoiceTriggerMode), 'auto');
      expect(prefs.getInt(AIConstants.keyVoiceSilenceTimeoutMs), 1500);
    });

    test('snapshotForSync 携带 audio_mode（仅 containsKey 时）', () async {
      SharedPreferences.setMockInitialValues({
        AIConstants.keyAudioMode: 'multimodal_chat',
      });

      final snapshot = await AIProviderManager.snapshotForSync();
      expect(snapshot['audio_mode'], 'multimodal_chat');
    });

    test('snapshotForSync 未设置 audio_mode 时不携带', () async {
      SharedPreferences.setMockInitialValues({});

      final snapshot = await AIProviderManager.snapshotForSync();
      expect(snapshot.containsKey('audio_mode'), isFalse);
    });

    test('applyFromServer 落地 audio_mode', () async {
      SharedPreferences.setMockInitialValues({});

      await AIProviderManager.applyFromServer({
        'audio_mode': 'multimodal_chat',
      });

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AIConstants.keyAudioMode), 'multimodal_chat');
    });

    test('mergeSnapshotWithServerAiConfig 补回 server audio_mode', () {
      final local = <String, dynamic>{'providers': [], 'binding': {}};
      final merged = AIProviderManager.mergeSnapshotWithServerAiConfig(
        local,
        {'audio_mode': 'multimodal_chat'},
      );
      expect(merged['audio_mode'], 'multimodal_chat');
    });

    test('mergeSnapshotWithServerAiConfig 本地已有 audio_mode 不被 server 覆盖', () {
      final local = <String, dynamic>{
        'audio_mode': 'transcription',
        'providers': [],
      };
      final merged = AIProviderManager.mergeSnapshotWithServerAiConfig(
        local,
        {'audio_mode': 'multimodal_chat'},
      );
      expect(merged['audio_mode'], 'transcription');
    });

    test('applyFromServer 从旧版 provider.audioMode 迁移全局 audio_mode', () async {
      SharedPreferences.setMockInitialValues({});

      await AIProviderManager.applyFromServer({
        'providers': [
          {
            'id': 'speech_p',
            'name': 'Speech',
            'apiKey': 'k',
            'audioModel': 'gpt-4o-audio',
            'audioMode': 'multimodal_chat',
          },
        ],
        'binding': {'speechProviderId': 'speech_p'},
      });

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AIConstants.keyAudioMode), 'multimodal_chat');
    });

    test('applyFromServer 顶层 audio_mode 优先于 provider.audioMode', () async {
      SharedPreferences.setMockInitialValues({});

      await AIProviderManager.applyFromServer({
        'audio_mode': 'transcription',
        'providers': [
          {
            'id': 'speech_p',
            'name': 'Speech',
            'audioMode': 'multimodal_chat',
          },
        ],
        'binding': {'speechProviderId': 'speech_p'},
      });

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AIConstants.keyAudioMode), 'transcription');
    });
  });
}
