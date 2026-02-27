import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _user;
  bool _isLoading = true;
  String? _error;
  StreamSubscription<User?>? _authSub;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;
  String? get error => _error;
  String get userRole => _user?.role ?? '';

  AuthProvider() {
    _init();
  }

  void _init() {
    _authSub = _authService.authStateChanges.listen((firebaseUser) async {
      if (firebaseUser != null) {
        try {
          _user = await _authService.getUserProfile(firebaseUser.uid);
          _error = null;
        } catch (e) {
          _user = null;
          _error = e.toString();
        }
      } else {
        _user = null;
      }
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
    required String role,
    String phone = '',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.register(
        email: email,
        password: password,
        name: name,
        role: role,
        phone: phone,
      );
    } on FirebaseAuthException catch (e) {
      _error = _mapAuthError(e.code);
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> signIn({required String email, required String password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.signIn(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      _error = _mapAuthError(e.code);
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _authService.signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      _error = _mapAuthError(e.code);
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> resetPassword(String email) async {
    _error = null;
    notifyListeners();

    try {
      await _authService.resetPassword(email);
    } on FirebaseAuthException catch (e) {
      _error = _mapAuthError(e.code);
    } catch (e) {
      _error = e.toString();
    }

    notifyListeners();
  }

  Future<void> signOut() async {
    // If driver is online, set them offline before signing out
    // Only set offline if they don't have an active order locking them in
    if (_user != null &&
        _user!.role == 'driver' &&
        _user!.driverStatus != 'idle' &&
        _user!.currentOrderId == null) {
      try {
        await _authService.updateUserField(_user!.uid, {
          'driverStatus': 'idle',
        });
      } catch (_) {
        // Best-effort; proceed with sign-out regardless
      }
    }
    await _authService.signOut();
    _user = null;
    notifyListeners();
  }

  Future<void> updateProfile(UserModel updatedUser) async {
    await _authService.updateProfile(updatedUser);
    _user = updatedUser;
    notifyListeners();
  }

  Future<void> toggleFavoriteRestaurant(String restaurantId) async {
    if (_user == null) return;

    final updatedFavorites = List<String>.from(_user!.favoriteRestaurantIds);
    if (updatedFavorites.contains(restaurantId)) {
      updatedFavorites.remove(restaurantId);
    } else {
      updatedFavorites.add(restaurantId);
    }

    final updatedUser = _user!.copyWith(
      favoriteRestaurantIds: updatedFavorites,
    );
    await updateProfile(updatedUser);
  }

  Future<void> toggleFavoriteMenuItem(String itemId) async {
    if (_user == null) return;

    final updatedFavorites = List<String>.from(_user!.favoriteMenuItemIds);
    if (updatedFavorites.contains(itemId)) {
      updatedFavorites.remove(itemId);
    } else {
      updatedFavorites.add(itemId);
    }

    final updatedUser = _user!.copyWith(favoriteMenuItemIds: updatedFavorites);
    await updateProfile(updatedUser);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      default:
        return 'Authentication error: $code';
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
