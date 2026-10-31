/// Provider for the current instant.
typedef NowProvider = DateTime Function();

/// The single source of "now" for the whole app.
///
/// Everything that needs the current time reads it from here instead of calling
/// `DateTime.now()` directly. Production never touches [now], so behaviour is
/// unchanged; tests (including the golden screenshots) replace it with a frozen
/// instant so a run at 08:39 and a run at 18:31 render the same pixels.
class AppClock {
  AppClock._();

  /// Swappable clock. Defaults to the real wall clock.
  static NowProvider now = DateTime.now;
}
