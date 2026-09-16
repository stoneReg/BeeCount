import 'package:flutter/material.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';

import '../../l10n/app_localizations.dart';
import '../../styles/tokens.dart';

/// 修改记录展示辅助(Cloud audit entry)。
class AuditDisplayHelper {
  AuditDisplayHelper._();

  static String actionLabel(AppLocalizations l10n, String action) {
    switch (action) {
      case 'create':
        return l10n.txAuditActionCreate;
      case 'delete':
        return l10n.txAuditActionDelete;
      default:
        return l10n.txAuditActionUpdate;
    }
  }

  static AuditActionStyle actionStyle(BuildContext context, String action) {
    switch (action) {
      case 'create':
        return AuditActionStyle(
          icon: Icons.add_circle_outline_rounded,
          accent: BeeTokens.success(context),
          surface: BeeTokens.success(context).withValues(alpha: 0.08),
          border: BeeTokens.success(context).withValues(alpha: 0.25),
        );
      case 'delete':
        return AuditActionStyle(
          icon: Icons.remove_circle_outline_rounded,
          accent: Theme.of(context).colorScheme.error,
          surface: Theme.of(context).colorScheme.error.withValues(alpha: 0.08),
          border: Theme.of(context).colorScheme.error.withValues(alpha: 0.25),
        );
      default:
        return AuditActionStyle(
          icon: Icons.edit_outlined,
          accent: const Color(0xFF0284C7),
          surface: const Color(0xFF0284C7).withValues(alpha: 0.08),
          border: const Color(0xFF0284C7).withValues(alpha: 0.25),
        );
    }
  }

  static String attribution(BeeCountCloudAuditEntry entry) {
    final account = _account(entry);
    final device = _device(entry);
    if (account == null && device == null) return '—';
    if (account == null) return device!;
    if (device == null) return account;
    return '$account — $device';
  }

  static List<AuditChangeLine> changeLines(BeeCountCloudAuditEntry entry) {
    final kind = entry.action;
    final filtered = _filterChanges(entry.changes, kind);
    if (filtered.isNotEmpty) {
      final lines = filtered.map((c) {
        final from = _formatValue(c.field, c.fromValue);
        final to = _formatValue(c.field, c.toValue);
        if (kind == 'create') {
          return AuditChangeLine(label: c.label, text: to);
        }
        if (kind == 'delete') {
          return AuditChangeLine(label: c.label, text: from);
        }
        return AuditChangeLine(label: c.label, text: '$from → $to');
      }).where((line) => line.text != '—').toList(growable: false);
      if (lines.isNotEmpty) return lines;
    }

    if (kind == 'create' || kind == 'delete') {
      return _payloadFallback(entry);
    }
    return const [];
  }

  static String? _account(BeeCountCloudAuditEntry entry) {
    if (entry.userDisplayName != null && entry.userDisplayName!.isNotEmpty) {
      return entry.userDisplayName;
    }
    if (entry.userEmail != null && entry.userEmail!.isNotEmpty) {
      return entry.userEmail;
    }
    return null;
  }

  static String? _device(BeeCountCloudAuditEntry entry) {
    if (entry.deviceName != null && entry.deviceName!.isNotEmpty) {
      return entry.deviceName;
    }
    if (entry.updatedByDeviceId != null && entry.updatedByDeviceId!.isNotEmpty) {
      return entry.updatedByDeviceId!.substring(0, 8);
    }
    return null;
  }

  static List<BeeCountCloudAuditFieldChange> _filterChanges(
    List<BeeCountCloudAuditFieldChange> changes,
    String action,
  ) {
    const skipIfPresent = {
      'categoryId': 'categoryName',
      'accountId': 'accountName',
      'fromAccountId': 'fromAccountName',
      'toAccountId': 'toAccountName',
      'tagIds': 'tags',
    };
    const order = [
      'type',
      'amount',
      'categoryName',
      'accountName',
      'fromAccountName',
      'toAccountName',
      'happenedAt',
      'note',
      'tags',
    ];
    final summaryFields = order.toSet();
    final fields = changes.map((c) => c.field).toSet();
    var filtered = changes.where((c) {
      final skip = skipIfPresent[c.field];
      if (skip != null && fields.contains(skip)) return false;
      return true;
    }).toList(growable: false);

    if (action == 'create' || action == 'delete') {
      final summary = filtered.where((c) => summaryFields.contains(c.field)).toList();
      if (summary.isNotEmpty) filtered = summary;
    }

    int rank(String field) {
      final idx = order.indexOf(field);
      return idx >= 0 ? idx : 999;
    }

    filtered.sort((a, b) {
      final cmp = rank(a.field).compareTo(rank(b.field));
      return cmp != 0 ? cmp : a.field.compareTo(b.field);
    });
    return filtered;
  }

  static List<AuditChangeLine> _payloadFallback(BeeCountCloudAuditEntry entry) {
    const specs = [
      ('type', '类型'),
      ('amount', '金额'),
      ('categoryName', '分类'),
      ('accountName', '账户'),
      ('happenedAt', '时间'),
      ('note', '备注'),
    ];
    final lines = <AuditChangeLine>[];
    for (final (key, label) in specs) {
      final raw = entry.payload[key];
      if (raw == null || (raw is String && raw.isEmpty)) continue;
      final text = _formatValue(key, raw);
      if (text == '—') continue;
      lines.add(AuditChangeLine(label: label, text: text));
    }
    return lines;
  }

  static String _formatValue(String field, Object? value) {
    if (value == null) return '—';
    if (value is bool) return value ? '是' : '否';
    if (field == 'type') {
      final s = value.toString().toLowerCase();
      if (s == 'expense') return '支出';
      if (s == 'income') return '收入';
      if (s == 'transfer') return '转账';
    }
    if (field == 'happenedAt') {
      final dt = DateTime.tryParse(value.toString());
      if (dt != null) {
        return dt.toLocal().toString().replaceFirst('.000', '');
      }
    }
    if (value is List) {
      return value.map((e) => e.toString()).where((e) => e.isNotEmpty).join('、');
    }
    return value.toString();
  }
}

class AuditActionStyle {
  const AuditActionStyle({
    required this.icon,
    required this.accent,
    required this.surface,
    required this.border,
  });

  final IconData icon;
  final Color accent;
  final Color surface;
  final Color border;
}

class AuditChangeLine {
  const AuditChangeLine({required this.label, required this.text});

  final String label;
  final String text;
}
