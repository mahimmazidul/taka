import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/motion.dart';
import '../utils/responsive.dart';
import 'add_entry_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'udhar_screen.dart';

/// Floating tab bar: Home · History · (+) · Udhar · Settings.
/// The add button lives *inside* the bar, so it never covers content.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  late final PageController _pages = PageController();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// Tabs glide instead of snapping. Swiping is off on purpose: History has
  /// horizontal chip rows, and stealing those drags would feel broken.
  void _select(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    _pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _addEntry() {
    Navigator.of(context).push(slideFadeRoute<void>(const AddEntryScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = <Widget>[
      HomeScreen(
        onOpenUdhar: () => _select(2),
        onOpenHistory: () => _select(1),
      ),
      const HistoryScreen(),
      const UdharScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: PageView(
        controller: _pages,
        physics: const NeverScrollableScrollPhysics(),
        children: tabs,
      ),
      bottomNavigationBar: _FloatingBar(
        index: _index,
        onSelect: _select,
        onAdd: _addEntry,
      ),
    );
  }
}

class _FloatingBar extends StatelessWidget {
  const _FloatingBar({
    required this.index,
    required this.onSelect,
    required this.onAdd,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final bool dark = AppColors.isDark(context);
    final Screen screen = Screen.of(context);

    // Landscape has half the height, so the bar takes half the vertical space it
    // does in portrait instead of eating a quarter of the screen.
    final double barHeight = screen.isLandscape ? 54 : 66;
    final double barRadius = screen.isLandscape ? 20 : 26;

    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(16, 0, 16, screen.isLandscape ? 8 : 12),
      child: ClipRRect(
        // A blur here looked lovely and cost a real frame every scroll tick on
        // mid-range phones. A flat translucent surface is indistinguishable once
        // the content behind it is bright.
        borderRadius: BorderRadius.circular(barRadius),
        child: DecoratedBox(
          decoration: const BoxDecoration(),
          child: Container(
            height: barHeight,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: (dark ? Palette.darkSurface : Colors.white).withValues(
                alpha: dark ? 0.97 : 0.99,
              ),
              borderRadius: BorderRadius.circular(barRadius),
              border: Border.all(color: AppColors.line(context)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.35 : 0.07),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                _TabItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  selected: index == 0,
                  onTap: () => onSelect(0),
                ),
                _TabItem(
                  icon: Icons.receipt_long_rounded,
                  label: 'History',
                  selected: index == 1,
                  onTap: () => onSelect(1),
                ),
                _AddButton(onTap: onAdd),
                _TabItem(
                  icon: Icons.handshake_rounded,
                  label: 'Udhar',
                  selected: index == 2,
                  onTap: () => onSelect(2),
                ),
                _TabItem(
                  icon: Icons.tune_rounded,
                  label: 'Settings',
                  selected: index == 3,
                  onTap: () => onSelect(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? Palette.taka : AppColors.muted(context);

    return Expanded(
      child: Pressable(
        onTap: onTap,
        scale: 0.92,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            AnimatedScale(
              scale: selected ? 1.06 : 1,
              duration: const Duration(milliseconds: 180),
              child: Icon(icon, size: 21, color: color),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                fontFamily: kFontFamily,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.9,
      child: Container(
        width: 46,
        height: 46,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFF12A98C), Palette.takaDeep],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Palette.taka.withValues(alpha: 0.34),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
      ),
    );
  }
}
