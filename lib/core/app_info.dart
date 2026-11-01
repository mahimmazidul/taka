/// Identity of the build. Kept in one place so About, the README and the release
/// tag can be checked against each other.
class AppInfo {
  AppInfo._();

  static const String name = 'Taka';
  static const String nameBn = 'টাকা';
  static const String tagline = 'Amar taka gelota koi?';
  static const String version = '1.6.0';

  /// The person this was built for, and by.
  static const String author = 'Mazidul Islam Mahim';
  static const String authorBn = 'মাজিদুল ইসলাম মাহিম';
  static const String builtIn = 'Bangladesh';

  /// Repository, used by the update check and the source link.
  static const String repo = 'mahimmazidul/taka';
  static const String repoUrl = 'https://github.com/$repo';

  /// Public places, in the order they are listed in Settings.
  ///
  /// A link with an empty [url] is simply not shown, so adding or removing one
  /// is a one-line change and never leaves a dead row behind.
  static const List<SocialLink> socials = <SocialLink>[
    SocialLink(
      id: 'telegram',
      label: 'Telegram',
      url: 'https://t.me/dumbhuman',
      iconName: 'telegram',
    ),
    SocialLink(
      id: 'facebook',
      label: 'Facebook',
      url: 'https://www.facebook.com/notgreatnotterrible',
      iconName: 'facebook',
    ),
    SocialLink(id: 'github', label: 'GitHub', url: repoUrl, iconName: 'github'),
  ];

  /// Only the links that point somewhere.
  static List<SocialLink> get visibleSocials =>
      socials.where((SocialLink link) => link.url.isNotEmpty).toList();
}

/// One external profile: a label, a URL, and an icon key the UI maps itself so
/// this file stays free of Flutter imports.
class SocialLink {
  const SocialLink({
    required this.id,
    required this.label,
    required this.url,
    required this.iconName,
  });

  final String id;
  final String label;
  final String url;
  final String iconName;
}
