import 'package:ficharqr/src/presentation/widgets/app_card.dart';
import '../widgets/app_page_layout.dart';
import 'package:ficharqr/src/presentation/theme/app_palette.dart';
import 'package:flutter/foundation.dart';
import '../widgets/browser_permission_dialog.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/image/profile_photo_cache.dart';
import '../../core/network/mobile_api_client.dart';
import '../../core/permissions/device_permission_bootstrap.dart';
import '../widgets/centered_snackbar.dart';
import '../widgets/croppable_image.dart';
import '../widgets/employee_photo_widget.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.apiClient,
    required this.token,
    this.employeeDni,
  });

  final MobileApiClient apiClient;
  final String token;

  /// DNI del empleado para construir la URL de foto como fallback cuando
  /// [EmployeeProfile.dni] es null (puede ocurrir en ciertos perfiles).
  final String? employeeDni;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();
  final _passwordActualController = TextEditingController();
  final _passwordNuevaController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final DevicePermissionBootstrap _devicePermissionBootstrap =
      DevicePermissionBootstrap();

  bool _loading = true;
  bool _savingProfile = false;
  bool _uploadingPhoto = false;
  bool _deletingPhoto = false;
  bool _savingPassword = false;
  bool _obscureActual = true;
  bool _obscureNueva = true;
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
    final previousPhotoUrl = _photoUrl(_profile);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await widget.apiClient.getMe(token: widget.token);
      final nextPhotoUrl = _photoUrl(profile);
      if (previousPhotoUrl != nextPhotoUrl) {
        await ProfilePhotoCache.evict(previousPhotoUrl);
      }
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _telefonoController.text = profile.telefono ?? '';
        _direccionController.text = profile.direccion ?? '';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Error inesperado al consultar perfil.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_savingProfile) return;
    setState(() => _savingProfile = true);
    try {
      final updated = await widget.apiClient.updatePerfil(
        token: widget.token,
        telefono: _telefonoController.text.trim(),
        direccion: _direccionController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _telefonoController.text = updated.telefono ?? '';
        _direccionController.text = updated.direccion ?? '';
      });
      _showMsg('Perfil actualizado correctamente.');
      await _loadProfile();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showMsg(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showMsg('Error inesperado al actualizar perfil.', isError: true);
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (source == ImageSource.camera) {
      final ok = kIsWeb
          ? await ensureBrowserPermissions(
              context,
              _devicePermissionBootstrap,
              location: false,
            )
          : await _devicePermissionBootstrap.isCameraGranted();
      if (!mounted) return;
      if (!ok) {
        if (!kIsWeb) _showCameraSettings();
        return;
      }
    }
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 72,
        maxWidth: 800,
        maxHeight: 800,
        requestFullMetadata: false,
      );
      if (picked == null || !mounted) return;
      final cropped = await cropPickedImage(
        context,
        picked,
        title: 'Recortar foto',
        mode: ImageCropMode.square,
        maxWidth: 800,
        maxHeight: 800,
        compressQuality: 72,
      );
      if (!mounted) return;
      final selected = cropped ?? picked;
      final size = await selected.length();
      setState(() {
        _selectedPhoto = selected;
        _selectedPhotoBytes = size;
      });
    } catch (_) {
      if (!mounted) return;
      _showMsg('No se pudo abrir la cámara/galería.', isError: true);
    }
  }

  Future<void> _uploadSelectedPhoto() async {
    final selected = _selectedPhoto;
    if (selected == null || _uploadingPhoto) return;
    final previousUrl = _photoUrl(_profile);
    setState(() => _uploadingPhoto = true);
    try {
      final updated = await widget.apiClient.updatePerfilConFotoFile(
        token: widget.token,
        fotoPath: selected.path,
        telefono: _telefonoController.text.trim(),
        direccion: _direccionController.text.trim(),
      );
      await ProfilePhotoCache.evict(previousUrl);
      if (!mounted) return;
      setState(() {
        _selectedPhoto = null;
        _selectedPhotoBytes = null;
        _telefonoController.text = updated.telefono ?? '';
        _direccionController.text = updated.direccion ?? '';
      });
      _showMsg('Foto de perfil actualizada.');
      await _loadProfile();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showMsg(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showMsg('Error inesperado al subir foto.', isError: true);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _deletePhoto() async {
    if (_deletingPhoto) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar foto', textAlign: TextAlign.center),
        content: const Text(
          'Se eliminara tu foto de perfil actual.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', textAlign: TextAlign.center),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', textAlign: TextAlign.center),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final previousUrl = _photoUrl(_profile);
    setState(() => _deletingPhoto = true);
    try {
      await widget.apiClient.deleteFotoPerfil(token: widget.token);
      await ProfilePhotoCache.evict(previousUrl);
      if (!mounted) return;
      setState(() {
        _selectedPhoto = null;
        _selectedPhotoBytes = null;
      });
      _showMsg('Foto eliminada.');
      await _loadProfile();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showMsg(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showMsg('Error inesperado al eliminar foto.', isError: true);
    } finally {
      if (mounted) setState(() => _deletingPhoto = false);
    }
  }

  Future<void> _savePassword() async {
    if (_savingPassword) return;
    final current = _passwordActualController.text;
    final next = _passwordNuevaController.text;
    if (current.trim().isEmpty || next.trim().isEmpty) {
      _showMsg('Completa password actual y nueva.', isError: true);
      return;
    }
    if (next.trim().length < 8) {
      _showMsg(
        'La nueva password debe tener al menos 8 caracteres.',
        isError: true,
      );
      return;
    }
    setState(() => _savingPassword = true);
    try {
      await widget.apiClient.updatePassword(
        token: widget.token,
        passwordActual: current,
        passwordNueva: next,
      );
      if (!mounted) return;
      _passwordActualController.clear();
      _passwordNuevaController.clear();
      _showMsg('Password actualizada correctamente.');
    } on ApiException catch (e) {
      if (!mounted) return;
      _showMsg(e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      _showMsg('Error inesperado al actualizar password.', isError: true);
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  void _showMsg(String text, {bool isError = false}) {
    showCenteredSnackBar(context, text: text, isError: isError);
  }

  void _showCameraSettings() {
    showCenteredSnackBar(
      context,
      text: 'Debés habilitar la cámara en Ajustes para actualizar la foto.',
      isError: true,
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: 'Ajustes',
        textColor: Colors.white,
        onPressed: () =>
            unawaited(_devicePermissionBootstrap.openAppSettings()),
      ),
    );
  }

  String _photoUrl(EmployeeProfile? profile) {
    if (profile == null) return '';
    final effectiveDni = profile.dni ?? widget.employeeDni;
    // Preferir siempre el endpoint canonico /empleados/imagen/{dni} ya que
    // el campo `foto` del backend puede ser una URL relativa (sin esquema)
    // que ProfilePhotoCache.resolve descarta, dejando la foto en blanco.
    if (effectiveDni != null && effectiveDni.isNotEmpty) {
      return widget.apiClient.buildEmpleadoImagenUrl(
        dni: effectiveDni,
        version: profile.imagenVersion,
      );
    }
    // Ultimo fallback: usar foto absoluta si la hay
    return ProfilePhotoCache.withVersion(
      profile.foto,
      version: profile.imagenVersion,
    );
  }

  String _fmtBytes(int? value) {
    if (value == null || value <= 0) return '–';
    if (value >= 1024 * 1024) {
      return '${(value / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(value / 1024).toStringAsFixed(0)} KB';
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    final remoteFoto = _photoUrl(p);
    final busyPhoto = _uploadingPhoto || _deletingPhoto;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil', textAlign: TextAlign.center),
        bottom: (_uploadingPhoto || _deletingPhoto || _savingProfile)
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth >= 900
                      ? 640.0
                      : double.infinity;
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        children: [
                          if (_error != null) ...[
                            _ErrorBanner(
                              message: _error!,
                              onRetry: _loadProfile,
                            ),
                            const SizedBox(height: 14),
                          ],

                          // ── Hero ───────────────────────────────────
                          _ProfileHero(
                            profile: p,
                            remoteFotoUrl: remoteFoto,
                            localPhotoPath: _selectedPhoto?.path,
                            token: widget.token,
                            busyPhoto: busyPhoto,
                            onPickCamera: () => _pickPhoto(ImageSource.camera),
                            onPickGallery: () =>
                                _pickPhoto(ImageSource.gallery),
                          ),
                          const SizedBox(height: 16),

                          // ── Info tiles ────────────────────────────
                          if (p != null) ...[
                            _SectionCard(
                              title: 'Informacion',
                              icon: Icons.badge_rounded,
                              children: [
                                _InfoTile(
                                  icon: Icons.numbers_rounded,
                                  label: 'Legajo',
                                  value: p.legajo ?? '–',
                                ),
                                _InfoTile(
                                  icon: Icons.fingerprint_rounded,
                                  label: 'DNI',
                                  value: p.dni ?? '–',
                                ),
                                _InfoTile(
                                  icon: Icons.email_rounded,
                                  label: 'Email',
                                  value: p.email ?? '–',
                                ),
                                if ((p.telefono ?? '').isNotEmpty)
                                  _InfoTile(
                                    icon: Icons.phone_rounded,
                                    label: 'Telefono',
                                    value: p.telefono!,
                                  ),
                                if ((p.direccion ?? '').isNotEmpty)
                                  _InfoTile(
                                    icon: Icons.home_rounded,
                                    label: 'Direccion',
                                    value: p.direccion!,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],

                          // ── Photo preview + upload ─────────────────
                          if (_selectedPhoto != null) ...[
                            _SectionCard(
                              title: 'Nueva foto seleccionada',
                              icon: Icons.photo_rounded,
                              children: [
                                _PhotoPreviewRow(
                                  photoPath: _selectedPhoto!.path,
                                  sizeLabel: _fmtBytes(_selectedPhotoBytes),
                                  uploading: _uploadingPhoto,
                                  onUpload: busyPhoto
                                      ? null
                                      : _uploadSelectedPhoto,
                                  onDiscard: busyPhoto
                                      ? null
                                      : () => setState(() {
                                          _selectedPhoto = null;
                                          _selectedPhotoBytes = null;
                                        }),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ] else if (remoteFoto.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: OutlinedButton.icon(
                                onPressed: busyPhoto ? null : _deletePhoto,
                                icon: Icon(
                                  Icons.delete_rounded,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                label: Text(
                                  _deletingPhoto
                                      ? 'Eliminando...'
                                      : 'Eliminar foto de perfil',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  minimumSize: const Size(double.infinity, 48),
                                ),
                              ),
                            ),
                          ],

                          // ── Edit data ──────────────────────────────
                          _SectionCard(
                            title: 'Editar datos',
                            icon: Icons.edit_rounded,
                            children: [
                              TextField(
                                controller: _telefonoController,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Telefono',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.phone_rounded),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _direccionController,
                                decoration: const InputDecoration(
                                  labelText: 'Direccion',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.home_rounded),
                                  isDense: true,
                                ),
                              ),
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                onPressed: _savingProfile ? null : _saveProfile,
                                icon: _savingProfile
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : const Icon(Icons.save_rounded),
                                label: Text(
                                  _savingProfile ? 'Guardando...' : 'Guardar',
                                  textAlign: TextAlign.center,
                                ),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 48),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // ── Change password ────────────────────────
                          _SectionCard(
                            title: 'Cambiar contraseña',
                            icon: Icons.lock_rounded,
                            children: [
                              TextField(
                                controller: _passwordActualController,
                                obscureText: _obscureActual,
                                decoration: InputDecoration(
                                  labelText: 'Contraseña actual',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.lock_rounded),
                                  isDense: true,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureActual
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureActual = !_obscureActual,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _passwordNuevaController,
                                obscureText: _obscureNueva,
                                decoration: InputDecoration(
                                  labelText: 'Nueva contraseña',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(
                                    Icons.lock_open_rounded,
                                  ),
                                  helperText: 'Mínimo 8 caracteres',
                                  isDense: true,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureNueva
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureNueva = !_obscureNueva,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              FilledButton.tonal(
                                onPressed: _savingPassword
                                    ? null
                                    : _savePassword,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 48),
                                ),
                                child: _savingPassword
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Actualizar contraseña',
                                        textAlign: TextAlign.center,
                                      ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

// ─── Profile hero ──────────────────────────────────────────────────────────────

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.profile,
    required this.remoteFotoUrl,
    required this.localPhotoPath,
    required this.token,
    required this.busyPhoto,
    required this.onPickCamera,
    required this.onPickGallery,
  });

  final EmployeeProfile? profile;
  final String remoteFotoUrl;
  final String? localPhotoPath;
  final String token;
  final bool busyPhoto;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = profile;
    final nombre = p?.nombreCompleto ?? 'Empleado';
    final estado = (p?.estado ?? '').toLowerCase();
    final estadoColor = estado == 'activo' ? Colors.green.shade700 : cs.error;

    return AppCard(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Colored banner top
          Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: AppColors.of(context).brandGradient,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar overlapping the banner
                Transform.translate(
                  offset: const Offset(0, -36),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: cs.surface, width: 3),
                        ),
                        child: EmployeePhotoWidget(
                          photoUrl: remoteFotoUrl,
                          localPhotoPath: localPhotoPath,
                          token: token,
                          radius: 44,
                          placeholderSize: 28,
                          iconSize: 40,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: PopupMenuButton<ImageSource>(
                          onSelected: (src) => src == ImageSource.camera
                              ? onPickCamera()
                              : onPickGallery(),
                          enabled: !busyPhoto,
                          tooltip: 'Cambiar foto',
                          offset: const Offset(0, 36),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: ImageSource.camera,
                              child: ListTile(
                                dense: true,
                                leading: Icon(Icons.camera_alt_rounded),
                                title: Text(
                                  'Cámara',
                                  textAlign: TextAlign.center,
                                ),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            PopupMenuItem(
                              value: ImageSource.gallery,
                              child: ListTile(
                                dense: true,
                                leading: Icon(Icons.photo_library_rounded),
                                title: Text(
                                  'Galeria',
                                  textAlign: TextAlign.center,
                                ),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              shape: BoxShape.circle,
                              border: Border.all(color: cs.surface, width: 2),
                            ),
                            child: Icon(
                              Icons.edit_rounded,
                              size: 14,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Name + estado badge (pull up to reduce gap from transform)
                Transform.translate(
                  offset: const Offset(0, -24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        nombre,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      if (p?.estado != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.of(
                              context,
                            ).surface(estadoColor.withValues(alpha: 0.12)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.of(
                                context,
                              ).border(estadoColor.withValues(alpha: 0.3)),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: AppColors.of(
                                    context,
                                  ).surface(estadoColor),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _capitalize(p!.estado!),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.of(
                                    context,
                                  ).foreground(estadoColor),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ─── Section card ──────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ─── Info tile ─────────────────────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Photo preview row ─────────────────────────────────────────────────────────

class _PhotoPreviewRow extends StatelessWidget {
  const _PhotoPreviewRow({
    required this.photoPath,
    required this.sizeLabel,
    required this.uploading,
    required this.onUpload,
    required this.onDiscard,
  });

  final String photoPath;
  final String sizeLabel;
  final bool uploading;
  final VoidCallback? onUpload;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: kIsWeb
              ? Image.network(
                  photoPath,
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                )
              : Image.file(
                  File(photoPath),
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                ),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        sizeLabel,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 12),
      AppAdaptiveActions(
        children: [
          FilledButton.icon(
            onPressed: onUpload,
            icon: uploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_rounded),
            label: Text(uploading ? 'Subiendo...' : 'Subir foto'),
          ),
          OutlinedButton(onPressed: onDiscard, child: const Text('Descartar')),
        ],
      ),
    ],
  );
}

// ─── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppCard(
      color: cs.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_rounded, color: cs.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: cs.onErrorContainer),
                textAlign: TextAlign.center,
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Reintentar',
                style: TextStyle(color: cs.onErrorContainer),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
