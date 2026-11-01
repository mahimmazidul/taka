/// Date helpers. Weeks start on Sunday, which is the norm in Bangladesh.
library;

import '../models/day_group.dart';
import '../core/clock.dart';

const int kWeekStartsOnWeekday = DateTime.sunday;

const List<String> _monthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const List<String> _monthShort = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const List<String> _weekdayShort = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

DateTime startOfDay(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);

DateTime startOfNextDay(DateTime moment) =>
    startOfDay(moment).add(const Duration(days: 1));

DateTime startOfWeek(DateTime moment) {
  final DateTime day = startOfDay(moment);
  final int diff = (day.weekday - kWeekStartsOnWeekday) % 7;
  return day.subtract(Duration(days: diff));
}

DateTime startOfMonth(DateTime moment) => DateTime(moment.year, moment.month);

DateTime startOfNextMonth(DateTime moment) =>
    DateTime(moment.year, moment.month + 1);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String monthName(int month) => _monthNames[(month - 1).clamp(0, 11)];

/// "carried from October" / "carried from December 2025" — the month before
/// [moment], with the year only when it is a different one, because
/// "carried from December" in January would be ambiguous.
String previousMonthLabel(DateTime moment) {
  final DateTime previous = DateTime(moment.year, moment.month - 1);
  final String name = monthName(previous.month);
  return previous.year == moment.year
      ? 'carried from $name'
      : 'carried from $name ${previous.year}';
}

String monthShort(int month) => _monthShort[(month - 1).clamp(0, 11)];

String formatMonthYear(DateTime moment) =>
    '${monthName(moment.month)} ${moment.year}';

String weekdayShort(DateTime moment) => _weekdayShort[moment.weekday - 1];

/// "Today", "Yesterday", "12 Oct", or "12 Oct 2025" for older years.
String formatDateLabel(DateTime moment) {
  final DateTime today = startOfDay(AppClock.now());
  final DateTime day = startOfDay(moment);
  final int delta = today.difference(day).inDays;

  if (delta == 0) return 'Today';
  if (delta == 1) return 'Yesterday';
  if (day.year == today.year) return '${day.day} ${monthShort(day.month)}';
  return '${day.day} ${monthShort(day.month)} ${day.year}';
}

/// Section heading for the history list.
/// Today/Yesterday get the weekday too ("Today · Sat, 31 Oct"); older days
/// would just repeat the date, so they show "Thu, 29 Oct".
String formatDayHeading(DateTime moment) {
  final DateTime today = startOfDay(AppClock.now());
  final int delta = today.difference(startOfDay(moment)).inDays;
  final String weekday =
      '${weekdayShort(moment)}, ${moment.day} ${monthShort(moment.month)}';

  if (delta == 0) return 'Today · $weekday';
  if (delta == 1) return 'Yesterday · $weekday';
  return weekday;
}

String formatTime(DateTime moment) {
  final int hour24 = moment.hour;
  final int hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final String minute = moment.minute.toString().padLeft(2, '0');
  final String meridiem = hour24 < 12 ? 'AM' : 'PM';
  return '$hour12:$minute $meridiem';
}

/// Keeps the current clock time when the user only picks a different day.
DateTime withCurrentTime(DateTime day) {
  final DateTime now = AppClock.now();
  return DateTime(
    day.year,
    day.month,
    day.day,
    now.hour,
    now.minute,
    now.second,
  );
}

/// Groups a newest-first list of dated items by calendar day, preserving order.
List<DayGroup<T>> groupByDay<T>(List<T> items, DateTime Function(T) dateOf) {
  final List<DayGroup<T>> groups = <DayGroup<T>>[];
  for (final T item in items) {
    final DateTime day = startOfDay(dateOf(item));
    if (groups.isNotEmpty && isSameDay(groups.last.day, day)) {
      groups.last.items.add(item);
    } else {
      groups.add(DayGroup<T>(day, <T>[item]));
    }
  }
  return groups;
}
