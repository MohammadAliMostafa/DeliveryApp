import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/application_model.dart';
import '../../models/restaurant_model.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';

class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _approveApplication(ApplicationModel app) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Application'),
        content: Text('Are you sure you want to approve ${app.userName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      if (app.requestedRole == UserRoles.restaurant) {
        // Create new restaurant
        final restaurantRef = _firestore
            .collection(FirestoreCollections.restaurants)
            .doc();
        final newRestaurant = RestaurantModel(
          id: restaurantRef.id,
          ownerId: app.userId,
          name: app.formData['storeName'] ?? 'Unknown Store',
          address: app.formData['storeAddress'] ?? '',
          phone: app.userPhone,
          businessType: app.formData['businessType'] ?? 'restaurant',
        );

        await restaurantRef.set(newRestaurant.toMap());
      }

      // Update user to approved and set correct role
      await _firestore
          .collection(FirestoreCollections.users)
          .doc(app.userId)
          .update({'isApproved': true, 'role': app.requestedRole});

      // Update application status
      await _firestore.collection('applications').doc(app.id).update({
        'status': 'approved',
      });

      if (mounted) {
        Helpers.showSnackBar(context, 'Application approved successfully');
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Error approving application: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _rejectApplication(ApplicationModel app) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Application'),
        content: Text('Are you sure you want to reject ${app.userName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await _firestore.collection('applications').doc(app.id).update({
        'status': 'rejected',
      });

      if (mounted) {
        Helpers.showSnackBar(context, 'Application rejected');
      }
    } catch (e) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Error rejecting application: $e',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pending Requests'), centerTitle: true),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('applications')
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading requests\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 80,
                    color: AppColors.textSecondary.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No pending requests',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final app = ApplicationModel.fromMap(data, docs[index].id);

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Role Badge + Name
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              app.userName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: app.requestedRole == UserRoles.driver
                                  ? Colors.blue.withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  app.requestedRole == UserRoles.driver
                                      ? Icons.delivery_dining
                                      : Icons.store,
                                  size: 16,
                                  color: app.requestedRole == UserRoles.driver
                                      ? Colors.blue
                                      : Colors.orange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  app.requestedRole.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: app.requestedRole == UserRoles.driver
                                        ? Colors.blue
                                        : Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      // Contact Info
                      Row(
                        children: [
                          const Icon(
                            Icons.email_outlined,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(app.userEmail),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            app.userPhone.isNotEmpty
                                ? app.userPhone
                                : 'No phone provided',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Form Data
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Application Details',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (app.requestedRole == UserRoles.driver) ...[
                              Text(
                                'Vehicle: ${app.formData['vehicleType'] ?? 'N/A'}',
                              ),
                              Text(
                                'License Plate: ${app.formData['licensePlate'] ?? 'N/A'}',
                              ),
                            ] else if (app.requestedRole ==
                                UserRoles.restaurant) ...[
                              Text(
                                'Store Name: ${app.formData['storeName'] ?? 'N/A'}',
                              ),
                              Text(
                                'Address: ${app.formData['storeAddress'] ?? 'N/A'}',
                              ),
                              Text(
                                'Type: ${app.formData['businessType'] ?? 'N/A'}',
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _rejectApplication(app),
                            icon: const Icon(
                              Icons.close,
                              color: AppColors.error,
                            ),
                            label: const Text('Reject'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () => _approveApplication(app),
                            icon: const Icon(Icons.check),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
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
