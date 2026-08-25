import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tripproject/core/theme/app_colors.dart';
import 'package:tripproject/core/widgets/glass_card.dart';
import 'package:tripproject/services/app_data_provider.dart';
import 'dart:io';

class Note {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: json['id'] as String,
    title: json['title'] as String,
    content: json['content'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  Note copyWith({String? title, String? content}) => Note(
    id: id,
    title: title ?? this.title,
    content: content ?? this.content,
    createdAt: createdAt,
  );
}

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Note> _notes = [];
  bool _isLoading = true;
  String _searchQuery = '';

  // A small rotating set of accent colors so cards don't all look identical.
  static const List<Color> _accentColors = [
    AppColors.sunsetBlue,
    Color(0xFFE8A87C),
    Color(0xFF8FBFA8),
    Color(0xFFC38DC0),
  ];

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<File> _notesFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/trip_notes.json');
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);

    try {
      final file = await _notesFile();

      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> jsonList = json.decode(contents);
        final notes = jsonList.map((json) => Note.fromJson(json)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        setState(() => _notes = notes);
      }
    } catch (e) {
      _showSnack(_isArabic() ? 'تعذر تحميل الملاحظات' : 'Could not load notes',
          isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveNotes() async {
    try {
      final file = await _notesFile();
      final jsonList = _notes.map((note) => note.toJson()).toList();
      await file.writeAsString(json.encode(jsonList));
    } catch (e) {
      _showSnack(_isArabic() ? 'تعذر حفظ الملاحظات' : 'Could not save notes',
          isError: true);
    }
  }

  bool _isArabic() => AppDataProvider.instance.language == 'ar';

  Color _accentFor(String id) {
    final index = id.hashCode.abs() % _accentColors.length;
    return _accentColors[index];
  }

  void _showSnack(String message,
      {bool isError = false, SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(fontSize: 14)),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.inverseSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        action: action,
      ),
    );
  }

  void _showNoteEditor([Note? note]) {
    final isAr = _isArabic();
    final titleController = TextEditingController(text: note?.title ?? '');
    final contentController = TextEditingController(text: note?.content ?? '');
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: colorScheme.surface,
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                note == null ? Icons.note_add_rounded : Icons.edit_rounded,
                color: colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              note == null
                  ? (isAr ? 'ملاحظة جديدة' : 'New Note')
                  : (isAr ? 'تعديل الملاحظة' : 'Edit Note'),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                style: GoogleFonts.poppins(fontSize: 15),
                decoration: InputDecoration(
                  labelText: isAr ? 'العنوان' : 'Title',
                  labelStyle: GoogleFonts.poppins(fontSize: 14),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: contentController,
                style: GoogleFonts.poppins(fontSize: 15),
                decoration: InputDecoration(
                  labelText: isAr ? 'المحتوى' : 'Content',
                  labelStyle: GoogleFonts.poppins(fontSize: 14),
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                  ),
                ),
                maxLines: 5,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onSurface.withValues(alpha: 0.6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Text(isAr ? 'إلغاء' : 'Cancel',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isEmpty) return;

              final newNote = Note(
                id: note?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                title: titleController.text.trim(),
                content: contentController.text.trim(),
                createdAt: note?.createdAt ?? DateTime.now(),
              );

              setState(() {
                if (note != null) {
                  final index = _notes.indexWhere((n) => n.id == note.id);
                  if (index != -1) _notes[index] = newNote;
                } else {
                  _notes.insert(0, newNote);
                }
              });

              _saveNotes();
              Navigator.pop(dialogContext);
              _showSnack(note == null
                  ? (isAr ? 'تمت إضافة الملاحظة' : 'Note added')
                  : (isAr ? 'تم تحديث الملاحظة' : 'Note updated'));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(isAr ? 'حفظ' : 'Save',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteNote(Note note) async {
    final isAr = _isArabic();
    final colorScheme = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: colorScheme.surface,
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.error.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.delete_outline_rounded, color: colorScheme.error, size: 28),
        ),
        title: Text(
          isAr ? 'حذف الملاحظة؟' : 'Delete note?',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        content: Text(
          isAr
              ? 'سيتم حذف "${note.title}" نهائيًا ولا يمكن التراجع عن هذا الإجراء.'
              : 'Are you sure you want to delete "${note.title}"? This action cannot be undone.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        actions: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.4)),
              ),
              child: Text(isAr ? 'إلغاء' : 'Cancel',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(isAr ? 'حذف' : 'Delete',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _deleteNote(note);
    }
  }

  void _deleteNote(Note note) {
    final isAr = _isArabic();
    final index = _notes.indexOf(note);

    setState(() {
      _notes.removeWhere((n) => n.id == note.id);
    });
    _saveNotes();

    // Offer a quick undo in case of an accidental confirm.
    _showSnack(
      isAr ? 'تم حذف الملاحظة' : 'Note deleted',
      action: SnackBarAction(
        label: isAr ? 'تراجع' : 'Undo',
        textColor: Theme.of(context).colorScheme.primaryContainer,
        onPressed: () {
          setState(() {
            final restoreIndex = index.clamp(0, _notes.length);
            _notes.insert(restoreIndex, note);
          });
          _saveNotes();
        },
      ),
    );
  }

  List<Note> get _filteredNotes {
    if (_searchQuery.trim().isEmpty) return _notes;
    final query = _searchQuery.toLowerCase();
    return _notes
        .where((n) =>
    n.title.toLowerCase().contains(query) ||
        n.content.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = _isArabic();
    final colorScheme = Theme.of(context).colorScheme;
    final notes = _filteredNotes;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          isAr ? 'ملاحظات' : 'Notes',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: isAr ? 'إضافة ملاحظة' : 'Add note',
            onPressed: () => _showNoteEditor(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (!_isLoading && _notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  hintText: isAr ? 'ابحث في الملاحظات...' : 'Search notes...',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: colorScheme.onSurface.withValues(alpha: 0.4)),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : notes.isEmpty
                ? _buildEmptyState(isAr, colorScheme)
                : RefreshIndicator(
              onRefresh: _loadNotes,
              color: colorScheme.primary,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: notes.length,
                itemBuilder: (context, index) {
                  final note = notes[index];
                  return _NoteCard(
                    note: note,
                    accentColor: _accentFor(note.id),
                    dateLabel: _formatDate(note.createdAt, isAr),
                    onEdit: () => _showNoteEditor(note),
                    onDelete: () => _confirmDeleteNote(note),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: notes.isEmpty && !_isLoading
          ? null
          : FloatingActionButton(
        onPressed: () => _showNoteEditor(),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildEmptyState(bool isAr, ColorScheme colorScheme) {
    final noResults = _searchQuery.trim().isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              noResults ? Icons.search_off_rounded : Icons.note_add_rounded,
              size: 56,
              color: colorScheme.primary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            noResults
                ? (isAr ? 'لا توجد نتائج' : 'No matching notes')
                : (isAr ? 'لا توجد ملاحظات' : 'No notes yet'),
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            noResults
                ? (isAr ? 'جرّب كلمة بحث مختلفة' : 'Try a different search term')
                : (isAr ? 'اضغط + لإضافة ملاحظة' : 'Tap + to add your first note'),
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date, bool isAr) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final time =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    if (target == today) {
      return isAr ? 'اليوم، $time' : 'Today, $time';
    }
    final yesterday = today.subtract(const Duration(days: 1));
    if (target == yesterday) {
      return isAr ? 'أمس، $time' : 'Yesterday, $time';
    }
    return '${date.day}/${date.month}/${date.year} · $time';
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  final Color accentColor;
  final String dateLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.note,
    required this.accentColor,
    required this.dateLabel,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onEdit,
          child: GlassCard(
            padding: EdgeInsets.zero,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border(
                  left: isRtl(context)
                      ? BorderSide.none
                      : BorderSide(color: accentColor, width: 4),
                  right: isRtl(context)
                      ? BorderSide(color: accentColor, width: 4)
                      : BorderSide.none,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          note.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit_outlined,
                            size: 19, color: colorScheme.onSurface.withValues(alpha: 0.55)),
                        splashRadius: 20,
                        onPressed: onEdit,
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded,
                            size: 19, color: colorScheme.error.withValues(alpha: 0.75)),
                        splashRadius: 20,
                        onPressed: onDelete,
                      ),
                    ],
                  ),
                  if (note.content.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      note.content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        height: 1.4,
                        color: colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 13, color: colorScheme.onSurface.withValues(alpha: 0.35)),
                      const SizedBox(width: 4),
                      Text(
                        dateLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool isRtl(BuildContext context) => Directionality.of(context) == TextDirection.rtl;
}