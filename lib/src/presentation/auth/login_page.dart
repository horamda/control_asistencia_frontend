import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_config.dart';
import '../../core/auth/biometric_credential_cache.dart';
import '../../core/auth/offline_credentials_cache.dart';
import '../../core/network/mobile_api_client.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.apiClient,
    required this.onLoginSuccess,
    this.onBiometricLogin,
    this.onBiometricReauth,
    this.biometricAvailable = false,
    this.biometricEnabled = true,
    this.hasStoredSession = false,
    this.biometricLoading = false,
    this.biometricReauthLoading = false,
    this.biometricError,
    this.offlineCredentialsCache,
    this.biometricCredentialCache,
  });

  final MobileApiClient apiClient;
  final Future<void> Function(LoginResponse session) onLoginSuccess;
  final Future<void> Function()? onBiometricLogin;
  final Future<void> Function()? onBiometricReauth;
  final bool biometricAvailable;
  final bool biometricEnabled;
  final bool hasStoredSession;
  final bool biometricLoading;
  final bool biometricReauthLoading;
  final String? biometricError;
  final OfflineCredentialsCache? offlineCredentialsCache;
  final BiometricCredentialCache? biometricCredentialCache;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _dniController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _offlineLoading = false;
  bool _obscurePassword = true;
  bool _isOffline = false;
  bool _hasOfflineCreds = false;
  String? _error;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isOffline = results.every((r) => r == ConnectivityResult.none);
      });
    }
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (!mounted) return;
      setState(() {
        _isOffline = results.every((r) => r == ConnectivityResult.none);
      });
    });

    final cache = widget.offlineCredentialsCache;
    if (cache != null) {
      final has = await cache.hasCredentials;
      if (mounted) setState(() => _hasOfflineCreds = has);
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _dniController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = await widget.apiClient.login(
        dni: _dniController.text.trim(),
        password: _passwordController.text,
      );
      // Persist credentials for offline access and biometric re-auth
      final offlineCache = widget.offlineCredentialsCache;
      if (offlineCache != null) {
        unawaited(offlineCache.save(
          dni: _dniController.text.trim(),
          password: _passwordController.text,
          empleado: session.empleado,
        ));
      }
      final bioCache = widget.biometricCredentialCache;
      if (bioCache != null) {
        unawaited(bioCache.save(
          dni: _dniController.text.trim(),
          password: _passwordController.text,
        ));
      }
      if (!mounted) return;
      await widget.onLoginSuccess(session);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Error inesperado de conexión.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitOffline() async {
    if (_offlineLoading) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _offlineLoading = true;
      _error = null;
    });

    try {
      final result = await widget.offlineCredentialsCache!.validate(
        dni: _dniController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      if (result.isOk) {
        final syntheticSession = LoginResponse(
          token: _generateOfflineToken(),
          empleado: result.empleado!,
        );
        await widget.onLoginSuccess(syntheticSession);
      } else {
        setState(() => _error = result.errorMessage);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Error al validar credenciales sin conexión.');
    } finally {
      if (mounted) setState(() => _offlineLoading = false);
    }
  }

  /// Genera un token offline opaco de 16 bytes aleatorios (hex).
  /// El prefijo 'offline_' permite detectarlo sin comparar contra un literal fijo.
  String _generateOfflineToken() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'offline_$hex';
  }

  bool get _canUseBiometric =>
      widget.biometricAvailable &&
      widget.biometricEnabled &&
      widget.hasStoredSession &&
      widget.onBiometricLogin != null;

  bool get _canBiometricReauth =>
      widget.biometricAvailable &&
      widget.biometricEnabled &&
      !widget.hasStoredSession &&
      widget.onBiometricReauth != null;

  bool get _offlineAvailable =>
      _isOffline &&
      _hasOfflineCreds &&
      widget.offlineCredentialsCache != null;

  String _biometricStatusText() {
    if (!widget.biometricAvailable) {
      return 'Huella no disponible o sin configurar en este dispositivo.';
    }
    if (!widget.biometricEnabled) {
      return 'Uso de huella desactivado en configuración.';
    }
    // Si hay re-auth disponible, se muestra el botón en su lugar.
    if (!widget.hasStoredSession && !_canBiometricReauth) {
      return 'Ingresa con DNI y contraseña una vez para habilitar huella.';
    }
    if (widget.onBiometricLogin == null && !_canBiometricReauth) {
      return 'Huella disponible.';
    }
    return '';
  }

  Widget _formCard() => _FormCard(
    formKey: _formKey,
    dniController: _dniController,
    passwordController: _passwordController,
    obscurePassword: _obscurePassword,
    loading: _loading,
    offlineLoading: _offlineLoading,
    offlineAvailable: _offlineAvailable,
    isOffline: _isOffline,
    error: _error,
    biometricError: widget.biometricError,
    canUseBiometric: _canUseBiometric,
    canBiometricReauth: _canBiometricReauth,
    biometricLoading: widget.biometricLoading,
    biometricReauthLoading: widget.biometricReauthLoading,
    biometricStatusText: _biometricStatusText(),
    onToggleObscure: () =>
        setState(() => _obscurePassword = !_obscurePassword),
    onSubmit: _submit,
    onOfflineSubmit: _submitOffline,
    onBiometricLogin: widget.onBiometricLogin,
    onBiometricReauth: widget.onBiometricReauth,
  );

  Widget? _devChip() {
    if (AppConfig.current.isProd) return null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.developer_mode, size: 12, color: Colors.white60),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              AppConfig.current.apiBaseUrl,
              style: const TextStyle(color: Colors.white60, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D3B66),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D3B66), Color(0xFF1B6FA8)],
          ),
        ),
        child: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.opaque,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;

                // Tablet / landscape grande: dos columnas
                if (w >= 700) {
                  return _WideLayout(
                    formCard: _formCard(),
                    devChip: _devChip(),
                  );
                }

                // Landscape phone: header compacto
                final compact = h < 480;
                return _NarrowLayout(
                  constraints: constraints,
                  compact: compact,
                  formCard: _formCard(),
                  devChip: _devChip(),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ── Wide layout (tablet / landscape >= 700px) ─────────────────────────────────

class _WideLayout extends StatelessWidget {
  const _WideLayout({required this.formCard, this.devChip});

  final Widget formCard;
  final Widget? devChip;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── Columna izquierda: brand ──
        Expanded(
          flex: 45,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _BrandHeader(compact: false),
                if (devChip != null) ...[
                  const SizedBox(height: 14),
                  devChip!,
                ],
              ],
            ),
          ),
        ),
        // Divisor vertical
        Container(
          width: 1,
          margin: const EdgeInsets.symmetric(vertical: 48),
          color: Colors.white.withValues(alpha: 0.18),
        ),
        // ── Columna derecha: formulario ──
        Expanded(
          flex: 55,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: formCard,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Narrow layout (phones) ────────────────────────────────────────────────────

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({
    required this.constraints,
    required this.compact,
    required this.formCard,
    this.devChip,
  });

  final BoxConstraints constraints;
  final bool compact;
  final Widget formCard;
  final Widget? devChip;

  @override
  Widget build(BuildContext context) {
    final hPad = constraints.maxWidth < 600 ? 24.0 : 56.0;
    final vPad = compact ? 12.0 : 24.0;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: constraints.maxHeight - vPad * 2,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _BrandHeader(compact: compact),
                if (devChip != null) ...[
                  SizedBox(height: compact ? 6 : 10),
                  devChip!,
                ],
                SizedBox(height: compact ? 16 : 32),
                formCard,
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Brand header ──────────────────────────────────────────────────────────────

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final circleSize = compact ? 60.0 : 84.0;
    final iconSize = compact ? 32.0 : 46.0;
    final titleSize = compact ? 22.0 : 30.0;

    return Column(
      children: [
        Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 2,
            ),
          ),
          child: Icon(
            Icons.qr_code_2_rounded,
            size: iconSize,
            color: Colors.white,
          ),
        ),
        SizedBox(height: compact ? 10 : 16),
        Text(
          'FichaYa',
          style: TextStyle(
            color: Colors.white,
            fontSize: titleSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 4),
          const Text(
            'Control de asistencia',
            style: TextStyle(color: Colors.white60, fontSize: 14),
          ),
        ],
      ],
    );
  }
}

// ── Form card ─────────────────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.formKey,
    required this.dniController,
    required this.passwordController,
    required this.obscurePassword,
    required this.loading,
    required this.offlineLoading,
    required this.offlineAvailable,
    required this.isOffline,
    required this.error,
    required this.biometricError,
    required this.canUseBiometric,
    required this.canBiometricReauth,
    required this.biometricLoading,
    required this.biometricReauthLoading,
    required this.biometricStatusText,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onOfflineSubmit,
    required this.onBiometricLogin,
    required this.onBiometricReauth,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController dniController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool loading;
  final bool offlineLoading;
  final bool offlineAvailable;
  final bool isOffline;
  final String? error;
  final String? biometricError;
  final bool canUseBiometric;
  final bool canBiometricReauth;
  final bool biometricLoading;
  final bool biometricReauthLoading;
  final String biometricStatusText;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final VoidCallback onOfflineSubmit;
  final Future<void> Function()? onBiometricLogin;
  final Future<void> Function()? onBiometricReauth;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final anyLoading = loading || offlineLoading;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 8,
      shadowColor: Colors.black38,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: AutofillGroup(
          child: Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Iniciar sesión',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ingresa tus credenciales de empleado',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),

                // ── DNI ──
                TextFormField(
                  controller: dniController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
                    labelText: 'DNI',
                    hintText: 'Número de documento',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Ingresa tu DNI.';
                    if (text.length < 7) return 'DNI invalido.';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // ── Contraseña ──
                TextFormField(
                  controller: passwordController,
                  textInputAction: TextInputAction.done,
                  obscureText: obscurePassword,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => isOffline && offlineAvailable
                      ? onOfflineSubmit()
                      : onSubmit(),
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    hintText: 'Tu contraseña',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: onToggleObscure,
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      tooltip: obscurePassword
                          ? 'Mostrar contraseña'
                          : 'Ocultar contraseña',
                    ),
                  ),
                  validator: (value) {
                    if ((value ?? '').isEmpty) return 'Ingresa tu contraseña.';
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ── Error banner ──
                if ((error ?? '').isNotEmpty) ...[
                  _ErrorBanner(message: error!),
                  const SizedBox(height: 16),
                ],
                if ((biometricError ?? '').isNotEmpty) ...[
                  _ErrorBanner(message: biometricError!),
                  const SizedBox(height: 16),
                ],

                // ── Offline notice ──
                if (isOffline) ...[
                  _OfflineNotice(offlineAvailable: offlineAvailable),
                  const SizedBox(height: 16),
                ],

                // ── Ingresar (online) ──
                if (!isOffline || !offlineAvailable)
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: anyLoading ? null : onSubmit,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Text(
                              'Ingresar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                // ── Continuar sin conexion ──
                if (offlineAvailable) ...[
                  if (!isOffline) ...[
                    const SizedBox(height: 12),
                    _Divider(label: 'o'),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: anyLoading ? null : onOfflineSubmit,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: offlineLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_off_rounded, size: 20),
                      label: Text(
                        offlineLoading
                            ? 'Validando...'
                            : 'Continuar sin conexión',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],

                // ── Biometrico ──
                () {
                  final showBioButton = canUseBiometric ||
                      canBiometricReauth ||
                      biometricLoading ||
                      biometricReauthLoading;
                  final bioLoading = biometricLoading || biometricReauthLoading;
                  final bioEnabled =
                      (canUseBiometric || canBiometricReauth) &&
                      !anyLoading &&
                      !bioLoading;
                  final bioCallback =
                      canUseBiometric ? onBiometricLogin : onBiometricReauth;
                  if (showBioButton) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        _Divider(label: 'o'),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            onPressed:
                                bioEnabled ? () => bioCallback!.call() : null,
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (bioLoading)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                else
                                  const Icon(Icons.fingerprint, size: 22),
                                const SizedBox(width: 10),
                                Text(
                                  bioLoading
                                      ? 'Validando huella...'
                                      : 'Ingresar con huella',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  if (biometricStatusText.isNotEmpty) {
                    return Column(
                      children: [
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.fingerprint,
                              size: 14,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                biometricStatusText,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                }(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Offline notice ────────────────────────────────────────────────────────────

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice({required this.offlineAvailable});

  final bool offlineAvailable;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = offlineAvailable
        ? cs.tertiaryContainer
        : cs.surfaceContainerHighest;
    final onColor = offlineAvailable
        ? cs.onTertiaryContainer
        : cs.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.wifi_off_rounded, size: 16, color: onColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              offlineAvailable
                  ? 'Sin conexión. Podés ingresar con tus credenciales guardadas.'
                  : 'Sin conexión a internet. Conectate para ingresar.',
              style: TextStyle(color: onColor, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Divider with label ────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  const _Divider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 18, color: cs.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: cs.onErrorContainer, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
