import '../theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Lightweight startup screen; its animation never delays authentication.
class AppStartupScreen extends StatelessWidget {
  const AppStartupScreen({super.key, this.animate = true});

  final bool animate;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: AppColors.of(context).surface(AppPalette.navy),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.of(context).brandGradient,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 540;
              final logoSize = (constraints.maxWidth - 48).clamp(
                0.0,
                compact ? 180.0 : 240.0,
              );
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Semantics(
                          label: 'FichaYa, control de asistencia',
                          image: true,
                          child: ExcludeSemantics(
                            child: SizedBox.square(
                              dimension: logoSize,
                              child: Lottie.asset(
                                'assets/branding/fichaya_splash.json',
                                fit: BoxFit.contain,
                                repeat: false,
                                animate: animate && !reduceMotion,
                                controller: animate && !reduceMotion
                                    ? null
                                    : const AlwaysStoppedAnimation<double>(1),
                                errorBuilder: (context, error, stackTrace) =>
                                    Image.asset(
                                      'assets/branding/fichaya-header.png',
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.qr_code_rounded,
                                        size: 96,
                                        color: Colors.white,
                                      ),
                                    ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Control de asistencia',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.of(
                              context,
                            ).foreground(const Color(0xFFD2E5F0)),
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: compact ? 32 : 56),
                        SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            value: reduceMotion ? 0.75 : null,
                            strokeWidth: 2.5,
                            strokeCap: StrokeCap.round,
                            backgroundColor: AppColors.of(
                              context,
                            ).surface(const Color(0x33FFFFFF)),
                            color: Colors.white,
                            semanticsLabel: 'Iniciando FichaYa',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Preparando tu acceso…',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.of(
                              context,
                            ).foreground(const Color(0xFFD2E5F0)),
                            fontSize: 14,
                          ),
                        ),
                      ],
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
}
