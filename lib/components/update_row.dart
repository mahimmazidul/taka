import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_theme.dart';
import '../services/update_checker.dart';
import 'settings_row.dart';

/// "Check for updates" — one row, one request, one honest answer.
///
/// It never nags: it only speaks when the user taps it, and if it cannot reach
/// GitHub it says so plainly instead of inventing a version.
class UpdateRow extends StatefulWidget {
  const UpdateRow({super.key, this.checker});

  /// Injected by tests; production builds one with a real HTTP client.
  final UpdateChecker? checker;

  @override
  State<UpdateRow> createState() => _UpdateRowState();
}

class _UpdateRowState extends State<UpdateRow> {
  UpdateChecker? _checker;
  bool _busy = false;
  ReleaseCheck? _result;
  bool _failed = false;

  UpdateChecker get _client => _checker ??= widget.checker ?? UpdateChecker();

  @override
  void dispose() {
    if (widget.checker == null) _checker?.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (_busy) return;

    // Second tap on an "available" row opens the download page instead of
    // asking GitHub the same question again.
    final ReleaseCheck? known = _result;
    if (known != null && known.isNewer) {
      await launchUrl(
        Uri.parse(known.url),
        mode: LaunchMode.externalApplication,
      );
      return;
    }
    setState(() {
      _busy = true;
      _failed = false;
      _result = null;
    });
    final ReleaseCheck? check = await _client.latest();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _result = check;
      _failed = check == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final String? value;
    if (_busy) {
      value = 'Checking…';
    } else if (_failed) {
      value = 'Could not check';
    } else if (_result == null) {
      value = null;
    } else if (_result!.isNewer) {
      value = 'v${_result!.latestVersion} available';
    } else {
      value = 'Up to date';
    }

    return SettingsRow(
      icon: Icons.system_update_alt_rounded,
      title: 'Check for updates',
      subtitle: _result != null && _result!.isNewer
          ? 'Tap again to open the release page'
          : 'Asks GitHub, does nothing else',
      value: value,
      valueTint: _result != null && _result!.isNewer ? Palette.taka : null,
      onTap: _check,
    );
  }
}
