/// GitHub 仓库配置（用于检查更新、下载 Release 等）
class GitHubConfig {
  GitHubConfig._();

  /// 仓库所有者，可通过 --dart-define=GITHUB_REPO_OWNER=xxx 覆盖
  static const repoOwner = String.fromEnvironment(
    'GITHUB_REPO_OWNER',
    defaultValue: 'stoneReg',
  );

  /// 仓库名称，可通过 --dart-define=GITHUB_REPO_NAME=xxx 覆盖
  static const repoName = String.fromEnvironment(
    'GITHUB_REPO_NAME',
    defaultValue: 'BeeCount',
  );

  /// 完整仓库路径，如 stoneReg/BeeCount
  static String get repoFullName => '$repoOwner/$repoName';

  /// 仓库主页
  static String get repoUrl => 'https://github.com/$repoFullName';

  /// Releases 页面
  static String get releasesUrl => '$repoUrl/releases';

  /// 获取最新 Release 的 GitHub API 地址
  static String get releasesLatestApiUrl =>
      'https://api.github.com/repos/$repoFullName/releases/latest';
}
