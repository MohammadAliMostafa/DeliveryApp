import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart'
    as gsin;
import '../models/user_model.dart';
import '../models/application_model.dart';
import '../utils/constants.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId:
        '201127488522-2oti854391nja6j6qa6mogb77chghdms.apps.googleusercontent.com',
  );

  final gsin.GoogleSignIn _googleSignInWindows = gsin.GoogleSignIn(
    params: gsin.GoogleSignInParams(
      clientId:
          '201127488522-4h6tkp6h0vfupjkvap5d1sdcdbeim9qr.apps.googleusercontent.com',
    ),
  );

  /// Current Firebase user
  User? get currentUser => _auth.currentUser;

  /// Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel> register({
    required String email,
    required String password,
    required String name,
    required String role,
    String phone = '',
    Map<String, dynamic>? formData,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final bool isApproved =
        role == UserRoles.customer || role == UserRoles.admin;

    final user = UserModel(
      uid: credential.user!.uid,
      name: name,
      email: email,
      role: role,
      phone: phone,
      isApproved: isApproved,
      driverStatus: role == UserRoles.driver ? DriverStatus.idle : null,
    );

    await _firestore
        .collection(FirestoreCollections.users)
        .doc(user.uid)
        .set(user.toMap());

    if (!isApproved) {
      final appRef = _firestore.collection('applications').doc();
      final application = ApplicationModel(
        id: appRef.id,
        userId: user.uid,
        userName: user.name,
        userEmail: user.email,
        userPhone: user.phone,
        requestedRole: role,
        status: 'pending',
        formData: formData ?? {},
      );
      await appRef.set(application.toMap());
    }

    return user;
  }

  /// Sign in with email and password
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    return await getUserProfile(credential.user!.uid);
  }

  /// Sign in with Google
  Future<UserModel> signInWithGoogle() async {
    String? accessToken;
    String? idToken;

    if (Platform.isWindows) {
      final credentials = await _googleSignInWindows.signIn();
      if (credentials == null) {
        throw Exception('Google Sign-In cancelled');
      }
      accessToken = credentials.accessToken;
      idToken = credentials.idToken;
    } else {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google Sign-In cancelled');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      accessToken = googleAuth.accessToken;
      idToken = googleAuth.idToken;
    }

    // Create a new credential
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: accessToken,
      idToken: idToken,
    );

    // Sign in to Firebase with the Google User Credential
    final UserCredential userCredential = await _auth.signInWithCredential(
      credential,
    );
    final User? user = userCredential.user;

    if (user == null) {
      throw Exception('Google Sign-In failed');
    }

    // Check if user exists in Firestore
    final doc = await _firestore
        .collection(FirestoreCollections.users)
        .doc(user.uid)
        .get();

    if (doc.exists) {
      return UserModel.fromMap(doc.data()!);
    } else {
      // Create new user if not exists
      final newUser = UserModel(
        uid: user.uid,
        name: user.displayName ?? 'User',
        email: user.email ?? '',
        role: UserRoles.customer, // Default role
        phone: user.phoneNumber ?? '',
        profileImageUrl: user.photoURL,
        driverStatus: null,
      );

      await _firestore
          .collection(FirestoreCollections.users)
          .doc(newUser.uid)
          .set(newUser.toMap());

      return newUser;
    }
  }

  /// Get user profile from Firestore
  Future<UserModel> getUserProfile(String uid) async {
    final doc = await _firestore
        .collection(FirestoreCollections.users)
        .doc(uid)
        .get();

    if (!doc.exists) {
      throw Exception('User profile not found');
    }

    return UserModel.fromMap(doc.data()!);
  }

  /// Get user role
  Future<String> getUserRole(String uid) async {
    final user = await getUserProfile(uid);
    return user.role;
  }

  /// Update user profile
  Future<void> updateProfile(UserModel user) async {
    await _firestore
        .collection(FirestoreCollections.users)
        .doc(user.uid)
        .update(user.toMap());
  }

  /// Update specific fields on a user document
  Future<void> updateUserField(String uid, Map<String, dynamic> fields) async {
    await _firestore
        .collection(FirestoreCollections.users)
        .doc(uid)
        .update(fields);
  }

  /// Sign out
  Future<void> signOut() async {
    final futures = <Future<dynamic>>[
      _auth.signOut(),
      _googleSignIn.signOut(),
    ];

    if (Platform.isWindows) {
      futures.add(_googleSignInWindows.signOut());
    }

    await Future.wait(futures);
  }

  /// Password reset
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
