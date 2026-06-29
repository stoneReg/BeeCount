import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/ai/providers/ai_constants.dart';
import 'package:beecount/ai/providers/ai_provider_manager.dart';

/// #252 PR A：静音阈值随 AI 配置多设备同步
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AIProviderManager 静音阈值同步', () {
    test('snapshotForSync 带上 voice_silence_timeout_ms', () async {
      SharedPreferences.setMockInitialValues({
        AIConstants.keyVoiceSilenceTimeoutMs: 1800,
      });

      final snapshot = await AIProviderManager.snapshotForSync();
      expect(snapshot['voice_silence_timeout_ms'], 1800);
    });

    test('applyFromServer 落地静音阈值', () async {
      SharedPreferences.setMockInitialValues({});

      await AIProviderManager.applyFromServer({
        'voice_silence_timeout_ms': 2200,
      });

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(AIConstants.keyVoiceSilenceTimeoutMs), 2200);
    });

    test('applyFromServer 缺省语音字段时不覆盖本地', () async {
      SharedPreferences.setMockInitialValues({
        AIConstants.keyVoiceSilenceTimeoutMs: 1500,
      });

      await AIProviderManager.applyFromServer({'strategy': 'cloud_first'});

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(AIConstants.keyVoiceSilenceTimeoutMs), 1500);
    });
  });
}
