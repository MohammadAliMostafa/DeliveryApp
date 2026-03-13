import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/restaurant_model.dart';
import '../../providers/restaurant_provider.dart';
import '../../utils/theme.dart';
import '../../utils/helpers.dart';
import 'restaurant_detail_screen.dart';
import 'store_detail_screen.dart';

class AllOffersScreen extends StatelessWidget {
  const AllOffersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final restaurantProv = context.watch<RestaurantProvider>();
    final allOffers = restaurantProv.allOffers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Special Offers'),
        backgroundColor: AppColors.background,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: allOffers.isEmpty
          ? const Center(
              child: Text(
                'No offers available right now.',
                style: TextStyle(color: AppColors.textHint, fontSize: 16),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // 2 columns for mobile
                childAspectRatio: 0.75, // Taller cards
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: allOffers.length,
              itemBuilder: (context, index) {
                final offer = allOffers[index];
                final restaurant = restaurantProv.restaurants.firstWhere(
                  (r) => r.id == offer.restaurantId,
                  orElse: () => RestaurantModel(
                    id: '',
                    name: 'Unknown Restaurant',
                    imageUrl: '',
                    rating: 0,
                    categories: [],
                    ownerId: '',
                  ),
                );

                // Use custom color or fallback to default orange
                final cardColor = offer.color != null
                    ? Color(offer.color!)
                    : const Color(0xFFFF6B35);

                // Compute luminance to determine text color (white for dark backgrounds, dark grey for light)
                final isDarkBackground = cardColor.computeLuminance() < 0.5;
                final textColor = isDarkBackground
                    ? Colors.white
                    : Colors.black87;
                final subTextColor = isDarkBackground
                    ? Colors.white70
                    : Colors.black54;

                return GestureDetector(
                  onTap: () {
                    if (restaurant.id.isNotEmpty) {
                      restaurantProv.selectRestaurant(restaurant);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              restaurant.businessType == 'restaurant'
                              ? RestaurantDetailScreen(
                                  highlightOfferId: offer.id,
                                )
                              : StoreDetailScreen(highlightOfferId: offer.id),
                        ),
                      );
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: cardColor.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Decorative background pattern
                        Positioned(
                          right: -20,
                          top: -20,
                          child: Icon(
                            Icons.local_offer,
                            size: 100,
                            color: isDarkBackground
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Offer Image
                            Expanded(
                              flex: 5,
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(20),
                                      topRight: Radius.circular(20),
                                    ),
                                    child: offer.imageUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: offer.imageUrl,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) => Container(
                                              color: Colors.white.withValues(
                                                alpha: 0.2,
                                              ),
                                            ),
                                            errorWidget: (_, __, ___) =>
                                                Container(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.2),
                                                  child: const Icon(
                                                    Icons.restaurant,
                                                    color: Colors.white54,
                                                  ),
                                                ),
                                          )
                                        : Container(
                                            color: Colors.white.withValues(
                                              alpha: 0.1,
                                            ),
                                            width: double.infinity,
                                            child: const Icon(
                                              Icons.restaurant,
                                              color: Colors.white54,
                                              size: 40,
                                            ),
                                          ),
                                  ),
                                  if (offer.hasDiscount)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.1,
                                              ),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          '-${offer.discountPercentage}%',
                                          style: TextStyle(
                                            color: cardColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Content
                            Expanded(
                              flex: 4,
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Restaurant Name
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isDarkBackground
                                                  ? Colors.black.withValues(
                                                      alpha: 0.2,
                                                    )
                                                  : Colors.white.withValues(
                                                      alpha: 0.3,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              restaurant.name,
                                              style: TextStyle(
                                                color: textColor,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          // Title
                                          Text(
                                            offer.title,
                                            style: TextStyle(
                                              color: textColor,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                              height: 1.1,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (offer.itemNames.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              offer.itemNames.join(', '),
                                              style: TextStyle(
                                                color: subTextColor,
                                                fontSize: 10,
                                                fontStyle: FontStyle.italic,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // Price
                                    if (offer.hasDiscount)
                                      Text(
                                        Helpers.formatPrice(
                                          offer.originalPrice,
                                        ),
                                        style: TextStyle(
                                          decoration:
                                              TextDecoration.lineThrough,
                                          color: subTextColor,
                                          fontSize: 11,
                                        ),
                                      ),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDarkBackground
                                            ? Colors.white
                                            : Colors.black87,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        Helpers.formatPrice(offer.bundlePrice),
                                        style: TextStyle(
                                          color: isDarkBackground
                                              ? cardColor
                                              : Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
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
