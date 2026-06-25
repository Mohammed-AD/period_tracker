import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:bloom_cycle/models/user_settings.dart';
import 'package:bloom_cycle/services/cycle_repository.dart';
import 'package:bloom_cycle/services/profile_image_service.dart';
import 'package:bloom_cycle/theme/app_theme.dart';
import 'package:bloom_cycle/screens/lock/change_pin_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late UserSettings _settings;
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  String? _photoPath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _settings = CycleRepository.getSettings();
    _nameController = TextEditingController(text: _settings.userName ?? '');
    _ageController = TextEditingController(text: _settings.age?.toString() ?? '');
    _photoPath = _settings.profileImagePath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _openPhotoSheet() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: AppColors.primary),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
              if (!kIsWeb)
                ListTile(
                  leading: Icon(Icons.photo_camera_outlined, color: AppColors.primary),
                  title: const Text('Take a photo'),
                  onTap: () => Navigator.pop(ctx, 'camera'),
                ),
              if (_photoPath != null && _photoPath!.isNotEmpty)
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded, color: AppColors.concern),
                  title: Text('Remove photo', style: TextStyle(color: AppColors.concern)),
                  onTap: () => Navigator.pop(ctx, 'remove'),
                ),
            ],
          ),
        ),
      ),
    );

    // IMPORTANT: `choice == null` means the sheet was dismissed (tapped
    // outside / swiped down) without the user choosing anything. That
    // must be a strict no-op — it must NOT be treated as "remove photo".
    if (choice == null) return;

    if (choice == 'remove') {
      await _removePhoto();
    } else if (choice == 'gallery') {
      await _pickAndSave(ImageSource.gallery);
    } else if (choice == 'camera') {
      await _pickAndSave(ImageSource.camera);
    }
  }

  Future<void> _pickAndSave(ImageSource source) async {
    final picked = await ProfileImageService.pickFromSource(source);
    if (picked == null) return; // user backed out of the native picker

    final newPath = await ProfileImageService.saveLocally(picked, previousPath: _photoPath);
    if (newPath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save that photo — please try again.')),
        );
      }
      return;
    }
    setState(() => _photoPath = newPath);
  }

  Future<void> _removePhoto() async {
    final old = _photoPath;
    setState(() => _photoPath = null);
    await ProfileImageService.deletePhoto(old);
  }

  Future<void> _save() async {
    final ageText = _ageController.text.trim();
    int? age;
    if (ageText.isNotEmpty) {
      age = int.tryParse(ageText);
      if (age == null || age < 9 || age > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid age between 9 and 100')),
        );
        return;
      }
    }

    setState(() => _saving = true);
    _settings.userName = _nameController.text.trim().isEmpty ? null : _nameController.text.trim();
    _settings.age = age;
    _settings.profileImagePath = _photoPath;
    await CycleRepository.saveSettings(_settings);
    setState(() => _saving = false);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _openChangePinScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChangePinScreen()),
    );
  }

  Widget _buildChangePinTile() {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _openChangePinScreen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_reset_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Change PIN',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('Update your 4-digit app lock PIN',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  ImageProvider? _avatarImage() {
    if (_photoPath == null || _photoPath!.isEmpty) return null;
    if (kIsWeb) return NetworkImage(_photoPath!);
    return FileImage(File(_photoPath!));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Center(
            child: GestureDetector(
              onTap: _openPhotoSheet,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: AppColors.primaryLight,
                    backgroundImage: _avatarImage(),
                    child: _avatarImage() == null
                        ? Icon(Icons.person_rounded, color: AppColors.primary, size: 44)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.background, width: 2),
                      ),
                      child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: _openPhotoSheet,
              child: Text(
                _photoPath == null || _photoPath!.isEmpty ? 'Add photo' : 'Change photo',
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Name', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(hintText: 'Your name'),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 20),
          Text('Age', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _ageController,
            decoration: const InputDecoration(hintText: 'Optional'),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 8),
          Text(
            'Your age helps tailor cycle insights. Stored only on this device.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),
          Divider(color: AppColors.divider),
          const SizedBox(height: 16),
          Text('Security', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          _buildChangePinTile(),
        ],
      ),
    );
  }
}
