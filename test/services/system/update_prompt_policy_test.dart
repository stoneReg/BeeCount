import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:beecount/services/system/update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UpdateService.shouldPromptForVersion', () {
    test('空版本不提示', () {
      expect(
        UpdateService.shouldPromptForVersion(
          availableVersion: '',
          dismissedVersion: null,
        ),
        isFalse,
      );
    });

    test('未关闭过任何版本 → 提示', () {
      expect(
        UpdateService.shouldPromptForVersion(
          availableVersion: '1.2.0',
          dismissedVersion: null,
        ),
        isTrue,
      );
    });

    test('已关闭的正是当前版本 → 不提示', () {
      expect(
        UpdateService.shouldPromptForVersion(
          availableVersion: '1.2.0',
          dismissedVersion: '1.2.0',
        ),
        isFalse,
      );
    });

    test('已关闭旧版本、现有更新版本 → 再提示', () {
      expect(
        UpdateService.shouldPromptForVersion(
          availableVersion: '1.3.0',
          dismissedVersion: '1.2.0',
        ),
        isTrue,
      );
    });
  });

  group('UpdateService.dismissVersion prefs', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('dismissVersion 后 getDismissedVersion 能读回', () async {
      expect(await UpdateService.getDismissedVersion(), isNull);
      await UpdateService.dismissVersion('2.0.0');
      expect(await UpdateService.getDismissedVersion(), '2.0.0');
    });

    test('prefs 中已关闭版本与 shouldPrompt 一致', () async {
      await UpdateService.dismissVersion('1.5.0');
      final dismissed = await UpdateService.getDismissedVersion();
      expect(
        UpdateService.shouldPromptForVersion(
          availableVersion: '1.5.0',
          dismissedVersion: dismissed,
        ),
        isFalse,
      );
      expect(
        UpdateService.shouldPromptForVersion(
          availableVersion: '1.6.0',
          dismissedVersion: dismissed,
        ),
        isTrue,
      );
    });
  });
}
