import 'package:flutter/material.dart';

import '../../models/offer_model.dart';
import '../../models/restaurant_model.dart';
import '../../services/firestore_service.dart';
import '../../utils/theme.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              const Text(
                'Offers Management',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              FilledButton.icon(
                onPressed: () => _showAddOfferDialog(context, firestore),
                icon: const Icon(Icons.add),
                label: const Text('Global Offer Config'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Search
          TextField(
            decoration: InputDecoration(
              hintText: 'Search offers by title...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onChanged: (value) =>
                setState(() => _searchQuery = value.toLowerCase()),
          ),
          const SizedBox(height: 24),

          // Offers List View
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: StreamBuilder<List<OfferModel>>(
                stream: firestore.getAllOffers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  var offers = snapshot.data ?? [];

                  if (_searchQuery.isNotEmpty) {
                    offers = offers
                        .where(
                          (o) => o.title.toLowerCase().contains(_searchQuery),
                        )
                        .toList();
                  }

                  if (offers.isEmpty) {
                    return const Center(
                      child: Text(
                        'No active offers found.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: offers.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final offer = offers[index];
                      // Fetch restaurant name async, but for UI simplicity we might just show the required fields
                      // In a real app we'd join this data in the ViewModel or backend
                      return FutureBuilder<RestaurantModel?>(
                        future: firestore.getRestaurant(offer.restaurantId),
                        builder: (context, restSnap) {
                          final storeName =
                              restSnap.data?.name ?? 'Unknown Store';
                          return ListTile(
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Color(offer.color ?? 0xFFE0E0E0),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.local_offer,
                                color: Colors.white,
                              ),
                            ),
                            title: Row(
                              children: [
                                Text(
                                  offer.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (!offer.isActive) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'INACTIVE',
                                      style: TextStyle(
                                        color: AppColors.error,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Text(
                              '$storeName • \$${offer.bundlePrice.toStringAsFixed(2)}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: AppColors.error,
                              ),
                              onPressed: () =>
                                  _deleteOffer(context, offer.id, firestore),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteOffer(
    BuildContext context,
    String offerId,
    FirestoreService firestore,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Offer?'),
        content: const Text(
          'This will permanently remove the offer from the system.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await firestore.deleteOffer(offerId);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Offer deleted')));
      }
    }
  }

  void _showAddOfferDialog(BuildContext context, FirestoreService firestore) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Global Offer Config'),
        content: const Text(
          'This feature allows admins to create a site-wide promotion. To create store-specific offers, log in as a store owner or manage that specific store via the Stores Management tab.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }
}
