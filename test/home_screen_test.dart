import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/screens/customer/home_screen.dart';
import 'package:flutter_application_1/providers/auth_provider.dart';
import 'package:flutter_application_1/providers/restaurant_provider.dart';
import 'package:flutter_application_1/providers/cart_provider.dart';
import 'package:flutter_application_1/models/user_model.dart';
import 'package:flutter_application_1/models/restaurant_model.dart';
import 'package:flutter_application_1/models/menu_item_model.dart';
import 'package:flutter_application_1/models/offer_model.dart';

// Stub providers to avoid Firebase
class MockAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  UserModel? get user => UserModel(
    uid: '123',
    email: 'test@test.com',
    name: 'Test User',
    role: 'customer',
  );
  @override
  bool get isLoading => false;
  @override
  bool get isLoggedIn => true;
  @override
  String get userRole => 'customer';
  @override
  String? get error => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockRestaurantProvider extends ChangeNotifier
    implements RestaurantProvider {
  @override
  List<RestaurantModel> get restaurants => [
    RestaurantModel(
      id: 'r1',
      name: 'Test Brand',
      imageUrl: '',
      rating: 4.5,
      categories: ['Italian'],
      ownerId: 'o1',
    ),
  ];
  @override
  List<MenuItemModel> get featuredItems => [
    MenuItemModel(id: 'm1', restaurantId: 'r1', name: 'Pizza', price: 10.0),
  ];
  @override
  List<OfferModel> get allOffers => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockCartProvider extends ChangeNotifier implements CartProvider {
  @override
  int get itemCount => 0;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('Home Screen links are functional', (WidgetTester tester) async {
    final mockAuth = MockAuthProvider();
    final mockRest = MockRestaurantProvider();
    final mockCart = MockCartProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
          ChangeNotifierProvider<RestaurantProvider>.value(value: mockRest),
          ChangeNotifierProvider<CartProvider>.value(value: mockCart),
        ],
        child: const MaterialApp(home: CustomerHomeScreen()),
      ),
    );

    // Verify Brands render (at least one, as it appears in Brands and Featured list)
    expect(find.text('Test Brand'), findsAtLeastNWidgets(1));

    // Verify Search bar is clickable
    expect(find.text('Search stores, dishes, products'), findsOneWidget);

    // Verify Profile icon exists
    expect(find.byIcon(Icons.person_outline), findsOneWidget);

    // Verify Featured Item renders
    expect(find.text('Pizza'), findsOneWidget);
  });
}
