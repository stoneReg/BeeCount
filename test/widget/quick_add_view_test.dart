/// 快速记账([QuickAddView])headless 冒烟测试:四格固定入口 × 小/中 × 明暗。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/widget/views/quick_add_view.dart';
import 'package:beecount/widget/widget_spec.dart' show HWSize;

void main() {
  Widget wrap(Widget child, Size size) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(width: size.width, height: size.height, child: child),
    );
  }

  const labels = (
    voice: '语音记账',
    ai: 'AI小助手',
    camera: '拍照记账',
    manual: '记一笔',
  );

  group('QuickAddView.small(110x110)', () {
    testWidgets('四格入口正常渲染,不抛异常', (tester) async {
      const size = Size(110, 110);
      await tester.pumpWidget(wrap(
        QuickAddView(
          size: HWSize.small,
          themeColor: const Color(0xFFF5A623),
          dark: false,
          voiceLabel: labels.voice,
          aiLabel: labels.ai,
          cameraLabel: labels.camera,
          manualLabel: labels.manual,
          width: size.width,
          height: size.height,
        ),
        size,
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text(labels.voice), findsOneWidget);
      expect(find.text(labels.ai), findsOneWidget);
      expect(find.text(labels.camera), findsOneWidget);
      expect(find.text(labels.manual), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });
  });

  group('QuickAddView.medium(250x110)', () {
    testWidgets('四格入口正常渲染,不抛异常', (tester) async {
      const size = Size(250, 110);
      await tester.pumpWidget(wrap(
        QuickAddView(
          size: HWSize.medium,
          themeColor: const Color(0xFFF5A623),
          dark: true,
          voiceLabel: labels.voice,
          aiLabel: labels.ai,
          cameraLabel: labels.camera,
          manualLabel: labels.manual,
          width: size.width,
          height: size.height,
        ),
        size,
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      for (final label in [labels.voice, labels.ai, labels.camera, labels.manual]) {
        expect(find.text(label), findsOneWidget);
      }
    });
  });
}
