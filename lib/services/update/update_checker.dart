import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../config/github_config.dart';
import '../system/logger_service.dart';
import 'update_result.dart';

/// 更新检查管理类
class UpdateChecker {
  UpdateChecker._();

  static final Dio _dio = Dio();

  /// 清理 release notes，移除 commit hash 和链接
  static String _cleanReleaseNotes(String body) {
    if (body.isEmpty) return body;

    logger.info('UpdateChecker', '====== 原始 release notes ======');
    logger.info('UpdateChecker', body);
    logger.info('UpdateChecker', '====== 开始清理 ======');

    final lines = body.split('\n');
    final cleanedLines = <String>[];

    for (var line in lines) {
      logger.info('UpdateChecker', '处理行: "$line"');

      // 跳过包含 "Full Changelog" 的行
      if (line.contains('Full Changelog')) {
        logger.info('UpdateChecker', '  -> 跳过: 包含 Full Changelog');
        continue;
      }

      // 移除 commit hash 和链接部分：匹配 ([hash](url)) 格式
      // 使用正则表达式匹配 ([任意字符](任意字符)) 的模式
      final regex = RegExp(r'\s*\(\[[a-f0-9]{7}\]\(https://github\.com/[^\)]+\)\)');
      if (regex.hasMatch(line)) {
        line = line.replaceAll(regex, '');
        logger.info('UpdateChecker', '  -> 移除 commit 链接后: "$line"');
      }

      // 跳过空行
      if (line.trim().isEmpty) {
        logger.info('UpdateChecker', '  -> 跳过: 空行');
        continue;
      }

      logger.info('UpdateChecker', '  -> 保留');
      cleanedLines.add(line);
    }

    final result = cleanedLines.join('\n').trim();
    logger.info('UpdateChecker', '====== 清理后的 release notes ======');
    logger.info('UpdateChecker', result);
    logger.info('UpdateChecker', '====== 清理完成 ======');

    return result;
  }

  /// 生成随机User-Agent，避免被GitHub限制
  static String _generateRandomUserAgent() {
    final userAgents = [
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/119.0',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:109.0) Gecko/20100101 Firefox/119.0',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36 Edg/119.0.0.0',
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
      'Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/119.0',
    ];

    // 使用时间戳作为随机种子，确保每次调用都可能不同
    final random = (DateTime.now().millisecondsSinceEpoch % userAgents.length);
    final selectedUA = userAgents[random];

    logger.info('UpdateChecker', '使用User-Agent: ${selectedUA.substring(0, 50)}...');
    return selectedUA;
  }

  /// 检查更新信息
  static Future<UpdateResult> checkUpdate() async {
    try {
      // 获取当前版本信息
      final currentInfo = await _getAppInfo();
      final currentVersion = _normalizeVersion(currentInfo.version);

      logger.info('UpdateChecker', '当前版本: $currentVersion');

      // 配置Dio超时
      _dio.options.connectTimeout = const Duration(seconds: 30);
      _dio.options.receiveTimeout = const Duration(minutes: 2);
      _dio.options.sendTimeout = const Duration(minutes: 2);

      // 获取最新 release 信息 - 添加重试机制
      logger.info('UpdateChecker', '开始请求GitHub API...');
      Response? resp;
      int attempts = 0;
      const maxAttempts = 3;

      while (attempts < maxAttempts) {
        attempts++;
        try {
          logger.info('UpdateChecker', '尝试第$attempts次请求GitHub API...');
          resp = await _dio.get(
            GitHubConfig.releasesLatestApiUrl,
            options: Options(
              headers: {
                'Accept': 'application/vnd.github+json',
                'User-Agent': _generateRandomUserAgent(),
              },
            ),
          );
          // 如果是成功响应，跳出循环
          if (resp.statusCode == 200) {
            logger.info('UpdateChecker', 'GitHub API请求成功');
            break;
          } else {
            logger.warning('UpdateChecker', '第$attempts次请求返回错误状态码: ${resp.statusCode}');
            if (attempts == maxAttempts) {
              break; // 最后一次尝试，不再重试
            }
            await Future.delayed(const Duration(seconds: 1));
          }
        } catch (e) {
          logger.error('UpdateChecker', '第$attempts次请求失败', e);
          if (attempts == maxAttempts) {
            rethrow; // 最后一次尝试失败时抛出异常
          }
          // 等待1秒后重试
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      logger.info('UpdateChecker', 'GitHub API响应状态码: ${resp?.statusCode}');
      if (resp != null && resp.statusCode == 200) {
        final data = resp.data;
        final latestVersion = _normalizeVersion(data['tag_name']);

        logger.info('UpdateChecker', '最新版本: $latestVersion');

        if (_isNewerVersion(latestVersion, currentVersion)) {
          // 找到 APK 下载链接 — v3.2.1 起 Release 含多个 APK(arm64 主包 /
          // armeabi-v7a / x86_64 / universal),需要按设备选择,否则 arm64 真机
          // 装到 armv7 包会走系统 32-bit 兼容层导致严重卡顿
          final assets = data['assets'] as List;
          final abis = await _deviceSupportedAbis();
          final rawTag = (data['tag_name'] ?? '').toString();
          final apkUrl = pickApkUrl(
            assets,
            latestVersion,
            supportedAbis: abis,
            rawTagName: rawTag,
          );
          logger.info(
            'UpdateChecker',
            '设备 ABI=$abis, tag=$rawTag, 选用=${apkUrl ?? "无"}',
          );

          if (apkUrl != null) {
            return UpdateResult(
              hasUpdate: true,
              version: latestVersion,
              downloadUrl: apkUrl,
              releaseNotes: _cleanReleaseNotes(data['body'] ?? ''),
            );
          } else {
            return UpdateResult(
              hasUpdate: false,
              message: '__UPDATE_NO_APK_FOUND__',
            );
          }
        } else {
          return UpdateResult(
            hasUpdate: false,
            message: '__UPDATE_ALREADY_LATEST_SIMPLE__',
          );
        }
      } else {
        final statusCode = resp?.statusCode ?? 'unknown';
        final responseData = resp?.data ?? 'no response';
        logger.error('UpdateChecker',
            'GitHub API请求失败: HTTP $statusCode, 响应: $responseData');
        return UpdateResult(
          hasUpdate: false,
          message: '__UPDATE_CHECK_HTTP_FAILED__:$statusCode',
        );
      }
    } catch (e) {
      logger.error('UpdateChecker', '检查更新异常', e);
      return UpdateResult(
        hasUpdate: false,
        message: '__UPDATE_CHECK_EXCEPTION__:$e',
      );
    }
  }

  /// 读取本机支持的 ABI 列表（arm64 真机常见 `['arm64-v8a','armeabi-v7a',...]`）。
  static Future<List<String>> _deviceSupportedAbis() async {
    if (!Platform.isAndroid) return const ['arm64-v8a'];
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      if (info.supportedAbis.isNotEmpty) {
        return List<String>.from(info.supportedAbis);
      }
    } catch (e) {
      logger.warning('UpdateChecker', '读取设备 ABI 失败，默认 arm64', e);
    }
    // 现代真机绝大多数为 arm64；无法探测时宁可选 64 位也不要误选 32 位
    return const ['arm64-v8a'];
  }

  /// 从 GitHub Release assets 列表里挑出适配当前设备的 APK。
  ///
  /// v3.2.1 起 Release 含多个按 ABI 拆分的 APK:
  ///   - beecount-VER.apk / beecount-vVER.apk  主分发(arm64-v8a)
  ///   - beecount-VER-armeabi-v7a.apk            armv7 老 32-bit 设备
  ///   - beecount-VER-x86_64.apk                 模拟器
  ///   - beecount-VER-universal.apk              多 ABI 兜底
  ///
  /// 历史 bug:
  /// 1) 取 assets 字母序第一个 → armeabi-v7a 包，arm64 真机跑 32-bit 兼容层严重卡顿
  /// 2) tag 带 `v` 前缀时 CI 产出 `beecount-v4.0.1.apk`，仅匹配去 v 的名字会 miss，
  ///    再回退到 `values.first` 仍装上 32 位包（stoneReg v4.0.1 已复现）
  ///
  /// [normalizedVersion] 应为去掉 `v` 的版本（如 `4.0.1`）；[rawTagName] 保留原始 tag。
  static String? pickApkUrl(
    List assets,
    String normalizedVersion, {
    required List<String> supportedAbis,
    String? rawTagName,
  }) {
    final apkByName = <String, String>{};
    for (final asset in assets) {
      final name = asset['name'].toString();
      // 只要 .apk；排除 .aab 等
      if (name.endsWith('.apk')) {
        apkByName[name] = asset['browser_download_url'].toString();
      }
    }
    if (apkByName.isEmpty) return null;

    final versionKeys = <String>{
      normalizedVersion,
      'v$normalizedVersion',
      if (rawTagName != null && rawTagName.isNotEmpty) rawTagName,
    };

    List<String> namesFor(String abiSuffix) {
      // abiSuffix: '' | '-arm64-v8a' | '-armeabi-v7a' | '-x86_64' | '-universal'
      return [
        for (final v in versionKeys) 'beecount-$v$abiSuffix.apk',
      ];
    }

    String? firstHit(Iterable<String> names) {
      for (final name in names) {
        final url = apkByName[name];
        if (url != null) return url;
      }
      return null;
    }

    final abis =
        supportedAbis.map((e) => e.toLowerCase()).toList(growable: false);
    final hasArm64 = abis.any((a) => a.contains('arm64'));
    final hasX64 = abis.any((a) => a == 'x86_64' || a == 'x86-64');
    final onlyArmv7 = !hasArm64 &&
        !hasX64 &&
        abis.any((a) => a.contains('armeabi'));

    if (hasArm64) {
      return firstHit([
        ...namesFor(''),
        ...namesFor('-arm64-v8a'),
        ...namesFor('-universal'),
        // 绝不回退到 armeabi-v7a
      ]);
    }

    if (hasX64) {
      return firstHit([
        ...namesFor('-x86_64'),
        ...namesFor('-universal'),
        ...namesFor(''),
      ]);
    }

    if (onlyArmv7) {
      return firstHit([
        ...namesFor('-armeabi-v7a'),
        ...namesFor('-universal'),
      ]);
    }

    // 未知 ABI：优先 64 位主包 / universal，armeabi 放最后
    return firstHit([
      ...namesFor(''),
      ...namesFor('-arm64-v8a'),
      ...namesFor('-universal'),
      ...namesFor('-x86_64'),
      ...namesFor('-armeabi-v7a'),
    ]);
  }

  // 辅助方法
  static Future<AppInfo> _getAppInfo() async {
    final p = await PackageInfo.fromPlatform();
    final commit = const String.fromEnvironment('GIT_COMMIT');
    final buildTime = const String.fromEnvironment('BUILD_TIME');
    final ciVersion = const String.fromEnvironment('CI_VERSION');

    final version = ciVersion.isNotEmpty ? ciVersion : 'dev-${p.version}';

    return AppInfo(version, p.buildNumber,
        commit: commit.isEmpty ? null : commit,
        buildTime: buildTime.isEmpty ? null : buildTime);
  }

  static String _normalizeVersion(String version) {
    String normalized = version;
    if (normalized.startsWith('v')) {
      normalized = normalized.substring(1);
    }
    if (normalized.startsWith('dev-')) {
      normalized = normalized.substring(4);
    }
    final dashIndex = normalized.indexOf('-');
    if (dashIndex != -1) {
      normalized = normalized.substring(0, dashIndex);
    }
    return normalized;
  }

  static bool _isNewerVersion(String newVersion, String currentVersion) {
    final newParts = newVersion
        .split('.')
        .map(int.tryParse)
        .where((e) => e != null)
        .cast<int>()
        .toList();
    final currentParts = currentVersion
        .split('.')
        .map(int.tryParse)
        .where((e) => e != null)
        .cast<int>()
        .toList();

    final maxLength =
        [newParts.length, currentParts.length].reduce((a, b) => a > b ? a : b);
    while (newParts.length < maxLength) {
      newParts.add(0);
    }
    while (currentParts.length < maxLength) {
      currentParts.add(0);
    }

    for (int i = 0; i < maxLength; i++) {
      if (newParts[i] > currentParts[i]) return true;
      if (newParts[i] < currentParts[i]) return false;
    }

    return false;
  }
}