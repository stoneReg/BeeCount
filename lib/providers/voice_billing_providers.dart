import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ai/providers/ai_constants.dart';
import '../ai/providers/ai_provider_manager.dart';
import '../services/system/logger_service.dart';

/// 语音记账设置数据（PR A：仅静音阈值；触发方式在 PR B 扩展）
class VoiceBillingSettings {
  /// 自动检测模式下的静音判定阈值（毫秒）
  final int silenceTimeoutMs;

  const VoiceBillingSettings({
    this.silenceTimeoutMs = defaultSilenceTimeoutMs,
  });

  /// 默认静音阈值（毫秒）：从历史的 800ms 放宽到 1500ms，对自然停顿更友好
  static const int defaultSilenceTimeoutMs = 1500;

  /// 静音阈值可调下限（毫秒）
  static const int minSilenceTimeoutMs = 500;

  /// 静音阈值可调上限（毫秒）
  static const int maxSilenceTimeoutMs = 4000;

  VoiceBillingSettings copyWith({int? silenceTimeoutMs}) {
    return VoiceBillingSettings(
      silenceTimeoutMs: silenceTimeoutMs ?? this.silenceTimeoutMs,
    );
  }
}

/// 语音记账设置 Notifier
///
/// 配置落 SharedPreferences，并随 AI 配置一起做多设备同步（见
/// [AIProviderManager.snapshotForSync] / [AIProviderManager.applyFromServer]）。
class VoiceBillingSettingsNotifier extends StateNotifier<VoiceBillingSettings> {
  final Completer<void> _loadCompleter = Completer<void>();

  VoiceBillingSettingsNotifier() : super(const VoiceBillingSettings()) {
    _load();
  }

  /// 确保已从本地加载完成
  Future<void> ensureLoaded() => _loadCompleter.future;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final timeout = _clampTimeout(
      prefs.getInt(AIConstants.keyVoiceSilenceTimeoutMs) ??
          VoiceBillingSettings.defaultSilenceTimeoutMs,
    );

    if (!mounted) return;
    state = VoiceBillingSettings(silenceTimeoutMs: timeout);
    if (!_loadCompleter.isCompleted) {
      _loadCompleter.complete();
    }
  }

  static int _clampTimeout(int value) => value.clamp(
        VoiceBillingSettings.minSilenceTimeoutMs,
        VoiceBillingSettings.maxSilenceTimeoutMs,
      );

  /// 设置静音判定阈值（毫秒），自动夹取到合法区间
  Future<void> setSilenceTimeoutMs(int value) async {
    final clamped = _clampTimeout(value);
    state = state.copyWith(silenceTimeoutMs: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AIConstants.keyVoiceSilenceTimeoutMs, clamped);
    _notifyConfigChanged();
  }

  /// 重新从本地加载（多设备同步落地后由外部 invalidate 触发重建即可）
  Future<void> reload() => _load();

  /// 触发 AI 配置变更回调，把语音设置一并推到 server 同步到其它设备
  void _notifyConfigChanged() {
    try {
      AIProviderManager.onConfigChanged?.call();
    } catch (e, st) {
      logger.warning('VoiceBillingSettings', 'onConfigChanged 触发失败: $e', st);
    }
  }
}

/// 语音记账设置 Provider
final voiceBillingSettingsProvider =
    StateNotifierProvider<VoiceBillingSettingsNotifier, VoiceBillingSettings>(
        (ref) {
  return VoiceBillingSettingsNotifier();
});
