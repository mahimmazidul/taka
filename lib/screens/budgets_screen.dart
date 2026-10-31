import 'package:flutter/material.dart';

import '../utils/responsive.dart';
import '../components/app_sheet.dart';
import '../components/budget_line.dart';
import '../components/category_tile.dart';
import '../components/primary_button.dart';
import '../components/section_title.dart';
import '../core/app_theme.dart';
import '../core/motion.dart';
import '../models/app_category.dart';
import '../models/budget_progress.dart';
import '../store/app_state.dart';
import '../store/category_actions.dart';
import '../store/settings_actions.dart';
import '../utils/format_currency.dart';

/// Monthly caps: one overall limit, a limit per group, and a limit per item.
///
/// A group's row shows the rolled-up spend of everything inside it, so you can
/// cap "food" as a whole instead of adding up rice, fish and tea by hand.
class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  Future<void> _editLimit(
    BuildContext context, {
    required String title,
    required int? currentMinor,
    required Future<void> Function(int? minor) onSave,
  }) async {
    final TextEditingController controller = TextEditingController(
      text: currentMinor == null ? '' : minorToInputText(currentMinor),
    );

    await showAppSheet<void>(
      context: context,
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SheetTitle(
              title: title,
              subtitle: 'Leave empty to clear the limit',
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(hintText: 'Monthly limit'),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Save limit',
              icon: Icons.check_rounded,
              onPressed: () async {
                final String text = controller.text.trim();
                final int? minor = text.isEmpty
                    ? null
                    : parseAmountToMinor(text);
                await onSave(minor);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: AnimatedBuilder(
        animation: AppState.instance,
        builder: (BuildContext context, Widget? _) {
          final AppState state = AppState.instance;
          final String symbol = state.currencySymbol;
          final int monthSpend = state.month.expenseMinor;
          final int? overall = state.settings.monthlyBudgetMinor;

          return ListView(
            padding: EdgeInsets.fromLTRB(
              Screen.of(context).gutter,
              0,
              Screen.of(context).gutter,
              32,
            ),
            children: <Widget>[
              const SectionTitle(
                title: 'Overall',
                padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
              ),
              Pressable(
                onTap: () => _editLimit(
                  context,
                  title: 'Monthly spending cap',
                  currentMinor: overall,
                  onSave: (int? minor) => state.setMonthlyBudget(minor),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Row(
                    children: <Widget>[
                      const IconTile(
                        icon: Icons.speed_rounded,
                        color: Palette.taka,
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'All expenses this month',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink(context),
                              ),
                            ),
                            Text(
                              overall == null
                                  ? 'No cap set — tap to add one'
                                  : '${formatMoney(monthSpend, symbol: symbol)} of '
                                        '${formatMoney(overall, symbol: symbol)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.muted(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AppColors.muted(context),
                      ),
                    ],
                  ),
                ),
              ),
              if (overall != null)
                BudgetLine(
                  progress: BudgetProgress(
                    category: const AppCategory(
                      id: 'overall',
                      name: 'All expenses',
                      nameBn: 'সব খরচ',
                      icon: 'other',
                      colorHex: '#0E9F6E',
                      kind: CategoryKind.expense,
                    ),
                    spentMinor: monthSpend,
                    budgetMinor: overall,
                  ),
                  symbol: symbol,
                ),
              const SectionTitle(title: 'Groups roll up everything inside'),
              for (final AppCategory group in state.expenseGroups) ...<Widget>[
                _LimitRow(
                  category: group,
                  spentMinor: state.spendOf(group.id),
                  symbol: symbol,
                  isGroup: true,
                  onTap: () => _editLimit(
                    context,
                    title: '${group.label} budget',
                    currentMinor: group.budgetMinor,
                    onSave: (int? minor) =>
                        state.setCategoryBudget(group.id, minor),
                  ),
                ),
                for (final AppCategory child in state.childrenOf(group.id))
                  _LimitRow(
                    category: child,
                    spentMinor: state.monthSpend[child.id] ?? 0,
                    symbol: symbol,
                    indent: true,
                    onTap: () => _editLimit(
                      context,
                      title: '${child.label} budget',
                      currentMinor: child.budgetMinor,
                      onSave: (int? minor) =>
                          state.setCategoryBudget(child.id, minor),
                    ),
                  ),
                const PreferenceDivider(),
              ],
              const SectionTitle(title: 'Standalone'),
              for (final AppCategory category in state.standaloneExpense)
                _LimitRow(
                  category: category,
                  spentMinor: state.monthSpend[category.id] ?? 0,
                  symbol: symbol,
                  onTap: () => _editLimit(
                    context,
                    title: '${category.label} budget',
                    currentMinor: category.budgetMinor,
                    onSave: (int? minor) =>
                        state.setCategoryBudget(category.id, minor),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: AppColors.muted(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Taka warns at 80% of a limit and turns the bar red once you pass it.',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color: AppColors.muted(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One limit row: icon, label, "৳ 95 of ৳ 200", percentage, and — when a limit
/// is set — a bare 4 px track underneath.
class _LimitRow extends StatelessWidget {
  const _LimitRow({
    required this.category,
    required this.spentMinor,
    required this.symbol,
    required this.onTap,
    this.indent = false,
    this.isGroup = false,
  });

  final AppCategory category;
  final int spentMinor;
  final String symbol;
  final VoidCallback onTap;
  final bool indent;
  final bool isGroup;

  @override
  Widget build(BuildContext context) {
    final int? limit = category.budgetMinor;
    final double ratio = (limit ?? 0) > 0 ? spentMinor / limit! : 0;
    final BudgetStatus status = ratio >= 1
        ? BudgetStatus.exceeded
        : ratio >= 0.8
        ? BudgetStatus.warning
        : BudgetStatus.ok;
    final Color accent = switch (status) {
      BudgetStatus.ok => category.color,
      BudgetStatus.warning => Palette.warning,
      BudgetStatus.exceeded => Palette.expense,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Pressable(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(indent ? 40 : 20, 10, 20, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CategoryTile(category: category, size: isGroup ? 40 : 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        category.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isGroup ? 14.5 : 14,
                          fontWeight: isGroup
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: AppColors.ink(context),
                        ),
                      ),
                      Text(
                        limit == null
                            ? '${formatMoney(spentMinor, symbol: symbol)} this month · no limit'
                            : '${formatMoney(spentMinor, symbol: symbol)} of '
                                  '${formatMoney(limit, symbol: symbol)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: limit == null || status == BudgetStatus.ok
                              ? AppColors.muted(context)
                              : accent,
                          fontWeight: limit == null || status == BudgetStatus.ok
                              ? FontWeight.w400
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  limit == null ? 'Set' : '${(ratio * 100).round()}%',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: limit == null
                        ? FontWeight.w500
                        : FontWeight.w700,
                    color: limit == null ? AppColors.muted(context) : accent,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (limit != null)
          Padding(
            padding: EdgeInsets.fromLTRB(indent ? 86 : 66, 6, 20, 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: ratio.clamp(0, 1),
                minHeight: 4,
                backgroundColor: AppColors.line(context),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          )
        else
          const SizedBox(height: 4),
      ],
    );
  }
}

/// 1 px separator used between sections.
class PreferenceDivider extends StatelessWidget {
  const PreferenceDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Container(height: 1, color: AppColors.line(context)),
    );
  }
}
