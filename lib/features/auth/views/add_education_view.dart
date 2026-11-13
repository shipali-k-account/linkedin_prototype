
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/theme/app_colors.dart';
import '../services/firestore_service.dart';

class AddEducationView extends StatefulWidget {
  const AddEducationView({super.key});

  @override
  State<AddEducationView> createState() => _AddEducationViewState();
}

class _AddEducationViewState extends State<AddEducationView> {
  final FirestoreService _firestoreService = FirestoreService();

  final _institutionController = TextEditingController();
  final _degreeController = TextEditingController();
  final _fieldController = TextEditingController();
  final _startYearController = TextEditingController();
  final _endYearController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _institutionController.dispose();
    _degreeController.dispose();
    _fieldController.dispose();
    _startYearController.dispose();
    _endYearController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveEducation() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    if (_institutionController.text.trim().isEmpty ||
        _degreeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your institution and degree'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final document = await _firestoreService.getDocument(
        'Users',
        user.uid,
      );

      final userData = document.data() ?? {};

      final List<Map<String, dynamic>> educationList =
          List<Map<String, dynamic>>.from(
        userData['education'] ?? [],
      );

      educationList.add({
        'institution': _institutionController.text.trim(),
        'degree': _degreeController.text.trim(),
        'fieldOfStudy': _fieldController.text.trim(),
        'startYear': _startYearController.text.trim(),
        'endYear': _endYearController.text.trim(),
        'description': _descriptionController.text.trim(),
        'createdAt': Timestamp.now(),
      });

      await _firestoreService.updateDocument(
        'Users',
        user.uid,
        {
          'education': educationList,
        },
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Education details added successfully!'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save education: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.primaryText,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 14,
            ),
            filled: true,
            fillColor: AppColors.white,
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
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Add Education',
          style: TextStyle(
            color: AppColors.primaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.primaryText,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildField(
              label: 'School / College / University',
              controller: _institutionController,
              hint: 'Enter institution name',
            ),
            _buildField(
              label: 'Degree',
              controller: _degreeController,
              hint: 'Example: Bachelor of Engineering',
            ),
            _buildField(
              label: 'Field of Study',
              controller: _fieldController,
              hint: 'Example: Artificial Intelligence and Machine Learning',
            ),
            _buildField(
              label: 'Start Year',
              controller: _startYearController,
              hint: 'Example: 2023',
              keyboardType: TextInputType.number,
            ),
            _buildField(
              label: 'End Year',
              controller: _endYearController,
              hint: 'Example: 2027 or Present',
            ),
            _buildField(
              label: 'Description',
              controller: _descriptionController,
              hint: 'Add details about your studies...',
              maxLines: 4,
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveEducation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 15),
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
                        'Save Education',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
