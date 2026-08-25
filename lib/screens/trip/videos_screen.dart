// Mirrors MusicScreen's structure and visual style. Uses the `video_player`
// package for local file playback, so make sure it's in pubspec.yaml:
//   video_player: ^2.9.1
//
// Persistence assumes LocalCacheService gets four new methods analogous to
// the music ones already there:
//   List<String> loadVideoFiles();
//   Future<void> saveVideoFiles(List<String> paths);
//   Map<String, String> loadVideoNames();       // path -> custom display name
//   Future<void> saveVideoNames(Map<String, String> names);

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:tripproject/core/theme/app_colors.dart';
import 'package:tripproject/core/widgets/glass_card.dart';
import 'package:tripproject/services/app_data_provider.dart';
import 'package:tripproject/services/local_cache_service.dart';

const _kVideoAccent = Color(0xFFE85D75);
const _kSpeedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

class VideosScreen extends StatefulWidget {
  const VideosScreen({super.key});

  @override
  State<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  VideoPlayerController? _controller;
  final List<String> _videoFiles = [];
  // path -> user-chosen display name. Falls back to the real file name for
  // any path not present here.
  final Map<String, String> _videoNames = {};
  int _currentTrackIndex = -1;
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _restorePlaylist();
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  /// Restore previously added video files (and any custom names) from local
  /// cache.
  Future<void> _restorePlaylist() async {
    final saved = LocalCacheService.instance.loadVideoFiles();
    final savedNames = LocalCacheService.instance.loadVideoNames();
    if ((saved.isNotEmpty || savedNames.isNotEmpty) && mounted) {
      setState(() {
        _videoFiles.addAll(saved);
        _videoNames.addAll(savedNames);
      });
    }
  }

  /// Persist current playlist to disk.
  Future<void> _savePlaylist() async {
    await LocalCacheService.instance.saveVideoFiles(_videoFiles);
  }

  /// Persist custom display names to disk.
  Future<void> _saveVideoNames() async {
    await LocalCacheService.instance.saveVideoNames(_videoNames);
  }

  void _videoListener() {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final value = controller.value;
    setState(() {
      _duration = value.duration;
      _position = value.position;
      _isPlaying = value.isPlaying;
    });
    if (value.position >= value.duration && value.duration > Duration.zero) {
      setState(() => _isPlaying = false);
    }
  }

  Future<void> _pickVideoFiles() async {
    try {
      final video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        setState(() {
          _videoFiles.add(video.path);
        });
        _savePlaylist();
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _playVideo(String path, int index) async {
    try {
      final old = _controller;
      old?.removeListener(_videoListener);

      final newController = VideoPlayerController.file(File(path));
      await newController.initialize();
      newController.setPlaybackSpeed(_playbackSpeed);
      newController.addListener(_videoListener);

      await old?.dispose();

      setState(() {
        _controller = newController;
        _currentTrackIndex = index;
        _duration = newController.value.duration;
        _position = Duration.zero;
      });

      await newController.play();
      setState(() => _isPlaying = true);
    } catch (e) {
      // Handle error
    }
  }

  void _pauseVideo() {
    _controller?.pause();
    setState(() => _isPlaying = false);
  }

  void _resumeVideo() {
    _controller?.play();
    setState(() => _isPlaying = true);
  }

  void _seekVideo(double value) {
    _controller?.seekTo(Duration(seconds: value.toInt()));
  }

  void _skipSeconds(int seconds) {
    final controller = _controller;
    if (controller == null) return;
    final target = _position + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > _duration ? _duration : target);
    controller.seekTo(clamped);
  }

  void _setSpeed(double speed) {
    _controller?.setPlaybackSpeed(speed);
    setState(() => _playbackSpeed = speed);
  }

  Future<void> _openFullscreen() async {
    final controller = _controller;
    if (controller == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullscreenVideoPlayer(
          controller: controller,
          accent: _kVideoAccent,
          playbackSpeed: _playbackSpeed,
          onSpeedChanged: _setSpeed,
          formatDuration: _formatDuration,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _getFileName(String path) {
    return path.split('/').last.split('\\').last;
  }

  /// The name shown in the UI: the user's custom name if they've renamed
  /// this video, otherwise the real file name.
  String _getDisplayName(String path) {
    return _videoNames[path] ?? _getFileName(path);
  }

  /// Opens a dialog letting the user set a custom display name for a video.
  /// This only changes the label shown in the app — the underlying file on
  /// disk is left untouched.
  Future<void> _renameVideo(BuildContext context, bool isAr, String path) async {
    final controller = TextEditingController(text: _getDisplayName(path));

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isAr ? 'إعادة تسمية الفيديو' : 'Rename video',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: isAr ? 'اسم الفيديو' : 'Video name',
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _kVideoAccent),
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(isAr ? 'حفظ' : 'Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != _getDisplayName(path)) {
      HapticFeedback.selectionClick();
      setState(() => _videoNames[path] = newName);
      _saveVideoNames();
    }
  }

  /// Confirms with the user, then removes [path] (at [index]) from the
  /// playlist. Note this only removes it from the app's list — it does not
  /// delete the actual file from the device.
  Future<void> _deleteVideo(
      BuildContext context,
      bool isAr,
      String path,
      int index,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isAr ? 'حذف الفيديو؟' : 'Delete video?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          isAr
              ? 'سيتم إزالة "${_getDisplayName(path)}" من القائمة فقط، ولن يُحذف الملف من جهازك.'
              : 'This removes "${_getDisplayName(path)}" from the list only — the file itself won\'t be deleted from your device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isAr ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    HapticFeedback.mediumImpact();
    setState(() {
      if (index == _currentTrackIndex) {
        _controller?.removeListener(_videoListener);
        _controller?.pause();
        _controller?.dispose();
        _controller = null;
        _currentTrackIndex = -1;
        _isPlaying = false;
        _duration = Duration.zero;
        _position = Duration.zero;
      } else if (index < _currentTrackIndex) {
        _currentTrackIndex -= 1;
      }
      _videoFiles.removeAt(index);
      _videoNames.remove(path);
    });
    _savePlaylist();
    _saveVideoNames();
  }

  @override
  Widget build(BuildContext context) {
    final provider = AppDataProvider.instance;
    final isAr = provider.language == 'ar';
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'الفيديوهات' : 'Videos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _pickVideoFiles,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Now Playing Section
            if (_currentTrackIndex >= 0 &&
                _currentTrackIndex < _videoFiles.length &&
                _controller != null &&
                _controller!.value.isInitialized)
              Padding(
                padding: const EdgeInsets.all(16),
                child: GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio == 0
                              ? 16 / 9
                              : _controller!.value.aspectRatio,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              VideoPlayer(_controller!),
                              Positioned(
                                right: 8,
                                top: 8,
                                child: _RoundIconButton(
                                  icon: Icons.fullscreen_rounded,
                                  onTap: _openFullscreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              _getDisplayName(_videoFiles[_currentTrackIndex]),
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _renameVideo(
                              context,
                              isAr,
                              _videoFiles[_currentTrackIndex],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Progress Bar
                      Slider(
                        value: _position.inSeconds
                            .toDouble()
                            .clamp(0, _duration.inSeconds.toDouble()),
                        max: _duration.inSeconds.toDouble() > 0
                            ? _duration.inSeconds.toDouble()
                            : 1,
                        onChanged: _seekVideo,
                        activeColor: _kVideoAccent,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(_position),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: scheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          Text(
                            _formatDuration(_duration),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: scheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.skip_previous),
                            onPressed: _currentTrackIndex > 0
                                ? () => _playVideo(
                                _videoFiles[_currentTrackIndex - 1],
                                _currentTrackIndex - 1)
                                : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.replay_5_rounded),
                            onPressed: () => _skipSeconds(-5),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [_kVideoAccent, AppColors.sunsetOrange],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                              color: Colors.white,
                              onPressed: _isPlaying ? _pauseVideo : _resumeVideo,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.forward_5_rounded),
                            onPressed: () => _skipSeconds(5),
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next),
                            onPressed: _currentTrackIndex < _videoFiles.length - 1
                                ? () => _playVideo(
                                _videoFiles[_currentTrackIndex + 1],
                                _currentTrackIndex + 1)
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Speed control
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isAr ? 'السرعة' : 'Speed',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: scheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<double>(
                            initialValue: _playbackSpeed,
                            onSelected: _setSpeed,
                            itemBuilder: (context) => _kSpeedOptions
                                .map((speed) => PopupMenuItem<double>(
                              value: speed,
                              child: Text('${speed}x'),
                            ))
                                .toList(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _kVideoAccent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_playbackSpeed}x',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _kVideoAccent,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            // Video List
            SizedBox(
              height: _videoFiles.isEmpty
                  ? MediaQuery.of(context).size.height - 200
                  : null,
              child: _videoFiles.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.video_library_outlined,
                      size: 64,
                      color: _kVideoAccent.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isAr ? 'لا توجد ملفات فيديو' : 'No video files',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: scheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isAr ? 'اضغط + لإضافة ملفات فيديو' : 'Tap + to add video files',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: scheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                itemCount: _videoFiles.length,
                itemBuilder: (context, index) {
                  final path = _videoFiles[index];
                  final isCurrentTrack = index == _currentTrackIndex;
                  final displayName = _getDisplayName(path);
                  final isRenamed = _videoNames.containsKey(path);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Dismissible(
                      key: ValueKey(path),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        final result = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: Text(
                              isAr ? 'حذف الفيديو؟' : 'Delete video?',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                            ),
                            content: Text(
                              isAr
                                  ? 'سيتم إزالة "$displayName" من القائمة فقط، ولن يُحذف الملف من جهازك.'
                                  : 'This removes "$displayName" from the list only — the file itself won\'t be deleted from your device.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext, false),
                                child: Text(isAr ? 'إلغاء' : 'Cancel'),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                onPressed: () => Navigator.pop(dialogContext, true),
                                child: Text(isAr ? 'حذف' : 'Delete'),
                              ),
                            ],
                          ),
                        );
                        return result ?? false;
                      },
                      onDismissed: (_) {
                        HapticFeedback.mediumImpact();
                        setState(() {
                          final currentIndex = _videoFiles.indexOf(path);
                          if (currentIndex == -1) return;
                          if (currentIndex == _currentTrackIndex) {
                            _controller?.removeListener(_videoListener);
                            _controller?.pause();
                            _controller?.dispose();
                            _controller = null;
                            _currentTrackIndex = -1;
                            _isPlaying = false;
                            _duration = Duration.zero;
                            _position = Duration.zero;
                          } else if (currentIndex < _currentTrackIndex) {
                            _currentTrackIndex -= 1;
                          }
                          _videoFiles.removeAt(currentIndex);
                          _videoNames.remove(path);
                        });
                        _savePlaylist();
                        _saveVideoNames();
                      },
                      background: Container(
                        alignment: AlignmentDirectional.centerEnd,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.delete_rounded, color: Colors.white),
                      ),
                      child: GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isCurrentTrack
                                    ? [_kVideoAccent, AppColors.sunsetOrange]
                                    : [
                                  _kVideoAccent.withValues(alpha: 0.2),
                                  _kVideoAccent.withValues(alpha: 0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isCurrentTrack && _isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: isCurrentTrack ? Colors.white : _kVideoAccent,
                            ),
                          ),
                          title: Text(
                            displayName,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight:
                              isCurrentTrack ? FontWeight.w600 : FontWeight.w400,
                              color: scheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: isRenamed
                              ? Text(
                            _getFileName(path),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: scheme.onSurface.withValues(alpha: 0.4),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            tooltip: isAr ? 'إعادة تسمية' : 'Rename',
                            onPressed: () => _renameVideo(context, isAr, path),
                          ),
                          onTap: () {
                            if (isCurrentTrack) {
                              if (_isPlaying) {
                                _pauseVideo();
                              } else {
                                _resumeVideo();
                              }
                            } else {
                              _playVideo(path, index);
                            }
                          },
                          onLongPress: () => _deleteVideo(context, isAr, path, index),
                        ),
                      ),
                    ),
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

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

/// Fullscreen playback view. Reuses the same controller as the main screen
/// so playback continues seamlessly; locks to landscape and hides system
/// chrome while active, and restores both on exit.
class _FullscreenVideoPlayer extends StatefulWidget {
  const _FullscreenVideoPlayer({
    required this.controller,
    required this.accent,
    required this.playbackSpeed,
    required this.onSpeedChanged,
    required this.formatDuration,
  });

  final VideoPlayerController controller;
  final Color accent;
  final double playbackSpeed;
  final ValueChanged<double> onSpeedChanged;
  final String Function(Duration) formatDuration;

  @override
  State<_FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<_FullscreenVideoPlayer> {
  bool _controlsVisible = true;
  late double _speed = widget.playbackSpeed;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    widget.controller.addListener(_onTick);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTick);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  void _skipSeconds(int seconds) {
    final controller = widget.controller;
    final position = controller.value.position;
    final duration = controller.value.duration;
    final target = position + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > duration ? duration : target);
    controller.seekTo(clamped);
  }

  void _setSpeed(double speed) {
    widget.controller.setPlaybackSpeed(speed);
    widget.onSpeedChanged(speed);
    setState(() => _speed = speed);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final value = controller.value;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _controlsVisible = !_controlsVisible),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: value.aspectRatio == 0 ? 16 / 9 : value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            ),
            if (_controlsVisible) ...[
              // Top-left: exit fullscreen
              Positioned(
                top: 16,
                left: 16,
                child: _RoundIconButton(
                  icon: Icons.fullscreen_exit_rounded,
                  onTap: () => Navigator.pop(context),
                ),
              ),
              // Top-right: speed
              Positioned(
                top: 16,
                right: 16,
                child: PopupMenuButton<double>(
                  initialValue: _speed,
                  onSelected: _setSpeed,
                  itemBuilder: (context) => _kSpeedOptions
                      .map((speed) => PopupMenuItem<double>(
                    value: speed,
                    child: Text('${speed}x'),
                  ))
                      .toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_speed}x',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              // Center controls: -5s / play-pause / +5s
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RoundIconButton(
                    icon: Icons.replay_5_rounded,
                    onTap: () => _skipSeconds(-5),
                  ),
                  const SizedBox(width: 24),
                  Material(
                    color: widget.accent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        setState(() {
                          value.isPlaying ? controller.pause() : controller.play();
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Icon(
                          value.isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  _RoundIconButton(
                    icon: Icons.forward_5_rounded,
                    onTap: () => _skipSeconds(5),
                  ),
                ],
              ),
              // Bottom: progress bar
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Row(
                  children: [
                    Text(
                      widget.formatDuration(value.position),
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
                    ),
                    Expanded(
                      child: Slider(
                        value: value.position.inSeconds
                            .toDouble()
                            .clamp(0, value.duration.inSeconds.toDouble()),
                        max: value.duration.inSeconds.toDouble() > 0
                            ? value.duration.inSeconds.toDouble()
                            : 1,
                        activeColor: widget.accent,
                        onChanged: (v) => controller.seekTo(Duration(seconds: v.toInt())),
                      ),
                    ),
                    Text(
                      widget.formatDuration(value.duration),
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}