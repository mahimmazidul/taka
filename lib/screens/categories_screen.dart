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

/// Manage expense categories and income sources.
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
              onTap: () =>
                  showCategoryEditor(context, kind: CategoryKind.expense),
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
          final Map<String, int> spend = state.monthSpend;

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: <Widget>[
              const SectionTitle(
                title: 'Expense categories',
                padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
              ),
              for (final AppCategory category in state.categoriesForKind(
                CategoryKind.expense,
              ))
                _CategoryRow(
                  category: category,
                  subtitle: <String>[
                    category.name,
                    if ((category.budgetMinor ?? 0) > 0)
                      'limit ${formatMoney(category.budgetMinor!, symbol: state.currencySymbol)}',
                    if ((spend[category.id] ?? 0) > 0)
                      '${formatMoney(spend[category.id]!, symbol: state.currencySymbol)} this month',
                  ].join(' · '),
                  onTap: () => showCategoryEditor(
                    context,
                    category: category,
                    kind: category.kind,
                  ),
                ),
              const SectionTitle(
                title: 'Income sources',
                padding: EdgeInsets.fromLTRB(20, 24, 20, 4),
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
                  'Tap a category to rename it, change its icon or colour, or delete it. '
                  'Deleting a category moves its entries to "Other" — nothing is lost.',
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
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.subtitle,
    required this.onTap,
  });

  final AppCategory category;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        child: Row(
          children: <Widget>[
            CategoryTile(category: category, size: 38),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    category.label,
                    style: TextStyle(
                      fontSize: 14.5,
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
