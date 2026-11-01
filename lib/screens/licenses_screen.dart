import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_info.dart';
import '../core/app_theme.dart';
import '../components/entry_row.dart';
import '../core/motion.dart';
import '../components/section_title.dart';
import '../utils/responsive.dart';

/// The licences that ship with this app, as text, in the app.
///
/// Flutter's own `showLicensePage` only knows about the packages the build
/// tool noticed, and it shows nothing at all when that list is empty — which is
/// what it looks like in a test, and what it would look like if the bundle ever
/// came up short. So the two licences that matter here are read from the assets
/// and printed in place, with a link to the package list for everything else.
class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final double gutter = Screen.of(context).gutter;

    return Scaffold(
      appBar: AppBar(title: const Text('Licences')),
      body: ListView(
        padding: EdgeInsets.only(
          top: 4,
          bottom: 28,
          left: gutter,
          right: gutter,
        ),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${AppInfo.name} · ${AppInfo.nameBn}',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'v${AppInfo.version} · free to use for anything noncommercial',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.muted(context),
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle(title: 'This app'),
          _LicenseText(asset: 'LICENSE'),
          const SectionTitle(title: 'Font'),
          _LicenseText(asset: 'assets/fonts/OFL.txt'),
          const SectionTitle(title: 'Everything else'),
          _PackagesRow(),
          const Hairline(indent: 20),
        ],
      ),
    );
  }
}

/// One licence file, printed as it is.
///
/// Deliberately *not* a monospace face: the app bundles one font family, and a
/// font that has to be found on the device renders as empty boxes the moment it
/// is missing. Small type in the app's own font is honest and always readable.
class _LicenseText extends StatelessWidget {
  const _LicenseText({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _load(asset),
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Text(
            _plain(snapshot.data ?? ''),
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: AppColors.muted(context),
            ),
          ),
        );
      },
    );
  }

  /// The licence files are markdown. Headings and link syntax would be noise in
  /// a text block, so the punctuation is dropped and the words are kept.
  String _plain(String raw) {
    return raw
        .replaceAll(RegExp(r'^#+\s*', multiLine: true), '')
        .replaceAllMapped(
          RegExp(r'\[([^\]]+)\]\([^)]*\)'),
          (Match match) => match[1] ?? '',
        )
        .replaceAllMapped(RegExp(r'<([^>\s]+)>'), (Match m) => m[1] ?? '')
        .replaceAll('**', '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  Future<String> _load(String path) async {
    try {
      return await rootBundle.loadString(path);
    } catch (_) {
      return 'This licence file could not be read from the app bundle ($path). '
          'It is in the repository, next to the code.';
    }
  }
}

class _PackagesRow extends StatelessWidget {
  const _PackagesRow();

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => showLicensePage(
        context: context,
        applicationName: '${AppInfo.name} · ${AppInfo.nameBn}',
        applicationVersion: 'v${AppInfo.version}',
        applicationLegalese:
            'PolyForm Noncommercial License 1.0.0\n© ${AppInfo.author}',
      ),
      scale: 0.985,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.inventory_2_outlined,
              size: 19,
              color: AppColors.muted(context),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Third-party packages',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink(context),
                    ),
                  ),
                  Text(
                    'Flutter, sqflite, http, url_launcher and the rest',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.muted(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.muted(context),
            ),
          ],
        ),
      ),
    );
  }
}
