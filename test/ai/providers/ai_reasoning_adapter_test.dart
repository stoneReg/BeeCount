import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/ai/providers/ai_reasoning_adapter.dart';

void main() {
  group('ReasoningAdapter.buildExtraBody', () {
    test('off 或 none 不传任何字段', () {
      expect(
        ReasoningAdapter.buildExtraBody(
          level: AIReasoningLevel.off,
          vendor: AIReasoningVendor.volcengine,
        ),
        isNull,
      );
      expect(
        ReasoningAdapter.buildExtraBody(
          level: AIReasoningLevel.high,
          vendor: AIReasoningVendor.none,
        ),
        isNull,
      );
    });

    test('volcengine 映射 reasoning_effort', () {
      expect(
        ReasoningAdapter.buildExtraBody(
          level: AIReasoningLevel.low,
          vendor: AIReasoningVendor.volcengine,
        ),
        {'reasoning_effort': 'minimal'},
      );
      expect(
        ReasoningAdapter.buildExtraBody(
          level: AIReasoningLevel.medium,
          vendor: AIReasoningVendor.volcengine,
        ),
        {'reasoning_effort': 'medium'},
      );
      expect(
        ReasoningAdapter.buildExtraBody(
          level: AIReasoningLevel.high,
          vendor: AIReasoningVendor.volcengine,
        ),
        {'reasoning_effort': 'high'},
      );
    });

    test('zhipu / openai_compat 首版不传', () {
      expect(
        ReasoningAdapter.buildExtraBody(
          level: AIReasoningLevel.medium,
          vendor: AIReasoningVendor.zhipu,
        ),
        isNull,
      );
      expect(
        ReasoningAdapter.buildExtraBody(
          level: AIReasoningLevel.low,
          vendor: AIReasoningVendor.openaiCompat,
        ),
        isNull,
      );
    });
  });

  group('AIReasoningLevelCodec / AIReasoningVendorCodec', () {
    test('未知值兜底', () {
      expect(AIReasoningLevelCodec.fromStorage('weird'), AIReasoningLevel.off);
      expect(AIReasoningVendorCodec.fromStorage('weird'), AIReasoningVendor.none);
    });

    test('往返一致', () {
      expect(
        AIReasoningLevelCodec.fromStorage(AIReasoningLevel.high.storageValue),
        AIReasoningLevel.high,
      );
      expect(
        AIReasoningVendorCodec.fromStorage(
            AIReasoningVendor.openaiCompat.storageValue),
        AIReasoningVendor.openaiCompat,
      );
    });
  });
}
