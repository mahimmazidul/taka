import '../models/app_category.dart';
import 'default_subcategories.dart';

/// The seeded **groups** — the first row of chips on the add-entry screen.
/// A group is a container: it rolls up its items' spend and can hold its own
/// monthly limit, but entries are logged against the items inside it.
AppCategory _group({
  required String id,
  required String name,
  required String nameBn,
  required String icon,
  required String color,
  required int order,
}) => AppCategory(
  id: id,
  name: name,
  nameBn: nameBn,
  icon: icon,
  colorHex: color,
  kind: CategoryKind.expense,
  sortOrder: order,
  isGroup: true,
);

/// A top-level item with no parent: loggable on its own (Dining out, Other).
AppCategory _leaf({
  required String id,
  required String name,
  required String nameBn,
  required String icon,
  required String color,
  required int order,
  CategoryKind kind = CategoryKind.expense,
  bool isFood = false,
}) => AppCategory(
  id: id,
  name: name,
  nameBn: nameBn,
  icon: icon,
  colorHex: color,
  kind: kind,
  sortOrder: order,
  isFood: isFood,
);

/// Expense groups, in the order a hall student thinks about money: food first,
/// then body, then books, then the boring bills.
///
/// `g_eatout` was a single leaf until v1.5.0 ("Dining out"); it is a group now,
/// because "dining out" is burgers and shawarma and a biryani run, and one lump
/// answered nothing. The old `eatout` row is kept as its general item so every
/// entry already pointing at it still means what it meant.
final List<AppCategory> _expenseGroups = <AppCategory>[
  _group(
    id: 'g_main',
    name: 'Main course',
    nameBn: 'মেইন কোর্স',
    icon: 'rice',
    color: '#E9A23B',
    order: 0,
  ),
  _group(
    id: 'g_drinks',
    name: 'Drinks',
    nameBn: 'ড্রিংকস',
    icon: 'drink',
    color: '#3C7EDB',
    order: 1,
  ),
  _group(
    id: 'g_snacks',
    name: 'Snacks',
    nameBn: 'নাস্তা',
    icon: 'snacks',
    color: '#E4572E',
    order: 2,
  ),
  _group(
    id: 'g_sweets',
    name: 'Sweets',
    nameBn: 'মিষ্টি',
    icon: 'sweets',
    color: '#E86FA8',
    order: 3,
  ),
  _group(
    id: 'g_fruits',
    name: 'Fruits',
    nameBn: 'ফল',
    icon: 'fruit',
    color: '#4CAF50',
    order: 4,
  ),
  _group(
    id: 'g_grooming',
    name: 'Cosmetics & grooming',
    nameBn: 'কসমেটিকস',
    icon: 'cosmetics',
    color: '#B455D6',
    order: 5,
  ),
  _group(
    id: 'g_study',
    name: 'Books & stationery',
    nameBn: 'বই-খাতা',
    icon: 'book',
    color: '#8C6E4A',
    order: 6,
  ),
  _group(
    id: 'g_clothes',
    name: 'Clothes',
    nameBn: 'কাপড়',
    icon: 'shirt',
    color: '#5B6FE0',
    order: 7,
  ),
  _group(
    id: 'g_health',
    name: 'Health',
    nameBn: 'স্বাস্থ্য',
    icon: 'health',
    color: '#12A594',
    order: 8,
  ),
  _group(
    id: 'g_hall',
    name: 'Hall & room',
    nameBn: 'হল খরচ',
    icon: 'home',
    color: '#8C6E4A',
    order: 9,
  ),
  _group(
    id: 'g_transport',
    name: 'Transport',
    nameBn: 'যাতায়াত',
    icon: 'bus',
    color: '#4AA3A2',
    order: 10,
  ),
  _group(
    id: 'g_mobile',
    name: 'Mobile & internet',
    nameBn: 'মোবাইল',
    icon: 'phone',
    color: '#6B7684',
    order: 11,
  ),
  _group(
    id: 'g_fun',
    name: 'Entertainment',
    nameBn: 'বিনোদন',
    icon: 'movie',
    color: '#E4572E',
    order: 12,
  ),
  _group(
    id: 'g_gifts',
    name: 'Gifts & family',
    nameBn: 'উপহার ও পরিবার',
    icon: 'gift',
    color: '#E86FA8',
    order: 13,
  ),
  _group(
    id: 'g_eatout',
    name: 'Dining out',
    nameBn: 'বাইরের খাবার',
    icon: 'restaurant',
    color: '#E4572E',
    order: 20,
  ),
  _group(
    id: 'g_fees',
    name: 'Fees & fines',
    nameBn: 'ফি ও জরিমানা',
    icon: 'receipt',
    color: '#D98E2B',
    order: 14,
  ),
];

/// Items that sit on the top row themselves — no sub-list, one tap.
final List<AppCategory> _standalone = <AppCategory>[
  _leaf(
    id: 'laundry',
    name: 'Laundry',
    nameBn: 'লন্ড্রি',
    icon: 'laundry',
    color: '#4AA3A2',
    order: 21,
  ),
  _leaf(
    id: 'other',
    name: 'Other',
    nameBn: 'অন্যান্য',
    icon: 'other',
    color: '#6B7684',
    order: 99,
  ),
];

/// Money coming in. Income sources stay flat — you do not need a tree to say
/// "tuition".
final List<AppCategory> _incomeSources = <AppCategory>[
  _leaf(
    id: 'home_money',
    name: 'From home',
    nameBn: 'বাসা থেকে',
    icon: 'savings',
    color: '#0E9F6E',
    order: 0,
    kind: CategoryKind.income,
  ),
  _leaf(
    id: 'tuition',
    name: 'Tuition',
    nameBn: 'টিউশন',
    icon: 'school',
    color: '#3C7EDB',
    order: 1,
    kind: CategoryKind.income,
  ),
  _leaf(
    id: 'scholarship',
    name: 'Scholarship',
    nameBn: 'বৃত্তি',
    icon: 'scholarship',
    color: '#8B5CF6',
    order: 2,
    kind: CategoryKind.income,
  ),
  _leaf(
    id: 'freelance',
    name: 'Freelance',
    nameBn: 'ফ্রিল্যান্স',
    icon: 'laptop',
    color: '#4AA3A2',
    order: 3,
    kind: CategoryKind.income,
  ),
  _leaf(
    id: 'gift',
    name: 'Gift',
    nameBn: 'উপহার',
    icon: 'gift',
    color: '#E86FA8',
    order: 4,
    kind: CategoryKind.income,
  ),
  _leaf(
    id: 'other_income',
    name: 'Other',
    nameBn: 'অন্যান্য',
    icon: 'income_other',
    color: '#12A594',
    order: 5,
    kind: CategoryKind.income,
  ),
];

/// Everything the database seeds on a fresh install, parents before children so
/// a foreign key on `parent_id` could be added later without reordering.
final List<AppCategory> kDefaultCategories = <AppCategory>[
  ..._expenseGroups,
  ...kDefaultSubcategories,
  ..._standalone,
  ..._incomeSources,
];
