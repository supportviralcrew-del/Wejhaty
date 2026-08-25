      import 'dart:convert';
      import 'dart:io';

      import 'package:audioplayers/audioplayers.dart';
      import 'package:file_picker/file_picker.dart';
      import 'package:flutter/material.dart';
      import 'package:flutter/services.dart';
      import 'package:google_fonts/google_fonts.dart';
      import 'package:tripproject/core/theme/app_colors.dart';
      import 'package:tripproject/core/widgets/glass_card.dart';
      import 'package:tripproject/services/app_data_provider.dart';
      import 'package:tripproject/services/local_cache_service.dart';

      /// Where does a track's audio come from.
      enum _TrackSource { user, anasheed }

      class MusicScreen extends StatefulWidget {
        const MusicScreen({super.key});

        @override
        State<MusicScreen> createState() => _MusicScreenState();
      }

      class _MusicScreenState extends State<MusicScreen> {
        final AudioPlayer _audioPlayer = AudioPlayer();

        // ── User-picked tracks (from device storage) ─────────────────────────────
        final List<String> _musicFiles = [];
        // Maps a track's file path -> user-chosen display name.
        Map<String, String> _musicNames = {};

        // ── Bundled "Anasheed" tracks (from assets/Anasheed) ─────────────────────
        // Stored as full asset keys, e.g. "assets/Anasheed/song1.mp3".
        List<String> _anasheedFiles = [];
        bool _anasheedExpanded = true;
        bool _loadingAnasheed = true;

        // ── Playback state ────────────────────────────────────────────────────────
        _TrackSource? _currentSource;
        int _currentTrackIndex = -1;
        bool _isPlaying = false;
        Duration _duration = Duration.zero;
        Duration _position = Duration.zero;

        // ── Selection state ───────────────────────────────────────────────────────
        bool _isSelectionMode = false;
        final Set<String> _selectedMusic = {};

        static const String _anasheedAssetFolder = 'assets/Anasheed/';

        @override
        void initState() {
          super.initState();
          _initAudioPlayer();
          _restorePlaylist();
          _loadAnasheedTracks();
        }

        @override
        void dispose() {
          _audioPlayer.dispose();
          super.dispose();
        }

        /// Restore previously added music files (and their custom names) from
        /// local cache.
        Future<void> _restorePlaylist() async {
          final saved = LocalCacheService.instance.loadMusicFiles();
          final savedNames = LocalCacheService.instance.loadMusicNames();
          if (mounted) {
            setState(() {
              if (saved.isNotEmpty) _musicFiles.addAll(saved);
              _musicNames = savedNames;
            });
          }
        }

        /// Reads Flutter's asset manifest and picks out every mp3 bundled under
        /// assets/Anasheed/. This means you don't need to hardcode file names here
        /// — just drop mp3 files into that folder and list them in pubspec.yaml.
        Future<void> _loadAnasheedTracks() async {
          try {
            // Use modern AssetManifest API (Flutter 3.10+) which handles
            // the new binary format automatically.
            final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
            
            final files = manifest.listAssets()
                .where((key) {
                  final keyLower = key.toLowerCase();
                  // More flexible matching for the folder name and handle potential backslashes
                  return (keyLower.contains('anasheed/') || keyLower.contains('anasheed\\')) &&
                         keyLower.endsWith('.mp3');
                })
                .toList()
              ..sort();

            if (mounted) {
              setState(() {
                _anasheedFiles = files;
                _loadingAnasheed = false;
              });
            }
          } catch (e) {
            debugPrint('Error loading anasheed tracks: $e');
            if (mounted) {
              setState(() {
                _loadingAnasheed = false;
              });
            }
          }
        }

        /// Persist current playlist to disk.
        Future<void> _savePlaylist() async {
          await LocalCacheService.instance.saveMusicFiles(_musicFiles);
        }

        /// Persist current display-name map to disk.
        Future<void> _saveNames() async {
          await LocalCacheService.instance.saveMusicNames(_musicNames);
        }

        void _initAudioPlayer() {
          _audioPlayer.onDurationChanged.listen((duration) {
            if (mounted) {
              setState(() {
                _duration = duration;
              });
            }
          });

          _audioPlayer.onPositionChanged.listen((position) {
            if (mounted) {
              setState(() {
                _position = position;
              });
            }
          });

          _audioPlayer.onPlayerComplete.listen((event) {
            if (mounted) {
              setState(() {
                _isPlaying = false;
                _position = Duration.zero;
              });
            }
          });
        }

        Future<void> _pickMusicFiles() async {
          try {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.audio,
              allowMultiple: true,
            );

            if (result != null && result.files.isNotEmpty) {
              setState(() {
                _musicFiles.addAll(result.files.map((file) => file.path!).toList());
              });
              // Persist the updated playlist
              _savePlaylist();
            }
          } catch (e) {
            // Handle error
          }
        }

        /// Plays a track from either playlist. [index] is the index within its
        /// own list (_musicFiles or _anasheedFiles), not a global index.
        Future<void> _playTrack(_TrackSource source, int index) async {
          try {
            if (source == _TrackSource.user) {
              await _audioPlayer.play(DeviceFileSource(_musicFiles[index]));
            } else {
              // AssetSource resolves relative to "assets/", so strip that prefix
              // off the manifest key (e.g. "assets/Anasheed/song1.mp3" ->
              // "Anasheed/song1.mp3").
              final assetKey = _anasheedFiles[index];
              final relativePath = assetKey.startsWith('assets/')
                  ? assetKey.substring('assets/'.length)
                  : assetKey;
              await _audioPlayer.play(AssetSource(relativePath));
            }
            setState(() {
              _currentSource = source;
              _currentTrackIndex = index;
              _isPlaying = true;
            });
          } catch (e) {
            // Handle error
          }
        }

        void _pauseMusic() {
          _audioPlayer.pause();
          setState(() {
            _isPlaying = false;
          });
        }

        void _resumeMusic() {
          _audioPlayer.resume();
          setState(() {
            _isPlaying = true;
          });
        }

        void _seekMusic(double value) {
          _audioPlayer.seek(Duration(seconds: value.toInt()));
        }

        String _formatDuration(Duration duration) {
          final minutes = duration.inMinutes;
          final seconds = duration.inSeconds.remainder(60);
          return '$minutes:${seconds.toString().padLeft(2, '0')}';
        }

        /// Returns the user-chosen display name for [path] if one was set via
        /// rename, otherwise falls back to the raw file name.
        String _getFileName(String path) {
          final custom = _musicNames[path];
          if (custom != null && custom.trim().isNotEmpty) return custom;
          return path.split('/').last.split('\\').last;
        }

        /// Display name for a bundled Anasheed asset — the raw file name, cleaned
        /// up a bit (no extension, underscores/dashes turned into spaces). These
        /// can't be renamed, so this is always derived straight from the file.
        String _getAnasheedName(String assetPath) {
          String decoded = assetPath;
          try {
            if (assetPath.contains('%')) {
              decoded = Uri.decodeFull(assetPath);
            }
          } catch (_) {}
          final fileName = decoded.split('/').last;
          final withoutExt = fileName.replaceAll(RegExp(r'\.mp3$', caseSensitive: false), '');
          return withoutExt.replaceAll(RegExp(r'[_-]'), ' ').trim();
        }

        /// Currently playing track's display name, regardless of which playlist
        /// it came from.
        String? get _currentTrackName {
          if (_currentSource == _TrackSource.user &&
              _currentTrackIndex >= 0 &&
              _currentTrackIndex < _musicFiles.length) {
            return _getFileName(_musicFiles[_currentTrackIndex]);
          }
          if (_currentSource == _TrackSource.anasheed &&
              _currentTrackIndex >= 0 &&
              _currentTrackIndex < _anasheedFiles.length) {
            return _getAnasheedName(_anasheedFiles[_currentTrackIndex]);
          }
          return null;
        }

        bool get _hasNowPlaying => _currentTrackName != null;

        Future<void> _renameTrack(String path) async {
          final provider = AppDataProvider.instance;
          final isAr = provider.language == 'ar';
          final controller = TextEditingController(text: _getFileName(path));

          final newName = await showDialog<String>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text(isAr ? 'إعادة تسمية' : 'Rename Track'),
                content: TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: isAr ? 'اسم المسار' : 'Track name',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(isAr ? 'إلغاء' : 'Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(controller.text),
                    child: Text(isAr ? 'حفظ' : 'Save'),
                  ),
                ],
              );
            },
          );

          if (newName != null && newName.trim().isNotEmpty && mounted) {
            setState(() {
              _musicNames[path] = newName.trim();
            });
            await _saveNames();
          }
        }

        Future<void> _deleteSelectedMusic() async {
          final provider = AppDataProvider.instance;
          final isAr = provider.language == 'ar';

          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text(isAr ? 'حذف دائم' : 'Delete permanently'),
                content: Text(
                  _selectedMusic.length == 1
                      ? (isAr ? 'هل تريد حذف هذا المسار؟' : 'Do you want to delete this track?')
                      : (isAr ? 'هل تريد حذف هذه المسارات؟' : 'Do you want to delete these tracks?'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(isAr ? 'لا' : 'No'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      isAr ? 'نعم' : 'Yes',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              );
            },
          );

          if (confirmed != true) return;

          bool playingDeleted = false;

          for (final path in _selectedMusic.toList()) {
            final index = _musicFiles.indexOf(path);
            if (index != -1) {
              final wasCurrent = _currentSource == _TrackSource.user && index == _currentTrackIndex;
              final wasBeforeCurrent = _currentSource == _TrackSource.user && index < _currentTrackIndex;

              if (wasCurrent) {
                playingDeleted = true;
              }

              _musicFiles.removeAt(index);
              _musicNames.remove(path);

              if (wasCurrent) {
                _currentSource = null;
                _currentTrackIndex = -1;
                _isPlaying = false;
                _position = Duration.zero;
                _duration = Duration.zero;
              } else if (wasBeforeCurrent && _currentTrackIndex > 0) {
                _currentTrackIndex -= 1;
              }
            }

            try {
              final file = File(path);
              if (await file.exists()) {
                await file.delete();
              }
            } catch (_) {}
          }

          if (playingDeleted) {
            await _audioPlayer.stop();
          }

          setState(() {
            _isSelectionMode = false;
            _selectedMusic.clear();
          });

          await _savePlaylist();
          await _saveNames();
        }

        Future<void> _deleteTrack(int index) async {
          final path = _musicFiles[index];
          final provider = AppDataProvider.instance;
          final isAr = provider.language == 'ar';

          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text(isAr ? 'حذف دائم' : 'Delete permanently'),
                content: Text(
                  isAr
                      ? 'هل تريد حذف "${_getFileName(path)}"؟'
                      : 'Do you want to delete "${_getFileName(path)}"?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(isAr ? 'لا' : 'No'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      isAr ? 'نعم' : 'Yes',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              );
            },
          );

          if (confirmed != true) return;

          final wasCurrent = _currentSource == _TrackSource.user && index == _currentTrackIndex;
          final wasBeforeCurrent = _currentSource == _TrackSource.user && index < _currentTrackIndex;

          if (wasCurrent) {
            await _audioPlayer.stop();
          }

          setState(() {
            _musicFiles.removeAt(index);
            _musicNames.remove(path);

            if (wasCurrent) {
              _currentSource = null;
              _currentTrackIndex = -1;
              _isPlaying = false;
              _position = Duration.zero;
              _duration = Duration.zero;
            } else if (wasBeforeCurrent) {
              _currentTrackIndex -= 1;
            }
          });

          try {
            final file = File(path);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (_) {}

          await _savePlaylist();
          await _saveNames();
        }

        @override
        Widget build(BuildContext context) {
          final provider = AppDataProvider.instance;
          final isAr = provider.language == 'ar';

          return Scaffold(
            appBar: AppBar(
              title: Text(
                _isSelectionMode
                    ? (isAr ? 'تم تحديد ${_selectedMusic.length}' : '${_selectedMusic.length} Selected')
                    : (isAr ? 'موسيقى' : 'Music'),
              ),
              leading: _isSelectionMode
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        setState(() {
                          _isSelectionMode = false;
                          _selectedMusic.clear();
                        });
                      },
                    )
                  : null,
              actions: _isSelectionMode
                  ? [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            if (_selectedMusic.length == _musicFiles.length) {
                              _selectedMusic.clear();
                            } else {
                              _selectedMusic.addAll(_musicFiles);
                            }
                          });
                        },
                        icon: const Icon(Icons.select_all_rounded),
                        tooltip: isAr ? 'تحديد الكل' : 'Select all',
                      ),
                      if (_selectedMusic.isNotEmpty)
                        IconButton(
                          onPressed: _deleteSelectedMusic,
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                          tooltip: isAr ? 'حذف' : 'Delete',
                        ),
                    ]
                  : [
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: _pickMusicFiles,
                      ),
                    ],
            ),
            body: Column(
              children: [
                // Now Playing Section
                if (_hasNowPlaying)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.restaurantCard.withValues(alpha: 0.3),
                                  AppColors.restaurantCard.withValues(alpha: 0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.music_note_rounded,
                              size: 64,
                              color: AppColors.restaurantCard,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _currentTrackName ?? '',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 16),
                          // Progress Bar
                          Slider(
                            value: _position.inSeconds
                                .toDouble()
                                .clamp(0, _duration.inSeconds.toDouble()),
                            max: _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1,
                            onChanged: _seekMusic,
                            activeColor: AppColors.restaurantCard,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(_position),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                              Text(
                                _formatDuration(_duration),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Controls
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.skip_previous),
                                onPressed: _currentTrackIndex > 0
                                    ? () => _playTrack(_currentSource!, _currentTrackIndex - 1)
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppColors.restaurantCard, AppColors.sunsetOrange],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                                  color: Colors.white,
                                  onPressed: _isPlaying ? _pauseMusic : _resumeMusic,
                                ),
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                icon: const Icon(Icons.skip_next),
                                onPressed: _currentTrackIndex <
                                    (_currentSource == _TrackSource.user
                                        ? _musicFiles.length
                                        : _anasheedFiles.length) -
                                        1
                                    ? () => _playTrack(_currentSource!, _currentTrackIndex + 1)
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                // Scrollable content: Anasheed folder + user music list
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildAnasheedFolder(isAr),
                      const SizedBox(height: 20),
                      _buildMyMusicSection(isAr),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // ── Anasheed folder (bundled, read-only) ──────────────────────────────────
        Widget _buildAnasheedFolder(bool isAr) {
          if (_loadingAnasheed) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (_anasheedFiles.isEmpty) {
            // Nothing bundled — don't show an empty folder.
            return const SizedBox.shrink();
          }

          return GlassCard(
            padding: EdgeInsets.zero,
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: _anasheedExpanded,
                onExpansionChanged: (expanded) {
                  setState(() => _anasheedExpanded = expanded);
                },
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.restaurantCard.withValues(alpha: 0.25),
                        AppColors.restaurantCard.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.folder_rounded, color: AppColors.restaurantCard),
                ),
                title: Text(
                  isAr ? 'أناشيد' : 'Anasheed',
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  isAr ? '${_anasheedFiles.length} ملف' : '${_anasheedFiles.length} tracks',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                children: [
                  for (int i = 0; i < _anasheedFiles.length; i++)
                    _buildTrackTile(
                      displayName: _getAnasheedName(_anasheedFiles[i]),
                      isCurrentTrack: _currentSource == _TrackSource.anasheed && _currentTrackIndex == i,
                      onTap: () => _handleTrackTap(_TrackSource.anasheed, i),
                      // No popup menu: Anasheed tracks can't be renamed or deleted.
                      trailing: null,
                    ),
                ],
              ),
            ),
          );
        }

        // ── User's own music list ─────────────────────────────────────────────────
        Widget _buildMyMusicSection(bool isAr) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  isAr ? 'ملفاتي' : 'My Music',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
              if (_musicFiles.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.music_note,
                          size: 48,
                          color: AppColors.restaurantCard.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isAr ? 'لا توجد ملفات موسيقية' : 'No music files',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isAr ? 'اضغط + لإضافة ملفات MP3' : 'Tap + to add MP3 files',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                for (int i = 0; i < _musicFiles.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onLongPress: () {
                        if (!_isSelectionMode) {
                          setState(() {
                            _isSelectionMode = true;
                            _selectedMusic.add(_musicFiles[i]);
                          });
                        }
                      },
                      child: GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: _buildTrackTile(
                          displayName: _getFileName(_musicFiles[i]),
                          isCurrentTrack: _currentSource == _TrackSource.user && _currentTrackIndex == i,
                          onTap: () {
                            if (_isSelectionMode) {
                              setState(() {
                                final path = _musicFiles[i];
                                if (_selectedMusic.contains(path)) {
                                  _selectedMusic.remove(path);
                                  if (_selectedMusic.isEmpty) _isSelectionMode = false;
                                } else {
                                  _selectedMusic.add(path);
                                }
                              });
                            } else {
                              _handleTrackTap(_TrackSource.user, i);
                            }
                          },
                          trailing: _isSelectionMode
                              ? Icon(
                                  _selectedMusic.contains(_musicFiles[i])
                                      ? Icons.check_circle_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  color: _selectedMusic.contains(_musicFiles[i])
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                                )
                              : PopupMenuButton<String>(
                                  icon: Icon(
                                    Icons.more_vert,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                  onSelected: (value) {
                                    if (value == 'rename') {
                                      _renameTrack(_musicFiles[i]);
                                    } else if (value == 'delete') {
                                      _deleteTrack(i);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'rename',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.edit_outlined, size: 20),
                                          const SizedBox(width: 12),
                                          Text(isAr ? 'إعادة تسمية' : 'Rename'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                          const SizedBox(width: 12),
                                          Text(
                                            isAr ? 'حذف' : 'Delete',
                                            style: const TextStyle(color: Colors.red),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
            ],
          );
        }

        /// Shared row layout for a single track, used by both the Anasheed folder
        /// and the user's music list. Pass `trailing: null` to hide the menu
        /// button entirely (used for the read-only Anasheed tracks).
        Widget _buildTrackTile({
          required String displayName,
          required bool isCurrentTrack,
          required VoidCallback onTap,
          required Widget? trailing,
        }) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isCurrentTrack
                      ? [AppColors.restaurantCard, AppColors.sunsetOrange]
                      : [
                    AppColors.restaurantCard.withValues(alpha: 0.2),
                    AppColors.restaurantCard.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isCurrentTrack && _isPlaying ? Icons.pause : Icons.play_arrow,
                color: isCurrentTrack ? Colors.white : AppColors.restaurantCard,
              ),
            ),
            title: Text(
              displayName,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: isCurrentTrack ? FontWeight.w600 : FontWeight.w400,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: trailing,
            onTap: onTap,
          );
        }

        void _handleTrackTap(_TrackSource source, int index) {
          final isCurrentTrack = _currentSource == source && _currentTrackIndex == index;
          if (isCurrentTrack) {
            if (_isPlaying) {
              _pauseMusic();
            } else {
              _resumeMusic();
            }
          } else {
            _playTrack(source, index);
          }
        }
      }