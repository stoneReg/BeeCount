import 'package:flutter_test/flutter_test.dart';

import 'package:beecount/services/update/update_checker.dart';

List<Map<String, dynamic>> _stoneRegV401Assets() => [
      {
        'name': 'beecount-v4.0.1-armeabi-v7a.apk',
        'browser_download_url': 'https://example.com/armeabi.apk',
      },
      {
        'name': 'beecount-v4.0.1-universal.apk',
        'browser_download_url': 'https://example.com/universal.apk',
      },
      {
        'name': 'beecount-v4.0.1-x86_64.apk',
        'browser_download_url': 'https://example.com/x86_64.apk',
      },
      {
        'name': 'beecount-v4.0.1.apk',
        'browser_download_url': 'https://example.com/arm64.apk',
      },
    ];

List<Map<String, dynamic>> _upstream360Assets() => [
      {
        'name': 'beecount-3.6.0-armeabi-v7a.apk',
        'browser_download_url': 'https://example.com/armeabi.apk',
      },
      {
        'name': 'beecount-3.6.0-universal.apk',
        'browser_download_url': 'https://example.com/universal.apk',
      },
      {
        'name': 'beecount-3.6.0.apk',
        'browser_download_url': 'https://example.com/arm64.apk',
      },
    ];

void main() {
  group('UpdateChecker.pickApkUrl — stoneReg v 前缀 tag', () {
    test('arm64 真机选主包 beecount-v4.0.1.apk，绝不选 armeabi', () {
      final url = UpdateChecker.pickApkUrl(
        _stoneRegV401Assets(),
        '4.0.1',
        supportedAbis: const ['arm64-v8a', 'armeabi-v7a', 'armeabi'],
        rawTagName: 'v4.0.1',
      );
      expect(url, 'https://example.com/arm64.apk');
    });

    test('仅匹配去 v 版本名时，靠 rawTag / v-prefixed 文件名仍能命中', () {
      // 模拟旧逻辑只造 normalized 名字会 miss 的场景：assets 只有带 v 的文件
      final url = UpdateChecker.pickApkUrl(
        _stoneRegV401Assets(),
        '4.0.1',
        supportedAbis: const ['arm64-v8a'],
        // 不传 rawTag 也能靠内置 'v$normalized' 命中
      );
      expect(url, 'https://example.com/arm64.apk');
    });

    test('arm64 缺主包时回退 universal，仍不选 armeabi', () {
      final assets = _stoneRegV401Assets()
          .where((a) => a['name'] != 'beecount-v4.0.1.apk')
          .toList();
      final url = UpdateChecker.pickApkUrl(
        assets,
        '4.0.1',
        supportedAbis: const ['arm64-v8a', 'armeabi-v7a'],
        rawTagName: 'v4.0.1',
      );
      expect(url, 'https://example.com/universal.apk');
    });
  });

  group('UpdateChecker.pickApkUrl — 上游无 v 前缀', () {
    test('arm64 选 beecount-3.6.0.apk', () {
      final url = UpdateChecker.pickApkUrl(
        _upstream360Assets(),
        '3.6.0',
        supportedAbis: const ['arm64-v8a'],
        rawTagName: '3.6.0',
      );
      expect(url, 'https://example.com/arm64.apk');
    });
  });

  group('UpdateChecker.pickApkUrl — 按 ABI', () {
    test('纯 32 位设备才选 armeabi-v7a', () {
      final url = UpdateChecker.pickApkUrl(
        _stoneRegV401Assets(),
        '4.0.1',
        supportedAbis: const ['armeabi-v7a', 'armeabi'],
        rawTagName: 'v4.0.1',
      );
      expect(url, 'https://example.com/armeabi.apk');
    });

    test('x86_64 模拟器选 x86_64 包', () {
      final url = UpdateChecker.pickApkUrl(
        _stoneRegV401Assets(),
        '4.0.1',
        supportedAbis: const ['x86_64'],
        rawTagName: 'v4.0.1',
      );
      expect(url, 'https://example.com/x86_64.apk');
    });
  });
}
