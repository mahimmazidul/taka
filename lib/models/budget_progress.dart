import 'app_category.dart';

enum BudgetStatus {
  /// Under 80% of the limit.
  ok,

  /// 80% to 99% — warn the user.
  warning,

  /// 100% or more — over the limit.
  exceeded,
}

/// A category budget joined with what has actually been spent this month.
class BudgetProgress {
  const BudgetProgress({
    required this.category,
    required this.spentMinor,
    required this.budgetMinor,
  });

  final AppCategory category;
  final int spentMinor;
  final int budgetMinor;

  double get ratio => budgetMinor <= 0 ? 0 : spentMinor / budgetMinor;

  int get remainingMinor => budgetMinor - spentMinor;

  BudgetStatus get status {
    if (ratio >= 1) return BudgetStatus.exceeded;
    if (ratio >= 0.8) return BudgetStatus.warning;
    return BudgetStatus.ok;
  }

  /// Clamped 0..1 so a 140% bar still renders inside its track.
  double get clampedRatio => ratio.clamp(0, 1).toDouble();
}
