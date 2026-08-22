import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controllers.dart';
import '../../app/app_theme.dart';
import '../../shared/brand.dart';
import '../auth/auth.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  var _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _pageController.jumpToPage(1);
      return;
    }
    await _pageController.animateToPage(
      1,
      duration: context.motion.transition,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _continueWithGoogle() async {
    final success = await ref
        .read(authControllerProvider.notifier)
        .signInWithGoogle();
    if (success) {
      await ref.read(onboardingCompleteProvider.notifier).complete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.spacing.lg,
                context.spacing.lg,
                context.spacing.lg,
                0,
              ),
              child: Row(
                children: [
                  const BrandMark(size: 44),
                  SizedBox(width: context.spacing.md),
                  Text(
                    'Pocket Speech',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  Semantics(
                    label: 'Page ${_page + 1} of 2',
                    child: Text('${_page + 1} / 2'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (value) => setState(() => _page = value),
                children: const [_WelcomePage(), _PrivacyPage()],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.spacing.lg,
                context.spacing.sm,
                context.spacing.lg,
                context.spacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (auth.failure case final failure?) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        failure.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    SizedBox(height: context.spacing.sm),
                  ],
                  if (_page == 0)
                    FilledButton(onPressed: _next, child: const Text('Next'))
                  else
                    FilledButton.icon(
                      onPressed: auth.phase == AuthPhase.authenticating
                          ? null
                          : _continueWithGoogle,
                      icon: auth.phase == AuthPhase.authenticating
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: const Text('Continue with Google'),
                    ),
                  if (_page == 1) ...[
                    SizedBox(height: context.spacing.sm),
                    Text(
                      'By continuing, you acknowledge the privacy summary. '
                      'Google sign-in is required to use Pocket Speech.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.all(context.spacing.xl),
    child: Column(
      children: [
        SizedBox(height: context.spacing.xxl),
        const Waveform(height: 100, semanticLabel: 'Pocket Speech waveform'),
        SizedBox(height: context.spacing.xxl),
        Text(
          'Your voice, kept close.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall,
        ),
        SizedBox(height: context.spacing.lg),
        Text(
          'Create a personal Voice Profile and turn your words into speech '
          'without giving up ownership of your files.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class _PrivacyPage extends StatelessWidget {
  const _PrivacyPage();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.all(context.spacing.xl),
    child: Column(
      children: [
        SizedBox(height: context.spacing.xl),
        Icon(
          Icons.mobile_friendly,
          size: 72,
          color: Theme.of(context).colorScheme.primary,
        ),
        SizedBox(height: context.spacing.xl),
        Text(
          'Private by design',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        SizedBox(height: context.spacing.lg),
        const _PrivacyPoint(
          icon: Icons.folder_outlined,
          title: 'Files stay on this device',
          body: 'Voice Profiles and generated audio remain in app storage.',
        ),
        const _PrivacyPoint(
          icon: Icons.cloud_sync_outlined,
          title: 'Temporary cloud processing',
          body: 'Audio and text are processed only to create your result.',
        ),
        const _PrivacyPoint(
          icon: Icons.verified_user_outlined,
          title: 'Your voice, with consent',
          body:
              'Creating a Voice Profile will require an ownership attestation.',
        ),
      ],
    ),
  );
}

class _PrivacyPoint extends StatelessWidget {
  const _PrivacyPoint({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: context.spacing.lg),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        SizedBox(width: context.spacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: context.spacing.xs),
              Text(body),
            ],
          ),
        ),
      ],
    ),
  );
}
