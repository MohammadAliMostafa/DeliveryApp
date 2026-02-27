import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload image bytes and return the download URL.
  /// [path] e.g. 'restaurants/{id}/icon.jpg'
  Future<String> uploadImageBytes(String path, Uint8List bytes) async {
    final ref = _storage.ref().child(path);
    final metadata = SettableMetadata(contentType: 'image/jpeg');
    await ref.putData(bytes, metadata);
    return await ref.getDownloadURL();
  }

  /// Delete an image at the given path.
  Future<void> deleteImage(String path) async {
    try {
      await _storage.ref().child(path).delete();
    } catch (_) {
      // Ignore if file doesn't exist
    }
  }
}
