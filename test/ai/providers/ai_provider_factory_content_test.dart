import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/ai/providers/ai_provider_factory.dart';

void main() {
  group('AIProviderFactory.parseOpenAiChatContent', () {
    test('解析字符串 content', () {
      final text = AIProviderFactory.parseOpenAiChatContent({
        'choices': [
          {
            'message': {'content': '  {"amount": 10}  '},
          },
        ],
      });
      expect(text, '{"amount": 10}');
    });

    test('解析 content part 数组', () {
      final text = AIProviderFactory.parseOpenAiChatContent({
        'choices': [
          {
            'message': {
              'content': [
                {'type': 'text', 'text': 'hello '},
                {'type': 'text', 'text': 'world'},
              ],
            },
          },
        ],
      });
      expect(text, 'hello world');
    });

    test('空 choices / 空 content 抛 AIException', () {
      expect(
        () => AIProviderFactory.parseOpenAiChatContent({'choices': []}),
        throwsA(isA<AIException>()),
      );
      expect(
        () => AIProviderFactory.parseOpenAiChatContent({
          'choices': [
            {'message': {'content': ''}},
          ],
        }),
        throwsA(isA<AIException>()),
      );
    });
  });

  group('AIProviderFactory.buildOpenAiVisionChatBody + reasoning', () {
    test('基础 body 含 model 与 image_url', () {
      final body = AIProviderFactory.buildOpenAiVisionChatBody(
        visionModel: 'doubao-seed-2-0-mini-260428',
        prompt: '分析账单',
        base64Image: 'abc123',
      );
      expect(body['model'], 'doubao-seed-2-0-mini-260428');
      final messages = body['messages'] as List;
      final content = (messages.first as Map)['content'] as List;
      expect(content.any((p) => (p as Map)['type'] == 'image_url'), isTrue);
    });

    test('low + volcengine 合并后含 reasoning_effort minimal', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({
        'ai_reasoning_level': 'low',
        'ai_reasoning_vendor': 'volcengine',
      });

      final body = AIProviderFactory.buildOpenAiVisionChatBody(
        visionModel: 'doubao-seed-2-0-mini-260428',
        prompt: '分析账单',
        base64Image: 'abc123',
      );
      await AIProviderFactory.mergeReasoningIntoBodyForTest(body);

      expect(body['reasoning_effort'], 'minimal');
    });

    test('off 时不含 reasoning_effort', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({
        'ai_reasoning_level': 'off',
        'ai_reasoning_vendor': 'volcengine',
      });

      final body = AIProviderFactory.buildOpenAiVisionChatBody(
        visionModel: 'doubao-seed-2-0-mini-260428',
        prompt: '分析账单',
        base64Image: 'abc123',
      );
      await AIProviderFactory.mergeReasoningIntoBodyForTest(body);

      expect(body.containsKey('reasoning_effort'), isFalse);
    });
  });

  group('AIProviderFactory.audioFormatForPath', () {
    test('扩展名与 format 严格一致', () {
      expect(
        AIProviderFactory.audioFormatForPath('/tmp/voice.wav'),
        'wav',
      );
      expect(
        AIProviderFactory.audioFormatForPath('/tmp/voice.m4a'),
        'm4a',
      );
      expect(
        AIProviderFactory.audioFormatForPath('/tmp/voice.mp3'),
        'mp3',
      );
    });
  });
}
