import 'package:flutter/material.dart';

import '../components/budget_line.dart';
import '../components/empty_state.dart';
import '../components/entry_row.dart';
import '../components/hero_balance.dart';
import '../components/section_title.dart';
import '../components/stat_strip.dart';
import '../components/week_bars.dart';
import '../core/app_theme.dart';
import '../core/motion.dart';
import '../models/budget_progress.dart';
import '../models/transaction_entry.dart';
import '../store/app_state.dart';
import '../store/settings_actions.dart';
import '../utils/date_helpers.dart';
import '../utils/format_currency.dart';
import 'add_entry_screen.dart';
import 'budgets_screen.dart';

/// Dashboard. One hero, then open sections separated by hairlines — no stacks
/// of rounded boxes.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onOpenUdhar,
    required this.onOpenHistory,
  });

  final VoidCallback onOpenUdhar;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppState.instance,
      builder: (BuildContext context, Widget? _) {
        final AppState state = AppState.instance;
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
        }

        final String symbol = state.currencySymbol;
        final DateTime now = DateTime.now();

        return SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: state.refresh,
            color: Palette.taka,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 110),
              physics: const AlwaysScrollableScrollPhysics(),
              children: <Widget>[
                _Header(
                  monthLabel: formatMonthYear(now),
                  isDark: state.settings.darkMode,
                ),
                const SizedBox(height: 14),
                Reveal(
                  child: HeroBalance(
                    balanceMinor: state.month.netMinor,
                    incomeMinor: state.month.incomeMinor,
                    expenseMinor: state.month.expenseMinor,
                    monthLabel: 'Balance · ${monthName(now.month)}',
                    symbol: symbol,
                  ),
                ),
                Reveal(
                  index: 1,
                  child: StatStrip(
                    todayMinor: state.today.expenseMinor,
                    weekMinor: state.week.expenseMinor,
                    monthMinor: state.month.expenseMinor,
                    symbol: symbol,
                  ),
                ),
                SectionTitle(title: 'Last 7 days', actionLabel: 'History', onAction: onOpenHistory),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Reveal(index: 2, child: WeekBars(days: state.lastSevenDays)),
                ),
                if (state.settings.budgetsEnabled) ...<Widget>[
                  SectionTitle(
                    title: 'Budgets',
                    actionLabel: 'Manage',
                    onAction: () => Navigator.of(context)
                        .push(slideFadeRoute<void>(const BudgetsScreen())),
                  ),
                  _BudgetsBlock(
                    budgets: state.budgets,
                    symbol: symbol,
                    onManage: () => Navigator.of(context)
                        .push(slideFadeRoute<void>(const BudgetsScreen())),
                  ),
                ],
                if (state.settings.udharEnabled) ...<Widget>[
                  SectionTitle(title: 'Udhar', actionLabel: 'Open', onAction: onOpenUdhar),
                  _UdharRow(
                    lentMinor: state.udharTotals.lentMinor,
                    borrowedMinor: state.udharTotals.borrowedMinor,
                    symbol: symbol,
                    onTap: onOpenUdhar,
                  ),
                ],
                SectionTitle(
                  title: 'Recent',
                  actionLabel: state.recentEntries.isEmpty ? null : 'See all',
                  onAction: onOpenHistory,
                ),
                _RecentBlock(
                  entries: state.recentEntries,
                  symbol: symbol,
                  onOpenHistory: onOpenHistory,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.monthLabel, required this.isDark});

  final String monthLabel;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'টাকা',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: AppColors.ink(context),
                  ),
                ),
                Text(
                  monthLabel,
                  style: TextStyle(fontSize: 12, color: AppColors.muted(context)),
                ),
              ],
            ),
          ),
          Pressable(
            onTap: () => AppState.instance.toggleDarkMode(),
            scale: 0.9,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.line(context)),
              ),
              child: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                size: 19,
                color: AppColors.muted(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _BudgetsBlock extends StatelessWidget {
  const _BudgetsBlock({
    required this.budgets,
    required this.symbol,
    required this.onManage,
  });

  final List<BudgetProgress> budgets;
  final String symbol;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    if (budgets.isEmpty) {
      return EmptyState(
        icon: Icons.flag_outlined,
        title: 'No budget set',
        message: 'Set a monthly limit per category and Taka will warn you at 80%.',
        actionLabel: 'Set a budget',
        onAction: onManage,
        compact: true,
      );
    }

    final List<BudgetProgress> visible =
        budgets.length > 3 ? budgets.sublist(0, 3) : budgets;

    return Column(
      children: <Widget>[
        for (final BudgetProgress progress in visible)
          BudgetLine(progress: progress, symbol: symbol, onTap: onManage),
        if (budgets.length > visible.length)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '+${budgets.length - visible.length} more',
                style: TextStyle(fontSize: 11.5, color: AppColors.muted(context)),
              ),
            ),
          ),
      ],
    );
  }
}

class _UdharRow extends StatelessWidget {
  const _UdharRow({
    required this.lentMinor,
    required this.borrowedMinor,
    required this.symbol,
    required this.onTap,
  });

  final int lentMinor;
  final int borrowedMinor;
  final String symbol;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'To receive ${formatMoney(lentMinor, symbol: symbol)}',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.income(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'To pay ${formatMoney(borrowedMinor, symbol: symbol)}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.muted(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.muted(context)),
          ],
        ),
      ),
    );
  }
}

class _RecentBlock extends StatelessWidget {
  const _RecentBlock({
    required this.entries,
    required this.symbol,
    required this.onOpenHistory,
  });

  final List<TransactionEntry> entries;
  final String symbol;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppState.instance;

    if (entries.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Nothing recorded yet',
        message: 'Your first entry takes about five seconds.',
        actionLabel: 'Add an entry',
        onAction: () => Navigator.of(context)
            .push(slideFadeRoute<void>(const AddEntryScreen())),
      );
    }

    return Column(
      children: <Widget>[
        for (int i = 0; i < entries.length; i++) ...<Widget>[
          EntryRow(
            entry: entries[i],
            category: state.categoryById(entries[i].categoryId),
            symbol: symbol,
            onTap: onOpenHistory,
          ),
          if (i != entries.length - 1) const Hairline(indent: 76),
        ],
      ],
    );
  }
}
