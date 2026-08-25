import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tripproject/core/theme/app_colors.dart';
import 'package:tripproject/core/theme/app_theme.dart';
import 'package:tripproject/services/checklist_service.dart';

class ChecklistSheet extends StatefulWidget {
  const ChecklistSheet({super.key, required this.isAr});

  final bool isAr;

  @override
  State<ChecklistSheet> createState() => _ChecklistSheetState();
}

class _ChecklistSheetState extends State<ChecklistSheet> {
  final _controller = TextEditingController();

  void _add() {
    ChecklistService.instance.addItem(_controller.text);
    _controller.clear();
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAr = widget.isAr;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(
          color: isDark ? AppColors.glassBorder : Colors.black.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: ListenableBuilder(
        listenable: ChecklistService.instance,
        builder: (context, _) {
          final items = ChecklistService.instance.items;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: isAr ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.checklistCard.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.checklist_rounded, color: AppColors.checklistCard),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isAr ? 'قائمة التحقق' : 'Travel Checklist',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${ChecklistService.instance.doneCount}/${ChecklistService.instance.totalCount}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.checklistCard,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Add row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _add(),
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: isAr ? 'أضف عنصر جديد' : 'Add a new item',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                          borderSide: const BorderSide(color: AppColors.checklistCard, width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    onPressed: _add,
                    style: IconButton.styleFrom(backgroundColor: AppColors.checklistCard),
                    icon: const Icon(Icons.add_rounded, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // List
              Flexible(
                child: items.isEmpty
                    ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Text(
                      isAr ? 'لا توجد عناصر بعد' : 'No items yet',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                )
                    : ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Dismissible(
                      key: ValueKey(item.id),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => ChecklistService.instance.removeItem(item.id),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                        ),
                        child: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                        leading: Checkbox(
                          value: item.done,
                          activeColor: AppColors.checklistCard,
                          onChanged: (_) => ChecklistService.instance.toggleItem(item.id),
                        ),
                        title: Text(
                          item.title,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            decoration: item.done ? TextDecoration.lineThrough : null,
                            color: item.done
                                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                          onPressed: () => ChecklistService.instance.removeItem(item.id),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}