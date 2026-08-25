import 'package:flutter/foundation.dart';
import 'package:tripproject/services/local_cache_service.dart';

class PhotosService extends ChangeNotifier {
  PhotosService._();
  static final PhotosService instance = PhotosService._();

  final List<String> _photoPaths = [];
  final _cache = LocalCacheService.instance;

  List<String> get photoPaths => List.unmodifiable(_photoPaths.reversed);

  Future<void> init() async {
    await _cache.init();
    final loaded = _cache.loadPhotos();
    _photoPaths.clear();
    _photoPaths.addAll(loaded);
  }

  void addPhoto(String path) {
    _photoPaths.add(path);
    _save();
    notifyListeners();
  }

  void removePhoto(String path) {
    _photoPaths.remove(path);
    _save();
    notifyListeners();
  }

  Future<void> _save() async {
    await _cache.savePhotos(_photoPaths);
  }
}