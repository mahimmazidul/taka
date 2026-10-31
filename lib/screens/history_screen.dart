import 'package:flutter/material.dart';

import '../components/empty_state.dart';
import '../components/entry_row.dart';
import '../components/segmented.dart';
import '../core/app_theme.dart';
import '../core/motion.dart';
import '../models/app_category.dart';
import '../models/day_group.dart';
import '../models/transaction_entry.dart';
import '../store/app_state.dart';
import '../utils/date_helpers.dart';
import '../utils/format_currency.dart';
import 'add_entry_screen.dart';

enum _Range { all, thisMonth, last7 }

/// Full ledger: search, type filter, category filter, date range, grouped by
/// day with per-day totals. Tap to edit, long-press to delete.
///
/// Filtering runs in memory against [AppState.allEntries], so results change
/// as you type without touching the database.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _search = TextEditingController();
  EntryType? _type;
  String? _categoryId;
  _Range _range = _Range.thisMonth;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openCategoryFilter() async {
    final List<AppCategory> categories = AppState.instance.categories;
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: <Widget>[
            _FilterRow(
              label: 'All categories',
              selected: _categoryId == null,
              onTap: () => Navigator.pop(context, ''),
            ),
            for (final AppCategory category in categories)
              _FilterRow(
                label: '${category.label}  ·  ${category.name}',
                icon: category.iconData,
                tint: category.color,
                selected: _categoryId == category.id,
                onTap: () => Navigator.pop(context, category.id),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() => _categoryId = picked.isEmpty ? null : picked);
  }

  Future<void> _confirmDelete(TransactionEntry entry) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete entry?'),
        content: Text(
          '${formatMoney(entry.amountMinor, symbol: AppState.instance.currencySymbol)}'
          '${entry.note.isEmpty ? '' : ' · ${entry.note}'}',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Palette.expense),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await AppState.instance.deleteTransaction(entry.id);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (BuildContext context, Widget? _) {
        final AppState state = AppState.instance;
        final String symbol = state.currencySymbol;
        final DateTime now = DateTime.now();

        DateTime? from;
        if (_range == _Range.thisMonth) from = startOfMonth(now);
        if (_range == _Range.last7) {
          from = startOfDay(now).subtract(const Duration(days: 6));
        }

        final List<TransactionEntry> entries = state.filterEntries(
          type: _type,
          categoryId: _categoryId,
          search: _search.text,
          from: from,
        );
        final List<DayGroup<TransactionEntry>> groups =
            groupByDay<TransactionEntry>(
              entries,
              (TransactionEntry e) => e.occurredAt,
            );
        final int net = entries.fold<int>(
          0,
          (int sum, TransactionEntry e) =>
              sum + (e.isExpense ? -e.amountMinor : e.amountMinor),
        );

        return SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'History',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: AppColors.ink(context),
                      ),
                    ),
                    Text(
                      '${entries.length} entries · net ${formatMoney(net, symbol: symbol)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: TextField(
                  controller: _search,
                  onChanged: (String _) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search notes',
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: AppColors.muted(context),
                    ),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _search.clear();
                              setState(() {});
                            },
                          ),
                  ),
                ),
              ),
              SizedBox(
                height: 54,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  children: <Widget>[
                    AppChip(
                      label: 'All',
                      selected: _type == null,
                      onTap: () => setState(() => _type = null),
                    ),
                    const SizedBox(width: 8),
                    AppChip(
                      label: 'Expense',
                      selected: _type == EntryType.expense,
                      onTap: () => setState(() => _type = EntryType.expense),
                    ),
                    const SizedBox(width: 8),
                    AppChip(
                      label: 'Income',
                      selected: _type == EntryType.income,
                      onTap: () => setState(() => _type = EntryType.income),
                    ),
                    const SizedBox(width: 8),
                    AppChip(
                      label: _categoryId == null
                          ? 'Category'
                          : state.categoryById(_categoryId!)?.label ??
                                'Category',
                      icon: Icons.local_offer_outlined,
                      selected: _categoryId != null,
                      onTap: _openCategoryFilter,
                    ),
                    const SizedBox(width: 8),
                    AppChip(
                      label: switch (_range) {
                        _Range.all => 'All time',
                        _Range.thisMonth => 'This month',
                        _Range.last7 => 'Last 7 days',
                      },
                      icon: Icons.date_range_rounded,
                      selected: _range != _Range.all,
                      onTap: () => setState(() {
                        _range = switch (_range) {
                          _Range.all => _Range.thisMonth,
                          _Range.thisMonth => _Range.last7,
                          _Range.last7 => _Range.all,
                        };
                      }),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: entries.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'Nothing here',
                        message: 'Try a different filter, or add an entry with the + button.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 110),
                        itemCount: groups.length,
                        itemBuilder: (BuildContext context, int index) {
                          final DayGroup<TransactionEntry> group =
                              groups[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              _DayHeader(group: group, symbol: symbol),
                              for (
                                int i = 0;
                                i < group.items.length;
                                i++
                              ) ...<Widget>[
                                EntryRow(
                                  entry: group.items[i],
                                  category: state.categoryById(
                                    group.items[i].categoryId,
                                  ),
                                  symbol: symbol,
                                  onTap: () => Navigator.of(context).push(
                                    slideFadeRoute<void>(
                                      AddEntryScreen(entry: group.items[i]),
                                    ),
                                  ),
                                  onLongPress: () =>
                                      _confirmDelete(group.items[i]),
                                ),
                                if (i != group.items.length - 1)
                                  const Hairline(indent: 76),
                              ],
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.group, required this.symbol});

  final DayGroup<TransactionEntry> group;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final int spend = group.items
        .where((TransactionEntry e) => e.isExpense)
        .fold<int>(0, (int sum, TransactionEntry e) => sum + e.amountMinor);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              formatDayHeading(group.day),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: AppColors.muted(context),
              ),
            ),
          ),
          Text(
            formatMoney(spend, symbol: symbol),
            style: TextStyle(fontSize: 11.5, color: AppColors.muted(context)),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.label,
    this.icon,
    this.tint,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final Color? tint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 18, color: tint ?? AppColors.muted(context)),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 14.5, color: AppColors.ink(context)),
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded, size: 18, color: Palette.taka),
          ],
        ),
      ),
    );
  }
}
