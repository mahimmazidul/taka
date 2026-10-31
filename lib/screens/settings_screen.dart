import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../components/app_sheet.dart';
import '../components/section_title.dart';
import '../components/settings_row.dart';
import '../core/app_theme.dart';
import '../core/motion.dart';
import '../store/app_state.dart';
import '../store/data_actions.dart';
import '../store/settings_actions.dart';
import '../utils/currency_catalog.dart';
import '../utils/export_data.dart';
import 'budgets_screen.dart';
import 'categories_screen.dart';
import '../core/clock.dart';

/// Preferences, category management, backup and the destructive button.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _pickCurrency(BuildContext context) async {
    final AppState state = AppState.instance;
    await showAppSheet<void>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
          children: <Widget>[
            const SheetTitle(
              title: 'Currency',
              subtitle: 'Used for every amount',
            ),
            for (final CurrencyOption option in kCurrencies)
              SettingsRow(
                icon: Icons.payments_outlined,
                title: option.label,
                onTap: () async {
                  await state.setCurrency(option.code);
                  if (context.mounted) Navigator.of(context).pop();
                },
                trailing: state.settings.currencyCode == option.code
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: Palette.taka,
                      )
                    : null,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportJson(BuildContext context) async {
    final String json = await AppState.instance.buildFullBackup();
    await shareTextFile(
      fileName: 'taka-backup-${AppClock.now().millisecondsSinceEpoch}.json',
      content: json,
      subject: 'Taka backup',
    );
    if (context.mounted) _toast(context, 'Backup ready to save or share');
  }

  Future<void> _exportCsv(BuildContext context) async {
    final String csv = await AppState.instance.buildCsv();
    await shareTextFile(
      fileName: 'taka-ledger-${AppClock.now().millisecondsSinceEpoch}.csv',
      content: csv,
      subject: 'Taka ledger',
    );
    if (context.mounted) _toast(context, 'CSV ready to save or share');
  }

  Future<void> _import(BuildContext context) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final PlatformFile file = result.files.single;
    final String raw;
    if (file.bytes != null) {
      raw = utf8.decode(file.bytes!);
    } else if (file.path != null) {
      raw = await File(file.path!).readAsString();
    } else {
      return;
    }

    if (!context.mounted) return;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Replace current data?'),
        content: const Text(
          'Importing a backup overwrites the entries and udhar records you have now.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await AppState.instance.restoreBackup(raw);
      if (context.mounted) _toast(context, 'Backup restored');
    } on FormatException {
      if (context.mounted) _toast(context, 'That file is not a Taka backup');
    }
  }

  Future<void> _clear(BuildContext context) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete all entries?'),
        content: const Text(
          'Every expense, income and udhar record will be deleted. '
          'Categories and settings stay. This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Palette.expense),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await AppState.instance.clearAllData();
    if (context.mounted) _toast(context, 'All entries deleted');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: AnimatedBuilder(
        animation: AppState.instance,
        builder: (BuildContext context, Widget? _) {
          final AppState state = AppState.instance;
          final bool dark = state.settings.darkMode;

          return ListView(
            padding: const EdgeInsets.only(bottom: 110),
            children: <Widget>[
              const SectionTitle(
                title: 'Appearance',
                padding: EdgeInsets.fromLTRB(20, 6, 20, 4),
              ),
              SettingsGroup(
                children: <Widget>[
                  SettingsRow(
                    icon: dark
                        ? Icons.dark_mode_outlined
                        : Icons.light_mode_outlined,
                    title: 'Dark mode',
                    subtitle: dark ? 'On' : 'Off',
                    onTap: () => state.toggleDarkMode(),
                    trailing: Switch.adaptive(
                      value: dark,
                      activeThumbColor: Palette.taka,
                      onChanged: (bool value) => state.setDarkMode(value),
                    ),
                  ),
                ],
              ),
              const SectionTitle(title: 'Money'),
              SettingsGroup(
                children: <Widget>[
                  SettingsRow(
                    icon: Icons.payments_outlined,
                    title: 'Currency',
                    value:
                        '${state.settings.currencySymbol} '
                        '${state.settings.currencyCode}',
                    onTap: () => _pickCurrency(context),
                  ),
                  SettingsRow(
                    icon: Icons.flag_outlined,
                    title: 'Monthly budgets',
                    subtitle: state.settings.budgetsEnabled
                        ? 'Warnings at 80%'
                        : 'Hidden',
                    onTap: () =>
                        Navigator.of(context)
                            .push(slideFadeRoute<void>(const BudgetsScreen())),
                  ),
                  SettingsRow(
                    icon: Icons.handshake_outlined,
                    title: 'Udhar tracker',
                    subtitle: state.settings.udharEnabled
                        ? 'Shown on Home'
                        : 'Hidden',
                    trailing: Switch.adaptive(
                      value: state.settings.udharEnabled,
                      activeThumbColor: Palette.taka,
                      onChanged: (bool value) => state.setUdharEnabled(value),
                    ),
                  ),
                ],
              ),
              const SectionTitle(title: 'Categories'),
              SettingsGroup(
                children: <Widget>[
                  SettingsRow(
                    icon: Icons.category_outlined,
                    title: 'Manage categories',
                    subtitle:
                        '${state.categories.length} total · rename, recolour, delete',
                    onTap: () => Navigator.of(context)
                        .push(slideFadeRoute<void>(const CategoriesScreen())),
                  ),
                ],
              ),
              const SectionTitle(title: 'Data'),
              SettingsGroup(
                children: <Widget>[
                  SettingsRow(
                    icon: Icons.ios_share_rounded,
                    title: 'Export backup (JSON)',
                    subtitle: 'Everything, restorable in one tap',
                    onTap: () => _exportJson(context),
                  ),
                  SettingsRow(
                    icon: Icons.table_chart_outlined,
                    title: 'Export ledger (CSV)',
                    subtitle: 'Open it in Excel or Sheets',
                    onTap: () => _exportCsv(context),
                  ),
                  SettingsRow(
                    icon: Icons.download_rounded,
                    title: 'Import backup',
                    subtitle: 'Replaces current entries',
                    onTap: () => _import(context),
                  ),
                  SettingsRow(
                    icon: Icons.delete_outline_rounded,
                    title: 'Clear all data',
                    danger: true,
                    onTap: () => _clear(context),
                  ),
                ],
              ),
              const SectionTitle(title: 'About'),
              SettingsGroup(
                children: <Widget>[
                  const SettingsRow(
                    icon: Icons.info_outline_rounded,
                    title: 'Taka · টাকা',
                    subtitle: 'Amar taka gelota koi?',
                    value: 'v1.0.0',
                  ),
                  SettingsRow(
                    icon: Icons.lock_outline_rounded,
                    title: 'Fully offline',
                    subtitle: 'No account, no cloud, no tracking. Your data stays on this phone.',
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
