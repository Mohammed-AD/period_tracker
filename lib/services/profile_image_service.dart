import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Outcome of a photo-picker interaction, used so the caller can tell
/// "user picked a new photo", "user explicitly chose remove", and
/// "user dismissed the sheet without choosing anything" apart — these
/// must NOT all be treated the same, or dismissing the sheet would wipe
/// an existing photo by mistake.
enum ProfileImagePickOutcome { picked, removed, cancelled }

class ProfileImagePickResult {
  final ProfileImagePickOutcome outcome;
  final String? path; // set only when outcome == picked
  const ProfileImagePickResult(this.outcome, {this.path});
}

/// Manages the user's local profile photo. The photo is copied into the
/// app's own documents directory (so it survives even if the original
/// gallery file is deleted) and only its on-device path is stored in
/// Hive (see UserSettings.profileImagePath). Nothing is ever uploaded.
class ProfileImageService {
  static final ImagePicker _picker = ImagePicker();

  static Future<XFile?> pickFromSource(ImageSource source) async {
    if (kIsWeb && source == ImageSource.camera) {
      // Camera capture works on web too via image_picker, but we keep
      // this simple — gallery/file picker covers the common case.
    }
    try {
      return await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
    } catch (_) {
      return null;
    }
  }

  /// Copies the picked file into permanent local app storage and
  /// returns the new path. Deletes any previous photo first.
  static Future<String?> saveLocally(XFile picked, {String? previousPath}) async {
    if (kIsWeb) {
      // No durable filesystem to copy into on web; just reuse the blob
      // path image_picker already gives us for the current session.
      return picked.path;
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ext = picked.path.split('.').last;
      final fileName = 'profile_photo_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final newPath = '${dir.path}/$fileName';
      await File(picked.path).copy(newPath);

      if (previousPath != null && previousPath.isNotEmpty && !kIsWeb) {
        await _deleteIfExists(previousPath);
      }
      return newPath;
    } catch (_) {
      return null;
    }
  }

  static Future<void> deletePhoto(String? path) async {
    if (path == null || path.isEmpty || kIsWeb) return;
    await _deleteIfExists(path);
  }

  static Future<void> _deleteIfExists(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Non-fatal — stale file left on disk is harmless.
    }
  }
}
