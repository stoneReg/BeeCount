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
      final providers = snapshot['providers'] as List;
      expect(providers, isNotEmpty);
      expect((providers.first as Map)['audioMode'], 'transcription');
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

    test('snapshotForSync 携带 reasoning 字段（仅 containsKey 时）', () async {
      SharedPreferences.setMockInitialValues({
        AIConstants.keyAiReasoningLevel: 'medium',
        AIConstants.keyAiReasoningVendor: 'volcengine',
      });

      final snapshot = await AIProviderManager.snapshotForSync();
      expect(snapshot['ai_reasoning_level'], 'medium');
      expect(snapshot['ai_reasoning_vendor'], 'volcengine');
    });

    test('snapshotForSync 未设置 reasoning 时不携带', () async {
      SharedPreferences.setMockInitialValues({});

      final snapshot = await AIProviderManager.snapshotForSync();
      expect(snapshot.containsKey('ai_reasoning_level'), isFalse);
      expect(snapshot.containsKey('ai_reasoning_vendor'), isFalse);
    });

    test('applyFromServer 落地 reasoning 且缺省不覆盖本地', () async {
      SharedPreferences.setMockInitialValues({
        AIConstants.keyAiReasoningLevel: 'low',
        AIConstants.keyAiReasoningVendor: 'volcengine',
      });

      await AIProviderManager.applyFromServer({
        'ai_reasoning_level': 'high',
        'ai_reasoning_vendor': 'volcengine',
      });

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AIConstants.keyAiReasoningLevel), 'high');
      expect(prefs.getString(AIConstants.keyAiReasoningVendor), 'volcengine');

      await AIProviderManager.applyFromServer({'strategy': 'cloud_first'});
      expect(prefs.getString(AIConstants.keyAiReasoningLevel), 'high');
      expect(prefs.getString(AIConstants.keyAiReasoningVendor), 'volcengine');
    });
  });
}
