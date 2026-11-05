import '../core/clock.dart';
import '../models/app_settings.dart';
import '../models/savings_entry.dart';
import '../utils/id.dart';
import 'app_state.dart';

/// Putting money aside, taking it back, and the optional goal.
extension SavingsActions on AppState {
  /// Moves [amountMinor] into the pot, or back out of it.
  ///
  /// Nothing is written to the transaction ledger: saving is not spending, and a
  /// month that counted it as spending would answer "where did the money go"
  /// with the one place it did not go.
  Future<void> addSavings({
    required SavingsDirection direction,
    required int amountMinor,
    String note = '',
    DateTime? occurredAt,
  }) async {
    if (amountMinor <= 0) return;
    final DateTime now = AppClock.now();
    await savingsRepo.insert(
      SavingsEntry(
        id: newId(),
        direction: direction,
        amountMinor: amountMinor,
        note: note.trim(),
        occurredAt: occurredAt ?? now,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await refresh();
  }

  /// Removes a movement. Takes the money back to where it was.
  Future<void> deleteSavings(String id) async {
    await savingsRepo.delete(id);
    await refresh();
  }

  /// A target is optional and can be cleared; the pot does not need one.
  Future<void> setSavingsGoal({int? amountMinor, String? label}) async {
    final AppSettings next = (amountMinor == null || amountMinor <= 0)
        ? settings.copyWith(clearSavingsGoal: true)
        : settings.copyWith(
            savingsGoalMinor: amountMinor,
            savingsGoalLabel: (label ?? '').trim().isEmpty
                ? null
                : label!.trim(),
          );
    await applySettings(next);
  }

  Future<void> setSavingsEnabled(bool value) async {
    await applySettings(settings.copyWith(savingsEnabled: value));
    await refresh();
  }
}
