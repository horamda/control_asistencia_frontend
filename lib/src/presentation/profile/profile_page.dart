import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/image/profile_photo_cache.dart';
import '../../core/network/mobile_api_client.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.apiClient, required this.token});

  final MobileApiClient apiClient;
  final String token;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();
  final _passwordActualController = TextEditingController();
  final _passwordNuevaController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _loading = true;
  bool _savingProfile = false;
  bool _uploadingPhoto = false;
  bool _deletingPhoto = false;
  bool _savingPassword = false;
  String? _error;
  EmployeeProfile? _profile;
  XFile? _selectedPhoto;
  int? _selectedPhotoBytes;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _telefonoController.dispose();
    _direccionController.dispose();
    _passwordActualController.dispose();
    _passwordNuevaController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final previousPhotoUrl = (_profile?.foto ?? '').trim();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await widget.apiClient.getMe(token: widget.token);
      final nextPhotoUrl = (profile.foto ?? '').trim();
      if (previousPhotoUrl != nextPhotoUrl) {
        await ProfilePhotoCache.evict(previousPhotoUrl);
        ProfilePhotoCache.bump();
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = profile;
        _telefonoController.text = profile.telefono ?? '';
        _direccionController.text = profile.direccion ?? '';
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Error inesperado al consultar perfil.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_savingProfile) {
      return;
    }
    setState(() {
      _savingProfile = true;
    });
    try {
      final updated = await widget.apiClient.updatePerfil(
        token: widget.token,
        telefono: _telefonoController.text.trim(),
        direccion: _direccionController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _telefonoController.text = updated.telefono ?? '';
        _direccionController.text = updated.direccion ?? '';
      });
      _showMessage('Perfil actualizado correctamente.');
      await _loadProfile();
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      _showMessage(e.message, isError: true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('Error inesperado al actualizar perfil.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _savingProfile = false;
        });
      }
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 72,
        maxWidth: 960,
        maxHeight: 960,
        requestFullMetadata: false,
      );
      if (picked == null || !mounted) {
        return;
      }
      final size = await picked.length();
      setState(() {
        _selectedPhoto = picked;
        _selectedPhotoBytes = size;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('No se pudo abrir la camara/galeria.', isError: true);
    }
  }

  Future<void> _uploadSelectedPhoto() async {
    final selected = _selectedPhoto;
    final previousPhotoUrl = (_profile?.foto ?? '').trim();
    if (selected == null) {
      _showMessage('Selecciona una foto antes de subir.', isError: true);
      return;
    }
    if (_uploadingPhoto) {
      return;
    }

    setState(() {
      _uploadingPhoto = true;
    });
    try {
      final updated = await widget.apiClient.updatePerfilConFotoFile(
        token: widget.token,
        fotoPath: selected.path,
        telefono: _telefonoController.text.trim(),
        direccion: _direccionController.text.trim(),
      );
      await ProfilePhotoCache.evict(previousPhotoUrl);
      ProfilePhotoCache.bump();
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedPhoto = null;
        _selectedPhotoBytes = null;
        _telefonoController.text = updated.telefono ?? '';
        _direccionController.text = updated.direccion ?? '';
      });
      _showMessage('Foto de perfil actualizada.');
      await _loadProfile();
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      _showMessage(e.message, isError: true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('Error inesperado al subir foto.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _uploadingPhoto = false;
        });
      }
    }
  }

  Future<void> _deletePhoto() async {
    final previousPhotoUrl = (_profile?.foto ?? '').trim();
    if (_deletingPhoto) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar foto'),
          content: const Text('Se eliminara tu foto de perfil actual.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }

    setState(() {
      _deletingPhoto = true;
    });
    try {
      await widget.apiClient.deleteFotoPerfil(token: widget.token);
      await ProfilePhotoCache.evict(previousPhotoUrl);
      ProfilePhotoCache.bump();
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedPhoto = null;
        _selectedPhotoBytes = null;
      });
      _showMessage('Foto eliminada.');
      await _loadProfile();
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      _showMessage(e.message, isError: true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('Error inesperado al eliminar foto.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _deletingPhoto = false;
        });
      }
    }
  }

  Future<void> _savePassword() async {
    if (_savingPassword) {
      return;
    }
    final current = _passwordActualController.text;
    final next = _passwordNuevaController.text;
    if (current.trim().isEmpty || next.trim().isEmpty) {
      _showMessage('Completa password actual y nueva.', isError: true);
      return;
    }
    if (next.trim().length < 8) {
      _showMessage(
        'La nueva password debe tener al menos 8 caracteres.',
        isError: true,
      );
      return;
    }

    setState(() {
      _savingPassword = true;
    });
    try {
      await widget.apiClient.updatePassword(
        token: widget.token,
        passwordActual: current,
        passwordNueva: next,
      );
      if (!mounted) {
        return;
      }
      _passwordActualController.clear();
      _passwordNuevaController.clear();
      _showMessage('Password actualizada correctamente.');
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      _showMessage(e.message, isError: true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('Error inesperado al actualizar password.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _savingPassword = false;
        });
      }
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  String _fmtBytes(int? value) {
    if (value == null || value <= 0) {
      return '-';
    }
    if (value >= 1024 * 1024) {
      return '${(value / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(value / 1024).toStringAsFixed(0)} KB';
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final remoteFoto = ProfilePhotoCache.withRevision(
      (profile?.foto ?? '').trim(),
    );
    final hasRemoteFoto = remoteFoto.isNotEmpty;
    final busyPhotoAction = _uploadingPhoto || _deletingPhoto;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Card(
                      color: const Color(0xFFFFF4E5),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_error!),
                      ),
                    ),
                  if (_error != null) const SizedBox(height: 10),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile?.nombreCompleto ?? 'Empleado',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text('ID: ${profile?.id ?? '-'}'),
                          Text('DNI: ${profile?.dni ?? '-'}'),
                          Text('Legajo: ${profile?.legajo ?? '-'}'),
                          Text('Email: ${profile?.email ?? '-'}'),
                          Text('Estado: ${profile?.estado ?? '-'}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Foto de perfil',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: _ProfilePhotoAvatar(
                              localPhotoPath: _selectedPhoto?.path,
                              remotePhotoUrl: remoteFoto,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: busyPhotoAction
                                      ? null
                                      : () => _pickPhoto(ImageSource.camera),
                                  icon: const Icon(Icons.photo_camera_outlined),
                                  label: const Text('Camara'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: busyPhotoAction
                                      ? null
                                      : () => _pickPhoto(ImageSource.gallery),
                                  icon: const Icon(
                                    Icons.photo_library_outlined,
                                  ),
                                  label: const Text('Galeria'),
                                ),
                              ),
                            ],
                          ),
                          if (_selectedPhoto != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Foto seleccionada: ${_selectedPhoto!.name} (${_fmtBytes(_selectedPhotoBytes)})',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: busyPhotoAction
                                        ? null
                                        : _uploadSelectedPhoto,
                                    icon: const Icon(Icons.upload_outlined),
                                    label: Text(
                                      _uploadingPhoto
                                          ? 'Subiendo...'
                                          : 'Subir foto',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: busyPhotoAction
                                        ? null
                                        : () {
                                            setState(() {
                                              _selectedPhoto = null;
                                              _selectedPhotoBytes = null;
                                            });
                                          },
                                    child: const Text('Descartar'),
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.tonalIcon(
                                onPressed: (!hasRemoteFoto || busyPhotoAction)
                                    ? null
                                    : _deletePhoto,
                                icon: const Icon(Icons.delete_outline),
                                label: Text(
                                  _deletingPhoto
                                      ? 'Eliminando...'
                                      : 'Eliminar foto',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Editar datos',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _telefonoController,
                            decoration: const InputDecoration(
                              labelText: 'Telefono',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _direccionController,
                            decoration: const InputDecoration(
                              labelText: 'Direccion',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _savingProfile ? null : _saveProfile,
                              icon: const Icon(Icons.save_outlined),
                              label: Text(
                                _savingProfile
                                    ? 'Guardando...'
                                    : 'Guardar perfil',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cambiar password',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _passwordActualController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password actual',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _passwordNuevaController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password nueva',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.tonalIcon(
                              onPressed: _savingPassword ? null : _savePassword,
                              icon: const Icon(Icons.lock_outline),
                              label: Text(
                                _savingPassword
                                    ? 'Actualizando...'
                                    : 'Actualizar password',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ProfilePhotoAvatar extends StatelessWidget {
  const _ProfilePhotoAvatar({this.localPhotoPath, this.remotePhotoUrl});

  final String? localPhotoPath;
  final String? remotePhotoUrl;

  @override
  Widget build(BuildContext context) {
    final local = (localPhotoPath ?? '').trim();
    final remote = (remotePhotoUrl ?? '').trim();

    if (local.isNotEmpty) {
      return CircleAvatar(
        radius: 48,
        backgroundColor: const Color(0xFFE5ECF3),
        backgroundImage: FileImage(File(local)),
      );
    }
    if (remote.isNotEmpty) {
      return CircleAvatar(
        radius: 48,
        backgroundColor: const Color(0xFFE5ECF3),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: remote,
            width: 96,
            height: 96,
            fit: BoxFit.cover,
            placeholder: (_, __) => const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            errorWidget: (_, __, ___) =>
                const Icon(Icons.person_outline, size: 44),
          ),
        ),
      );
    }
    return const CircleAvatar(
      radius: 48,
      backgroundColor: Color(0xFFE5ECF3),
      child: Icon(Icons.person_outline, size: 44),
    );
  }
}
