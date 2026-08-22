import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../shared/ui.dart';

class VoicesScreen extends StatelessWidget {
  const VoicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageBody(
        children: [
          Text(
            'Voice Profiles',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          SizedBox(height: context.spacing.sm),
          Text(
            'Private voice states stored on this device.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: context.spacing.xl),
          EmptyStateCard(
            icon: Icons.record_voice_over_outlined,
            title: 'Make this voice yours',
            message:
                'Your Voice Profiles will appear here. Recording and '
                'temporary processing are coming in the next build.',
            action: FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.add),
              label: const Text('Create Voice Profile'),
            ),
          ),
        ],
      ),
    );
  }
}
