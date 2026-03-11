import 'package:flutter/material.dart';

void showCenteredSnackBar(
  BuildContext context, {
  required String text,
  bool isError = false,
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 3),
  Color? backgroundColor,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }
  final media = MediaQuery.maybeOf(context);
  final bottomMargin = media == null
      ? 280.0
      : (media.size.height * 0.38).clamp(220.0, 420.0).toDouble();

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(text, textAlign: TextAlign.center),
      backgroundColor:
          backgroundColor ?? (isError ? Colors.red.shade700 : Colors.green),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(20, 0, 20, bottomMargin),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      duration: duration,
      action: action,
    ),
  );
}
