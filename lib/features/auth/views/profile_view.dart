
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/cloudinary_service.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  final ImagePicker _imagePicker = ImagePicker();
  final CloudinaryService _cloudinaryService = CloudinaryService();

  late Future<DocumentSnapshot<Map<String, dynamic>>> _userFuture;

  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // Load user profile from Firestore
  void _loadProfile() {
    final user = FirebaseAuth.instance.currentUser!;

    _userFuture = _firestoreService.getDocument(
      'Users',
      user.uid,
    );
  }

  // Select and upload profile picture
  Future<void> _pickAndUploadProfileImage() async {
    try {
      final XFile? selectedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 800,
      );

      if (selectedImage == null) return;

      setState(() {
        _isUploadingImage = true;
      });

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      // Upload image to Cloudinary
      final imageUrl = await _cloudinaryService.uploadProfileImage(
        selectedImage,
      );

      // Save image URL in Firestore
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .update({
        'profileImageUrl': imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _loadProfile();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile picture updated successfully!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to upload image: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  // Open create or edit profile page
  Future<void> _openProfileForm({
    required String name,
    required String headline,
    required String about,
    required bool isEditing,
  }) async {
    final result = await context.push<bool>(
      '/edit-profile',
      extra: {
        'name': name,
        'headline': headline,
        'about': about,
        'isEditing': isEditing,
      },
    );

    if (result == true && mounted) {
      setState(() {
        _loadProfile();
      });
    }
  }

  // Logout
  Future<void> _logout() async {
    await _authService.logout();

    if (!mounted) return;

    context.go('/login');
  }

  // Reusable profile section
  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            content,
          ],
        ),
      ),
    );
  }

  // Profile picture widget
  Widget _buildProfileImage(String imageUrl) {
    return GestureDetector(
      onTap: _isUploadingImage
          ? null
          : _pickAndUploadProfileImage,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 52,
            backgroundColor: AppColors.border,
            backgroundImage: imageUrl.isNotEmpty
                ? NetworkImage(imageUrl)
                : null,
            child: imageUrl.isEmpty
                ? const Icon(
                    Icons.person,
                    size: 55,
                    color: AppColors.white,
                  )
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: CircleAvatar(
              radius: 17,
              backgroundColor: AppColors.primary,
              child: _isUploadingImage
                  ? const Padding(
                      padding: EdgeInsets.all(7),
                      child: CircularProgressIndicator(
                        color: AppColors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.camera_alt,
                      size: 18,
                      color: AppColors.white,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Profile'),
      ),

      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            );
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              !snapshot.data!.exists) {
            return const Center(
              child: Text(
                'Unable to load profile details',
                style: TextStyle(
                  color: AppColors.secondaryText,
                ),
              ),
            );
          }

          final userData = snapshot.data!.data()!;

          final name = userData['name'] ?? 'Your Name';

          final email = FirebaseAuth.instance.currentUser?.email
              ?? 'No email available';

          final headline = userData['headline'] ?? '';
          final about = userData['about'] ?? '';

          final imageUrl = userData['profileImageUrl'] ?? '';

          final isProfileCreated =
              userData['profileCompleted'] == true;

          final skills = List<String>.from(
            userData['skills'] ?? [],
          );

          final education = List<Map<String, dynamic>>.from(
            userData['education'] ?? [],
          );

          final experience = List<Map<String, dynamic>>.from(
            userData['experience'] ?? [],
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile header
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildProfileImage(imageUrl),

                        const SizedBox(height: 16),

                        Text(
                          name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryText,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          headline.isEmpty
                              ? 'Add your professional headline'
                              : headline,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.secondaryText,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          email,
                          style: const TextStyle(
                            color: AppColors.secondaryText,
                          ),
                        ),

                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          child: isProfileCreated
                              ? OutlinedButton.icon(
                                  onPressed: () {
                                    _openProfileForm(
                                      name: name,
                                      headline: headline,
                                      about: about,
                                      isEditing: true,
                                    );
                                  },
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Edit Profile'),
                                )
                              : ElevatedButton.icon(
                                  onPressed: () {
                                    _openProfileForm(
                                      name: name,
                                      headline: headline,
                                      about: about,
                                      isEditing: false,
                                    );
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Create Profile'),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // About section
                _buildSection(
                  title: 'About',
                  icon: Icons.person_outline,
                  content: Text(
                    about.isEmpty
                        ? 'Add information about yourself.'
                        : about,
                    style: const TextStyle(
                      color: AppColors.primaryText,
                    ),
                  ),
                ),

                // Education section
                _buildSection(
                  title: 'Education',
                  icon: Icons.school_outlined,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (education.isEmpty)
                        const Text(
                          'No education details added yet.',
                          style: TextStyle(
                            color: AppColors.secondaryText,
                          ),
                        ),

                      ...education.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.school,
                                color: AppColors.primary,
                                size: 30,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['institution'] ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: AppColors.primaryText,
                                      ),
                                    ),
                                    Text(
                                      '${item['degree'] ?? ''} - ${item['fieldOfStudy'] ?? ''}',
                                      style: const TextStyle(
                                        color: AppColors.primaryText,
                                      ),
                                    ),
                                    Text(
                                      '${item['startYear'] ?? ''} - ${item['endYear'] ?? ''}',
                                      style: const TextStyle(
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                    if ((item['description'] ?? '')
                                        .toString()
                                        .isNotEmpty)
                                      Text(
                                        item['description'],
                                        style: const TextStyle(
                                          color: AppColors.primaryText,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      const Divider(),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () async {
                            final result =
                                await context.push<bool>(
                              '/add-education',
                            );

                            if (result == true && mounted) {
                              setState(() {
                                _loadProfile();
                              });
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add education'),
                        ),
                      ),
                    ],
                  ),
                ),

                // Experience section
                _buildSection(
                  title: 'Experience',
                  icon: Icons.work_outline,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (experience.isEmpty)
                        const Text(
                          'No work experience added yet.',
                          style: TextStyle(
                            color: AppColors.secondaryText,
                          ),
                        ),

                      ...experience.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.business,
                                color: AppColors.primary,
                                size: 30,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['jobTitle'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryText,
                                      ),
                                    ),
                                    Text(
                                      item['company'] ?? '',
                                      style: const TextStyle(
                                        color: AppColors.primaryText,
                                      ),
                                    ),
                                    Text(
                                      item['employmentType'] ?? '',
                                      style: const TextStyle(
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                    Text(
                                      item['location'] ?? '',
                                      style: const TextStyle(
                                        color: AppColors.primaryText,
                                      ),
                                    ),
                                    Text(
                                      '${item['startDate'] ?? ''} - ${item['endDate'] ?? ''}',
                                      style: const TextStyle(
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                    if ((item['description'] ?? '')
                                        .toString()
                                        .isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 6,
                                        ),
                                        child: Text(
                                          item['description'],
                                          style: const TextStyle(
                                            color: AppColors.primaryText,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      const Divider(),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () async {
                            final result =
                                await context.push<bool>(
                              '/add-experience',
                            );

                            if (result == true && mounted) {
                              setState(() {
                                _loadProfile();
                              });
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add experience'),
                        ),
                      ),
                    ],
                  ),
                ),

                // Skills section
                _buildSection(
                  title: 'Skills',
                  icon: Icons.star_outline,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (skills.isEmpty)
                        const Text(
                          'No skills added yet.',
                          style: TextStyle(
                            color: AppColors.secondaryText,
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: skills.map((skill) {
                            return Chip(
                              label: Text(skill),
                            );
                          }).toList(),
                        ),

                      const SizedBox(height: 12),

                      TextButton.icon(
                        onPressed: () async {
                          final result =
                              await context.push<bool>(
                            '/add-skills',
                          );

                          if (result == true && mounted) {
                            setState(() {
                              _loadProfile();
                            });
                          }
                        },
                        icon: const Icon(Icons.edit),
                        label: Text(
                          skills.isEmpty
                              ? 'Add Skills'
                              : 'Edit Skills',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),

      // Logout button
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
