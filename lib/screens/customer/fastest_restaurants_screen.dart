import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/restaurant_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/theme.dart';
import 'home_screen.dart'; // To access FeaturedItemCard

class FastestRestaurantsScreen extends StatelessWidget {
  const FastestRestaurantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final restProv = context.watch<RestaurantProvider>();
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    // 1. Sort open restaurants by distance + prep time
    final openRestaurants = restProv.restaurants
        .where((r) => r.isOpen)
        .toList();

    openRestaurants.sort((a, b) {
      double timeA = a.estimatedDeliveryMin.toDouble();
      double timeB = b.estimatedDeliveryMin.toDouble();

      if (user?.latitude != null && user?.longitude != null) {
        if (a.latitude != 0 && a.longitude != 0) {
          final distA = Geolocator.distanceBetween(
            user!.latitude!,
            user.longitude!,
            a.latitude,
            a.longitude,
          );
          timeA += (distA / 400);
        }
        if (b.latitude != 0 && b.longitude != 0) {
          final distB = Geolocator.distanceBetween(
            user!.latitude!,
            user.longitude!,
            b.latitude,
            b.longitude,
          );
          timeB += (distB / 400);
        }
      }
      return timeA.compareTo(timeB);
    });

    // 2. Map sorted restaurants to their featured items
    final fastestRestaurantIds = openRestaurants.map((r) => r.id).toSet();

    final fastItems = restProv.featuredItems
        .where((item) => fastestRestaurantIds.contains(item.restaurantId))
        .toList();

    fastItems.sort((a, b) {
      final indexA = openRestaurants.indexWhere((r) => r.id == a.restaurantId);
      final indexB = openRestaurants.indexWhere((r) => r.id == b.restaurantId);
      return indexA.compareTo(indexB);
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Fastest Items Near You')),
      body: fastItems.isEmpty
          ? const Center(
              child: Text(
                'No fast items available right now',
                style: TextStyle(color: AppColors.textHint, fontSize: 16),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75, // Adjust to fit FeaturedItemCard well
              ),
              itemCount: fastItems.length,
              itemBuilder: (context, index) {
                final item = fastItems[index];
                return FeaturedItemCard(item: item);
              },
            ),
    );
  }
}
