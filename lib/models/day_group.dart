/// A day's worth of rows, used by the history list and day headings.
class DayGroup<T> {
  DayGroup(this.day, this.items);

  final DateTime day;
  final List<T> items;
}
