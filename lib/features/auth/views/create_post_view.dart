
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../services/cloudinary_service.dart';

class CreatePostView extends StatefulWidget {
  const CreatePostView({super.key});

  @override
  State<CreatePostView> createState() => _CreatePostViewState();
}

class _CreatePostViewState extends State<CreatePostView> {
  final TextEditingController _postController =
      TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();
  final CloudinaryService _cloudinaryService = CloudinaryService();

  Uint8List? _selectedImageBytes;
  XFile? _selectedImage;

  bool _isPickingImage = false;
  bool _isPublishing = false;

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  // Select image from gallery
  Future<void> _pickImage() async {
    if (_isPickingImage || _isPublishing) return;

    setState(() {
      _isPickingImage = true;
    });

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 1200,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();

        if (!mounted) return;

        setState(() {
          _selectedImage = image;
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to select image: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  // Remove selected image
  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
    });
  }

  // Publish post
  Future<void> _publishPost() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login first'),
        ),
      );
      return;
    }

    final content = _postController.text.trim();

    if (content.isEmpty && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write something or add a photo'),
        ),
      );
      return;
    }

    setState(() {
      _isPublishing = true;
    });

    try {
      final userDocument = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .get();

      final userData = userDocument.data() ?? {};

      String imageUrl = '';

      // Upload selected image to Cloudinary
      if (_selectedImage != null) {
        imageUrl = await _cloudinaryService.uploadProfileImage(
          _selectedImage!,
        );
      }

      // Save post in Firestore
      await FirebaseFirestore.instance.collection('Posts').add({
        'userId': user.uid,
        'authorName': userData['name'] ?? 'User',
        'authorImageUrl': userData['profileImageUrl'] ?? '',
        'content': content,
        'imageUrl': imageUrl,
        'likes': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post published successfully!'),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to publish post: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPublishing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: const Text(
          'Create Post',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.primaryText,
          ),
        ),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.primaryText,
        elevation: 0,
        surfaceTintColor: AppColors.white,

        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isPublishing ? null : _publishPost,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
              child: _isPublishing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Text(
                      'Post',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),

      body: user == null
          ? const Center(
              child: Text('Please login first'),
            )
          : FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: FirebaseFirestore.instance
                  .collection('Users')
                  .doc(user.uid)
                  .get(),

              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Unable to load profile: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.error,
                      ),
                    ),
                  );
                }

                final userData = snapshot.data?.data() ?? {};

                final name = userData['name'] ?? 'User';
                final imageUrl =
                    userData['profileImageUrl'] ?? '';

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isWideScreen =
                        constraints.maxWidth >= 700;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),

                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isWideScreen ? 650 : 600,
                          ),

                          child: Card(
                            color: AppColors.white,
                            elevation: 0,
                            margin: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),

                            child: Padding(
                              padding: const EdgeInsets.all(18),

                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  // USER DETAILS
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 25,
                                        backgroundColor:
                                            AppColors.background,
                                        backgroundImage:
                                            imageUrl is String &&
                                                    imageUrl.isNotEmpty
                                                ? NetworkImage(imageUrl)
                                                : null,
                                        child: imageUrl is String &&
                                                imageUrl.isNotEmpty
                                            ? null
                                            : const Icon(
                                                Icons.person,
                                                color: AppColors
                                                    .secondaryText,
                                              ),
                                      ),

                                      const SizedBox(width: 12),

                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name.toString(),
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight:
                                                    FontWeight.bold,
                                                color: AppColors
                                                    .primaryText,
                                              ),
                                            ),

                                            const SizedBox(height: 3),

                                            const Text(
                                              'Share with your network',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors
                                                    .secondaryText,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 22),

                                  // POST TEXT FIELD
                                  TextField(
                                    controller: _postController,
                                    enabled: !_isPublishing,
                                    minLines: 5,
                                    maxLines: 12,
                                    maxLength: 2000,

                                    style: const TextStyle(
                                      fontSize: 16,
                                      height: 1.5,
                                      color: AppColors.primaryText,
                                    ),

                                    decoration: InputDecoration(
                                      hintText:
                                          'What would you like to talk about?',
                                      hintStyle: const TextStyle(
                                        color: AppColors.secondaryText,
                                      ),
                                      filled: true,
                                      fillColor: AppColors.white,
                                      contentPadding:
                                          const EdgeInsets.all(14),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      enabledBorder:
                                          OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      focusedBorder:
                                          OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                          color: AppColors.primary,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // IMAGE PREVIEW
                                  if (_selectedImageBytes != null) ...[
                                    Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Image.memory(
                                            _selectedImageBytes!,
                                            width: double.infinity,
                                            height: 260,
                                            fit: BoxFit.contain,
                                          ),
                                        ),

                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: IconButton(
                                            onPressed: _removeImage,
                                            tooltip: 'Remove image',
                                            icon: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                            ),
                                            style: IconButton.styleFrom(
                                              backgroundColor:
                                                  Colors.black54,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 16),
                                  ],

                                  const Divider(
                                    color: AppColors.border,
                                  ),

                                  const SizedBox(height: 10),

                                  // ADD PHOTO BUTTON
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed:
                                              _isPickingImage ||
                                                      _isPublishing
                                                  ? null
                                                  : _pickImage,

                                          icon: _isPickingImage
                                              ? const SizedBox(
                                                  height: 18,
                                                  width: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: AppColors
                                                        .primary,
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.image_outlined,
                                                ),

                                          label: Text(
                                            _isPickingImage
                                                ? 'Opening gallery...'
                                                : _selectedImage == null
                                                    ? 'Add a photo'
                                                    : 'Change photo',
                                          ),

                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                AppColors.primary,
                                            side: const BorderSide(
                                              color: AppColors.primary,
                                            ),
                                            padding:
                                                const EdgeInsets.symmetric(
                                              vertical: 13,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(9),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 16),

                                  // PUBLISH BUTTON
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _isPublishing
                                          ? null
                                          : _publishPost,

                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AppColors.primary,
                                        foregroundColor:
                                            AppColors.white,
                                        padding:
                                            const EdgeInsets.symmetric(
                                          vertical: 15,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(25),
                                        ),
                                      ),

                                      child: _isPublishing
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text(
                                              'Publish Post',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight:
                                                    FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
