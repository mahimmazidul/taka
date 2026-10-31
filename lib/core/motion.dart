import 'package:flutter/material.dart';

import '../utils/format_currency.dart';

/// Press feedback: a 90 ms scale-down while the finger is down. Cheap (no
/// shadows, no blur), and it makes every tappable row feel alive.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.972,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final HitTestBehavior behavior;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool value) {
    if (_down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final bool interactive = widget.onTap != null || widget.onLongPress != null;

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: interactive ? (_) => _set(true) : null,
      onTapCancel: interactive ? () => _set(false) : null,
      onTapUp: interactive ? (_) => _set(false) : null,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Fade + rise entrance for content blocks. [index] staggers a list for free.
class Reveal extends StatelessWidget {
  const Reveal({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 14,
    this.duration = const Duration(milliseconds: 320),
  });

  final Widget child;
  final int index;
  final double offset;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final Duration delay = Duration(milliseconds: 40 * index.clamp(0, 6));

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration + delay,
      curve: Interval(
        delay.inMilliseconds / (duration.inMilliseconds + delay.inMilliseconds),
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (BuildContext context, double value, Widget? child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, offset * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Number that counts to its new value instead of snapping.
class AnimatedMoney extends StatefulWidget {
  const AnimatedMoney(
    this.minorUnits, {
    super.key,
    this.style,
    this.symbol = kDefaultCurrencySymbol,
    this.signed = false,
    this.duration = const Duration(milliseconds: 450),
  });

  final int minorUnits;
  final TextStyle? style;
  final String symbol;
  final bool signed;
  final Duration duration;

  @override
  State<AnimatedMoney> createState() => _AnimatedMoneyState();
}

class _AnimatedMoneyState extends State<AnimatedMoney> {
  late int _from = widget.minorUnits;

  @override
  void didUpdateWidget(covariant AnimatedMoney oldWidget) {
    super.didUpdateWidget(oldWidget);
    _from = oldWidget.minorUnits;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(
        begin: _from.toDouble(),
        end: widget.minorUnits.toDouble(),
      ),
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double value, Widget? _) {
        return Text(
          formatMoney(
            value.round(),
            symbol: widget.symbol,
            signed: widget.signed,
          ),
          style: widget.style,
          maxLines: 1,
        );
      },
    );
  }
}

/// Page transition used everywhere: quick fade with a small upward slide.
Route<T> slideFadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondary,
          Widget child,
        ) {
          final CurvedAnimation enter = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: enter,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.055),
                end: Offset.zero,
              ).animate(enter),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.985, end: 1).animate(enter),
                child: child,
              ),
            ),
          );
        },
  );
}
