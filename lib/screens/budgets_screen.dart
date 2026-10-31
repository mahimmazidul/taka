import 'package:flutter/material.dart';

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
import '../utils/budget_calculator.dart';
import '../utils/format_currency.dart';

/// Monthly caps: one overall limit plus a limit per category.
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
          final Map<String, int> spend = state.monthSpend;
          final List<AppCategory> expenseCategories = state.categoriesForKind(
            CategoryKind.expense,
          );
          final int monthSpend = state.month.expenseMinor;
          final int? overall = state.settings.monthlyBudgetMinor;

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
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
                      IconTile(icon: Icons.speed_rounded, color: Palette.taka),
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
              const SectionTitle(title: 'Per category'),
              for (final AppCategory category in expenseCategories) ...<Widget>[
                _CategoryLimitRow(
                  category: category,
                  spentMinor: spend[category.id] ?? 0,
                  symbol: symbol,
                  onTap: () => _editLimit(
                    context,
                    title: '${category.label} budget',
                    currentMinor: category.budgetMinor,
                    onSave: (int? minor) =>
                        state.setCategoryBudget(category.id, minor),
                  ),
                ),
                const PreferenceDivider(),
              ],
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

Color _statusColor(BudgetProgress progress) => switch (progress.status) {
  BudgetStatus.ok => progress.category.color,
  BudgetStatus.warning => Palette.warning,
  BudgetStatus.exceeded => Palette.expense,
};

class _CategoryLimitRow extends StatelessWidget {
  const _CategoryLimitRow({
    required this.category,
    required this.spentMinor,
    required this.symbol,
    required this.onTap,
  });

  final AppCategory category;
  final int spentMinor;
  final String symbol;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final int? limit = category.budgetMinor;
    final List<BudgetProgress> derived = buildBudgetProgress(
      categories: <AppCategory>[category],
      spentByCategoryMinor: <String, int>{category.id: spentMinor},
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Pressable(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CategoryTile(category: category, size: 36),
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
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.ink(context),
                        ),
                      ),
                      if (derived.isNotEmpty)
                        Text(
                          '${formatMoney(spentMinor, symbol: symbol)} of '
                          '${formatMoney(limit!, symbol: symbol)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: derived.first.status == BudgetStatus.ok
                                ? AppColors.muted(context)
                                : _statusColor(derived.first),
                            fontWeight: derived.first.status == BudgetStatus.ok
                                ? FontWeight.w400
                                : FontWeight.w600,
                          ),
                        )
                      else
                        Text(
                          '${formatMoney(spentMinor, symbol: symbol)} spent '
                          'this month',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.muted(context),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  derived.isNotEmpty
                      ? '${(derived.first.ratio * 100).round()}%'
                      : limit == null
                      ? 'Set limit'
                      : formatMoney(limit, symbol: symbol),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: limit == null
                        ? FontWeight.w500
                        : FontWeight.w700,
                    color: derived.isNotEmpty
                        ? _statusColor(derived.first)
                        : limit == null
                        ? AppColors.muted(context)
                        : AppColors.ink(context),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (derived.isNotEmpty)
          BudgetLine(
            progress: derived.first,
            symbol: symbol,
            showHeader: false,
            showDetail: false,
            padding: const EdgeInsets.fromLTRB(68, 6, 20, 4),
          ),
      ],
    );
  }
}

/// 1 px separator used between preference rows.
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
