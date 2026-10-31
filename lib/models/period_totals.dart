/// Expense/income sums for a time window (today, this week, this month, all time).
class PeriodTotals {
  const PeriodTotals({required this.expenseMinor, required this.incomeMinor});

  const PeriodTotals.empty() : expenseMinor = 0, incomeMinor = 0;

  final int expenseMinor;
  final int incomeMinor;

  int get netMinor => incomeMinor - expenseMinor;

  bool get isEmpty => expenseMinor == 0 && incomeMinor == 0;
}

/// One column of the 7-day chart.
class DailyTotal {
  const DailyTotal({
    required this.day,
    required this.expenseMinor,
    required this.incomeMinor,
  });

  /// Midnight of the day this bucket represents.
  final DateTime day;
  final int expenseMinor;
  final int incomeMinor;
}
