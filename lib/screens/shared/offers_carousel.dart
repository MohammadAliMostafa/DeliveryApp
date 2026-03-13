import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/offer_model.dart';
import '../../models/restaurant_model.dart';
import '../../providers/restaurant_provider.dart';
import '../../utils/helpers.dart';
import '../customer/restaurant_detail_screen.dart';
import '../customer/store_detail_screen.dart';

class OffersCarousel extends StatelessWidget {
  final List<OfferModel> offers;
  final RestaurantProvider restaurantProv;

  const OffersCarousel({
    super.key,
    required this.offers,
    required this.restaurantProv,
  });

  @override
  Widget build(BuildContext context) {
    if (offers.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 190,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: offers.length > 5 ? 5 : offers.length,
        itemBuilder: (context, index) {
          final offer = offers[index];
          final restaurant = restaurantProv.restaurants.firstWhere(
            (r) => r.id == offer.restaurantId,
            orElse: () => RestaurantModel(
              id: '',
              name: 'Unknown',
              imageUrl: '',
              rating: 0,
              categories: [],
              ownerId: '',
            ),
          );

          // Use custom color or fallback
          final cardColor = offer.color != null
              ? Color(offer.color!)
              : const Color(0xFFFF6B35);

          final isDarkBackground = cardColor.computeLuminance() < 0.5;

          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              elevation: 4,
              shadowColor: Colors.black.withValues(alpha: 0.1),
              child: InkWell(
                onTap: () {
                  if (restaurant.id.isNotEmpty) {
                    restaurantProv.selectRestaurant(restaurant);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => restaurant.businessType == 'restaurant'
                            ? RestaurantDetailScreen(highlightOfferId: offer.id)
                            : StoreDetailScreen(highlightOfferId: offer.id),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 310,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Decorative background icon (subtle)
                      Positioned(
                        right: -10,
                        bottom: -10,
                        child: Icon(
                          Icons.local_offer,
                          size: 100,
                          color: cardColor.withValues(alpha: 0.04),
                        ),
                      ),
                      Row(
                        children: [
                          // Image Container
                          if (offer.imageUrl.isNotEmpty)
                            Container(
                              width: 120,
                              decoration: const BoxDecoration(
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                ),
                                child: CachedNetworkImage(
                                  imageUrl: offer.imageUrl,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    color: Colors.grey.shade100,
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    color: Colors.grey.shade100,
                                    child: const Icon(
                                      Icons.fastfood,
                                      color: Colors.black26,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // Details
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Store Badge (Accent Color)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: cardColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      restaurant.name,
                                      style: TextStyle(
                                        color: isDarkBackground
                                            ? Colors.white
                                            : Colors.black87,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    offer.title,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  if (offer.description.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        offer.description,
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  if (offer.itemNames.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text(
                                        '${offer.itemNames.length} items',
                                        style: const TextStyle(
                                          color: Colors.black54,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  const Spacer(),
                                  if (offer.hasDiscount) ...[
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          Helpers.formatPrice(
                                            offer.originalPrice,
                                          ),
                                          style: const TextStyle(
                                            decoration:
                                                TextDecoration.lineThrough,
                                            color: Colors.black38,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          Helpers.formatPrice(
                                            offer.bundlePrice,
                                          ),
                                          style: TextStyle(
                                            color: cardColor,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else
                                    Text(
                                      Helpers.formatPrice(offer.bundlePrice),
                                      style: TextStyle(
                                        color: cardColor,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
