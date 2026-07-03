import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/ai/providers/ai_constants.dart';
import 'package:beecount/ai/providers/ai_provider_config.dart';
import 'package:beecount/ai/providers/ai_provider_manager.dart';

/// 新 App ↔ 老 Cloud：server 对 ai_config 是 JSON 透传，验证整包往返不丢新字段。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('新 App 与老 Cloud JSON 透传往返', () {
    test('设备 A snapshot → 模拟 server 存取 → 设备 B applyFromServer', () async {
      // 设备 A：已配置多模态 + 语音 + 深度思考
      SharedPreferences.setMockInitialValues({
        AIConstants.keyVoiceTriggerMode: 'hold_to_talk',
        AIConstants.keyVoiceSilenceTimeoutMs: 2000,
        AIConstants.keyAiReasoningLevel: 'low',
        AIConstants.keyAiReasoningVendor: 'volcengine',
        'ai_providers_v2': '''
[{"id":"zhipu_glm","name":"智谱GLM","isBuiltIn":true,"apiKey":"k","baseUrl":"https://open.bigmodel.cn/api/paas/v4","textModel":"glm-4-flash","visionModel":"glm-4v-flash","audioModel":"glm-4-voice","audioMode":"multimodal_chat","createdAt":"2024-01-01T00:00:00.000"}]
''',
        'ai_capability_binding_v2':
            '{"textProviderId":"zhipu_glm","visionProviderId":"zhipu_glm","speechProviderId":"zhipu_glm"}',
      });

      final pushed = await AIProviderManager.snapshotForSync();

      // 模拟老 Cloud：整包 JSON 写入 DB 再读出，不做字段裁剪
      final serverBlob = Map<String, dynamic>.from(pushed);

      // 设备 B：空本地，从 server 拉取
      SharedPreferences.setMockInitialValues({});
      await AIProviderManager.applyFromServer(serverBlob);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AIConstants.keyVoiceTriggerMode), 'hold_to_talk');
      expect(prefs.getInt(AIConstants.keyVoiceSilenceTimeoutMs), 2000);
      expect(prefs.getString(AIConstants.keyAiReasoningLevel), 'low');
      expect(prefs.getString(AIConstants.keyAiReasoningVendor), 'volcengine');

      final providers = await AIProviderManager.getProviders();
      expect(providers.first.audioMode, AIAudioMode.multimodalChat);
    });

    test('设备 B 未配置过 reasoning 时 snapshot 不携带空 key（防覆盖 server）', () async {
      SharedPreferences.setMockInitialValues({
        'ai_providers_v2': '''
[{"id":"zhipu_glm","name":"智谱GLM","isBuiltIn":true,"apiKey":"k","baseUrl":"https://open.bigmodel.cn/api/paas/v4","textModel":"glm-4-flash","visionModel":"glm-4v-flash","audioModel":"glm-4-voice","audioMode":"multimodal_chat","createdAt":"2024-01-01T00:00:00.000"}]
''',
        'ai_capability_binding_v2':
            '{"textProviderId":"zhipu_glm","visionProviderId":"zhipu_glm","speechProviderId":"zhipu_glm"}',
      });

      final snapshot = await AIProviderManager.snapshotForSync();
      expect(snapshot.containsKey('ai_reasoning_level'), isFalse);
      expect(snapshot.containsKey('ai_reasoning_vendor'), isFalse);
      expect(snapshot.containsKey('voice_trigger_mode'), isFalse);
    });
  });
}
