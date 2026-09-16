import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/ai/providers/ai_reasoning_adapter.dart';

void main() {
  group('ReasoningAdapter.buildExtraBody', () {
    test('off 返回 null（omit 语义）', () {
      expect(
        ReasoningAdapter.buildExtraBody(level: AIReasoningLevel.off),
        isNull,
      );
    });

    test('档位映射为标准 reasoning_effort', () {
      expect(
        ReasoningAdapter.buildExtraBody(level: AIReasoningLevel.low),
        {'reasoning_effort': 'minimal'},
      );
      expect(
        ReasoningAdapter.buildExtraBody(level: AIReasoningLevel.medium),
        {'reasoning_effort': 'medium'},
      );
      expect(
        ReasoningAdapter.buildExtraBody(level: AIReasoningLevel.high),
        {'reasoning_effort': 'high'},
      );
    });
  });

  group('AIReasoningLevelCodec', () {
    test('未知值兜底 off', () {
      expect(
        AIReasoningLevelCodec.fromStorage('unknown'),
        AIReasoningLevel.off,
      );
    });
  });
}
