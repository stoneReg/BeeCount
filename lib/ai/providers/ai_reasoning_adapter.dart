import 'package:shared_preferences/shared_preferences.dart';

import 'ai_constants.dart';

/// 深度思考档位
enum AIReasoningLevel {
  off,
  low,
  medium,
  high,
}

/// 深度思考档位与存储字符串互转
extension AIReasoningLevelCodec on AIReasoningLevel {
  String get storageValue {
    switch (this) {
      case AIReasoningLevel.off:
        return 'off';
      case AIReasoningLevel.low:
        return 'low';
      case AIReasoningLevel.medium:
        return 'medium';
      case AIReasoningLevel.high:
        return 'high';
    }
  }

  static AIReasoningLevel fromStorage(String? value) {
    switch (value) {
      case 'low':
        return AIReasoningLevel.low;
      case 'medium':
        return AIReasoningLevel.medium;
      case 'high':
        return AIReasoningLevel.high;
      case 'off':
      default:
        return AIReasoningLevel.off;
    }
  }
}

/// 根据档位组装 chat/completions 额外 body 字段（标准 reasoning_effort）。
class ReasoningAdapter {
  ReasoningAdapter._();

  static Future<AIReasoningLevel> loadLevelFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return AIReasoningLevelCodec.fromStorage(
      prefs.getString(AIConstants.keyAiReasoningLevel),
    );
  }

  /// 按档位生成需 merge 进请求 body 的字段；关闭时不传参（omit 语义）。
  static Map<String, dynamic>? buildExtraBody({
    required AIReasoningLevel level,
  }) {
    final effort = _reasoningEffort(level);
    if (effort == null) return null;
    return {'reasoning_effort': effort};
  }

  static String? _reasoningEffort(AIReasoningLevel level) {
    switch (level) {
      case AIReasoningLevel.off:
        return null;
      case AIReasoningLevel.low:
        return 'minimal';
      case AIReasoningLevel.medium:
        return 'medium';
      case AIReasoningLevel.high:
        return 'high';
    }
  }
}
