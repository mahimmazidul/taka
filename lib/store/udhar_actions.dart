import '../models/udhar_entry.dart';
import '../utils/id.dart';
import 'app_state.dart';

/// Lend/borrow actions.
extension UdharActions on AppState {
  Future<void> addUdhar({
    required UdharType type,
    required String person,
    required int amountMinor,
    required String note,
    required DateTime occurredAt,
  }) async {
    final DateTime now = this.now;
    await udharRepo.insert(
      UdharEntry(
        id: newId(),
        type: type,
        person: person.trim(),
        amountMinor: amountMinor,
        note: note.trim(),
        occurredAt: occurredAt,
        returned: false,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await refresh();
  }

  Future<void> setUdharReturned(String id, {required bool returned}) async {
    await udharRepo.setReturned(id, returned: returned);
    await refresh();
  }

  Future<void> deleteUdhar(String id) async {
    await udharRepo.delete(id);
    await refresh();
  }

  List<UdharEntry> udharFor(UdharType type) =>
      udharEntries.where((UdharEntry entry) => entry.type == type).toList(growable: false);
}
