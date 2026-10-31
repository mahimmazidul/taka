import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/app_category.dart';
import '../models/app_settings.dart';
import '../models/transaction_entry.dart';
import '../models/udhar_entry.dart';
import '../core/clock.dart';

const String kBackupFormat = 'taka-backup';
const int kBackupVersion = 1;

/// Full backup payload: settings + categories + ledger + udhar.
String buildBackupJson({
  required AppSettings settings,
  required List<AppCategory> categories,
  required List<TransactionEntry> transactions,
  required List<UdharEntry> udhar,
}) {
  final Map<String, Object?> payload = <String, Object?>{
    'format': kBackupFormat,
    'version': kBackupVersion,
    'exportedAt': AppClock.now().toIso8601String(),
    'settings': settings.toMap(),
    'categories': categories.map((AppCategory c) => c.toMap()).toList(),
    'transactions': transactions
        .map((TransactionEntry t) => t.toMap())
        .toList(),
    'udhar': udhar.map((UdharEntry u) => u.toMap()).toList(),
  };
  return const JsonEncoder.withIndent('  ').convert(payload);
}

/// CSV of the ledger, one row per entry. Notes are quoted so commas survive.
String buildLedgerCsv({
  required List<TransactionEntry> transactions,
  required List<AppCategory> categories,
}) {
  final StringBuffer buffer = StringBuffer()
    ..writeln('date,type,amount_bdt,category,category_bn,note');

  for (final TransactionEntry entry in transactions) {
    final AppCategory? category = categories
        .where((AppCategory c) => c.id == entry.categoryId)
        .cast<AppCategory?>()
        .firstWhere((AppCategory? c) => true, orElse: () => null);

    final String amount = (entry.amountMinor / 100).toStringAsFixed(2);
    final String note = entry.note.replaceAll('"', '""');
    buffer.writeln(
      '${entry.occurredAt.toIso8601String()},${entry.type.dbValue},$amount,'
      '"${category?.name ?? ''}","${category?.nameBn ?? ''}","$note"',
    );
  }
  return buffer.toString();
}

/// Parsed backup, ready to hand to the importer.
class ImportBundle {
  const ImportBundle({
    required this.settings,
    required this.categories,
    required this.transactions,
    required this.udhar,
  });

  final AppSettings settings;
  final List<AppCategory> categories;
  final List<TransactionEntry> transactions;
  final List<UdharEntry> udhar;
}

/// Throws [FormatException] when the file is not a Taka backup.
ImportBundle parseBackupJson(String raw) {
  final Object? decoded = jsonDecode(raw);
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('Not a JSON object');
  }
  if (decoded['format'] != kBackupFormat) {
    throw const FormatException('Not a Taka backup file');
  }

  List<Map<String, Object?>> rows(Object? value) =>
      (value as List<Object?>? ?? const <Object?>[])
          .whereType<Map<String, Object?>>()
          .toList(growable: false);

  return ImportBundle(
    settings: AppSettings.fromMap(
      (decoded['settings'] as Map<String, Object?>? ??
              const <String, Object?>{})
          .map(
            (String key, Object? value) =>
                MapEntry<String, String>(key, '$value'),
          ),
    ),
    categories: rows(decoded['categories'])
        .map(AppCategory.fromMap)
        .toList(growable: false),
    transactions: rows(decoded['transactions'])
        .map(TransactionEntry.fromMap)
        .toList(growable: false),
    udhar: rows(decoded['udhar'])
        .map(UdharEntry.fromMap)
        .toList(growable: false),
  );
}

/// Writes text to the app's temp folder and opens the system share sheet.
Future<void> shareTextFile({
  required String fileName,
  required String content,
  required String subject,
}) async {
  final Directory dir = await getTemporaryDirectory();
  final File file = File(p.join(dir.path, fileName));
  await file.writeAsString(content);
  await SharePlus.instance.share(
    ShareParams(
      files: <XFile>[XFile(file.path, mimeType: 'text/plain')],
      subject: subject,
    ),
  );
}
