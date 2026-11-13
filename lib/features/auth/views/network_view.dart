
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme/app_colors.dart';

class NetworkView extends StatefulWidget {
  const NetworkView({super.key});

  @override
  State<NetworkView> createState() => _NetworkViewState();
}

class _NetworkViewState extends State<NetworkView> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _searchController =
      TextEditingController();

  String _searchText = '';
  bool _loading = false;

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

  // GET CONNECTION STATUS
  Future<String> _getConnectionStatus(String userId) async {
    final uid = _auth.currentUser!.uid;

    final sent = await _db
        .collection('Connections')
        .where('senderId', isEqualTo: uid)
        .get();

    final received = await _db
        .collection('Connections')
        .where('receiverId', isEqualTo: uid)
        .get();

    for (final doc in [...sent.docs, ...received.docs]) {
      final data = doc.data();

      if (data['senderId'] == userId ||
          data['receiverId'] == userId) {
        final status = data['status'];

        if (status == 'accepted') return 'accepted';

        if (status == 'pending') {
          return data['senderId'] == uid ? 'sent' : 'received';
        }

        if (status == 'rejected' &&
            data['senderId'] == uid) {
          return 'rejected';
        }
      }
    }

    return 'none';
  }

  // GET ACCEPTED CONNECTIONS
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _getConnections() async {
    final uid = _auth.currentUser!.uid;

    final sent = await _db
        .collection('Connections')
        .where('senderId', isEqualTo: uid)
        .get();

    final received = await _db
        .collection('Connections')
        .where('receiverId', isEqualTo: uid)
        .get();

    final all = [...sent.docs, ...received.docs];

    return all.where((doc) {
      return doc.data()['status'] == 'accepted';
    }).toList();
  }

  // SEND CONNECTION REQUEST
  Future<void> _sendRequest(
    String receiverId,
    Map<String, dynamic> receiverData,
  ) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null || _loading) return;
    if (receiverId == currentUser.uid) return;

    setState(() => _loading = true);

    try {
      final sent = await _db
          .collection('Connections')
          .where('senderId', isEqualTo: currentUser.uid)
          .get();

      final received = await _db
          .collection('Connections')
          .where('receiverId', isEqualTo: currentUser.uid)
          .get();

      final all = [...sent.docs, ...received.docs];

      for (final doc in all) {
        final data = doc.data();

        final sameUser =
            data['senderId'] == receiverId ||
            data['receiverId'] == receiverId;

        if (!sameUser) continue;

        if (data['status'] == 'accepted') {
          _showMessage('You are already connected.');
          return;
        }

        if (data['status'] == 'pending') {
          if (data['senderId'] == currentUser.uid) {
            _showMessage('Connection request already sent.');
          } else {
            _showMessage(
              'This user has already sent you a request. '
              'Check your Requests tab.',
            );
          }
          return;
        }

        if (data['status'] == 'rejected' &&
            data['senderId'] == currentUser.uid) {
          _showMessage('This request was previously rejected.');
          return;
        }
      }

      final currentUserDoc =
          await _db.collection('Users').doc(currentUser.uid).get();

      final senderData = currentUserDoc.data() ?? {};

      final requestRef = _db
          .collection('Connections')
          .doc('${currentUser.uid}_$receiverId');

      final notificationRef =
          _db.collection('Notifications').doc();

      await _db.runTransaction((transaction) async {
        transaction.set(requestRef, {
          'senderId': currentUser.uid,
          'receiverId': receiverId,
          'senderName': _userName(senderData),
          'receiverName': _userName(receiverData),
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.set(notificationRef, {
          'recipientId': receiverId,
          'senderId': currentUser.uid,
          'senderName': _userName(senderData),
          'type': 'connection_request',
          'message':
              '${_userName(senderData)} sent you a connection request.',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      _showMessage('Connection request sent!');
      if (mounted) setState(() {});
    } catch (e) {
      _showMessage('Could not send request: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ACCEPT OR REJECT REQUEST
  Future<void> _respondToRequest(
    String connectionId,
    String senderId,
    String senderName,
    bool accept,
  ) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      final currentUserDoc =
          await _db.collection('Users').doc(currentUser.uid).get();

      final currentUserData = currentUserDoc.data() ?? {};

      final requestRef =
          _db.collection('Connections').doc(connectionId);

      final notificationRef =
          _db.collection('Notifications').doc();

      await _db.runTransaction((transaction) async {
        transaction.update(requestRef, {
          'status': accept ? 'accepted' : 'rejected',
        });

        if (accept) {
          transaction.set(notificationRef, {
            'recipientId': senderId,
            'senderId': currentUser.uid,
            'senderName': _userName(currentUserData),
            'type': 'connection_accepted',
            'message':
                '${_userName(currentUserData)} accepted your connection request.',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      });

      _showMessage(
        accept ? 'Connection request accepted!' : 'Request rejected.',
      );

      if (mounted) setState(() {});
    } catch (e) {
      _showMessage('Something went wrong: $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // REUSABLE USER AVATAR
  Widget _buildAvatar(String name) {
    return CircleAvatar(
      radius: 25,
      backgroundColor: AppColors.primary.withValues(alpha: 0.10),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  // RESPONSIVE CONTENT CONTAINER
  Widget _responsiveContent(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: child,
          ),
        );
      },
    );
  }

  // USER CARD
  Widget _buildUserCard(
    String userId,
    Map<String, dynamic> data,
  ) {
    if (userId == _auth.currentUser?.uid) {
      return const SizedBox.shrink();
    }

    final name = _userName(data);

    return Card(
      color: AppColors.white,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        child: Row(
          children: [
            _buildAvatar(name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _userHeadline(data),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              flex: 0,
              child: FutureBuilder<String>(
                future: _getConnectionStatus(userId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const SizedBox(
                      width: 24,
                      height: 24,
                      child: Icon(
                        Icons.refresh,
                        color: AppColors.secondaryText,
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    );
                  }

                  final status = snapshot.data!;

                  if (status == 'sent') {
                    return _statusLabel('Requested');
                  }

                  if (status == 'received') {
                    return _statusLabel('Respond');
                  }

                  if (status == 'accepted') {
                    return _statusLabel('Connected');
                  }

                  if (status == 'rejected') {
                    return _statusLabel('Declined');
                  }

                  return OutlinedButton(
                    onPressed: _loading
                        ? null
                        : () => _sendRequest(userId, data),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(
                        color: AppColors.primary,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 7,
                      ),
                      minimumSize: const Size(0, 34),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Connect',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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

  Widget _statusLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // SEARCH USERS
  Widget _buildSearchSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Find People',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search by name or email',
            prefixIcon: const Icon(
              Icons.search,
              color: AppColors.secondaryText,
            ),
            filled: true,
            fillColor: AppColors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
            suffixIcon: _searchText.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchText = '');
                    },
                  )
                : null,
          ),
          onChanged: (value) {
            setState(() {
              _searchText = value.toLowerCase().trim();
            });
          },
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _db.collection('Users').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Unable to load users.');
            }

            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              );
            }

            final users = snapshot.data!.docs.where((doc) {
              if (doc.id == _auth.currentUser?.uid) {
                return false;
              }

              final data = doc.data();
              final name = _userName(data).toLowerCase();
              final email =
                  (data['email'] ?? '').toString().toLowerCase();

              return _searchText.isEmpty ||
                  name.contains(_searchText) ||
                  email.contains(_searchText);
            }).toList();

            if (users.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No users found.',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: users
                  .map((doc) => _buildUserCard(doc.id, doc.data()))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  // INCOMING REQUESTS
  Widget _buildRequestsSection() {
    final uid = _auth.currentUser!.uid;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('Connections')
          .where('receiverId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Unable to load requests.');
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
            ),
          );
        }

        final requests = snapshot.data!.docs.where((doc) {
          return doc.data()['status'] == 'pending';
        }).toList();

        if (requests.isEmpty) {
          return _emptyState(
            Icons.person_add_alt_1_outlined,
            'No pending connection requests.',
          );
        }

        return Column(
          children: requests.map((doc) {
            final data = doc.data();
            final senderId = data['senderId'] ?? '';
            final senderName = data['senderName'] ?? 'User';

            return Card(
              color: AppColors.white,
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _buildAvatar(senderName),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            senderName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Wants to connect with you',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 2,
                      children: [
                        IconButton(
                          tooltip: 'Accept',
                          icon: const Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                          ),
                          onPressed: () => _respondToRequest(
                            doc.id,
                            senderId,
                            senderName,
                            true,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Reject',
                          icon: const Icon(
                            Icons.cancel,
                            color: AppColors.error,
                          ),
                          onPressed: () => _respondToRequest(
                            doc.id,
                            senderId,
                            senderName,
                            false,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ACCEPTED CONNECTIONS
  Widget _buildConnectionsSection() {
    return FutureBuilder<
        List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      future: _getConnections(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Unable to load connections.');
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
            ),
          );
        }

        final connections = snapshot.data!;

        if (connections.isEmpty) {
          return _emptyState(
            Icons.people_outline,
            'You have no connections yet.',
          );
        }

        return Column(
          children: connections.map((doc) {
            final data = doc.data();
            final uid = _auth.currentUser!.uid;

            final otherUserId = data['senderId'] == uid
                ? data['receiverId']
                : data['senderId'];

            return FutureBuilder<DocumentSnapshot>(
              future: _db
                  .collection('Users')
                  .doc(otherUserId)
                  .get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData ||
                    !userSnapshot.data!.exists) {
                  return const SizedBox.shrink();
                }

                final userData = userSnapshot.data!.data()
                    as Map<String, dynamic>;

                final name = _userName(userData);

                return Card(
                  color: AppColors.white,
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    leading: _buildAvatar(name),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryText,
                      ),
                    ),
                    subtitle: Text(
                      _userHeadline(userData),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                    ),
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }

  Widget _emptyState(IconData icon, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 45),
      child: Center(
        child: Column(
          children: [
            Icon(
              icon,
              size: 48,
              color: AppColors.secondaryText,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.primaryText,
          elevation: 0,
          title: const Text(
            'My Network',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryText,
            ),
          ),
          bottom: const TabBar(
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.secondaryText,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            tabs: [
              Tab(text: 'Discover'),
              Tab(text: 'Requests'),
              Tab(text: 'Connections'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _responsiveContent(
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildSearchSection(),
              ),
            ),
            _responsiveContent(
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildRequestsSection(),
              ),
            ),
            _responsiveContent(
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildConnectionsSection(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
