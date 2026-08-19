import 'package:flutter/material.dart';

import '../widget_spec.dart' show HWSize;
import 'widget_view_style.dart';

/// 快速记账(quickAdd):小档 2×2、中档 4×1(占 4×2 槽位),四入口与原生点击层一致。
class QuickAddView extends StatelessWidget {
  final HWSize size;

  final Color themeColor;
  final bool dark;

  final String voiceLabel;
  final String aiLabel;
  final String cameraLabel;
  final String manualLabel;

  final String titleLabel;

  final double width;
  final double height;

  const QuickAddView({
    super.key,
    required this.size,
    required this.themeColor,
    required this.dark,
    required this.voiceLabel,
    required this.aiLabel,
    required this.cameraLabel,
    required this.manualLabel,
    required this.width,
    required this.height,
    this.titleLabel = '快速记账',
  });

  @override
  Widget build(BuildContext context) {
    if (_isSmall) {
      return _buildSmall2x2();
    }
    return _buildMedium1x4();
  }

  bool get _isSmall => size == HWSize.small;

  /// 小档 2×2(110×110 dp 槽位)。
  Widget _buildSmall2x2() {
    return _cardContainer(
      padding: 6,
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(fontSize: 10),
          Expanded(
            child: Row(
              children: [
                _gridCell(_actionCell(Icons.mic, voiceLabel, primary: true, compact: true)),
                _gridCell(_actionCell(Icons.auto_awesome, aiLabel, compact: true)),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                _gridCell(_actionCell(Icons.camera_alt, cameraLabel, compact: true)),
                _gridCell(_actionCell(Icons.edit_outlined, manualLabel, primary: true, compact: true)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 中档 4×1(250×110 dp,对应 Android 4×2 槽位)。
  Widget _buildMedium1x4() {
    return _cardContainer(
      padding: 8,
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title(fontSize: 11),
          Expanded(
            child: Row(
              children: [
                _gridCell(_actionCell(Icons.mic, voiceLabel, primary: true)),
                _gridCell(_actionCell(Icons.auto_awesome, aiLabel)),
                _gridCell(_actionCell(Icons.camera_alt, cameraLabel)),
                _gridCell(_actionCell(Icons.edit_outlined, manualLabel, primary: true)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardContainer({
    required Widget child,
    required double padding,
    required double radius,
  }) {
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: widgetCardBackground(dark),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
  }

  Widget _title({required double fontSize}) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 2),
      child: Text(
        titleLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: widgetTextSecondary(dark),
        ),
      ),
    );
  }

  Widget _gridCell(Widget child) {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.all(_isSmall ? 2 : 3),
        child: child,
      ),
    );
  }

  Widget _actionCell(
    IconData icon,
    String label, {
    bool primary = false,
    bool compact = false,
  }) {
    final glyph = compact ? 16.0 : 20.0;
    final gap = compact ? 1.0 : 2.0;
    final vPad = compact ? 3.0 : 4.0;
    final labelSize = compact ? 8.5 : 10.0;
    final bg = primary
        ? themeColor
        : themeColor.withValues(alpha: dark ? 0.2 : 0.1);
    final fg = primary ? Colors.white : widgetTextPrimary(dark);
    final iconColor = primary ? Colors.white : themeColor;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(compact ? 10 : 12),
      ),
      padding: EdgeInsets.symmetric(horizontal: 2, vertical: vPad),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: glyph),
          SizedBox(height: gap),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: labelSize,
              height: 1.0,
              fontWeight: primary ? FontWeight.w600 : FontWeight.w500,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
