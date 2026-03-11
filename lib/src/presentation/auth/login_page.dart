import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_config.dart';
import '../../core/network/mobile_api_client.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.apiClient,
    required this.onLoginSuccess,
    this.onBiometricLogin,
    this.biometricAvailable = false,
    this.biometricEnabled = true,
    this.hasStoredSession = false,
    this.biometricLoading = false,
    this.biometricError,
  });

  final MobileApiClient apiClient;
  final Future<void> Function(LoginResponse session) onLoginSuccess;
  final Future<void> Function()? onBiometricLogin;
  final bool biometricAvailable;
  final bool biometricEnabled;
  final bool hasStoredSession;
  final bool biometricLoading;
  final String? biometricError;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _dniController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _dniController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) {
      return;
    }
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = await widget.apiClient.login(
        dni: _dniController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) {
        return;
      }
      await widget.onLoginSuccess(session);
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
        _error = 'Error inesperado de conexion.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth < 600 ? 12.0 : 20.0;
              final verticalPadding = constraints.maxHeight < 700 ? 12.0 : 24.0;
              final minHeight =
                  (constraints.maxHeight - (verticalPadding * 2))
                      .clamp(0.0, double.infinity)
                      .toDouble();
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: AutofillGroup(
                            child: Form(
                              key: _formKey,
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Control de Asistencia',
                                    style: Theme.of(context).textTheme.headlineSmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Ingreso de empleado',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  if (!AppConfig.current.isProd) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Servidor: ${AppConfig.current.apiBaseUrl}',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                  const SizedBox(height: 20),
                                  TextFormField(
                                    controller: _dniController,
                                    keyboardType: TextInputType.number,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [AutofillHints.username],
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(10),
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'DNI',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      final text = value?.trim() ?? '';
                                      if (text.isEmpty) {
                                        return 'Ingresa tu DNI.';
                                      }
                                      if (text.length < 7) {
                                        return 'DNI invalido.';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: _passwordController,
                                    textInputAction: TextInputAction.done,
                                    obscureText: _obscurePassword,
                                    autofillHints: const [AutofillHints.password],
                                    onFieldSubmitted: (_) => _submit(),
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      border: const OutlineInputBorder(),
                                      suffixIcon: IconButton(
                                        onPressed: () {
                                          setState(() {
                                            _obscurePassword = !_obscurePassword;
                                          });
                                        },
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                        ),
                                      ),
                                    ),
                                    validator: (value) {
                                      if ((value ?? '').isEmpty) {
                                        return 'Ingresa tu password.';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  if (_error != null) ...[
                                    Text(
                                      _error!,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.error,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  if (widget.biometricError != null) ...[
                                    Text(
                                      widget.biometricError!,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.error,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  SizedBox(
                                    height: 48,
                                    child: FilledButton(
                                      onPressed: _loading ? null : _submit,
                                      child: _loading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text('Ingresar'),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    height: 48,
                                    child: OutlinedButton.icon(
                                      onPressed:
                                          widget.onBiometricLogin != null &&
                                              !_loading &&
                                              !widget.biometricLoading
                                          ? () => widget.onBiometricLogin!.call()
                                          : null,
                                      icon: widget.biometricLoading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(Icons.fingerprint),
                                      label: Text(
                                        widget.biometricLoading
                                            ? 'Validando huella...'
                                            : 'Ingresar con huella',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _biometricStatusText(),
                                    style: Theme.of(context).textTheme.bodySmall,
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
            },
          ),
        ),
      ),
    );
  }

  String _biometricStatusText() {
    if (!widget.biometricAvailable) {
      return 'Huella no disponible en este dispositivo o sin configurar.';
    }
    if (!widget.biometricEnabled) {
      return 'Uso de huella desactivado en este dispositivo.';
    }
    if (!widget.hasStoredSession) {
      return 'Ingresa con DNI y password una vez para habilitar huella.';
    }
    if (widget.onBiometricLogin == null) {
      return 'Huella disponible.';
    }
    return 'Huella disponible para ingreso rapido.';
  }
}
