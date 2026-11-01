import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/motion.dart';

/// One settings line: icon, title, optional subtitle, trailing value/chevron.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
    this.trailing,
    this.danger = false,
    this.valueTint,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool danger;

  /// Colour for the value text, when the value is telling you something (an
  /// update is waiting, for instance). Distinct from the row's own text tint.
  final Color? valueTint;

  @override
  Widget build(BuildContext context) {
    final Color tint = danger ? Palette.expense : AppColors.ink(context);

    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        child: Row(
          children: <Widget>[
            Icon(
              icon,
              size: 19,
              color: danger ? Palette.expense : AppColors.muted(context),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: tint,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.muted(context),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (value != null)
              // Align inside the flexible space: Flexible alone hands the text a
              // share of the row and leaves it stranded mid-screen.
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: valueTint == null
                          ? FontWeight.w400
                          : FontWeight.w600,
                      color: valueTint ?? AppColors.muted(context),
                    ),
                  ),
                ),
              ),
            ?trailing,
            if (onTap != null && trailing == null)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 19,
                  color: AppColors.muted(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Grouped settings block with a hairline between rows.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final List<Widget> spaced = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      spaced.add(children[i]);
      if (i != children.length - 1) {
        spaced.add(
          Padding(
            padding: const EdgeInsets.only(left: 53),
            child: Container(height: 1, color: AppColors.line(context)),
          ),
        );
      }
    }
    return Column(children: spaced);
  }
}
