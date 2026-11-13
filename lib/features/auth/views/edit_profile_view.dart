
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';

class EditProfileView extends StatefulWidget {
  final String name;
  final String headline;
  final String about;
  final bool isEditing;

  const EditProfileView({
    super.key,
    required this.name,
    required this.headline,
    required this.about,
    required this.isEditing,
  });

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  late TextEditingController _nameController;
  late TextEditingController _headlineController;
  late TextEditingController _aboutController;
  late TextEditingController _skillsController;

  List<Map<String, TextEditingController>> _education = [];
  List<Map<String, TextEditingController>> _experience = [];

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.name);
    _headlineController = TextEditingController(text: widget.headline);
    _aboutController = TextEditingController(text: widget.about);
    _skillsController = TextEditingController();

    _loadExistingDetails();
  }

  // CREATE EDUCATION CONTROLLERS
  Map<String, TextEditingController> _createEducation(
    Map<String, dynamic> data,
  ) {
    return {
      'institution': TextEditingController(
        text: data['institution']?.toString() ?? '',
      ),
      'degree': TextEditingController(
        text: data['degree']?.toString() ?? '',
      ),
      'fieldOfStudy': TextEditingController(
        text: data['fieldOfStudy']?.toString() ?? '',
      ),
      'startYear': TextEditingController(
        text: data['startYear']?.toString() ?? '',
      ),
      'endYear': TextEditingController(
        text: data['endYear']?.toString() ?? '',
      ),
      'description': TextEditingController(
        text: data['description']?.toString() ?? '',
      ),
    };
  }

  // CREATE EXPERIENCE CONTROLLERS
  Map<String, TextEditingController> _createExperience(
    Map<String, dynamic> data,
  ) {
    return {
      'jobTitle': TextEditingController(
        text: data['jobTitle']?.toString() ?? '',
      ),
      'company': TextEditingController(
        text: data['company']?.toString() ?? '',
      ),
      'employmentType': TextEditingController(
        text: data['employmentType']?.toString() ?? '',
      ),
      'location': TextEditingController(
        text: data['location']?.toString() ?? '',
      ),
      'startDate': TextEditingController(
        text: data['startDate']?.toString() ?? '',
      ),
      'endDate': TextEditingController(
        text: data['endDate']?.toString() ?? '',
      ),
      'description': TextEditingController(
        text: data['description']?.toString() ?? '',
      ),
    };
  }

  // LOAD EXISTING PROFILE DETAILS
  Future<void> _loadExistingDetails() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final document =
          await _db.collection('Users').doc(user.uid).get();

      final data = document.data() ?? {};

      final educationData =
          List<Map<String, dynamic>>.from(data['education'] ?? []);

      final experienceData =
          List<Map<String, dynamic>>.from(data['experience'] ?? []);

      final skillsData = List<String>.from(data['skills'] ?? []);

      if (!mounted) return;

      setState(() {
        _skillsController.text = skillsData.join(', ');

        _education = educationData
            .map((item) => _createEducation(item))
            .toList();

        _experience = experienceData
            .map((item) => _createExperience(item))
            .toList();

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      _showMessage('Unable to load profile details: $e');
    }
  }

  // DISPOSE ENTRY CONTROLLERS
  void _disposeEntries(
    List<Map<String, TextEditingController>> entries,
  ) {
    for (final entry in entries) {
      for (final controller in entry.values) {
        controller.dispose();
      }
    }
  }

  // ADD EDUCATION
  void _addEducation() {
    setState(() {
      _education.add(_createEducation({}));
    });
  }

  // ADD EXPERIENCE
  void _addExperience() {
    setState(() {
      _experience.add(_createExperience({}));
    });
  }

  // REMOVE EDUCATION
  void _removeEducation(int index) {
    setState(() {
      for (final controller in _education[index].values) {
        controller.dispose();
      }
      _education.removeAt(index);
    });
  }

  // REMOVE EXPERIENCE
  void _removeExperience(int index) {
    setState(() {
      for (final controller in _experience[index].values) {
        controller.dispose();
      }
      _experience.removeAt(index);
    });
  }

  // GET EDUCATION DATA
  List<Map<String, dynamic>> _getEducationData() {
    return _education.map((item) {
      return {
        for (final entry in item.entries)
          entry.key: entry.value.text.trim(),
      };
    }).where((item) {
      return item.values.any(
        (value) => value.toString().isNotEmpty,
      );
    }).toList();
  }

  // GET EXPERIENCE DATA
  List<Map<String, dynamic>> _getExperienceData() {
    return _experience.map((item) {
      return {
        for (final entry in item.entries)
          entry.key: entry.value.text.trim(),
      };
    }).where((item) {
      return item.values.any(
        (value) => value.toString().isNotEmpty,
      );
    }).toList();
  }

  // SAVE COMPLETE PROFILE
  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('Please sign in first.');
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      _showMessage('Please enter your full name.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final skills = _skillsController.text
          .split(',')
          .map((skill) => skill.trim())
          .where((skill) => skill.isNotEmpty)
          .toList();

      await _db.collection('Users').doc(user.uid).set({
        'name': _nameController.text.trim(),
        'headline': _headlineController.text.trim(),
        'about': _aboutController.text.trim(),
        'skills': skills,
        'education': _getEducationData(),
        'experience': _getExperienceData(),
        'profileCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      _showMessage('Complete profile updated successfully!');
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Unable to save profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // SHOW MESSAGE
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // SECTION HEADING
  Widget _buildSectionHeading(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryText,
        ),
      ),
    );
  }

  // REUSABLE TEXT FIELD
  Widget _buildField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: AppColors.white,
          labelStyle: const TextStyle(
            color: AppColors.primary,
          ),
          hintStyle: const TextStyle(
            color: AppColors.secondaryText,
            fontSize: 14,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 15,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: AppColors.border,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: AppColors.primary,
              width: 1.5,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          alignLabelWithHint: maxLines > 1,
        ),
      ),
    );
  }

  // COMMON ENTRY CARD
  Widget _buildEntryCard({
    required String title,
    required VoidCallback onDelete,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              IconButton(
                onPressed: onDelete,
                tooltip: 'Delete',
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  // ADD BUTTON
  Widget _buildAddButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(
        Icons.add_circle_outline,
        color: AppColors.primary,
      ),
      label: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // EDUCATION SECTION
  Widget _buildEducationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeading('Education'),
            _buildAddButton(
              label: 'Add',
              onPressed: _addEducation,
            ),
          ],
        ),
        if (_education.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Text(
              'No education details added yet.',
              style: TextStyle(
                color: AppColors.secondaryText,
              ),
            ),
          ),
        ...List.generate(_education.length, (index) {
          final item = _education[index];

          return _buildEntryCard(
            title: 'Education ${index + 1}',
            onDelete: () => _removeEducation(index),
            children: [
              _buildField('Institution', item['institution']!),
              _buildField('Degree', item['degree']!),
              _buildField('Field of Study', item['fieldOfStudy']!),
              _buildField('Start Year', item['startYear']!),
              _buildField('End Year', item['endYear']!),
              _buildField(
                'Description',
                item['description']!,
                maxLines: 3,
              ),
            ],
          );
        }),
      ],
    );
  }

  // EXPERIENCE SECTION
  Widget _buildExperienceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeading('Experience'),
            _buildAddButton(
              label: 'Add',
              onPressed: _addExperience,
            ),
          ],
        ),
        if (_experience.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Text(
              'No experience details added yet.',
              style: TextStyle(
                color: AppColors.secondaryText,
              ),
            ),
          ),
        ...List.generate(_experience.length, (index) {
          final item = _experience[index];

          return _buildEntryCard(
            title: 'Experience ${index + 1}',
            onDelete: () => _removeExperience(index),
            children: [
              _buildField('Job Title', item['jobTitle']!),
              _buildField('Company', item['company']!),
              _buildField('Employment Type', item['employmentType']!),
              _buildField('Location', item['location']!),
              _buildField('Start Date', item['startDate']!),
              _buildField(
                'End Date',
                item['endDate']!,
                hint: 'Present or end date',
              ),
              _buildField(
                'Description',
                item['description']!,
                maxLines: 3,
              ),
            ],
          );
        }),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _headlineController.dispose();
    _aboutController.dispose();
    _skillsController.dispose();

    _disposeEntries(_education);
    _disposeEntries(_experience);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Edit Profile' : 'Create Your Profile',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.primaryText,
          ),
        ),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.primaryText,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PERSONAL INFORMATION
                  _buildSectionHeading('Personal Information'),

                  _buildField(
                    'Full Name',
                    _nameController,
                  ),

                  _buildField(
                    'Professional Headline',
                    _headlineController,
                    hint: 'Example: AIML Student | Flutter Developer',
                  ),

                  _buildField(
                    'About',
                    _aboutController,
                    maxLines: 5,
                    hint: 'Write something about yourself...',
                  ),

                  const SizedBox(height: 14),

                  // SKILLS
                  _buildSectionHeading('Skills'),

                  _buildField(
                    'Skills',
                    _skillsController,
                    maxLines: 3,
                    hint: 'Example: Flutter, Dart, Python, SQL',
                  ),

                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Separate each skill using a comma.',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // EDUCATION
                  _buildEducationSection(),

                  const SizedBox(height: 20),

                  // EXPERIENCE
                  _buildExperienceSection(),

                  const SizedBox(height: 24),

                  // SAVE BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                color: AppColors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Save Complete Profile',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
