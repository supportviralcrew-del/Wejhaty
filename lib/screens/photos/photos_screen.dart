import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tripproject/core/theme/app_colors.dart';
import 'package:tripproject/core/theme/app_theme.dart';
import 'package:tripproject/services/photos_service.dart';

enum _PhotosView { gallery, camera }

class PhotosScreen extends StatefulWidget {
  const PhotosScreen({super.key, required this.isAr});

  final bool isAr;

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  _PhotosView _view = _PhotosView.gallery;
  bool _isFullscreen = false;
  final _picker = ImagePicker();

  bool _isSelectionMode = false;
  final Set<String> _selectedPhotos = {};

  Future<void> _takePhoto() async {
    try {
      final photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (photo != null) {
        PhotosService.instance.addPhoto(photo.path);
        setState(() => _view = _PhotosView.gallery);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isAr ? 'تعذر الوصول إلى الكاميرا' : 'Could not access the camera',
            ),
          ),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final photo = await _picker.pickMedia();
      if (photo != null) {
        PhotosService.instance.addPhoto(photo.path);
        setState(() => _view = _PhotosView.gallery);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isAr ? 'تعذر الوصول إلى المعرض' : 'Could not access the gallery',
            ),
          ),
        );
      }
    }
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _deleteSelectedPhotos() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          widget.isAr ? 'حذف دائم' : 'Delete permanently',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          _selectedPhotos.length == 1
              ? (widget.isAr ? 'هل تريد حذف هذه الصورة؟' : 'Do you want to delete this image?')
              : (widget.isAr ? 'هل تريد حذف هذه الصور؟' : 'Do you want to delete these images?'),
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              widget.isAr ? 'لا' : 'No',
              style: GoogleFonts.poppins(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              widget.isAr ? 'نعم' : 'Yes',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      for (final path in _selectedPhotos) {
        PhotosService.instance.removePhoto(path);
      }
      setState(() {
        _isSelectionMode = false;
        _selectedPhotos.clear();
      });
    }
  }

  @override
  void dispose() {
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = widget.isAr;

    return Scaffold(
      appBar: _isFullscreen
          ? null
          : AppBar(
        title: Text(
          _isSelectionMode
              ? (isAr ? 'تم تحديد ${_selectedPhotos.length}' : '${_selectedPhotos.length} Selected')
              : (isAr ? 'الصور' : 'Photos'),
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedPhotos.clear();
                  });
                },
              )
            : null,
        actions: _isSelectionMode
            ? [
                IconButton(
                  onPressed: () {
                    final photos = PhotosService.instance.photoPaths;
                    setState(() {
                      if (_selectedPhotos.length == photos.length) {
                        _selectedPhotos.clear();
                      } else {
                        _selectedPhotos.addAll(photos);
                      }
                    });
                  },
                  icon: const Icon(Icons.select_all_rounded),
                  tooltip: isAr ? 'تحديد الكل' : 'Select all',
                ),
                if (_selectedPhotos.isNotEmpty)
                  IconButton(
                    onPressed: _deleteSelectedPhotos,
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                    tooltip: isAr ? 'حذف' : 'Delete',
                  ),
              ]
            : [
                IconButton(
                  onPressed: _toggleFullscreen,
                  icon: const Icon(Icons.fullscreen_rounded),
                  tooltip: isAr ? 'ملء الشاشة' : 'Fullscreen',
                ),
              ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_isFullscreen)
              Align(
                alignment: isAr ? Alignment.topLeft : Alignment.topRight,
                child: IconButton(
                  onPressed: _toggleFullscreen,
                  icon: const Icon(Icons.fullscreen_exit_rounded),
                  tooltip: isAr ? 'إنهاء ملء الشاشة' : 'Exit fullscreen',
                ),
              ),
            if (!_isSelectionMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _ViewToggleButton(
                        label: isAr ? 'اختر من المعرض' : 'Pick from Gallery',
                        icon: Icons.photo_library_rounded,
                        selected: _view == _PhotosView.gallery,
                        onTap: _pickFromGallery,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ViewToggleButton(
                        label: isAr ? 'التقاط صورة' : 'Take Photo',
                        icon: Icons.camera_alt_rounded,
                        selected: _view == _PhotosView.camera,
                        onTap: _takePhoto,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListenableBuilder(
                listenable: PhotosService.instance,
                builder: (context, _) {
                  final photos = PhotosService.instance.photoPaths;
                  if (photos.isEmpty) {
                    return Center(
                      child: Text(
                        isAr ? 'لا توجد صور بعد' : 'No photos yet',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: photos.length,
                    itemBuilder: (context, index) {
                      final path = photos[index];
                      final isSelected = _selectedPhotos.contains(path);
                      return GestureDetector(
                        onLongPress: () {
                          if (!_isSelectionMode) {
                            setState(() {
                              _isSelectionMode = true;
                              _selectedPhotos.add(path);
                            });
                          }
                        },
                        onTap: () {
                          if (_isSelectionMode) {
                            setState(() {
                              if (isSelected) {
                                _selectedPhotos.remove(path);
                                if (_selectedPhotos.isEmpty) {
                                  _isSelectionMode = false;
                                }
                              } else {
                                _selectedPhotos.add(path);
                              }
                            });
                          } else {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => _FullscreenPhotoViewer(photos: photos, initialIndex: index),
                              ),
                            );
                          }
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                              child: Image.file(File(path), fit: BoxFit.cover),
                            ),
                            if (_isSelectionMode)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.black.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                                    border: isSelected ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
                                  ),
                                ),
                              ),
                            if (_isSelectionMode)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Icon(
                                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewToggleButton extends StatelessWidget {
  const _ViewToggleButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.photosCard : AppColors.photosCard.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: selected ? Colors.white : AppColors.photosCard),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.photosCard,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullscreenPhotoViewer extends StatefulWidget {
  const _FullscreenPhotoViewer({required this.photos, required this.initialIndex});

  final List<String> photos;
  final int initialIndex;

  @override
  State<_FullscreenPhotoViewer> createState() => _FullscreenPhotoViewerState();
}

class _FullscreenPhotoViewerState extends State<_FullscreenPhotoViewer> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.photos.length,
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: Image.file(File(widget.photos[index]), fit: BoxFit.contain),
                ),
              );
            },
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}