import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/firebase_provider.dart';
import '../../repositories/profile_repository.dart';
import '../../validators/profile_validators.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  Uint8List? _savedPhoto;
  Uint8List? _selectedPhoto;
  bool _removePhoto = false;
  bool _loadingPhoto = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(firebaseAuthProvider).currentUser;
    _name = TextEditingController(
      text: user?.displayName ?? user?.email?.split('@').first ?? '',
    );
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    try {
      final photo =
          await ref.read(profileRepositoryProvider).readCurrentPhoto();
      if (mounted) setState(() => _savedPhoto = photo);
    } catch (_) {
      if (mounted) setState(() => _savedPhoto = null);
    } finally {
      if (mounted) setState(() => _loadingPhoto = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Foto profil',
            extensions: ['jpg', 'jpeg', 'png', 'webp'],
          ),
        ],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final result = validateProfilePhoto(bytes);
      if (result != PhotoValidationResult.valid) {
        if (mounted) _showMessage(photoValidationMessage(result));
        return;
      }
      if (!mounted) return;
      setState(() {
        _selectedPhoto = bytes;
        _removePhoto = false;
      });
    } catch (_) {
      if (mounted) {
        _showMessage('Foto tidak dapat dibaca. Silakan pilih ulang.');
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            name: _name.text,
            photoBytes: _selectedPhoto,
            removePhoto: _removePhoto,
          );
      if (!mounted) return;
      ref.invalidate(profilePhotoProvider);
      ref.invalidate(authStateProvider);
      Navigator.pop(context);
    } on InvalidProfilePhotoException {
      _showMessage('Foto profil tidak valid. Silakan pilih file gambar lain.');
    } on ProfilePhotoSaveException {
      _showMessage('Nama berhasil diperbarui, tetapi foto gagal disimpan.');
    } on FirebaseAuthException {
      _showMessage('Nama gagal diperbarui. Periksa koneksi lalu coba lagi.');
    } catch (_) {
      _showMessage('Profil gagal diperbarui. Silakan coba kembali.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final photo = _selectedPhoto ?? (_removePhoto ? null : _savedPhoto);
    final user = ref.watch(authStateProvider).asData?.value ??
        ref.watch(firebaseAuthProvider).currentUser;
    final initial =
        _name.text.trim().isEmpty ? 'M' : _name.text.trim()[0].toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profil')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                color: colors.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ProfileAvatar(
                          photo: photo,
                          initial: initial,
                          isLoading: _loadingPhoto,
                          isSaving: _saving,
                          onChoosePhoto: _choosePhoto,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Foto profil disimpan di perangkat ini. Maksimal 1 MB.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: colors.onSurfaceVariant, fontSize: 12),
                        ),
                        if (photo != null) ...[
                          const SizedBox(height: 8),
                          _RemovePhotoButton(
                            isSaving: _saving,
                            onRemove: () => setState(() {
                              _selectedPhoto = null;
                              _removePhoto = true;
                            }),
                          ),
                        ],
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          maxLength: maxProfileNameLength,
                          decoration: const InputDecoration(
                            labelText: 'Nama tampilan',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: validateProfileName,
                        ),
                        const SizedBox(height: 5),
                        InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Email akun',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          child: Text(user?.email ?? 'Email tidak tersedia'),
                        ),
                        const SizedBox(height: 22),
                        _SaveButton(
                          isSaving: _saving,
                          onSave: _save,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets yang diekstrak dari build() untuk memisahkan tanggung jawab UI
// ---------------------------------------------------------------------------

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.photo,
    required this.initial,
    required this.isLoading,
    required this.isSaving,
    required this.onChoosePhoto,
  });

  final Uint8List? photo;
  final String initial;
  final bool isLoading;
  final bool isSaving;
  final VoidCallback onChoosePhoto;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          CircleAvatar(
            radius: 52,
            backgroundColor: colors.primaryContainer,
            backgroundImage: photo == null ? null : MemoryImage(photo!),
            child: isLoading && photo == null
                ? const CircularProgressIndicator()
                : photo == null
                    ? Text(initial,
                        style: TextStyle(
                            color: colors.primary,
                            fontSize: 36,
                            fontWeight: FontWeight.w800))
                    : null,
          ),
          IconButton.filled(
            tooltip: 'Pilih foto profil',
            onPressed: isSaving ? null : onChoosePhoto,
            icon: const Icon(Icons.photo_camera_outlined),
          ),
        ],
      ),
    );
  }
}

class _RemovePhotoButton extends StatelessWidget {
  const _RemovePhotoButton({
    required this.isSaving,
    required this.onRemove,
  });

  final bool isSaving;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => TextButton.icon(
        onPressed: isSaving ? null : onRemove,
        icon: const Icon(Icons.delete_outline_rounded),
        label: const Text('Hapus foto profil'),
      );
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.isSaving,
    required this.onSave,
  });

  final bool isSaving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
        onPressed: isSaving ? null : onSave,
        icon: isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined),
        label: Text(isSaving ? 'Menyimpan...' : 'Simpan profil'),
      );
}
