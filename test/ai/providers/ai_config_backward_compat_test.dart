import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/ai/providers/ai_provider_manager.dart';

/// 新老 JSON 兼容：旧 snapshot 不含 mobile-only 新字段时不应被 merge 污染。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AI 配置向后兼容', () {
    test('旧 server JSON 无 audioMode/reasoning 时不崩溃', () async {
      SharedPreferences.setMockInitialValues({});

      await AIProviderManager.applyFromServer({
        'providers': [
          {
            'id': 'zhipu_glm',
            'name': '智谱GLM',
            'isBuiltIn': true,
            'apiKey': 'k',
            'baseUrl': 'https://open.bigmodel.cn/api/paas/v4',
            'textModel': 'glm-4-flash',
            'visionModel': 'glm-4v-flash',
            'audioModel': 'glm-4-voice',
          },
        ],
        'binding': {
          'textProviderId': 'zhipu_glm',
          'visionProviderId': 'zhipu_glm',
          'speechProviderId': 'zhipu_glm',
        },
      });

      final providers = await AIProviderManager.getProviders();
      expect(providers.first.audioMode.name, 'transcription');
    });

    test('旧 App snapshot 不含 reasoning key', () async {
      SharedPreferences.setMockInitialValues({});

      final snapshot = await AIProviderManager.snapshotForSync();
      expect(snapshot.containsKey('ai_reasoning_level'), isFalse);
      expect(snapshot.containsKey('ai_reasoning_vendor'), isFalse);
    });
  });
}
