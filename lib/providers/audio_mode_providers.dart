import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ai/providers/ai_constants.dart';
import '../ai/providers/ai_provider_config.dart';
import '../ai/providers/ai_provider_manager.dart';
import '../services/system/logger_service.dart';

/// 全局语音识别模式 Notifier（与 voice_trigger_mode 同级）
class AudioModeSettingsNotifier extends StateNotifier<AIAudioMode> {
  final Completer<void> _loadCompleter = Completer<void>();

  AudioModeSettingsNotifier() : super(AIAudioMode.transcription) {
    _load();
  }

  Future<void> ensureLoaded() => _loadCompleter.future;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = AIAudioModeCodec.fromStorage(
      prefs.getString(AIConstants.keyAudioMode),
    );

    if (!_loadCompleter.isCompleted) {
      _loadCompleter.complete();
    }
    if (!mounted) return;
    state = mode;
  }

  Future<void> setMode(AIAudioMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AIConstants.keyAudioMode, mode.storageValue);
    _notifyConfigChanged();
  }

  Future<void> reload() => _load();

  void _notifyConfigChanged() {
    try {
      AIProviderManager.onConfigChanged?.call();
    } catch (e, st) {
      logger.warning('AudioModeSettings', 'onConfigChanged 触发失败: $e', st);
    }
  }
}

final audioModeSettingsProvider =
    StateNotifierProvider<AudioModeSettingsNotifier, AIAudioMode>((ref) {
  return AudioModeSettingsNotifier();
});
