import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ai/providers/ai_constants.dart';
import '../ai/providers/ai_provider_manager.dart';
import '../ai/providers/ai_reasoning_adapter.dart';
import '../services/system/logger_service.dart';

/// 深度思考全局设置（仅档位）
class AIReasoningSettings {
  final AIReasoningLevel level;

  const AIReasoningSettings({this.level = AIReasoningLevel.off});
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

    if (!_loadCompleter.isCompleted) {
      _loadCompleter.complete();
    }
    if (!mounted) return;
    state = AIReasoningSettings(level: level);
  }

  Future<void> save(AIReasoningLevel level) async {
    state = AIReasoningSettings(level: level);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        AIConstants.keyAiReasoningLevel, level.storageValue);
    _notifyConfigChanged();
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
