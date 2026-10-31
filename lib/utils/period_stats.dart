import '../models/transaction_entry.dart';
import '../models/udhar_entry.dart';
import 'date_helpers.dart';

/// One day, with what went out and what came in.
class DayTotal {
  const DayTotal({
    required this.day,
    this.expenseMinor = 0,
    this.incomeMinor = 0,
  });

  final DateTime day;
  final int expenseMinor;
  final int incomeMinor;

  bool get isEmpty => expenseMinor == 0 && incomeMinor == 0;
}

/// One calendar month, rolled up.
class MonthTotal {
  const MonthTotal({
    required this.month,
    required this.expenseMinor,
    required this.incomeMinor,
    required this.days,
  });

  /// First day of the month.
  final DateTime month;
  final int expenseMinor;
  final int incomeMinor;
  final int days;

  int get netMinor => incomeMinor - expenseMinor;
}

/// Day-by-day totals for a window, oldest first, with empty days kept.
///
/// The empty days are the point: "what did I spend on Wednesday" has to answer
/// "nothing", not make Wednesday disappear from the week.
List<DayTotal> dailyTotals(
  List<TransactionEntry> entries, {
  required DateTime from,
  required DateTime toExclusive,
}) {
  final Map<DateTime, DayTotal> byDay = <DateTime, DayTotal>{};
  for (
    DateTime day = startOfDay(from);
    day.isBefore(toExclusive);
    day = startOfNextDay(day)
  ) {
    byDay[day] = DayTotal(day: day);
  }

  for (final TransactionEntry entry in entries) {
    final DateTime day = startOfDay(entry.occurredAt);
    final DayTotal? current = byDay[day];
    if (current == null) continue;
    byDay[day] = DayTotal(
      day: day,
      expenseMinor:
          current.expenseMinor + (entry.isExpense ? entry.amountMinor : 0),
      incomeMinor:
          current.incomeMinor + (entry.isExpense ? 0 : entry.amountMinor),
    );
  }

  final List<DayTotal> days = byDay.values.toList(growable: false);
  days.sort((DayTotal a, DayTotal b) => a.day.compareTo(b.day));
  return days;
}

/// Totals for every month from [from] to [to] inclusive, oldest first.
List<MonthTotal> monthlyTotals(
  List<TransactionEntry> entries, {
  required DateTime from,
  required DateTime to,
}) {
  final DateTime first = startOfMonth(from);
  final DateTime last = startOfMonth(to);
  final Map<DateTime, int> expense = <DateTime, int>{};
  final Map<DateTime, int> income = <DateTime, int>{};
  final Map<DateTime, int> activeDays = <DateTime, int>{};
  final Map<DateTime, Set<int>> dayNumbers = <DateTime, Set<int>>{};

  for (final TransactionEntry entry in entries) {
    final DateTime month = startOfMonth(entry.occurredAt);
    if (month.isBefore(first) || month.isAfter(last)) continue;
    if (entry.isExpense) {
      expense[month] = (expense[month] ?? 0) + entry.amountMinor;
    } else {
      income[month] = (income[month] ?? 0) + entry.amountMinor;
    }
    dayNumbers.putIfAbsent(month, () => <int>{}).add(entry.occurredAt.day);
    activeDays[month] = dayNumbers[month]!.length;
  }

  final List<MonthTotal> months = <MonthTotal>[];
  for (
    DateTime m = first;
    !m.isAfter(last);
    m = DateTime(m.year, m.month + 1)
  ) {
    months.add(
      MonthTotal(
        month: m,
        expenseMinor: expense[m] ?? 0,
        incomeMinor: income[m] ?? 0,
        days: activeDays[m] ?? 0,
      ),
    );
  }
  return months;
}

/// The first month the ledger has anything in, so the month list starts where
/// the user's history starts instead of at some arbitrary point.
DateTime firstMonthOf(List<TransactionEntry> entries, DateTime fallback) {
  DateTime earliest = fallback;
  for (final TransactionEntry entry in entries) {
    if (entry.occurredAt.isBefore(earliest)) earliest = entry.occurredAt;
  }
  return startOfMonth(earliest);
}

/// Whole years the ledger covers, newest first.
List<int> yearsCovered(List<TransactionEntry> entries, DateTime fallback) {
  int first = fallback.year;
  int last = fallback.year;
  for (final TransactionEntry entry in entries) {
    if (entry.occurredAt.year < first) first = entry.occurredAt.year;
    if (entry.occurredAt.year > last) last = entry.occurredAt.year;
  }
  return <int>[for (int y = last; y >= first; y--) y];
}

/// Entries that belong to one calendar day, newest first — what the day sheet
/// lists under the total.
List<TransactionEntry> entriesOnDay(
  List<TransactionEntry> entries,
  DateTime day,
) {
  final List<TransactionEntry> found = entries
      .where((TransactionEntry e) => isSameDay(e.occurredAt, day))
      .toList();
  found.sort(
    (TransactionEntry a, TransactionEntry b) =>
        b.occurredAt.compareTo(a.occurredAt),
  );
  return found;
}

/// Udhar is money too, but it is not spending: a loan leaves the pocket and
/// comes back. Kept here so the period screens never quietly fold it in.
int udharNetMinor(List<UdharEntry> entries) {
  int net = 0;
  for (final UdharEntry entry in entries) {
    if (entry.returned) continue;
    net += entry.type == UdharType.lent
        ? -entry.amountMinor
        : entry.amountMinor;
  }
  return net;
}
