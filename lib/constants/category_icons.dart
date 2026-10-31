import 'package:flutter/material.dart';

/// Keys and colours for category glyphs live here; `AppCategory` asks for the
/// resolved [IconData] through [categoryIcon] to avoid a circular import.
const Map<String, IconData> kCategoryIcons = <String, IconData>{
  'rice': Icons.rice_bowl_outlined,
  'fish': Icons.set_meal_outlined,
  'meat': Icons.kebab_dining_outlined,
  'veg': Icons.eco_outlined,
  'tea': Icons.local_cafe_outlined,
  'restaurant': Icons.restaurant_outlined,
  'cosmetics': Icons.face_retouching_natural_outlined,
  'shirt': Icons.checkroom_outlined,
  'laundry': Icons.local_laundry_service_outlined,
  'bus': Icons.directions_bus_outlined,
  'wifi': Icons.wifi_outlined,
  'book': Icons.menu_book_outlined,
  'medicine': Icons.medication_outlined,
  'movie': Icons.movie_outlined,
  'home': Icons.home_work_outlined,
  'phone': Icons.smartphone_outlined,
  'sports': Icons.sports_cricket_outlined,
  'gift': Icons.card_giftcard_outlined,
  'savings': Icons.savings_outlined,
  'school': Icons.school_outlined,
  'scholarship': Icons.workspace_premium_outlined,
  'laptop': Icons.laptop_mac_outlined,
  'salary': Icons.payments_outlined,
  'other': Icons.more_horiz_outlined,
  'income_other': Icons.add_circle_outline,
};

IconData categoryIcon(String key) =>
    kCategoryIcons[key] ?? Icons.more_horiz_outlined;

/// Icon keys offered in the category editor.
const List<String> kIconPickerKeys = <String>[
  'rice',
  'fish',
  'meat',
  'veg',
  'tea',
  'restaurant',
  'cosmetics',
  'shirt',
  'laundry',
  'bus',
  'wifi',
  'phone',
  'book',
  'medicine',
  'movie',
  'home',
  'sports',
  'gift',
  'savings',
  'school',
  'scholarship',
  'laptop',
  'salary',
  'other',
];

/// Colour swatches offered in the category editor.
const List<String> kCategoryPalette = <String>[
  '#0E9F6E',
  '#12A594',
  '#3C7EDB',
  '#5B6FE0',
  '#8B5CF6',
  '#B455D6',
  '#E86FA8',
  '#E8575D',
  '#E4572E',
  '#E9A23B',
  '#D98E2B',
  '#8CBF3F',
  '#4CAF50',
  '#4AA3A2',
  '#8C6E4A',
  '#6B7684',
];
