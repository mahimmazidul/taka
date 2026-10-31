import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/app_category.dart';

/// Soft tinted square holding a category glyph — no border, no shadow.
class CategoryTile extends StatelessWidget {
  const CategoryTile({super.key, required this.category, this.size = 42});

  final AppCategory category;
  final double size;

  @override
  Widget build(BuildContext context) =>
      IconTile(icon: category.iconData, color: category.color, size: size);
}

/// Same shape, explicit icon/colour — used by rows that have no category.
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.color,
    this.size = 42,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppColors.isDark(context) ? 0.20 : 0.13),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(icon, size: size * 0.48, color: color),
    );
  }
}
