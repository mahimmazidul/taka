import 'dart:math';

/// Small, collision-resistant-enough id for local rows. No uuid dependency:
/// microsecond timestamp + 31 bits of secure randomness.
final Random _random = Random.secure();

String newId() {
  final String time = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final String noise = _random.nextInt(0x7FFFFFFF).toRadixString(36);
  return '$time$noise';
}
