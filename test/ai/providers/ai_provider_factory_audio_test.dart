import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/ai/providers/ai_provider_factory.dart';

void main() {
  group('AIProviderFactory audio helpers', () {
    test('audioFormatForPath：wav/mp3/未知扩展名', () {
      expect(
        AIProviderFactory.audioFormatForPath('/tmp/a.wav'),
        'wav',
      );
      expect(
        AIProviderFactory.audioFormatForPath('/tmp/a.mp3'),
        'mp3',
      );
      expect(
        AIProviderFactory.audioFormatForPath('/tmp/a.unknown'),
        'wav',
      );
    });

    test('parseOpenAiChatContent：字符串 content', () {
      final text = AIProviderFactory.parseOpenAiChatContent({
        'choices': [
          {
            'message': {'content': '  {"amount": 1}  '},
          },
        ],
      });
      expect(text, '{"amount": 1}');
    });

    test('parseOpenAiChatContent：parts 数组', () {
      final text = AIProviderFactory.parseOpenAiChatContent({
        'choices': [
          {
            'message': {
              'content': [
                {'type': 'text', 'text': 'hello'},
                {'type': 'text', 'text': ' world'},
              ],
            },
          },
        ],
      });
      expect(text, 'hello world');
    });

    test('parseOpenAiChatContent：空 content 抛 AIException', () {
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
}
