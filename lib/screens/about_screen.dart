import 'package:flutter/material.dart';

import '../components/section_title.dart';
import '../core/app_info.dart';
import '../core/app_theme.dart';
import '../core/motion.dart';

/// Credit where it is due: who made this, and what it is made of.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
            child: Row(
              children: <Widget>[
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    // The launcher icon's sage gradient, so the app and its
                    // icon look like the same thing.
                    gradient: const LinearGradient(
                      colors: <Color>[Color(0xFF96D6BC), Color(0xFF3A846A)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Text(
                      '৳',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    '${AppInfo.name} · ${AppInfo.nameBn}',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink(context),
                    ),
                  ),
                ),
                // Pinned to the right edge of the header, the same way every
                // other value in the app sits.
                Text(
                  'v${AppInfo.version}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted(context),
                  ),
                ),
                const SizedBox(width: 2),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'A daily khata for hall life: what you ate, what you spent, who owes '
              'you, and how much of the month is left. Kept small on purpose, so it '
              'opens fast and stays out of the way.',
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: AppColors.muted(context),
              ),
            ),
          ),
          const SectionTitle(title: 'Made by'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Palette.taka.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    size: 20,
                    color: Palette.taka,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        AppInfo.author,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink(context),
                        ),
                      ),
                      Text(
                        '${AppInfo.authorBn} · ${AppInfo.builtIn}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.muted(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SectionTitle(title: 'Built with'),
          const _Credit(
            icon: Icons.flutter_dash,
            title: 'Flutter & Dart',
            subtitle: 'One codebase, drawn by the framework itself',
          ),
          const _Credit(
            icon: Icons.storage_rounded,
            title: 'SQLite (sqflite)',
            subtitle: 'Your ledger lives in one local database file',
          ),
          const _Credit(
            icon: Icons.text_fields_rounded,
            title: 'Hind Siliguri',
            subtitle:
                'SIL Open Font License 1.1 — Bangla, Latin and ৳ in one family',
          ),
          const _Credit(
            icon: Icons.interests_outlined,
            title: 'Material Symbols',
            subtitle: 'Every icon in the app, no image assets',
          ),
          const SectionTitle(title: 'A note'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Nothing to set up before the first entry. Export a backup now and '
              'then — Settings, then Export — and you can carry your book to a new '
              'phone whenever you change handsets.',
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: AppColors.muted(context),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Pressable(
              onTap: () {},
              scale: 0.99,
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.favorite_border,
                    size: 15,
                    color: AppColors.muted(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Made for hall life, and for anyone else keeping a khata in '
                      'their pocket.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.5,
                        color: AppColors.muted(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Credit extends StatelessWidget {
  const _Credit({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: AppColors.muted(context)),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.ink(context),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.muted(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
