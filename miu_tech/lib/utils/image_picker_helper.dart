import 'dart:io';
import 'package:image_picker/image_picker.dart';

Future<File?> pickImageFromGallery() async {
  final picker = ImagePicker();
  final XFile? image = await picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 80,
  );

  if (image == null) return null;
  return File(image.path);
}