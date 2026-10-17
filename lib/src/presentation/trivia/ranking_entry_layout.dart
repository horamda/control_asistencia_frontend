import 'package:flutter/material.dart';

/// Keeps names and scores readable without a fixed-height trailing slot.
class RankingEntryLayout extends StatelessWidget {
  const RankingEntryLayout({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });
  final Widget leading, title, subtitle, trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(14),
    child: LayoutBuilder(
      builder: (context, box) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final identity = Column(
          mainAxisSize: MainAxisSize.min,
          children: [title, const SizedBox(height: 6), subtitle],
        );
        if (box.maxWidth < 480 * scale) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              leading,
              const SizedBox(height: 8),
              identity,
              const SizedBox(height: 12),
              trailing,
            ],
          );
        }
        return Row(
          children: [
            leading,
            const SizedBox(width: 14),
            Expanded(child: identity),
            const SizedBox(width: 14),
            Flexible(child: trailing),
          ],
        );
      },
    ),
  );
}
