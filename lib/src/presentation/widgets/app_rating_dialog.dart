import 'package:flutter/material.dart';

import '../../core/feedback/app_rating_service.dart';

/// Shows a 1–5 star in-app rating dialog.
///
/// Usage:
/// ```dart
/// if (await ratingService.shouldShowDialog()) {
///   if (context.mounted) {
///     await showAppRatingDialog(context, ratingService: ratingService, pantalla: 'home');
///   }
/// }
/// ```
Future<void> showAppRatingDialog(
  BuildContext context, {
  required AppRatingService ratingService,
  String? pantalla,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AppRatingDialog(
      ratingService: ratingService,
      pantalla: pantalla,
    ),
  );
}

class _AppRatingDialog extends StatefulWidget {
  const _AppRatingDialog({
    required this.ratingService,
    this.pantalla,
  });

  final AppRatingService ratingService;
  final String? pantalla;

  @override
  State<_AppRatingDialog> createState() => _AppRatingDialogState();
}

class _AppRatingDialogState extends State<_AppRatingDialog> {
  int _selectedStars = 0;
  final _commentController = TextEditingController();
  bool _sending = false;
  bool _done = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedStars == 0 || _sending) return;
    setState(() => _sending = true);
    final ok = await widget.ratingService.submitRating(
      puntuacion: _selectedStars,
      comentario: _commentController.text.trim().isEmpty
          ? null
          : _commentController.text.trim(),
      pantalla: widget.pantalla,
    );
    if (!mounted) return;
    if (ok) {
      setState(() {
        _done = true;
        _sending = false;
      });
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (mounted) Navigator.of(context).pop();
    } else {
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo enviar la calificación. Intentá más tarde.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _dismiss() async {
    await widget.ratingService.markDismissed();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      content: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _done ? _buildSuccess(theme) : _buildForm(theme),
      ),
    );
  }

  Widget _buildSuccess(ThemeData theme) {
    return SizedBox(
      key: const ValueKey('success'),
      height: 140,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 52),
          const SizedBox(height: 12),
          Text(
            '¡Gracias por tu opinión!',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildForm(ThemeData theme) {
    return SizedBox(
      key: const ValueKey('form'),
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '¿Cómo calificás tu experiencia\ncon la app?',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final star = index + 1;
              return GestureDetector(
                onTap: () => setState(() => _selectedStars = star),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    star <= _selectedStars ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 40,
                    color: star <= _selectedStars
                        ? Colors.amber.shade600
                        : Colors.grey.shade400,
                  ),
                ),
              );
            }),
          ),
          if (_selectedStars > 0) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: _selectedStars >= 4
                    ? '¿Qué fue lo que más te gustó?'
                    : '¿Qué mejorarías?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: _sending ? null : _dismiss,
                child: const Text('Ahora no'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _selectedStars == 0 || _sending ? null : _submit,
                child: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Enviar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
