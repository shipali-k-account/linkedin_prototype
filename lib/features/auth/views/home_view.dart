
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../services/firestore_service.dart';

import 'network_view.dart';
import 'jobs_view.dart';
import 'messages_view.dart';
import 'notifications_view.dart';
import 'subscription_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final FirestoreService _firestoreService = FirestoreService();

  late Future<DocumentSnapshot<Map<String, dynamic>>> _userFuture;

  int _selectedIndex = 0;

  final User user = FirebaseAuth.instance.currentUser!;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _loadUser() {
    _userFuture = _firestoreService.getDocument('Users', user.uid);
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // CONFIRM DELETE
  Future<bool> _confirmDelete(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.white,
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.secondaryText),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  // DELETE POST AND ITS COMMENTS
  Future<void> _deletePost(String postId) async {
    final confirmed = await _confirmDelete(
      'Delete Post?',
      'Are you sure you want to delete this post and all its comments?',
    );

    if (!confirmed) return;

    try {
      final firestore = FirebaseFirestore.instance;

      final commentsRef = firestore
          .collection('Posts')
          .doc(postId)
          .collection('Comments');

      // Firestore does not automatically delete subcollections.
      // Delete comments in batches of 400.
      while (true) {
        final commentsSnapshot = await commentsRef.limit(400).get();

        if (commentsSnapshot.docs.isEmpty) break;

        final batch = firestore.batch();

        for (final comment in commentsSnapshot.docs) {
          batch.delete(comment.reference);
        }

        await batch.commit();
      }

      // Delete the post after deleting its comments.
      await firestore.collection('Posts').doc(postId).delete();

      _showMessage('Post deleted successfully.');
    } catch (e) {
      _showMessage('Unable to delete post: $e');
    }
  }

  // LIKE OR UNLIKE A POST
  Future<void> _toggleLike(
    String postId,
    List<dynamic> likes,
  ) async {
    final postRef = FirebaseFirestore.instance
        .collection('Posts')
        .doc(postId);

    try {
      if (likes.contains(user.uid)) {
        await postRef.update({
          'likes': FieldValue.arrayRemove([user.uid]),
        });
      } else {
        await postRef.update({
          'likes': FieldValue.arrayUnion([user.uid]),
        });
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Unable to update like: $e');
      }
    }
  }

  // OPEN COMMENTS
  void _showComments(String postId, String postOwnerId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return PostCommentsSheet(
          postId: postId,
          postOwnerId: postOwnerId,
        );
      },
    );
  }

  // DISPLAY ONE POST
  Widget _buildPost(
    String postId,
    Map<String, dynamic> postData,
  ) {
    final authorName = postData['authorName'] ?? 'User';
    final authorImage = postData['authorImageUrl'] ?? '';
    final content = postData['content'] ?? '';
    final postImage = postData['imageUrl'] ?? '';
    final postOwnerId = postData['userId'] ?? '';

    final likes = List<dynamic>.from(postData['likes'] ?? []);
    final isLiked = likes.contains(user.uid);
    final isMyPost = postOwnerId == user.uid;

    final timestamp = postData['createdAt'];

    String postTime = '';

    if (timestamp is Timestamp) {
      postTime = timestamp.toDate().toString().substring(0, 16);
    }

    final hasImage = postImage is String && postImage.isNotEmpty;

    return Card(
      color: AppColors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(
          color: AppColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AUTHOR DETAILS AND POST MENU
            Row(
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor: AppColors.background,
                  backgroundImage:
                      authorImage is String && authorImage.isNotEmpty
                          ? NetworkImage(authorImage)
                          : null,
                  child: authorImage is String && authorImage.isNotEmpty
                      ? null
                      : const Icon(
                          Icons.person,
                          color: AppColors.secondaryText,
                        ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName.toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        postTime,
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // THREE-DOT MENU FOR OWN POSTS
                if (isMyPost)
                  PopupMenuButton<String>(
                    tooltip: 'Post options',
                    color: AppColors.white,
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deletePost(postId);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              color: AppColors.error,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Delete Post',
                              style: TextStyle(
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // TEXT-ONLY POST DESIGN OR NORMAL POST TEXT
            if (content.toString().isNotEmpty)
              if (!hasImage)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F6FC),
                    borderRadius: BorderRadius.circular(10),
                    border: const Border(
                      left: BorderSide(
                        color: AppColors.primary,
                        width: 4,
                      ),
                    ),
                  ),
                  child: Text(
                    content.toString(),
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: AppColors.primaryText,
                    ),
                  ),
                )
              else
                Text(
                  content.toString(),
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: AppColors.primaryText,
                  ),
                ),

            // RESPONSIVE POST IMAGE
            if (hasImage) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  color: AppColors.background,
                  child: Image.network(
                    postImage,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text(
                            'Unable to load post image',
                            style: TextStyle(
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        return child;
                      }

                      return const SizedBox(
                        height: 180,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // LIKES COUNT
            Text(
              '${likes.length} likes',
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 13,
              ),
            ),

            const Divider(
              height: 20,
              color: AppColors.border,
            ),

            // LIKE AND COMMENT BUTTONS
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      _toggleLike(postId, likes);
                    },
                    icon: Icon(
                      isLiked
                          ? Icons.thumb_up
                          : Icons.thumb_up_outlined,
                      color: isLiked
                          ? AppColors.primary
                          : AppColors.secondaryText,
                    ),
                    label: Text(
                      'Like',
                      style: TextStyle(
                        color: isLiked
                            ? AppColors.primary
                            : AppColors.secondaryText,
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      _showComments(postId, postOwnerId.toString());
                    },
                    icon: const Icon(
                      Icons.comment_outlined,
                      color: AppColors.secondaryText,
                    ),
                    label: const Text(
                      'Comment',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // HOME FEED
  Widget _buildHomeFeed() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('Posts')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Unable to load posts: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.error,
                ),
              ),
            ),
          );
        }

        final posts = snapshot.data?.docs ?? [];

        if (posts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.feed_outlined,
                  size: 45,
                  color: AppColors.secondaryText,
                ),
                SizedBox(height: 10),
                Text(
                  'No posts yet!',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];

            return _buildPost(
              post.id,
              post.data(),
            );
          },
        );
      },
    );
  }

  // SELECTED PAGE
  Widget _buildSelectedPage() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeFeed();
      case 1:
        return const JobsView();
      case 2:
        return const NetworkView();
      case 3:
        return const NotificationsView();
      case 4:
        return const SubscriptionView();
      default:
        return _buildHomeFeed();
    }
  }

  // NAVIGATION DESTINATIONS
  List<NavigationDestination> _buildDestinations() {
    return const [
      NavigationDestination(
        icon: Icon(
          Icons.home_outlined,
          color: AppColors.secondaryText,
        ),
        selectedIcon: Icon(
          Icons.home,
          color: AppColors.primary,
        ),
        label: 'Home',
      ),
      NavigationDestination(
        icon: Icon(
          Icons.work_outline,
          color: AppColors.secondaryText,
        ),
        selectedIcon: Icon(
          Icons.work,
          color: AppColors.primary,
        ),
        label: 'Jobs',
      ),
      NavigationDestination(
        icon: Icon(
          Icons.people_outline,
          color: AppColors.secondaryText,
        ),
        selectedIcon: Icon(
          Icons.people,
          color: AppColors.primary,
        ),
        label: 'My Network',
      ),
      NavigationDestination(
        icon: Icon(
          Icons.notifications_none,
          color: AppColors.secondaryText,
        ),
        selectedIcon: Icon(
          Icons.notifications,
          color: AppColors.primary,
        ),
        label: 'Notification',
      ),
      NavigationDestination(
        icon: Icon(
          Icons.workspace_premium_outlined,
          color: AppColors.secondaryText,
        ),
        selectedIcon: Icon(
          Icons.workspace_premium,
          color: AppColors.primary,
        ),
        label: 'Subscription',
      ),
    ];
  }

  // RESPONSIVE DESKTOP NAVIGATION
  Widget _buildNavigationRail() {
    return NavigationRail(
      backgroundColor: AppColors.white,
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
      labelType: NavigationRailLabelType.all,
      selectedIconTheme: const IconThemeData(
        color: AppColors.primary,
      ),
      unselectedIconTheme: const IconThemeData(
        color: AppColors.secondaryText,
      ),
      selectedLabelTextStyle: const TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: const TextStyle(
        color: AppColors.secondaryText,
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: Text('Home'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.work_outline),
          selectedIcon: Icon(Icons.work),
          label: Text('Jobs'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: Text('My Network'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.notifications_none),
          selectedIcon: Icon(Icons.notifications),
          label: Text('Notifications'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.workspace_premium_outlined),
          selectedIcon: Icon(Icons.workspace_premium),
          label: Text('Subscription'),
        ),
      ],
    );
  }

  // APP BAR
  AppBar _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.primaryText,
      elevation: 0,
      surfaceTintColor: AppColors.white,
      titleSpacing: 12,
      title: Row(
        children: [
          // PROFILE PICTURE
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: _userFuture,
            builder: (context, snapshot) {
              final imageUrl =
                  snapshot.data?.data()?['profileImageUrl'] ?? '';

              return GestureDetector(
                onTap: () {
                  context.push('/profile');
                },
                child: CircleAvatar(
                  radius: 19,
                  backgroundColor: AppColors.background,
                  backgroundImage:
                      imageUrl is String && imageUrl.isNotEmpty
                          ? NetworkImage(imageUrl)
                          : null,
                  child: imageUrl is String && imageUrl.isNotEmpty
                      ? null
                      : const Icon(
                          Icons.person,
                          color: AppColors.secondaryText,
                        ),
                ),
              );
            },
          ),

          const SizedBox(width: 10),

          // SEARCH FIELD
          // SEARCH FIELD
Expanded(
  child: InkWell(
    borderRadius: BorderRadius.circular(25),
    onTap: () {
      showSearch(
        context: context,
        delegate: PeopleSearchDelegate(),
      );
    },
    child: Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.search,
            size: 20,
            color: AppColors.secondaryText,
          ),
          SizedBox(width: 8),
          Text(
            'Search',
            style: TextStyle(
              color: AppColors.secondaryText,
               fontSize: 13,

            ),
          ),
        ],
      ),
    ),
  ),
),

          // CREATE POST
          IconButton(
            tooltip: 'Create post',
            icon: const Icon(
              Icons.add_box_outlined,
              color: AppColors.primary,
            ),
            onPressed: () {
              context.push('/create-post');
            },
          ),

          // MESSAGES
          IconButton(
            tooltip: 'Messages',
            icon: const Icon(
              Icons.message_outlined,
              color: AppColors.primary,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MessagesView(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth >= 700;

        return Scaffold(
          backgroundColor: AppColors.background,

          appBar: _buildAppBar(),

          body: isWideScreen
              ? Row(
                  children: [
                    _buildNavigationRail(),
                    const VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: AppColors.border,
                    ),
                    Expanded(
                      child: _buildSelectedPage(),
                    ),
                  ],
                )
              : _buildSelectedPage(),

          // MOBILE BOTTOM NAVIGATION
          bottomNavigationBar: isWideScreen
              ? null
              : NavigationBar(
                  backgroundColor: AppColors.white,
                  indicatorColor: Colors.transparent,
                  elevation: 0,
                  selectedIndex: _selectedIndex,
                  labelBehavior:
                      NavigationDestinationLabelBehavior.alwaysShow,
                  labelTextStyle:
                      WidgetStateProperty.resolveWith<TextStyle>(
                    (states) {
                      if (states.contains(WidgetState.selected)) {
                        return const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        );
                      }

                      return const TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 11,
                      );
                    },
                  ),
                  onDestinationSelected: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  destinations: _buildDestinations(),
                ),
        );
      },
    );
  }
}

// COMMENTS BOTTOM SHEET
class PostCommentsSheet extends StatefulWidget {
  final String postId;
  final String postOwnerId;

  const PostCommentsSheet({
    super.key,
    required this.postId,
    required this.postOwnerId,
  });

  @override
  State<PostCommentsSheet> createState() => _PostCommentsSheetState();
}

class _PostCommentsSheetState extends State<PostCommentsSheet> {
  final TextEditingController _commentController =
      TextEditingController();

  bool _isSending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // DELETE COMMENT
  Future<void> _deleteComment(String commentId) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.white,
          title: const Text('Delete Comment?'),
          content: const Text(
            'Are you sure you want to delete this comment?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.secondaryText),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('Posts')
          .doc(widget.postId)
          .collection('Comments')
          .doc(commentId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment deleted successfully.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to delete comment: $e'),
          ),
        );
      }
    }
  }

  // ADD COMMENT TO FIRESTORE
  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    final currentUser = FirebaseAuth.instance.currentUser;

    if (text.isEmpty || currentUser == null) return;

    setState(() {
      _isSending = true;
    });

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(currentUser.uid)
          .get();

      final userData = userDoc.data() ?? {};

      await FirebaseFirestore.instance
          .collection('Posts')
          .doc(widget.postId)
          .collection('Comments')
          .add({
        'userId': currentUser.uid,
        'authorName': userData['name'] ?? 'User',
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _commentController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to add comment: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    final canDeleteAnyComment =
        currentUserId != null &&
        currentUserId == widget.postOwnerId;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: screenHeight * 0.75,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: screenWidth >= 700 ? 650 : double.infinity,
            ),
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Comments',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),

                  const Divider(
                    height: 1,
                    color: AppColors.border,
                  ),

                  Expanded(
                    child: StreamBuilder<
                        QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('Posts')
                          .doc(widget.postId)
                          .collection('Comments')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Center(
                            child: Text(
                              'Unable to load comments.',
                              style: TextStyle(
                                color: AppColors.error,
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

                        final comments = snapshot.data?.docs ?? [];

                        if (comments.isEmpty) {
                          return const Center(
                            child: Text(
                              'No comments yet. Be the first!',
                              style: TextStyle(
                                color: AppColors.secondaryText,
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: comments.length,
                          itemBuilder: (context, index) {
                            final commentDocument = comments[index];
                            final comment = commentDocument.data();

                            final commentUserId =
                                comment['userId'] ?? '';

                            final isMyComment =
                                currentUserId != null &&
                                commentUserId == currentUserId;

                            final canDelete =
                                isMyComment || canDeleteAnyComment;

                            return ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: AppColors.background,
                                child: Icon(
                                  Icons.person,
                                  color: AppColors.secondaryText,
                                ),
                              ),

                              title: Text(
                                comment['authorName'] ?? 'User',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryText,
                                ),
                              ),

                              subtitle: Text(
                                comment['text'] ?? '',
                                style: const TextStyle(
                                  color: AppColors.secondaryText,
                                ),
                              ),

                              // DELETE ONLY YOUR COMMENT
                              // OR COMMENTS ON YOUR OWN POST
                              trailing: canDelete
                                  ? IconButton(
                                      tooltip: 'Delete comment',
                                      onPressed: () {
                                        _deleteComment(
                                          commentDocument.id,
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: AppColors.error,
                                      ),
                                    )
                                  : null,
                            );
                          },
                        );
                      },
                    ),
                  ),

                  const Divider(
                    height: 1,
                    color: AppColors.border,
                  ),

                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            minLines: 1,
                            maxLines: 3,
                            decoration: InputDecoration(
                              hintText: 'Write a comment...',
                              filled: true,
                              fillColor: AppColors.white,
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
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
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        IconButton(
                          onPressed: _isSending ? null : _sendComment,
                          tooltip: 'Send comment',
                          icon: _isSending
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: AppColors.primary,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.send,
                                  color: AppColors.primary,
                                ),
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
    );
  }
}
// ========================================
// PEOPLE SEARCH
// ========================================

class PeopleSearchDelegate extends SearchDelegate {
  @override
  String get searchFieldLabel => 'Search people';

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _showUsers(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isEmpty) {
      return const Center(
        child: Text('Search for people by name'),
      );
    }

    return _showUsers(context);
  }

  Widget _showUsers(BuildContext context) {
    final searchText = query.trim().toLowerCase();

    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('Users')
          .get(),

      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Unable to search users: ${snapshot.error}',
            ),
          );
        }

        final allUsers = snapshot.data?.docs ?? [];

        // CASE-INSENSITIVE SEARCH
        final users = allUsers.where((document) {
          final name = (document.data()['name'] ?? '')
              .toString()
              .toLowerCase();

          return name.contains(searchText);
        }).toList();

        if (users.isEmpty) {
          return const Center(
            child: Text('No people found'),
          );
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final userDocument = users[index];
            final userData = userDocument.data();

            final name = userData['name'] ?? 'User';
            final email = userData['email'] ?? '';
            final imageUrl = userData['profileImageUrl'] ?? '';

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.background,
                backgroundImage:
                    imageUrl is String && imageUrl.isNotEmpty
                        ? NetworkImage(imageUrl)
                        : null,
                child: imageUrl is String && imageUrl.isNotEmpty
                    ? null
                    : const Icon(
                        Icons.person,
                        color: AppColors.primary,
                      ),
              ),

              title: Text(
                name.toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                ),
              ),

              subtitle: Text(
                email.toString(),
                style: const TextStyle(
                  color: AppColors.secondaryText,
                ),
              ),

              // OPEN USER PROFILE
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.secondaryText,
              ),

              onTap: () {
                final router = GoRouter.of(context);

                close(context, null);

                router.push('/user-profile/${userDocument.id}');
              },
            );
          },
        );
      },
    );
  }
}