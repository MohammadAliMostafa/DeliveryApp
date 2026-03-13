# Project Context: Porter

Porter is a multi-role food delivery application built with Flutter and Firebase. It supports four distinct user roles: **Customer**, **Driver**, **Restaurant**, and **Admin**.

## 🚀 Core Technologies

- **Frontend**: [Flutter](https://flutter.dev/) (SDK ^3.11.0)
- **Backend/Database**: [Firebase](https://firebase.google.com/) (Core, Auth, Cloud Firestore, Storage, Messaging)
- **State Management**: [Provider](https://pub.dev/packages/provider)
- **Navigation**: [GoRouter](https://pub.dev/packages/go_router) / Manual Routing via Shells
- **Maps & Location**: Google Maps Flutter, Geolocator, Flutter Map
- **UI Components**: Cached Network Image, Shimmer, Flutter Rating Bar, Badges
- **Local Notifications**: Flutter Local Notifications

## 🏗️ Architecture & Patterns

### State Management
The app uses the `Provider` pattern for state management. Key providers located in `lib/providers/`:
- `AuthProvider`: Manages user authentication state, roles, and profiles.
- `CartProvider`: Handles the customer's shopping cart.
- `OrderProvider`: Manages order creation and status tracking.
- `RestaurantProvider`: Handles restaurant-specific data and management.

### Routing & User Flows
The application uses a "Shell" architecture. After authentication, `RoleWrapper` (`lib/screens/auth/role_wrapper.dart`) determines which shell to load based on the user's role:
- `CustomerShell`: Main interface for customers (Browsing, Ordering, Cart).
- `DriverShell`: Interface for drivers (Order Pickup, Delivery, Earnings).
- `RestaurantShell`: Interface for restaurant owners (Menu Management, Order Fulfillment).
- `AdminShell`: Interface for system administrators (User Approval, Platform Monitoring).

### Data Models
Models are located in `lib/models/` and represent the core data structures:
- `UserModel`: User profiles and roles.
- `RestaurantModel`: Restaurant details, menus, and operating hours.
- `OrderModel`: Order details, status, and tracking information.
- `CartModel`: Temporary cart items.

## 📂 Directory Structure

```text
lib/
├── main.dart           # Application entry point & Provider initialization
├── firebase_options.dart # Firebase configuration
├── models/             # Data structures
├── providers/          # Business logic and state management
├── screens/            # UI organized by role
│   ├── admin/
│   ├── auth/           # Login, Register, Role Wrapper
│   ├── customer/
│   ├── driver/
│   ├── restaurant/
│   └── shared/          # Reusable screens (e.g., Map Picker)
├── services/           # External API/Service integrations (Firebase, Notifications)
├── utils/              # Constants, Themes, Helpers
└── widgets/            # Reusable UI components
```

## 🛠️ Getting Started

1.  **Dependencies**: Run `flutter pub get` to install all required packages.
2.  **Firebase**: Ensure `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are correctly placed if you're not using the generated `firebase_options.dart`.
3.  **Environment**: The project requires Flutter SDK `^3.11.0`.

## 📍 Key Files for Reference

- [main.dart](file:///c:/flutter/New%20folder/flutter_application_1/lib/main.dart) - App Entry
- [pubspec.yaml](file:///c:/flutter/New%20folder/flutter_application_1/pubspec.yaml) - Dependencies
- [role_wrapper.dart](file:///c:/flutter/New%20folder/flutter_application_1/lib/screens/auth/role_wrapper.dart) - Role Switching Logic
- [auth_provider.dart](file:///c:/flutter/New%20folder/flutter_application_1/lib/providers/auth_provider.dart) - Core Auth Logic
