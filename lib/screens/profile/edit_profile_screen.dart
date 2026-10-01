import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../repositories/profile_repository.dart';
import '../../services/report_photo_codec.dart';

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
    final user = FirebaseAuth.instance.currentUser;
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
      if (await file.length() > maxReportPhotoBytes) {
        if (mounted) _showMessage('Ukuran foto maksimal 1 MB.');
        return;
      }
      final bytes = await file.readAsBytes();
      final mimeType = detectReportPhotoMimeType(bytes);
      if (bytes.length > maxReportPhotoBytes || mimeType == null) {
        if (mounted) {
          _showMessage(
              'Pilih foto JPG, PNG, atau WebP yang valid, maksimal 1 MB.');
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        _selectedPhoto = bytes;
        _removePhoto = false;
      });
    } catch (_) {
      if (mounted)
        _showMessage('Foto tidak dapat dibaca. Silakan pilih ulang.');
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
    final user = FirebaseAuth.instance.currentUser;
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
                        Center(
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 52,
                                backgroundColor: colors.primaryContainer,
                                backgroundImage:
                                    photo == null ? null : MemoryImage(photo),
                                child: _loadingPhoto && photo == null
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
                                onPressed: _saving ? null : _choosePhoto,
                                icon: const Icon(Icons.photo_camera_outlined),
                              ),
                            ],
                          ),
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
                          TextButton.icon(
                            onPressed: _saving
                                ? null
                                : () => setState(() {
                                      _selectedPhoto = null;
                                      _removePhoto = true;
                                    }),
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('Hapus foto profil'),
                          ),
                        ],
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          maxLength: 80,
                          decoration: const InputDecoration(
                            labelText: 'Nama tampilan',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Nama tidak boleh kosong.';
                            }
                            if (value.trim().length > 80) {
                              return 'Nama maksimal 80 karakter.';
                            }
                            return null;
                          },
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
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save_outlined),
                          label:
                              Text(_saving ? 'Menyimpan...' : 'Simpan profil'),
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
