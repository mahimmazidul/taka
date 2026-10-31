import 'package:flutter/material.dart';

import '../components/category_tile.dart';
import '../components/section_title.dart';
import '../core/app_theme.dart';
import '../core/motion.dart';
import '../models/app_category.dart';
import '../store/app_state.dart';
import '../utils/format_currency.dart';
import 'budgets_screen.dart';
import 'category_editor_sheet.dart';

/// Manage the two-level category tree and the income sources.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Pressable(
              onTap: () => showCategoryEditor(
                context,
                kind: CategoryKind.expense,
                parentId: AppState.instance.expenseGroups.firstOrNull?.id,
              ),
              scale: 0.9,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Palette.taka.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Row(
                  children: <Widget>[
                    Icon(Icons.add_rounded, size: 16, color: Palette.taka),
                    SizedBox(width: 3),
                    Text(
                      'New',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Palette.taka,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: AppState.instance,
        builder: (BuildContext context, Widget? _) {
          final AppState state = AppState.instance;
          final String symbol = state.currencySymbol;

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: <Widget>[
              const SectionTitle(
                title: 'Expense groups',
                padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
              ),
              for (final AppCategory group in state.expenseGroups) ...<Widget>[
                _GroupRow(
                  group: group,
                  itemCount: state.childrenOf(group.id).length,
                  spendMinor: state.spendOf(group.id),
                  symbol: symbol,
                  onTap: () => showCategoryEditor(
                    context,
                    category: group,
                    kind: group.kind,
                  ),
                ),
                for (final AppCategory child in state.childrenOf(group.id))
                  _CategoryRow(
                    category: child,
                    indent: true,
                    subtitle: _subtitle(state, child, symbol),
                    onTap: () => showCategoryEditor(
                      context,
                      category: child,
                      kind: child.kind,
                      parentId: child.parentId,
                    ),
                  ),
              ],
              const SectionTitle(
                title: 'Standalone',
                padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              ),
              for (final AppCategory category in state.standaloneExpense)
                _CategoryRow(
                  category: category,
                  subtitle: _subtitle(state, category, symbol),
                  onTap: () => showCategoryEditor(
                    context,
                    category: category,
                    kind: category.kind,
                  ),
                ),
              const SectionTitle(
                title: 'Income sources',
                padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              ),
              for (final AppCategory category in state.categoriesForKind(
                CategoryKind.income,
              ))
                _CategoryRow(
                  category: category,
                  subtitle: category.name,
                  onTap: () => showCategoryEditor(
                    context,
                    category: category,
                    kind: category.kind,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                child: Text(
                  'Tap anything to rename it, change its icon or colour, move it '
                  'to another group, or delete it. Deleting an item moves its '
                  'entries to "Other"; deleting a group keeps its items and moves '
                  'them to the top row. Nothing is ever lost.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.5,
                    color: AppColors.muted(context),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: OutlinedButton.icon(
                  onPressed: () =>
                      Navigator.of(context)
                          .push(slideFadeRoute<void>(const BudgetsScreen())),
                  icon: const Icon(Icons.flag_outlined, size: 17),
                  label: const Text('Set monthly limits'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _subtitle(AppState state, AppCategory category, String symbol) {
    final int spend = state.monthSpend[category.id] ?? 0;
    return <String>[
      category.name,
      if ((category.budgetMinor ?? 0) > 0)
        'limit ${formatMoney(category.budgetMinor!, symbol: symbol)}',
      if (spend > 0) '${formatMoney(spend, symbol: symbol)} this month',
    ].join(' · ');
  }
}

/// A group header: bigger tile, its item count, and the month's rolled-up spend.
class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.group,
    required this.itemCount,
    required this.spendMinor,
    required this.symbol,
    required this.onTap,
  });

  final AppCategory group;
  final int itemCount;
  final int spendMinor;
  final String symbol;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
        child: Row(
          children: <Widget>[
            CategoryTile(category: group, size: 42),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    group.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink(context),
                    ),
                  ),
                  Text(
                    <String>[
                      group.name,
                      '$itemCount item${itemCount == 1 ? '' : 's'}',
                      if (spendMinor > 0)
                        '${formatMoney(spendMinor, symbol: symbol)} this month',
                    ].join(' · '),
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
            Icon(
              Icons.chevron_right_rounded,
              size: 19,
              color: AppColors.muted(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.subtitle,
    required this.onTap,
    this.indent = false,
  });

  final AppCategory category;
  final String subtitle;
  final VoidCallback onTap;
  final bool indent;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: Padding(
        padding: EdgeInsets.fromLTRB(indent ? 44 : 20, 8, 20, 8),
        child: Row(
          children: <Widget>[
            CategoryTile(category: category, size: indent ? 32 : 38),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    category.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: indent ? 14 : 14.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink(context),
                    ),
                  ),
                  Text(
                    subtitle,
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
            Icon(
              Icons.chevron_right_rounded,
              size: 19,
              color: AppColors.muted(context),
            ),
          ],
        ),
      ),
    );
  }
}
