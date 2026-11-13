
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme/app_colors.dart';

class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() =>
      _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _currentUserId => _auth.currentUser!.uid;

  // GET NOTIFICATION ICON
  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'connection_request':
        return Icons.person_add_alt_1;

      case 'connection_accepted':
        return Icons.people_alt_outlined;

      case 'new_message':
        return Icons.message_outlined;

      default:
        return Icons.notifications_outlined;
    }
  }

  // GET NOTIFICATION COLOR
  Color _getNotificationColor(String type) {
    switch (type) {
      case 'connection_request':
        return const Color(0xFFE69527);

      case 'connection_accepted':
        return AppColors.success;

      case 'new_message':
        return AppColors.primary;

      default:
        return AppColors.secondaryText;
    }
  }

  // MARK NOTIFICATION AS READ
  Future<void> _markAsRead(String notificationId) async {
    try {
      await _db
          .collection('Notifications')
          .doc(notificationId)
          .update({
        'isRead': true,
      });
    } catch (e) {
      debugPrint('Unable to mark notification as read: $e');
    }
  }

  // FORMAT NOTIFICATION TIME
  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';

    final date = timestamp.toDate();
    final difference = DateTime.now().difference(date);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  // BUILD NOTIFICATION CARD
  Widget _buildNotification(
    String notificationId,
    Map<String, dynamic> data,
  ) {
    final type = data['type'] ?? '';
    final message =
        data['message'] ?? 'You have a new notification.';
    final senderName = data['senderName'] ?? 'Someone';
    final isRead = data['isRead'] == true;
    final timestamp = data['createdAt'] as Timestamp?;

    final notificationColor = _getNotificationColor(type);

    return Material(
      color: isRead
          ? AppColors.white
          : AppColors.primary.withValues(alpha: 0.06),
      child: InkWell(
        onTap: () {
          if (!isRead) {
            _markAsRead(notificationId);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor:
                    notificationColor.withValues(alpha: 0.12),
                child: Icon(
                  _getNotificationIcon(type),
                  color: notificationColor,
                  size: 23,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      senderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.primaryText,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: AppColors.primaryText,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Text(
                      _formatTime(timestamp),
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              if (!isRead) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // EMPTY NOTIFICATION STATE
  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none,
              size: 65,
              color: AppColors.secondaryText,
            ),
            SizedBox(height: 14),
            Text(
              'No notifications yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
              ),
            ),
            SizedBox(height: 7),
            Text(
              'Your notifications will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_auth.currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('Please sign in to continue.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.primaryText,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
        ),
      ),

      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: _db
            .collection('Notifications')
            .where('recipientId', isEqualTo: _currentUserId)
            .snapshots(),

        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Unable to load notifications.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
            );
          }

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            );
          }

          final notifications = snapshot.data?.docs ?? [];

          if (notifications.isEmpty) {
            return _buildEmptyState();
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 850,
                  ),
                  child: Container(
                    color: AppColors.white,
                    child: ListView.separated(
                      itemCount: notifications.length,
                      separatorBuilder: (context, index) =>
                          const Divider(
                        height: 1,
                        thickness: 0.7,
                        color: AppColors.border,
                      ),
                      itemBuilder: (context, index) {
                        final notification =
                            notifications[index];

                        return _buildNotification(
                          notification.id,
                          notification.data(),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
