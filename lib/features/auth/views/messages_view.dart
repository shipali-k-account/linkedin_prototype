
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme/app_colors.dart';

// MESSAGES SCREEN
class MessagesView extends StatefulWidget {
  const MessagesView({super.key});

  @override
  State<MessagesView> createState() => _MessagesViewState();
}

class _MessagesViewState extends State<MessagesView> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late Future<List<Map<String, dynamic>>> _connectedUsersFuture;

  @override
  void initState() {
    super.initState();
    _connectedUsersFuture = _getConnectedUsers();
  }

  String _userName(Map<String, dynamic> data) {
    return data['fullName'] ??
        data['name'] ??
        data['displayName'] ??
        data['email'] ??
        'User';
  }

  String _userHeadline(Map<String, dynamic> data) {
    return data['headline'] ??
        data['bio'] ??
        data['jobTitle'] ??
        'Professional';
  }

  // GET ONLY ACCEPTED CONNECTIONS
  Future<List<Map<String, dynamic>>> _getConnectedUsers() async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw Exception('User is not signed in.');
    }

    final uid = currentUser.uid;

    final sent = await _db
        .collection('Connections')
        .where('senderId', isEqualTo: uid)
        .get();

    final received = await _db
        .collection('Connections')
        .where('receiverId', isEqualTo: uid)
        .get();

    final allConnections = [...sent.docs, ...received.docs];

    final connectedUsers = <Map<String, dynamic>>[];
    final addedUserIds = <String>{};

    for (final connection in allConnections) {
      final connectionData = connection.data();

      if (connectionData['status'] != 'accepted') {
        continue;
      }

      final otherUserId =
          connectionData['senderId'] == uid
              ? connectionData['receiverId']
              : connectionData['senderId'];

      if (addedUserIds.contains(otherUserId)) {
        continue;
      }

      final userDoc =
          await _db.collection('Users').doc(otherUserId).get();

      if (userDoc.exists) {
        connectedUsers.add({
          'uid': otherUserId,
          'data': userDoc.data() ?? {},
        });

        addedUserIds.add(otherUserId);
      }
    }

    return connectedUsers;
  }

  // OPEN CHAT
  void _openChat(
    String otherUserId,
    Map<String, dynamic> otherUserData,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          otherUserId: otherUserId,
          otherUserData: otherUserData,
        ),
      ),
    );
  }

  Widget _buildAvatar(String name, {double radius = 25}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withValues(alpha: 0.10),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
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
          'Messaging',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _connectedUsersFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Unable to load connections. Please try again.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            );
          }

          final users = snapshot.data ?? [];

          if (users.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 58,
                      color: AppColors.secondaryText.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'No connections yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Connect with people to start messaging.',
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

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 700;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 850),
                  child: Container(
                    color: AppColors.white,
                    child: ListView.separated(
                      padding: EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: isWide ? 16 : 4,
                      ),
                      itemCount: users.length,
                      separatorBuilder: (context, index) =>
                          const Divider(
                        height: 1,
                        indent: 80,
                        color: AppColors.border,
                      ),
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final userId = user['uid'] as String;
                        final userData =
                            user['data'] as Map<String, dynamic>;

                        final name = _userName(userData);
                        final headline = _userHeadline(userData);

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          leading: _buildAvatar(name, radius: 25),
                          title: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryText,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                              headline,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: AppColors.primary,
                          ),
                          onTap: () => _openChat(userId, userData),
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

// INDIVIDUAL CHAT SCREEN
class ChatPage extends StatefulWidget {
  final String otherUserId;
  final Map<String, dynamic> otherUserData;

  const ChatPage({
    super.key,
    required this.otherUserId,
    required this.otherUserData,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _messageController =
      TextEditingController();

  bool _sending = false;

  String get _currentUserId => _auth.currentUser!.uid;

  String get _otherUserName {
    final data = widget.otherUserData;

    return data['fullName'] ??
        data['name'] ??
        data['displayName'] ??
        data['email'] ??
        'User';
  }

  // UNIQUE CHAT ID FOR BOTH USERS
  String get _chatId {
    final ids = [_currentUserId, widget.otherUserId]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  CollectionReference<Map<String, dynamic>>
      get _messagesCollection {
    return _db
        .collection('Chats')
        .doc(_chatId)
        .collection('Messages');
  }

  @override
  void initState() {
    super.initState();
    _markMessagesAsRead();
  }

  // MARK RECEIVED MESSAGES AS READ
  Future<void> _markMessagesAsRead() async {
    try {
      final unreadMessages = await _messagesCollection
          .where('receiverId', isEqualTo: _currentUserId)
          .where('isRead', isEqualTo: false)
          .get();

      if (unreadMessages.docs.isEmpty) return;

      final batch = _db.batch();

      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {
          'isRead': true,
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Could not mark messages as read: $e');
    }
  }

  // SEND MESSAGE
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();

    if (message.isEmpty || _sending) return;

    setState(() {
      _sending = true;
    });

    try {
      final chatRef = _db.collection('Chats').doc(_chatId);

      final participantIds = [
        _currentUserId,
        widget.otherUserId,
      ]..sort();

      final chatDoc = await chatRef.get();

      if (!chatDoc.exists) {
        await chatRef.set({
          'participantIds': participantIds,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await _messagesCollection.add({
        'senderId': _currentUserId,
        'receiverId': widget.otherUserId,
        'text': message,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Create notification for receiver
      await _db.collection('Notifications').add({
        'recipientId': widget.otherUserId,
        'senderId': _currentUserId,
        'type': 'new_message',
        'message': 'You received a new message.',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _messageController.clear();
    } catch (e) {
      debugPrint('SEND MESSAGE ERROR: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message could not be sent. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final date = timestamp.toDate();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  // MESSAGE BUBBLE
  Widget _buildMessageBubble(
    Map<String, dynamic> data,
    double screenWidth,
  ) {
    final isMe = data['senderId'] == _currentUserId;
    final timestamp = data['createdAt'] as Timestamp?;

    return Align(
      alignment:
          isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: screenWidth >= 700
              ? 480
              : screenWidth * 0.78,
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 5,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.primary
              : const Color(0xFFF0F2F5),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              data['text'] ?? '',
              style: TextStyle(
                color: isMe
                    ? AppColors.white
                    : AppColors.primaryText,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _formatTime(timestamp),
              style: TextStyle(
                color: isMe
                    ? Colors.white70
                    : AppColors.secondaryText,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.primaryText,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  AppColors.primary.withValues(alpha: 0.10),
              child: Text(
                _otherUserName.isNotEmpty
                    ? _otherUserName[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _otherUserName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: _messagesCollection
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text(
                          'Unable to load messages.',
                          style: TextStyle(
                            color: AppColors.secondaryText,
                          ),
                        ),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      );
                    }

                    final messages = snapshot.data!.docs;

                    if (messages.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'Say hello! Start your conversation.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                        vertical: 15,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        return _buildMessageBubble(
                          messages[index].data(),
                          constraints.maxWidth,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),

          // MESSAGE INPUT
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: const BoxDecoration(
                color: AppColors.white,
                border: Border(
                  top: BorderSide(
                    color: AppColors.border,
                  ),
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 850,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          textCapitalization:
                              TextCapitalization.sentences,
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Write a message...',
                            hintStyle: const TextStyle(
                              color: AppColors.secondaryText,
                            ),
                            filled: true,
                            fillColor: AppColors.background,
                            contentPadding:
                                const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 46,
                        width: 46,
                        child: IconButton(
                          onPressed: _sending ? null : _sendMessage,
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.white,
                            disabledBackgroundColor:
                                AppColors.primary.withValues(alpha: 0.5),
                          ),
                          icon: _sending
                              ? const SizedBox(
                                  width: 19,
                                  height: 19,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.white,
                                  ),
                                )
                              : const Icon(Icons.send),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
