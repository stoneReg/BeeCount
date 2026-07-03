import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ai/providers/ai_constants.dart';
import '../ai/providers/ai_provider_manager.dart';
import '../ai/providers/ai_reasoning_adapter.dart';
import '../services/system/logger_service.dart';

/// 深度思考全局设置
class AIReasoningSettings {
  final AIReasoningLevel level;
  final AIReasoningVendor vendor;

  const AIReasoningSettings({
    this.level = AIReasoningLevel.off,
    this.vendor = AIReasoningVendor.none,
  });

  AIReasoningSettings copyWith({
    AIReasoningLevel? level,
    AIReasoningVendor? vendor,
  }) {
    return AIReasoningSettings(
      level: level ?? this.level,
      vendor: vendor ?? this.vendor,
    );
  }

  /// 档位非关闭时是否已选择有效厂商协议
  bool get isVendorRequiredButMissing =>
      level != AIReasoningLevel.off && vendor == AIReasoningVendor.none;
}

/// 深度思考设置 Notifier
class AIReasoningSettingsNotifier extends StateNotifier<AIReasoningSettings> {
  final Completer<void> _loadCompleter = Completer<void>();

  AIReasoningSettingsNotifier() : super(const AIReasoningSettings()) {
    _load();
  }

  Future<void> ensureLoaded() => _loadCompleter.future;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final level = AIReasoningLevelCodec.fromStorage(
      prefs.getString(AIConstants.keyAiReasoningLevel),
    );
    final vendor = AIReasoningVendorCodec.fromStorage(
      prefs.getString(AIConstants.keyAiReasoningVendor),
    );

    if (!_loadCompleter.isCompleted) {
      _loadCompleter.complete();
    }
    if (!mounted) return;
    state = AIReasoningSettings(level: level, vendor: vendor);
  }

  /// 仅更新 UI 档位，不写 prefs（待用户选厂商后一并保存）
  void previewLevel(AIReasoningLevel level) {
    if (level == AIReasoningLevel.off) return;
    state = state.copyWith(level: level);
  }

  /// 保存深度思考档位与厂商协议；档位非关闭时必须已选厂商。
  /// 返回 false 表示校验未通过（未选厂商）。
  Future<bool> save({
    required AIReasoningLevel level,
    required AIReasoningVendor vendor,
  }) async {
    final effectiveVendor =
        level == AIReasoningLevel.off ? AIReasoningVendor.none : vendor;
    if (level != AIReasoningLevel.off &&
        effectiveVendor == AIReasoningVendor.none) {
      return false;
    }

    state = AIReasoningSettings(level: level, vendor: effectiveVendor);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        AIConstants.keyAiReasoningLevel, level.storageValue);
    if (level == AIReasoningLevel.off) {
      await prefs.remove(AIConstants.keyAiReasoningVendor);
    } else {
      await prefs.setString(
          AIConstants.keyAiReasoningVendor, effectiveVendor.storageValue);
    }
    _notifyConfigChanged();
    return true;
  }

  Future<void> reload() => _load();

  void _notifyConfigChanged() {
    try {
      AIProviderManager.onConfigChanged?.call();
    } catch (e, st) {
      logger.warning('AIReasoningSettings', 'onConfigChanged 触发失败: $e', st);
    }
  }
}

final aiReasoningSettingsProvider =
    StateNotifierProvider<AIReasoningSettingsNotifier, AIReasoningSettings>(
        (ref) {
  return AIReasoningSettingsNotifier();
});
