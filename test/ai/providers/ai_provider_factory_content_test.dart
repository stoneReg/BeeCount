import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/ai/providers/ai_constants.dart';
import 'package:beecount/ai/providers/ai_provider_factory.dart';
import 'package:beecount/ai/providers/ai_reasoning_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mergeReasoningIntoBodyForTest', () {
    test('high 档位合并 reasoning_effort', () async {
      SharedPreferences.setMockInitialValues({
        AIConstants.keyAiReasoningLevel: 'high',
      });

      final body = <String, dynamic>{'model': 'gpt-4o'};
      await AIProviderFactory.mergeReasoningIntoBodyForTest(body);
      expect(body['reasoning_effort'], 'high');
    });

    test('off 不写入 reasoning_effort', () async {
      SharedPreferences.setMockInitialValues({
        AIConstants.keyAiReasoningLevel: 'off',
      });

      final body = <String, dynamic>{'model': 'gpt-4o'};
      await AIProviderFactory.mergeReasoningIntoBodyForTest(body);
      expect(body.containsKey('reasoning_effort'), isFalse);
    });

    test('low 档位合并 minimal', () async {
      SharedPreferences.setMockInitialValues({
        AIConstants.keyAiReasoningLevel: 'low',
      });

      final body = <String, dynamic>{'model': 'gpt-4o'};
      await AIProviderFactory.mergeReasoningIntoBodyForTest(body);
      expect(body['reasoning_effort'], 'minimal');
    });
  });

  group('buildOpenAiVisionChatBody', () {
    test('不含 reasoning 字段', () {
      final body = AIProviderFactory.buildOpenAiVisionChatBody(
        visionModel: 'gpt-4o',
        prompt: 'hi',
        base64Image: 'abc',
      );
      expect(body['model'], 'gpt-4o');
      expect(body.containsKey('reasoning_effort'), isFalse);
    });
  });

  group('parseOpenAiChatContent', () {
    test('parts 数组 content', () {
      final text = AIProviderFactory.parseOpenAiChatContent({
        'choices': [
          {
            'message': {
              'content': [
                {'text': 'part1'},
                {'text': 'part2'},
              ],
            },
          },
        ],
      });
      expect(text, 'part1part2');
    });

    test('null content 抛 AIException', () {
      expect(
        () => AIProviderFactory.parseOpenAiChatContent({
          'choices': [
            {'message': {}},
          ],
        }),
        throwsA(isA<AIException>()),
      );
    });
  });
}
