import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Registers the two licences that ship as files rather than as packages, so the
/// in-app Licences page can show them: this app's own terms and the Hind Siliguri
/// font's SIL Open Font License.
///
/// Flutter already collects the BSD-style licences of every package it bundles
/// (sqflite, http, url_launcher, Flutter itself) into `LicenseRegistry`; these two
/// are added here because they are assets, not dependencies.
void registerAppLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(<String>[
      'Taka',
      'টাকা',
    ], await _asset('LICENSE'));
  });

  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(<String>[
      'Hind Siliguri (Indian Type Foundry)',
    ], await _asset('assets/fonts/OFL.txt'));
  });
}

Future<String> _asset(String path) async {
  try {
    return await rootBundle.loadString(path);
  } catch (_) {
    // A missing asset is not worth crashing the licences page over; say so
    // plainly instead of showing nothing.
    return 'This licence file could not be read from the app bundle ($path). '
        'It is available in the repository.';
  }
}
