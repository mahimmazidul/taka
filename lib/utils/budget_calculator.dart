import '../models/app_category.dart';
import '../models/budget_progress.dart';

/// Joins budgeted categories with this month's spend, sorted so the categories
/// closest to (or over) their limit appear first — that's the useful order on
/// the dashboard. Budget-less categories are skipped.
List<BudgetProgress> buildBudgetProgress({
  required List<AppCategory> categories,
  required Map<String, int> spentByCategoryMinor,
}) {
  final List<BudgetProgress> rows = <BudgetProgress>[];

  for (final AppCategory category in categories) {
    if (category.kind != CategoryKind.expense) continue;
    final int budget = category.budgetMinor ?? 0;
    if (budget <= 0) continue;
    rows.add(
      BudgetProgress(
        category: category,
        spentMinor: spentByCategoryMinor[category.id] ?? 0,
        budgetMinor: budget,
      ),
    );
  }

  rows.sort((BudgetProgress a, BudgetProgress b) {
    final int bySeverity = b.ratio.compareTo(a.ratio);
    if (bySeverity != 0) return bySeverity;
    return a.category.sortOrder.compareTo(b.category.sortOrder);
  });

  return rows;
}
