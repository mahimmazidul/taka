import '../db/transaction_repository.dart';
import '../models/transaction_entry.dart';
import '../models/udhar_entry.dart';
import '../utils/export_data.dart';
import 'app_state.dart';

/// Backup, restore and destructive actions.
extension DataActions on AppState {
  /// Full backup including the ledger — reads every row, not just recent ones.
  Future<String> buildFullBackup() async {
    final List<TransactionEntry> all = await transactions.query(
      const TransactionQuery(),
    );
    return buildBackupJson(
      settings: settings,
      categories: categories,
      transactions: all,
      udhar: await udharRepo.all(),
    );
  }

  Future<String> buildCsv() async {
    final List<TransactionEntry> all = await transactions.query(
      const TransactionQuery(),
    );
    return buildLedgerCsv(transactions: all, categories: categories);
  }

  /// Replaces everything with the contents of a backup file.
  /// Throws [FormatException] for anything that is not a Taka backup.
  Future<void> restoreBackup(String raw) async {
    final ImportBundle bundle = parseBackupJson(raw);

    await transactions.deleteAll();
    await udharRepo.deleteAll();

    for (final category in bundle.categories) {
      await categoryRepo.upsert(category);
    }
    for (final TransactionEntry entry in bundle.transactions) {
      await transactions.insert(entry);
    }
    for (final UdharEntry entry in bundle.udhar) {
      await udharRepo.insert(entry);
    }
    await settingsRepo.write(bundle.settings);

    await refresh();
  }

  /// Wipes the ledger and udhar records. Categories and settings survive.
  Future<void> clearAllData() async {
    await transactions.deleteAll();
    await udharRepo.deleteAll();
    await refresh();
  }
}
