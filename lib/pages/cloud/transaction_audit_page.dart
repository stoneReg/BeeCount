import 'package:flutter/material.dart';
import 'package:flutter_cloud_sync/flutter_cloud_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../providers.dart';
import '../../styles/tokens.dart';
import '../../widgets/ui/ui.dart';
import 'audit_display_helper.dart';

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
                                return _AuditEntryCard(
                                  entry: entry,
                                  l10n: l10n,
                                  timeLabel: fmt.format(entry.updatedAt),
                                  showLedger: widget.transactionSyncId == null,
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

class _AuditEntryCard extends StatelessWidget {
  const _AuditEntryCard({
    required this.entry,
    required this.l10n,
    required this.timeLabel,
    required this.showLedger,
  });

  final BeeCountCloudAuditEntry entry;
  final AppLocalizations l10n;
  final String timeLabel;
  final bool showLedger;

  @override
  Widget build(BuildContext context) {
    final style = AuditDisplayHelper.actionStyle(context, entry.action);
    final actionLabel = AuditDisplayHelper.actionLabel(l10n, entry.action);
    final attribution = AuditDisplayHelper.attribution(entry);
    final changes = AuditDisplayHelper.changeLines(entry);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: style.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: style.border),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: style.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(style.icon, size: 18, color: style.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.txAuditFieldType,
                              style: TextStyle(
                                fontSize: 11,
                                color: BeeTokens.textTertiary(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: style.accent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    actionLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: style.accent,
                                    ),
                                  ),
                                ),
                                if (showLedger &&
                                    entry.ledgerName != null &&
                                    entry.ledgerName!.isNotEmpty)
                                  Text(
                                    entry.ledgerName!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: BeeTokens.textSecondary(context),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Text(
                        timeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: BeeTokens.textTertiary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.txAuditFieldAttribution,
                    style: TextStyle(
                      fontSize: 11,
                      color: BeeTokens.textTertiary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    attribution,
                    style: TextStyle(
                      fontSize: 14,
                      color: BeeTokens.textPrimary(context),
                    ),
                  ),
                  if (changes.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      l10n.txAuditFieldChanges,
                      style: TextStyle(
                        fontSize: 11,
                        color: BeeTokens.textTertiary(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final line in changes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.35,
                              color: BeeTokens.textPrimary(context),
                            ),
                            children: [
                              TextSpan(
                                text: '${line.label}：',
                                style: TextStyle(
                                  color: BeeTokens.textSecondary(context),
                                ),
                              ),
                              TextSpan(text: line.text),
                            ],
                          ),
                        ),
                      ),
                  ] else if (entry.action == 'delete') ...[
                    const SizedBox(height: 10),
                    Text(
                      l10n.txAuditDeleteDetailMissing,
                      style: TextStyle(
                        fontSize: 13,
                        color: BeeTokens.textSecondary(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
