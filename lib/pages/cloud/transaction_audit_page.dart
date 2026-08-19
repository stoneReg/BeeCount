import 'package:flutter/material.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../styles/tokens.dart';
import '../../widgets/ui/ui.dart';

/// BeeCount Cloud 修改记录页:可按单笔账单或最近修改浏览。
class TransactionAuditPage extends ConsumerStatefulWidget {
  const TransactionAuditPage({
    super.key,
    this.ledgerSyncId,
    this.transactionSyncId,
  });

  /// 账本 external sync id;为空时 recent API 返回全部可访问账本。
  final String? ledgerSyncId;

  /// 指定则只查该笔账单的 history;为空则查 recent。
  final String? transactionSyncId;

  @override
  ConsumerState<TransactionAuditPage> createState() =>
      _TransactionAuditPageState();
}

class _TransactionAuditPageState extends ConsumerState<TransactionAuditPage> {
  final _items = <BeeCountCloudAuditEntry>[];
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  int? _nextBeforeId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  Future<void> _load({required bool reset}) async {
    if (_loading || _loadingMore) return;
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final cloud = await ref.read(beecountCloudProviderInstance.future);
      if (!mounted) return;
      if (cloud == null) {
        setState(() => _error = AppLocalizations.of(context).cloudBeeCountCloudNotConnectedHint);
        return;
      }

      final page = widget.transactionSyncId != null &&
              widget.transactionSyncId!.isNotEmpty &&
              widget.ledgerSyncId != null &&
              widget.ledgerSyncId!.isNotEmpty
          ? await cloud.readTransactionHistory(
              ledgerId: widget.ledgerSyncId!,
              transactionSyncId: widget.transactionSyncId!,
              beforeId: reset ? null : _nextBeforeId,
            )
          : await cloud.readAuditRecent(
              ledgerId: widget.ledgerSyncId,
              beforeId: reset ? null : _nextBeforeId,
            );

      if (!mounted) return;
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(page.items);
        } else {
          _items.addAll(page.items);
        }
        _nextBeforeId = page.nextBeforeId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '${AppLocalizations.of(context).txAuditLoadFailed}: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  String _actionLabel(AppLocalizations l10n, String action) {
    switch (action) {
      case 'create':
        return l10n.txAuditActionCreate;
      case 'delete':
        return l10n.txAuditActionDelete;
      default:
        return l10n.txAuditActionUpdate;
    }
  }

  String _actorLine(BeeCountCloudAuditEntry entry) {
    final parts = <String>[];
    if (entry.deviceName != null && entry.deviceName!.isNotEmpty) {
      parts.add(entry.deviceName!);
    } else if (entry.updatedByDeviceId != null &&
        entry.updatedByDeviceId!.isNotEmpty) {
      parts.add(entry.updatedByDeviceId!.substring(0, 8));
    }
    if (entry.userDisplayName != null && entry.userDisplayName!.isNotEmpty) {
      parts.add(entry.userDisplayName!);
    } else if (entry.userEmail != null && entry.userEmail!.isNotEmpty) {
      parts.add(entry.userEmail!);
    }
    return parts.join(' · ');
  }

  Widget _changeBody(BeeCountCloudAuditEntry entry) {
    if (entry.action == 'create') {
      final amount = entry.payload['amount'];
      final note = entry.payload['note'];
      final parts = <String>[];
      if (amount is num) parts.add('$amount');
      if (note is String && note.isNotEmpty) parts.add(note);
      return Text(
        parts.isEmpty ? '—' : parts.join(' · '),
        style: TextStyle(fontSize: 12, color: BeeTokens.textSecondary(context)),
      );
    }
    if (entry.changes.isEmpty) {
      return Text(
        '—',
        style: TextStyle(fontSize: 12, color: BeeTokens.textSecondary(context)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in entry.changes)
          Text(
            '${c.label}: ${c.fromValue ?? '—'} → ${c.toValue ?? '—'}',
            style: TextStyle(fontSize: 12, color: BeeTokens.textSecondary(context)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fmt = DateFormat.yMd().add_Hms();

    return Scaffold(
      backgroundColor: BeeTokens.scaffoldBackground(context),
      body: Column(
        children: [
          PrimaryHeader(
            title: l10n.txAuditTitle,
            subtitle: widget.transactionSyncId == null
                ? l10n.txAuditRecentSubtitle
                : null,
            showBack: true,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: _loading && _items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 120),
                        Center(child: CircularProgressIndicator()),
                      ],
                    )
                  : _error != null && _items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(24),
                          children: [
                            Text(
                              _error!,
                              style: TextStyle(color: BeeTokens.textSecondary(context)),
                            ),
                          ],
                        )
                      : _items.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                const SizedBox(height: 120),
                                Center(
                                  child: Text(
                                    l10n.txAuditEmpty,
                                    style: TextStyle(
                                      color: BeeTokens.textSecondary(context),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _items.length + (_nextBeforeId != null ? 1 : 0),
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                if (index >= _items.length) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: TextButton(
                                      onPressed: _loadingMore
                                          ? null
                                          : () => _load(reset: false),
                                      child: _loadingMore
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : Text(l10n.txAuditLoadMore),
                                    ),
                                  );
                                }
                                final entry = _items[index];
                                return SectionCard(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _actionLabel(l10n, entry.action),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              fmt.format(entry.updatedAt),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: BeeTokens.textTertiary(context),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (entry.ledgerName != null &&
                                            widget.transactionSyncId == null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            entry.ledgerName!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: BeeTokens.textSecondary(context),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 4),
                                        Text(
                                          _actorLine(entry).isEmpty ? '—' : _actorLine(entry),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: BeeTokens.textSecondary(context),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        _changeBody(entry),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }
}
