
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/theme/app_colors.dart';

class SubscriptionView extends StatefulWidget {
  const SubscriptionView({super.key});

  @override
  State<SubscriptionView> createState() => _SubscriptionViewState();
}

class _SubscriptionViewState extends State<SubscriptionView> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _isLoading = false;

  String? get _userId => _auth.currentUser?.uid;

  // SELECT FREE PLAN
  Future<void> _selectFreePlan() async {
    if (_userId == null) {
      _showMessage('Please sign in first.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _db.collection('Subscriptions').doc(_userId).set({
        'userId': _userId,
        'planName': 'Free',
        'amount': 0,
        'status': 'active',
        'startDate': FieldValue.serverTimestamp(),
        'endDate': null,
        'isDemo': true,
      });

      if (!mounted) return;

      _showMessage('Free plan activated successfully!');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Unable to select plan: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // OPEN PREMIUM PAYMENT CONFIRMATION
  Future<void> _upgradeToPremium() async {
    if (_userId == null) {
      _showMessage('Please sign in first.');
      return;
    }

    final paymentResult = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text(
            'Premium Subscription',
            style: TextStyle(
              color: AppColors.primaryText,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Premium Subscription',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: AppColors.primaryText,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Amount: ₹499',
                style: TextStyle(
                  fontSize: 18,
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'This is a simulated payment. No real money will be charged.',
                style: TextStyle(
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Simulate Failure',
                style: TextStyle(color: AppColors.error),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
              ),
              child: const Text('Pay ₹499'),
            ),
          ],
        );
      },
    );

    if (paymentResult == null) return;

    await _saveDemoPayment(paymentResult);
  }

  // SAVE PAYMENT AND SUBSCRIPTION
  Future<void> _saveDemoPayment(bool isSuccessful) async {
    if (_userId == null) return;

    setState(() => _isLoading = true);

    try {
      final transactionRef = _db.collection('Transactions').doc();

      final batch = _db.batch();

      // SAVE TRANSACTION
      batch.set(transactionRef, {
        'userId': _userId,
        'transactionId': transactionRef.id,
        'planName': 'Premium',
        'amount': 499,
        'paymentStatus': isSuccessful ? 'success' : 'failed',
        'paymentMethod': 'Demo Payment',
        'isDemo': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (isSuccessful) {
        final subscriptionRef =
            _db.collection('Subscriptions').doc(_userId);

        batch.set(subscriptionRef, {
          'userId': _userId,
          'planName': 'Premium',
          'amount': 499,
          'status': 'active',
          'startDate': FieldValue.serverTimestamp(),
          'endDate': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 30)),
          ),
          'isDemo': true,
        });
      }

      await batch.commit();

      if (!mounted) return;

      if (isSuccessful) {
        _showMessage('Premium activated successfully!');
      } else {
        _showMessage(
          'Payment failed. Your current plan remains unchanged.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('Payment error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // SHOW MESSAGE
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // FEATURE LIST
  Widget _buildFeature(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle,
            color: AppColors.success,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // SUBSCRIPTION CARD
  Widget _buildPlanCard({
    required String name,
    required String price,
    required String duration,
    required List<String> features,
    required bool isPremium,
    required bool isCurrentPlan,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPremium ? AppColors.primary : AppColors.border,
          width: isPremium ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryText,
                  ),
                ),
              ),
              if (isPremium)
                const Chip(
                  label: Text('POPULAR'),
                  backgroundColor: Color(0xFFEAF3FC),
                  side: BorderSide.none,
                  labelStyle: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text(
                price,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  bottom: 5,
                  left: 5,
                ),
                child: Text(
                  duration,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
            ],
          ),

          const Divider(height: 28),

          ...features.map(_buildFeature),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading || isCurrentPlan
                  ? null
                  : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                disabledBackgroundColor: AppColors.primary.withValues(
                  alpha: 0.15,
                ),
                disabledForegroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
                elevation: 0,
              ),
              child: Text(
                isCurrentPlan
                    ? 'Current Plan'
                    : isPremium
                        ? 'Upgrade to Premium'
                        : 'Choose Free Plan',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userId == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Text(
            'Please sign in to continue.',
            style: TextStyle(
              color: AppColors.secondaryText,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Subscription Plans',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryText,
          ),
        ),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.primaryText,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _db
            .collection('Subscriptions')
            .doc(_userId)
            .snapshots(),
        builder: (context, snapshot) {
          final currentPlan =
              snapshot.data?.data()?['planName'] ?? 'Free';

          return Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWideScreen = constraints.maxWidth >= 850;

                  final horizontalPadding =
                      constraints.maxWidth >= 1100 ? 32.0 : 16.0;

                  final freeCard = _buildPlanCard(
                    name: 'Free Plan',
                    price: '₹0',
                    duration: '/ forever',
                    isPremium: false,
                    isCurrentPlan: currentPlan == 'Free',
                    features: [
                      'Create your professional profile',
                      'Connect with other users',
                      'Create and view posts',
                      'Apply for jobs',
                      'Send messages',
                    ],
                    onPressed: _selectFreePlan,
                  );

                  final premiumCard = _buildPlanCard(
                    name: 'Premium Plan',
                    price: '₹499',
                    duration: '/ month',
                    isPremium: true,
                    isCurrentPlan: currentPlan == 'Premium',
                    features: [
                      'All Free Plan features',
                      'Premium profile badge',
                      'Advanced job insights',
                      'Profile visitor insights',
                      'Priority profile visibility',
                    ],
                    onPressed: _upgradeToPremium,
                  );

                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 22,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 1000,
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Choose Your Plan',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryText,
                              ),
                            ),

                            const SizedBox(height: 8),

                            const Text(
                              'Choose the plan that suits your professional journey.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.secondaryText,
                                fontSize: 14,
                              ),
                            ),

                            const SizedBox(height: 22),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF3FC),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Your current plan: $currentPlan',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            if (isWideScreen)
                              Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: freeCard),
                                  const SizedBox(width: 20),
                                  Expanded(child: premiumCard),
                                ],
                              )
                            else
                              Column(
                                children: [
                                  freeCard,
                                  const SizedBox(height: 20),
                                  premiumCard,
                                ],
                              ),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              if (_isLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.12),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
