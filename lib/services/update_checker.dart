import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/app_info.dart';

/// The newest release GitHub knows about, as far as this build is concerned.
class ReleaseCheck {
  const ReleaseCheck({
    required this.latestVersion,
    required this.url,
    required this.isNewer,
  });

  final String latestVersion;
  final String url;
  final bool isNewer;
}

/// Asks GitHub for the latest release and compares it with the running build.
///
/// Minimal on purpose: one request, no library, no polling, no nagging. The app
/// is offline-first, so every failure — no network, DNS, a rate limit, a
/// changed response — is reported as "could not check" and never as an error
/// the user has to deal with.
class UpdateChecker {
  UpdateChecker({http.Client? client, this.endpoint = _defaultEndpoint})
    : _client = client ?? http.Client();

  static const String _defaultEndpoint =
      'https://api.github.com/repos/mahimmazidul/taka/releases/latest';

  final http.Client _client;
  final String endpoint;

  /// A release page for the fallback case where GitHub answered but the body is
  /// not what we expected.
  static const String releasesPage =
      'https://github.com/mahimmazidul/taka/releases/latest';

  Future<ReleaseCheck?> latest() async {
    try {
      final http.Response response = await _client
          .get(
            Uri.parse(endpoint),
            headers: <String, String>{'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;
      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, Object?>) return null;

      final String tag = (decoded['tag_name'] as String?) ?? '';
      final String url = (decoded['html_url'] as String?) ?? releasesPage;
      final String latestVersion = tag.startsWith('v') ? tag.substring(1) : tag;
      if (latestVersion.isEmpty) return null;

      return ReleaseCheck(
        latestVersion: latestVersion,
        url: url,
        isNewer: isNewerVersion(latestVersion, AppInfo.version),
      );
    } catch (_) {
      // Offline, timeout, rate limited, or a response we did not expect.
      return null;
    }
  }

  void dispose() => _client.close();
}

/// Is [candidate] newer than [current]?
///
/// Numeric comparison per dotted part, so 1.10.0 is after 1.9.0 — the mistake a
/// plain string compare makes. Missing parts count as zero; a suffix after `-`
/// (1.5.0-beta) is ignored, because only tagged releases are served here.
bool isNewerVersion(String candidate, String current) {
  final List<int> a = _parts(candidate);
  final List<int> b = _parts(current);
  final int length = a.length > b.length ? a.length : b.length;
  for (int i = 0; i < length; i++) {
    final int left = i < a.length ? a[i] : 0;
    final int right = i < b.length ? b[i] : 0;
    if (left != right) return left > right;
  }
  return false;
}

List<int> _parts(String version) {
  final String cleaned = version.split('-').first.trim();
  return <int>[
    for (final String piece in cleaned.split('.'))
      int.tryParse(piece.replaceAll(RegExp('[^0-9]'), '')) ?? 0,
  ];
}
