import 'package:flutter/material.dart';
import 'package:tripproject/services/local_cache_service.dart';

class ExpenseItem {
  ExpenseItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.currency,
    required this.date,
    this.category = 'other',
  });

  final String id;
  final String title;
  final double amount;
  final String currency;
  final DateTime date;

  /// One of [kExpenseCategories] ids. Older records saved before
  /// categories existed fall back to 'other'.
  final String category;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'amount': amount,
    'currency': currency,
    'date': date.toIso8601String(),
    'category': category,
  };

  static ExpenseItem fromJson(Map<String, dynamic> json) => ExpenseItem(
    id: json['id'] as String,
    title: json['title'] as String,
    amount: (json['amount'] as num).toDouble(),
    currency: json['currency'] as String,
    date: DateTime.parse(json['date'] as String),
    category: json['category'] as String? ?? 'other',
  );
}

/// Fixed expense categories used by the add-expense form and the
/// premium per-category breakdown.
class ExpenseCategory {
  const ExpenseCategory(this.id, this.labelEn, this.labelAr, this.icon);

  final String id;
  final String labelEn;
  final String labelAr;
  final IconData icon;

  String label({required bool isAr}) => isAr ? labelAr : labelEn;
}

const List<ExpenseCategory> kExpenseCategories = [
  ExpenseCategory('fuel', 'Fuel', 'وقود', Icons.local_gas_station_rounded),
  ExpenseCategory('food', 'Food', 'طعام', Icons.restaurant_rounded),
  ExpenseCategory('hotel', 'Hotel', 'إقامة', Icons.hotel_rounded),
  ExpenseCategory('shopping', 'Shopping', 'تسوق', Icons.shopping_bag_rounded),
  ExpenseCategory('tolls', 'Roads & Parking', 'طرق ومواقف', Icons.local_parking_rounded),
  ExpenseCategory('other', 'Other', 'أخرى', Icons.category_rounded),
];

/// Resolves a stored category id to its display metadata, falling back
/// to 'other' for unknown values.
ExpenseCategory expenseCategoryById(String id) =>
    kExpenseCategories.firstWhere(
      (c) => c.id == id,
      orElse: () => kExpenseCategories.last,
    );

/// Currencies relevant to a UAE -> Jordan road trip, plus a few common ones.
const List<String> kSupportedCurrencies = [
  'AED', // UAE Dirham
  'JOD', // Jordanian Dinar
  'SAR', // Saudi Riyal
  'USD',
  'EUR',
  'GBP',
  'EGP',
  'KWD',
  'QAR',
  'BHD',
  'OMR',
];

class ExpensesService extends ChangeNotifier {
  ExpensesService._();
  static final ExpensesService instance = ExpensesService._();

  final List<ExpenseItem> _items = [];
  final _cache = LocalCacheService.instance;

  List<ExpenseItem> get items =>
      List.unmodifiable(_items.reversed); // newest first

  Future<void> init() async {
    await _cache.init();
    final loaded = _cache.loadExpenses();
    _items.clear();
    _items.addAll(loaded.map((json) => ExpenseItem.fromJson(json)));
  }

  /// Adds an expense and persists it to disk before notifying listeners,
  /// so the UI never shows an entry that isn't actually saved yet.
  Future<void> addExpense({
    required String title,
    required double amount,
    required String currency,
    String category = 'other',
  }) async {
    _items.add(
      ExpenseItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title.trim().isEmpty ? currency : title.trim(),
        amount: amount,
        currency: currency,
        date: DateTime.now(),
        category: category,
      ),
    );
    await _save();
    notifyListeners();
  }

  /// Removes an expense and persists the change to disk before
  /// notifying listeners.
  Future<void> removeExpense(String id) async {
    _items.removeWhere((i) => i.id == id);
    await _save();
    notifyListeners();
  }

  /// Total spent per currency, e.g. {'AED': 1240.0, 'JOD': 30.0}
  Map<String, double> get totalsByCurrency {
    final totals = <String, double>{};
    for (final item in _items) {
      totals[item.currency] = (totals[item.currency] ?? 0) + item.amount;
    }
    return totals;
  }

  /// Total expenses across all currencies (sum of all amounts)
  double get totalExpenses {
    double sum = 0;
    for (final item in _items) {
      sum += item.amount;
    }
    return sum;
  }

  /// Average expense per transaction
  double get averageExpense {
    if (_items.isEmpty) return 0;
    return totalExpenses / _items.length;
  }

  /// Expenses grouped by month (for analytics)
  Map<String, List<ExpenseItem>> get expensesByMonth {
    final grouped = <String, List<ExpenseItem>>{};
    for (final item in _items) {
      final key = '${item.date.year}-${item.date.month.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(item);
    }
    return grouped;
  }

  /// Monthly totals (for analytics)
  Map<String, double> get monthlyTotals {
    final totals = <String, double>{};
    for (final entry in expensesByMonth.entries) {
      final monthTotal = entry.value.fold<double>(0, (sum, item) => sum + item.amount);
      totals[entry.key] = monthTotal;
    }
    return totals;
  }

  /// Total spent per category id (premium breakdown), sorted high→low.
  Map<String, double> get totalsByCategory {
    final totals = <String, double>{};
    for (final item in _items) {
      totals[item.category] = (totals[item.category] ?? 0) + item.amount;
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {for (final e in sorted) e.key: e.value};
  }

  /// Highest expense transaction
  ExpenseItem? get highestExpense {
    if (_items.isEmpty) return null;
    return _items.reduce((a, b) => a.amount > b.amount ? a : b);
  }

  /// Lowest expense transaction
  ExpenseItem? get lowestExpense {
    if (_items.isEmpty) return null;
    return _items.reduce((a, b) => a.amount < b.amount ? a : b);
  }

  /// Expenses from the last 30 days
  List<ExpenseItem> get recentExpenses {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    return _items.where((item) => item.date.isAfter(thirtyDaysAgo)).toList();
  }

  /// Total expenses in the last 30 days
  double get recentTotal {
    return recentExpenses.fold<double>(0, (sum, item) => sum + item.amount);
  }

  Future<void> _save() async {
    final itemsJson = _items.map((item) => item.toJson()).toList();
    await _cache.saveExpenses(itemsJson);
  }
}