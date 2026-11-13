
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/theme/app_colors.dart';

class AddExperienceView extends StatefulWidget {
  const AddExperienceView({super.key});

  @override
  State<AddExperienceView> createState() => _AddExperienceViewState();
}

class _AddExperienceViewState extends State<AddExperienceView> {
  final _companyController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _locationController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _employmentType = 'Full-time';
  bool _currentlyWorking = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _companyController.dispose();
    _jobTitleController.dispose();
    _locationController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveExperience() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    if (_companyController.text.trim().isEmpty ||
        _jobTitleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter company name and job title'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final userRef = FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid);

      final userDocument = await userRef.get();

      final userData = userDocument.data() ?? {};

      final List<Map<String, dynamic>> experiences =
          (userData['experience'] as List<dynamic>? ?? [])
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();

      experiences.add({
        'company': _companyController.text.trim(),
        'jobTitle': _jobTitleController.text.trim(),
        'employmentType': _employmentType,
        'location': _locationController.text.trim(),
        'startDate': _startDateController.text.trim(),
        'endDate': _currentlyWorking
            ? 'Present'
            : _endDateController.text.trim(),
        'currentlyWorking': _currentlyWorking,
        'description': _descriptionController.text.trim(),
        'createdAt': Timestamp.now(),
      });

      await userRef.update({
        'experience': experiences,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Experience added successfully!'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save experience: $e')),
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
          'Add Experience',
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
              label: 'Job Title',
              controller: _jobTitleController,
              hint: 'Example: Software Developer Intern',
            ),

            _buildField(
              label: 'Company Name',
              controller: _companyController,
              hint: 'Enter company name',
            ),

            const Text(
              'Employment Type',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              initialValue: _employmentType,
              decoration: InputDecoration(
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
              items: const [
                DropdownMenuItem(
                  value: 'Full-time',
                  child: Text('Full-time'),
                ),
                DropdownMenuItem(
                  value: 'Part-time',
                  child: Text('Part-time'),
                ),
                DropdownMenuItem(
                  value: 'Internship',
                  child: Text('Internship'),
                ),
                DropdownMenuItem(
                  value: 'Freelance',
                  child: Text('Freelance'),
                ),
                DropdownMenuItem(
                  value: 'Contract',
                  child: Text('Contract'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _employmentType = value;
                  });
                }
              },
            ),

            const SizedBox(height: 18),

            _buildField(
              label: 'Location',
              controller: _locationController,
              hint: 'Example: Mangaluru, Karnataka',
            ),

            _buildField(
              label: 'Start Date',
              controller: _startDateController,
              hint: 'Example: June 2026',
            ),

            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.primary,
              checkColor: AppColors.white,
              title: const Text(
                'I currently work here',
                style: TextStyle(
                  color: AppColors.primaryText,
                ),
              ),
              value: _currentlyWorking,
              onChanged: (value) {
                setState(() {
                  _currentlyWorking = value ?? false;
                  if (_currentlyWorking) {
                    _endDateController.clear();
                  }
                });
              },
            ),

            if (!_currentlyWorking)
              _buildField(
                label: 'End Date',
                controller: _endDateController,
                hint: 'Example: November 2026',
              ),

            _buildField(
              label: 'Description',
              controller: _descriptionController,
              hint: 'Describe your responsibilities and work...',
              maxLines: 4,
            ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveExperience,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    vertical: 15,
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
                        'Save Experience',
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
