import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/theme/app_colors.dart';

class PublicProfileView extends StatelessWidget {
  final String userId;

  const PublicProfileView({
    super.key,
    required this.userId,
  });

  List<Map<String, dynamic>> _convertList(dynamic value) {
    if (value is! List) return [];

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget content,
  }) {
    return Card(
      color: AppColors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppColors.white,
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('Users')
            .doc(userId)
            .get(),
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
              child: Text('Unable to load this profile.'),
            );
          }

          final data = snapshot.data!.data() ?? {};

          final name = (data['name'] ?? 'User').toString();
          final headline = (data['headline'] ?? '').toString();
          final about = (data['about'] ?? '').toString();
          final email = (data['email'] ?? '').toString();
          final imageUrl = (data['profileImageUrl'] ?? '').toString();

          final skills = (data['skills'] as List?)
                  ?.map((item) => item.toString())
                  .toList() ??
              [];

          final education = _convertList(data['education']);
          final experience = _convertList(data['experience']);

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // PROFILE HEADER
                  Card(
                    color: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 52,
                            backgroundColor: AppColors.background,
                            backgroundImage: imageUrl.isNotEmpty
                                ? NetworkImage(imageUrl)
                                : null,
                            child: imageUrl.isEmpty
                                ? const Icon(
                                    Icons.person,
                                    size: 55,
                                    color: AppColors.primary,
                                  )
                                : null,
                          ),
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
                                ? 'No professional headline added'
                                : headline,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.secondaryText,
                            ),
                          ),
                          if (email.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              email,
                              style: const TextStyle(
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ABOUT
                  _buildSection(
                    title: 'About',
                    icon: Icons.person_outline,
                    content: Text(
                      about.isEmpty
                          ? 'No information added yet.'
                          : about,
                      style: const TextStyle(
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),

                  // EDUCATION
                  _buildSection(
                    title: 'Education',
                    icon: Icons.school_outlined,
                    content: education.isEmpty
                        ? const Text('No education details added yet.')
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: education.map((item) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.school,
                                      color: AppColors.primary,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            (item['institution'] ?? '')
                                                .toString(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primaryText,
                                            ),
                                          ),
                                          Text(
                                            '${item['degree'] ?? ''} - ${item['fieldOfStudy'] ?? ''}',
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
                                              item['description'].toString(),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),

                  // EXPERIENCE
                  _buildSection(
                    title: 'Experience',
                    icon: Icons.work_outline,
                    content: experience.isEmpty
                        ? const Text('No work experience added yet.')
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: experience.map((item) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.business,
                                      color: AppColors.primary,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            (item['jobTitle'] ?? '')
                                                .toString(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primaryText,
                                            ),
                                          ),
                                          Text(
                                            (item['company'] ?? '').toString(),
                                          ),
                                          Text(
                                            (item['employmentType'] ?? '')
                                                .toString(),
                                          ),
                                          Text(
                                            (item['location'] ?? '').toString(),
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
                                            Text(
                                              item['description'].toString(),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),

                  // SKILLS
                  _buildSection(
                    title: 'Skills',
                    icon: Icons.star_outline,
                    content: skills.isEmpty
                        ? const Text('No skills added yet.')
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: skills.map((skill) {
                              return Chip(
                                label: Text(skill),
                              );
                            }).toList(),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}