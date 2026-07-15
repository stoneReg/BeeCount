import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 静默检测到的可升级版本（供首页横幅等轻量提示使用）。
class AvailableUpdate {
  final String version;
  final String downloadUrl;
  final String releaseNotes;

  const AvailableUpdate({
    required this.version,
    required this.downloadUrl,
    this.releaseNotes = '',
  });
}

/// 更新进度状态
class UpdateProgress {
  final double progress;
  final String status;
  final bool isActive;

  const UpdateProgress({
    required this.progress,
    required this.status,
    required this.isActive,
  });

  factory UpdateProgress.idle() => const UpdateProgress(
        progress: 0.0,
        status: '',
        isActive: false,
      );

  factory UpdateProgress.active(double progress, String status) =>
      UpdateProgress(
        progress: progress,
        status: status,
        isActive: true,
      );

  UpdateProgress copyWith({
    double? progress,
    String? status,
    bool? isActive,
  }) {
    return UpdateProgress(
      progress: progress ?? this.progress,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// 静默启动检查发现的可升级版本；`null` 表示无需提示。
final availableUpdateProvider =
    StateProvider<AvailableUpdate?>((ref) => null);

/// 更新进度Provider
final updateProgressProvider =
    StateProvider<UpdateProgress>((ref) => UpdateProgress.idle());
