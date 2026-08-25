import 'package:flutter/foundation.dart';
import 'package:tripproject/services/local_cache_service.dart';

class ChecklistItem {
  ChecklistItem({
    required this.id,
    required this.title,
    this.done = false,
  });

  final String id;
  final String title;
  bool done;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'done': done,
  };

  static ChecklistItem fromJson(Map<String, dynamic> json) => ChecklistItem(
    id: json['id'] as String,
    title: json['title'] as String,
    done: json['done'] as bool? ?? false,
  );
}

/// Simple in-memory singleton so the checklist survives closing/reopening
/// the bottom sheet, following the same `.instance` + ChangeNotifier
/// pattern used by AppDataProvider elsewhere in the app.
class ChecklistService extends ChangeNotifier {
  ChecklistService._();
  static final ChecklistService instance = ChecklistService._();

  final List<ChecklistItem> _items = [];
  final _cache = LocalCacheService.instance;

  List<ChecklistItem> get items => List.unmodifiable(_items);

  int get doneCount => _items.where((i) => i.done).length;
  int get totalCount => _items.length;

  Future<void> init() async {
    await _cache.init();
    final loaded = _cache.loadChecklistItems();
    _items.clear();
    _items.addAll(loaded.map((json) => ChecklistItem.fromJson(json)));
  }

  void addItem(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    _items.add(
      ChecklistItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: trimmed,
      ),
    );
    _save();
    notifyListeners();
  }

  void toggleItem(String id) {
    final item = _items.firstWhere((i) => i.id == id);
    item.done = !item.done;
    _save();
    notifyListeners();
  }

  void removeItem(String id) {
    _items.removeWhere((i) => i.id == id);
    _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final itemsJson = _items.map((item) => item.toJson()).toList();
    await _cache.saveChecklistItems(itemsJson);
  }
}