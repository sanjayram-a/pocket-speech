import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../shared/ui.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageBody(
        children: [
          Text('History', style: Theme.of(context).textTheme.headlineMedium),
          SizedBox(height: context.spacing.sm),
          Text(
            'Generated audio saved locally on this device.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: context.spacing.xl),
          const EmptyStateCard(
            icon: Icons.queue_music_outlined,
            title: 'Your audio will live here',
            message:
                'Completed Generations will be available to play, rename, '
                'export, and delete.',
          ),
        ],
      ),
    );
  }
}
