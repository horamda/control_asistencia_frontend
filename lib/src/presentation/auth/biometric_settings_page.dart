import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/auth/session_manager.dart';
import '../../core/feedback/clock_feedback_audio_service.dart';
import '../../core/feedback/clock_feedback_profile.dart';
import '../widgets/centered_snackbar.dart';

class BiometricSettingsPage extends StatefulWidget {
  const BiometricSettingsPage({super.key, required this.sessionManager});

  final SessionManager sessionManager;

  @override
  State<BiometricSettingsPage> createState() => _BiometricSettingsPageState();
}

class _BiometricSettingsPageState extends State<BiometricSettingsPage> {
  final ClockFeedbackAudioService _previewAudio = ClockFeedbackAudioService();

  bool _updating = false;
  bool _previewing = false;
  ClockFeedbackProfile? _selectedSoundProfile;

  @override
  void initState() {
    super.initState();
    _selectedSoundProfile = widget.sessionManager.clockFeedbackProfile;
    unawaited(_previewAudio.initialize());
  }

  @override
  void dispose() {
    unawaited(_previewAudio.dispose());
    super.dispose();
  }

  Future<void> _setBiometricUsage(bool enabled) async {
    if (_updating) {
      return;
    }
    final manager = widget.sessionManager;
    if (enabled && !manager.biometricAvailable) {
      _showMessage(
        'Este dispositivo no tiene huella disponible o no está configurada.',
        isError: true,
      );
      return;
    }

    setState(() {
      _updating = true;
    });
    try {
      if (enabled) {
        final ok = await manager.testBiometricAuthentication();
        if (!ok) {
          if (mounted) {
            _showMessage('No se pudo activar el uso de huella.', isError: true);
          }
          return;
        }
      }
      await manager.setBiometricEnabled(enabled);
      if (!mounted) {
        return;
      }
      _showMessage(
        enabled ? 'Uso de huella activado.' : 'Uso de huella desactivado.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _updating = false;
        });
      }
    }
  }

  Future<void> _testFingerprint() async {
    if (_updating || widget.sessionManager.isBiometricLoading) {
      return;
    }
    final ok = await widget.sessionManager.testBiometricAuthentication();
    if (!mounted) {
      return;
    }
    _showMessage(
      ok ? 'Huella validada correctamente.' : 'No se pudo validar la huella.',
      isError: !ok,
    );
  }

  Future<void> _saveAudioProfile() async {
    if (_updating) {
      return;
    }
    final selected =
        _selectedSoundProfile ?? widget.sessionManager.clockFeedbackProfile;
    if (selected == widget.sessionManager.clockFeedbackProfile) {
      _showMessage('Ese perfil ya está aplicado.');
      return;
    }
    setState(() {
      _updating = true;
    });
    try {
      await widget.sessionManager.setClockFeedbackProfile(selected);
      if (!mounted) {
        return;
      }
      _showMessage('Perfil de sonido aplicado: ${selected.label}.');
    } finally {
      if (mounted) {
        setState(() {
          _updating = false;
        });
      }
    }
  }

  Future<void> _previewSoundProfile() async {
    if (_updating || _previewing) {
      return;
    }
    final selected =
        _selectedSoundProfile ?? widget.sessionManager.clockFeedbackProfile;
    setState(() {
      _previewing = true;
    });
    try {
      await _previewAudio.setProfile(selected);
      await _previewAudio.play(tone: ClockFeedbackTone.success);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await _previewAudio.play(tone: ClockFeedbackTone.offlineQueued);
      await Future<void>.delayed(const Duration(milliseconds: 140));
      await _previewAudio.play(tone: ClockFeedbackTone.warning);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await _previewAudio.play(tone: ClockFeedbackTone.error);
      await Future<void>.delayed(const Duration(milliseconds: 180));
      await _previewAudio.play(tone: ClockFeedbackTone.fraud);
    } finally {
      if (mounted) {
        setState(() {
          _previewing = false;
        });
      }
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    showCenteredSnackBar(
      context,
      text: text,
      isError: isError,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seguridad y sonido')),
      body: AnimatedBuilder(
        animation: widget.sessionManager,
        builder: (context, _) {
          final manager = widget.sessionManager;
          final available = manager.biometricAvailable;
          final enabled = manager.biometricEnabled;
          final soundProfile = manager.clockFeedbackProfile;
          final selectedSoundProfile = _selectedSoundProfile ?? soundProfile;
          final hasUnsavedSoundChanges = selectedSoundProfile != soundProfile;
          final loading = _updating || manager.isBiometricLoading;
          return LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth >= 1200
                  ? 900.0
                  : constraints.maxWidth >= 900
                  ? 760.0
                  : double.infinity;
              final horizontalPadding = constraints.maxWidth < 600 ? 12.0 : 16.0;
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: ListView(
                    padding: EdgeInsets.all(horizontalPadding),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Acceso biométrico',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Activá el uso de huella para ingreso rápido y desbloqueo por inactividad.',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Card(
                        child: SwitchListTile.adaptive(
                          value: enabled,
                          onChanged: loading ? null : _setBiometricUsage,
                          title: const Text('Usar huella en este dispositivo'),
                          subtitle: Text(
                            !available
                                ? 'No disponible. Configurá una huella en el teléfono.'
                                : enabled
                                ? 'Activada para desbloquear sesión.'
                                : 'Desactivada.',
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed:
                              (!available || loading) ? null : _testFingerprint,
                          icon: loading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.fingerprint),
                          label: Text(loading ? 'Validando...' : 'Probar huella'),
                        ),
                      ),
                      if (manager.statusMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          manager.statusMessage!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sonido al fichar',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Define el volumen relativo de los tonos de feedback.',
                              ),
                              const SizedBox(height: 8),
                              RadioListTile<ClockFeedbackProfile>.adaptive(
                                contentPadding: EdgeInsets.zero,
                                value: ClockFeedbackProfile.subtle,
                                groupValue: selectedSoundProfile,
                                onChanged: loading
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          setState(() {
                                            _selectedSoundProfile = value;
                                          });
                                        }
                                      },
                                title: const Text('Discreto'),
                                subtitle: const Text('Más suave.'),
                              ),
                              RadioListTile<ClockFeedbackProfile>.adaptive(
                                contentPadding: EdgeInsets.zero,
                                value: ClockFeedbackProfile.balanced,
                                groupValue: selectedSoundProfile,
                                onChanged: loading
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          setState(() {
                                            _selectedSoundProfile = value;
                                          });
                                        }
                                      },
                                title: const Text('Balanceado'),
                                subtitle: const Text('Recomendado.'),
                              ),
                              RadioListTile<ClockFeedbackProfile>.adaptive(
                                contentPadding: EdgeInsets.zero,
                                value: ClockFeedbackProfile.strong,
                                groupValue: selectedSoundProfile,
                                onChanged: loading
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          setState(() {
                                            _selectedSoundProfile = value;
                                          });
                                        }
                                      },
                                title: const Text('Fuerte'),
                                subtitle: const Text('Más notorio.'),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: (loading || _previewing)
                                        ? null
                                        : _previewSoundProfile,
                                    icon: _previewing
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.volume_up_outlined),
                                    label: Text(
                                      _previewing
                                          ? 'Reproduciendo...'
                                          : 'Probar sonido',
                                    ),
                                  ),
                                  FilledButton.icon(
                                    onPressed:
                                        (loading || !hasUnsavedSoundChanges)
                                        ? null
                                        : _saveAudioProfile,
                                    icon: const Icon(Icons.save_outlined),
                                    label: const Text('Guardar perfil'),
                                  ),
                                ],
                              ),
                              if (hasUnsavedSoundChanges) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Tenés cambios de sonido sin guardar.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Text(
                            'Tip: si desactivás la huella, el bloqueo por inactividad no se usará y se pedirá el login completo al vencer el tiempo de inactividad.',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
