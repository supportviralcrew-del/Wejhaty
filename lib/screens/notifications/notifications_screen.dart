import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:tripproject/core/theme/app_colors.dart';
import 'package:tripproject/core/widgets/gradient_background.dart';
import 'package:tripproject/services/app_data_provider.dart';
import 'package:tripproject/services/notification_log_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-mark all as read when opening (status is saved persistently)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (NotificationLogService.instance.hasUnread) {
        NotificationLogService.instance.markAllAsRead();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = AppDataProvider.instance;
    final isAr = provider.language == 'ar';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Wrapped in GradientBackground because MaterialPageRoute is opaque.
    // With a transparent Scaffold the previous route would be obscured by the
    // native window background (white on web) — this makes the premium
    // gradient visible on the pushed route as well.
    return GradientBackground(
      child: ListenableBuilder(
        listenable: NotificationLogService.instance,
        builder: (context, _) {
          final notifications = NotificationLogService.instance.notifications;
          final hasUnread = NotificationLogService.instance.hasUnread;
          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: Icon(
                  isAr ? Icons.arrow_forward : Icons.arrow_back,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                isAr ? 'الإشعارات' : 'Notifications',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              actions: [
                if (hasUnread)
                  TextButton.icon(
                    onPressed: () => NotificationLogService.instance.markAllAsRead(),
                    icon: Icon(
                      Icons.done_all_rounded,
                      color: isDark ? AppColors.pGoldSoft : AppColors.primary,
                      size: 18,
                    ),
                    label: Text(
                      isAr ? 'قراءة الكل' : 'Read all',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.pGoldSoft : AppColors.primary,
                      ),
                    ),
                  ),
                if (notifications.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => NotificationLogService.instance.clear(),
                    icon: Icon(
                      Icons.delete_outline,
                      color: isDark ? Colors.white70 : Colors.black54,
                      size: 20,
                    ),
                    label: Text(
                      isAr ? 'مسح الكل' : 'Clear All',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
              ],
            ),
            body: SafeArea(
              child: notifications.isEmpty
                  ? _buildEmptyState(isAr, isDark)
                  : _buildNotificationsList(notifications, isAr, isDark),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isAr, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_outlined,
            size: 64,
            color: isDark ? Colors.white24 : Colors.black12,
          ),
          const SizedBox(height: 16),
          Text(
            isAr ? 'لا توجد إشعارات' : 'No Notifications',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black38,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isAr
                ? 'ستظهر هنا أحداث التطبيق المهمة'
                : 'Important app events will appear here',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.black26,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(
    List<NotificationEvent> notifications,
    bool isAr,
    bool isDark,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[notifications.length - 1 - index];
        return _buildNotificationCard(notification, isAr, isDark);
      },
    );
  }

  Widget _buildNotificationCard(
    NotificationEvent notification,
    bool isAr,
    bool isDark,
  ) {
    final iconData = _getIconForType(notification.type);
    final iconColor = _getColorForType(notification.type);
    final timeAgo = _formatTimeAgo(notification.timestamp, isAr);
    final title = isAr ? notification.titleAr : notification.title;
    final message = isAr ? notification.messageAr : notification.message;
    final isUnread = !notification.isRead;

    return InkWell(
      onTap: isUnread ? () => NotificationLogService.instance.markAsRead(notification.id) : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isUnread
              ? (isDark ? AppColors.pGold.withValues(alpha: 0.14) : AppColors.primary.withValues(alpha: 0.08))
              : (isDark ? AppColors.pGold.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.8)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnread
                ? (isDark ? AppColors.pGold.withValues(alpha: 0.35) : AppColors.primary.withValues(alpha: 0.18))
                : (isDark ? AppColors.pGold.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.06)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      iconData,
                      color: iconColor,
                      size: 22,
                    ),
                  ),
                  if (isUnread)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.pGold : AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: isDark ? AppColors.pSurfaceDark : Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: isUnread ? FontWeight.w800 : FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        Text(
                          timeAgo,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.4,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    if (notification.metadata != null &&
                        notification.metadata!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildMetadataChips(notification.metadata!, isAr, isDark),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataChips(
    Map<String, dynamic> metadata,
    bool isAr,
    bool isDark,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: metadata.entries.map((entry) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${entry.key}: ${entry.value}',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.subscriptionSuccess:
        return Icons.check_circle_rounded;
      case NotificationType.subscriptionFailed:
        return Icons.error_outline_rounded;
      case NotificationType.subscriptionExpired:
        return Icons.event_busy_rounded;
      case NotificationType.subscriptionCancelled:
        return Icons.cancel_rounded;
      case NotificationType.creditsRefilled:
        return Icons.refresh_rounded;
      case NotificationType.creditsLow:
        return Icons.warning_amber_rounded;
      case NotificationType.tripStarted:
        return Icons.play_arrow_rounded;
      case NotificationType.tripCompleted:
        return Icons.flag_rounded;
      case NotificationType.tripProgress:
        return Icons.trending_up_rounded;
      case NotificationType.error:
        return Icons.error_rounded;
      case NotificationType.info:
        return Icons.info_outline_rounded;
    }
  }

  Color _getColorForType(NotificationType type) {
    switch (type) {
      case NotificationType.subscriptionSuccess:
        return AppColors.success;
      case NotificationType.subscriptionFailed:
        return AppColors.error;
      case NotificationType.subscriptionExpired:
        return Colors.orange;
      case NotificationType.subscriptionCancelled:
        return Colors.grey;
      case NotificationType.creditsRefilled:
        return Colors.green;
      case NotificationType.creditsLow:
        return Colors.orange;
      case NotificationType.tripStarted:
        return AppColors.sunsetOrange;
      case NotificationType.tripCompleted:
        return AppColors.success;
      case NotificationType.tripProgress:
        return Colors.blue;
      case NotificationType.error:
        return AppColors.error;
      case NotificationType.info:
        return Colors.blue;
    }
  }

  String _formatTimeAgo(DateTime dateTime, bool isAr) {
    try {
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return isAr ? 'الآن' : 'now';
      } else if (difference.inMinutes < 60) {
        final mins = difference.inMinutes;
        return isAr ? 'منذ $mins دقيقة' : '${mins}m ago';
      } else if (difference.inHours < 24) {
        final hours = difference.inHours;
        return isAr ? 'منذ $hours ساعة' : '${hours}h ago';
      } else if (difference.inDays < 7) {
        final days = difference.inDays;
        return isAr ? 'منذ $days يوم' : '${days}d ago';
      } else {
        return DateFormat(isAr ? 'dd MMM' : 'MMM d').format(dateTime);
      }
    } catch (_) {
      // Fallback if intl locale data is unavailable (e.g., web without initialization)
      try {
        return DateFormat('MMM d').format(dateTime);
      } catch (_) {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    }
  }
}
