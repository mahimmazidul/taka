import 'package:flutter/widgets.dart';

/// Phone-first sizing.
///
/// Nothing is sized by a magic number any more: a 5" phone, a 6.7" phone and a
/// tablet get the same layout, scaled by how much screen they actually have.
/// The reference device is 390 × 844 logical pixels (a 6.1" phone).
class Screen {
  const Screen._(this.size);

  factory Screen.of(BuildContext context) =>
      Screen._(MediaQuery.sizeOf(context));

  final Size size;

  double get width => size.width;
  double get height => size.height;
  double get shortest => size.shortestSide;

  bool get isLandscape => width > height;

  /// Tall enough to stack, wide enough to sit side by side.
  bool get isWide => width >= 620;

  /// Side-by-side only when there is real horizontal room *and* little height —
  /// a phone in landscape, or a tablet.
  bool get useTwoPanes => isLandscape && width >= 600;

  bool get isSmall => shortest < 360;

  /// One ratio drives padding, radii and icon sizes. Clamped so a huge tablet
  /// does not turn the UI into a poster, and a tiny phone stays legible.
  double get scale {
    final double raw = shortest / 390;
    return raw.clamp(0.86, 1.24);
  }

  double px(double value) => value * scale;

  /// Extra side padding that keeps a list's text column readable once the
  /// window is wider than a phone: the content is capped, the rest is gutter.
  /// This is how every list gets landscape and tablet behaviour without a
  /// second layout.
  double get gutter => width <= 620 ? 0 : (width - 620) / 2;

  /// Font sizes follow the platform text scale but not the screen scale past a
  /// point — a 6.7" phone should not shout.
  double font(double value, BuildContext context) {
    final double factor = (shortest / 390).clamp(0.92, 1.08);
    return value * factor * MediaQuery.textScalerOf(context).scale(1);
  }
}

/// Centres content and caps its width, so a landscape phone or a tablet does not
/// stretch a list into unreadable full-bleed lines.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = 620});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
