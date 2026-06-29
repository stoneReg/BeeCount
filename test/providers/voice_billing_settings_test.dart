import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/providers/voice_billing_providers.dart';

/// #252 PR A：静音阈值可调与本地持久化
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoiceBillingSettings 默认值', () {
    test('默认 1500ms', () {
      const s = VoiceBillingSettings();
      expect(s.silenceTimeoutMs, 1500);
    });
  });

  group('VoiceBillingSettingsNotifier', () {
    test('阈值越界自动夹取到合法区间并持久化', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(voiceBillingSettingsProvider.notifier);
      await notifier.ensureLoaded();

      await notifier.setSilenceTimeoutMs(99999);
      expect(
        container.read(voiceBillingSettingsProvider).silenceTimeoutMs,
        VoiceBillingSettings.maxSilenceTimeoutMs,
      );

      await notifier.setSilenceTimeoutMs(10);
      expect(
        container.read(voiceBillingSettingsProvider).silenceTimeoutMs,
        VoiceBillingSettings.minSilenceTimeoutMs,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('voice_silence_timeout_ms'),
          VoiceBillingSettings.minSilenceTimeoutMs);
    });

    test('从 prefs 加载已保存的阈值', () async {
      SharedPreferences.setMockInitialValues({
        'voice_silence_timeout_ms': 2200,
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(voiceBillingSettingsProvider.notifier);
      await notifier.ensureLoaded();
      expect(
        container.read(voiceBillingSettingsProvider).silenceTimeoutMs,
        2200,
      );
    });
  });
}
