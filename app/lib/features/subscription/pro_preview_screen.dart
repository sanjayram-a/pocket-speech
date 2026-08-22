import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controllers.dart';
import '../../app/app_theme.dart';
import '../../shared/brand.dart';

class ProPreviewScreen extends ConsumerWidget {
  const ProPreviewScreen({super.key, this.onClose});

  final VoidCallback? onClose;

  void _finish(WidgetRef ref) {
    if (onClose case final callback?) {
      callback();
    } else {
      ref.read(proPreviewCompleteProvider.notifier).complete();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pocket Speech Pro'),
        actions: [
          TextButton(onPressed: () => _finish(ref), child: const Text('Skip')),
          SizedBox(width: context.spacing.sm),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.all(context.spacing.lg),
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(context.spacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BrandMark(),
                    SizedBox(height: context.spacing.xl),
                    Text(
                      'More room for every voice.',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    SizedBox(height: context.spacing.sm),
                    Text(
                      'Pro is being shaped for people who create more often.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: context.spacing.xl),
                    const _Benefit(
                      icon: Icons.graphic_eq,
                      text: 'Longer generations',
                    ),
                    const _Benefit(
                      icon: Icons.library_music_outlined,
                      text: 'More Voice Profiles',
                    ),
                    const _Benefit(
                      icon: Icons.speed,
                      text: 'Expanded monthly Usage',
                    ),
                    SizedBox(height: context.spacing.xl),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(context.spacing.lg),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: context.shapes.control,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Coming soon',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                                ),
                          ),
                          SizedBox(height: context.spacing.xs),
                          Text(
                            'Purchases are not enabled in this preview.',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: context.spacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: null,
                        child: const Text('Coming soon'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: context.spacing.lg),
            OutlinedButton(
              onPressed: () => _finish(ref),
              child: const Text('Continue with Free'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: context.spacing.md),
    child: Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        SizedBox(width: context.spacing.md),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
