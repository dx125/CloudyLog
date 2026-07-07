import 'package:flutter/material.dart';

import '../../branding/gust.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/puff_theme.dart';

/// Phase 2 teaser (see Documentation/TODO.md). The tab exists because the
/// design book's nav includes it; the feature doesn't yet.
class DuelsScreen extends StatelessWidget {
  const DuelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final puff = context.puff;

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FloatingGust(
                child: Gust(body: puff.action, face: puff.canvas, size: 130),
              ),
              const SizedBox(height: 22),
              Text(
                strings.duelsComingSoon,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                strings.duelsComingSoonBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
