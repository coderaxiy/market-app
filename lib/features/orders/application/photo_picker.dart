import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

enum PhotoSource { camera, gallery }

class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}

/// Where return photos come from. A seam so tests don't need a phone.
abstract class PhotoPicker {
  /// Null when the buyer backs out.
  Future<PickedPhoto?> pick(PhotoSource source);
}

/// Photos are re-encoded as JPEG and scaled down before upload: the backend takes JPEG,
/// PNG and WebP only (no HEIC), and a 12 MP photo is wasted bytes (it keeps 2048 px).
class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    final file = await _picker.pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );
    if (file == null) return null;
    return PickedPhoto(bytes: await file.readAsBytes(), filename: file.name);
  }
}

final photoPickerProvider = Provider<PhotoPicker>(
  (ref) => ImagePickerPhotoPicker(),
);
