import 'package:flutter/material.dart';
import '../theme/app_layout.dart';
import '../theme/app_visual.dart';
import 'app_page_layout.dart';

/// Keeps submission controls reachable on short screens and with large text.
class AppSubmissionBar extends StatelessWidget {
  const AppSubmissionBar({
    super.key,
    required this.summary,
    required this.actions,
  });
  final String summary;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    elevation: 2,
    child: SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .4,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!AppLayout.keyboardVisible(context)) ...[
                    Text(
                      summary,
                      style: AppVisual.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                  ],
                  AppAdaptiveActions(children: actions),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
