import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

void main() {
  final imageBytes = File('assets/icon/logo_red.jpg').readAsBytesSync();
  final originalImage = img.decodeImage(imageBytes);

  if (originalImage == null) {
    print('Failed to decode image');
    return;
  }

  // Calculate crop dimensions (60% of original)
  final targetWidth = (originalImage.width * 0.6).round();
  final targetHeight = (originalImage.height * 0.6).round();
  final startX = ((originalImage.width - targetWidth) / 2).round();
  final startY = ((originalImage.height - targetHeight) / 2).round();

  // Crop the image
  final croppedImage = img.copyCrop(
    originalImage,
    x: startX,
    y: startY,
    width: targetWidth,
    height: targetHeight,
  );

  // Save the cropped image
  final croppedBytes = img.encodeJpg(croppedImage);
  File('assets/icon/logo_red_cropped.jpg').writeAsBytesSync(croppedBytes);

  print('Cropped image saved successfully');
}
