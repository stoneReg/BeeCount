import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_constants.dart';

/// 深度思考档位
enum AIReasoningLevel {
  off,
  low,
  medium,
  high,
}

/// 深度思考厂商协议（用户显式选择，不通过 baseUrl 推断）
enum AIReasoningVendor {
  none,
  volcengine,
  zhipu,
  openaiCompat,
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

/// 深度思考厂商协议与存储字符串互转
extension AIReasoningVendorCodec on AIReasoningVendor {
  String get storageValue {
    switch (this) {
      case AIReasoningVendor.none:
        return 'none';
      case AIReasoningVendor.volcengine:
        return 'volcengine';
      case AIReasoningVendor.zhipu:
        return 'zhipu';
      case AIReasoningVendor.openaiCompat:
        return 'openai_compat';
    }
  }

  static AIReasoningVendor fromStorage(String? value) {
    switch (value) {
      case 'volcengine':
        return AIReasoningVendor.volcengine;
      case 'zhipu':
        return AIReasoningVendor.zhipu;
      case 'openai_compat':
        return AIReasoningVendor.openaiCompat;
      case 'none':
      default:
        return AIReasoningVendor.none;
    }
  }
}

/// 根据用户配置的厂商协议与档位组装 chat/completions 额外 body 字段。
class ReasoningAdapter {
  ReasoningAdapter._();

  /// 从 SharedPreferences 读取深度思考配置
  static Future<({AIReasoningLevel level, AIReasoningVendor vendor})>
      loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      level: AIReasoningLevelCodec.fromStorage(
        prefs.getString(AIConstants.keyAiReasoningLevel),
      ),
      vendor: AIReasoningVendorCodec.fromStorage(
        prefs.getString(AIConstants.keyAiReasoningVendor),
      ),
    );
  }

  /// 按 vendor + level 生成需 merge 进请求 body 的字段；无需传时返回 null。
  static Map<String, dynamic>? buildExtraBody({
    required AIReasoningLevel level,
    required AIReasoningVendor vendor,
  }) {
    if (level == AIReasoningLevel.off || vendor == AIReasoningVendor.none) {
      return null;
    }

    switch (vendor) {
      case AIReasoningVendor.volcengine:
        final effort = _volcengineReasoningEffort(level);
        if (effort == null) return null;
        return {'reasoning_effort': effort};
      case AIReasoningVendor.zhipu:
        if (kDebugMode) {
          debugPrint(
            '[ReasoningAdapter] 智谱 GLM 多模态路径暂不支持深度思考参数',
          );
        }
        return null;
      case AIReasoningVendor.openaiCompat:
        // 首版 OpenAI 兼容音频路径多数无 reasoning 参数，预留扩展
        return null;
      case AIReasoningVendor.none:
        return null;
    }
  }

  /// 火山方舟 / 豆包 reasoning_effort 映射
  static String? _volcengineReasoningEffort(AIReasoningLevel level) {
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
