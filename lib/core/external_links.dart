import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Icons for the profiles listed in [AppInfo.socials].
///
/// Kept as a switch rather than a map of consts so an unknown key falls back to
/// a generic link instead of throwing while the UI is being built.
IconData socialIcon(String key) => switch (key) {
  'telegram' => Icons.send_rounded,
  'facebook' => Icons.facebook_rounded,
  'github' => Icons.code_rounded,
  _ => Icons.link_rounded,
};

/// Open [url] in whatever the phone uses for it.
///
/// Returns false when nothing could handle the link, so the caller can tell the
/// user instead of leaving a tap that did nothing.
Future<bool> openExternal(String url) async {
  final Uri? uri = Uri.tryParse(url);
  if (uri == null) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
