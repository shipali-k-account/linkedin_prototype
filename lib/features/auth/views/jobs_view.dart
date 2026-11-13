
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/theme/app_colors.dart';

class JobsView extends StatefulWidget {
  const JobsView({super.key});

  @override
  State<JobsView> createState() => _JobsViewState();
}

class _JobsViewState extends State<JobsView> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Apply for a job.
  Future<void> _applyForJob(
    String jobId,
    Map<String, dynamic> job,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }

    final applicationId = '${user.uid}_$jobId';

    final applicationRef =
        _firestore.collection('Applications').doc(applicationId);

    try {
      await _firestore.runTransaction((transaction) async {
        final existing = await transaction.get(applicationRef);

        if (existing.exists) {
          throw Exception('Already applied');
        }

        transaction.set(applicationRef, {
          'userId': user.uid,
          'jobId': jobId,
          'company': job['company'],
          'role': job['role'],
          'salary': job['salary'],
          'appliedAt': FieldValue.serverTimestamp(),
          'status': 'Applied',
        });
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Application submitted successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final message = e.toString().contains('Already applied')
          ? 'You have already applied for this job.'
          : 'Unable to apply. Please try again.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('Jobs').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Unable to load jobs. Please try again.'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            );
          }

          final jobs = snapshot.data?.docs ?? [];

          if (jobs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.work_outline,
                    size: 55,
                    color: AppColors.secondaryText,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No jobs available',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 700;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(
                      horizontal: isWide ? 24 : 12,
                      vertical: 16,
                    ),
                    itemCount: jobs.length,
                    itemBuilder: (context, index) {
                      final document = jobs[index];
                      final job = document.data();
                      final jobId = document.id;

                      final user = FirebaseAuth.instance.currentUser;

                      if (user == null) {
                        return _buildJobCard(
                          jobId,
                          job,
                          false,
                          false,
                        );
                      }

                      final applicationId = '${user.uid}_$jobId';

                      return StreamBuilder<
                          DocumentSnapshot<Map<String, dynamic>>>(
                        stream: _firestore
                            .collection('Applications')
                            .doc(applicationId)
                            .snapshots(),
                        builder: (context, applicationSnapshot) {
                          if (applicationSnapshot.hasError) {
                            return _buildJobCard(
                              jobId,
                              job,
                              false,
                              false,
                            );
                          }

                          final applied =
                              applicationSnapshot.data?.exists ?? false;

                          final loading =
                              applicationSnapshot.connectionState ==
                                  ConnectionState.waiting;

                          return _buildJobCard(
                            jobId,
                            job,
                            applied,
                            loading,
                          );
                        },
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildJobCard(
    String jobId,
    Map<String, dynamic> job,
    bool applied,
    bool loading,
  ) {
    final company = job['company']?.toString() ?? 'Company';
    final role = job['role']?.toString() ?? 'Job Role';
    final salary = job['salary']?.toString() ?? 'Not specified';
    final description =
        job['description']?.toString() ?? 'No description available';
    final logo = job['logo']?.toString() ?? 'C';

    return Card(
      color: AppColors.white,
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(
          color: AppColors.border,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Company and role
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                  child: Text(
                    logo,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        company,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        role,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Salary
            Row(
              children: [
                const Icon(
                  Icons.payments_outlined,
                  size: 18,
                  color: AppColors.success,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    salary,
                    style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Job description
            Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: AppColors.secondaryText,
              ),
            ),

            const SizedBox(height: 18),

            // Apply button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: applied || loading
                    ? null
                    : () => _applyForJob(jobId, job),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  disabledBackgroundColor: applied
                      ? AppColors.primary.withValues(alpha: 0.10)
                      : Colors.grey.shade300,
                  disabledForegroundColor:
                      applied ? AppColors.primary : Colors.grey.shade600,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : Text(
                        applied ? 'Applied' : 'Apply',
                        style: const TextStyle(
                          fontSize: 15,
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
