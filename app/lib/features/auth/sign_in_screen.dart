import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../shared/brand.dart';
import 'auth.dart';

class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(context.spacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                children: [
                  const BrandMark(size: 64),
                  SizedBox(height: context.spacing.xl),
                  Text(
                    'Welcome back',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: context.spacing.sm),
                  Text(
                    'Sign in to open your identity-scoped Pocket Speech library.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (auth.failure case final failure?) ...[
                    SizedBox(height: context.spacing.xl),
                    Semantics(
                      liveRegion: true,
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(context.spacing.lg),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: context.shapes.control,
                        ),
                        child: Text(
                          failure.message,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: context.spacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: auth.phase == AuthPhase.authenticating
                          ? null
                          : () => ref
                                .read(authControllerProvider.notifier)
                                .signInWithGoogle(),
                      icon: auth.phase == AuthPhase.authenticating
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: const Text('Continue with Google'),
                    ),
                  ),
                  SizedBox(height: context.spacing.md),
                  Text(
                    'Authentication is required. There is no guest mode.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
