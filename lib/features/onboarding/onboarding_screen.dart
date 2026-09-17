import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controllers.dart';
import '../../app/app_theme.dart';
import '../../shared/brand.dart';
import '../../shared/ui.dart';

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

  Future<void> _finish() =>
      ref.read(onboardingCompleteProvider.notifier).complete();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                  const BrandMark(size: 40),
                  SizedBox(width: context.spacing.md),
                  Text(
                    'Pocket Speech',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Semantics(
                      label: 'Page ${_page + 1} of 2',
                      child: Text(
                        '${_page + 1} / 2',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
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
                  AnimatedSwitcher(
                    duration: context.motion.control,
                    child: _page == 0
                        ? SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              key: const ValueKey('next'),
                              onPressed: _next,
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 20,
                              ),
                              label: const Text('Next'),
                            ),
                          )
                        : SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              key: const ValueKey('start'),
                              onPressed: _finish,
                              icon: const Icon(
                                Icons.auto_awesome_rounded,
                                size: 20,
                              ),
                              label: const Text('Start using Pocket Speech'),
                            ),
                          ),
                  ),
                  if (_page == 1) ...[
                    SizedBox(height: context.spacing.md),
                    Container(
                      padding: EdgeInsets.all(context.spacing.md),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainer.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: scheme.outlineVariant.withValues(alpha: 0.7),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 16,
                            color: scheme.onSurfaceVariant,
                          ),
                          SizedBox(width: context.spacing.sm),
                          Expanded(
                            child: Text(
                              'No account required. The voice engine is downloaded only when you choose to install it.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: context.spacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Dot(active: _page == 0),
                      const SizedBox(width: 8),
                      _Dot(active: _page == 1),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      width: active ? 22 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? scheme.primary : scheme.outlineVariant,
        borderRadius: BorderRadius.circular(100),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.spacing.xl),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          SizedBox(height: context.spacing.xl),
          Container(
            padding: EdgeInsets.all(context.spacing.xl),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: scheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                const Waveform(
                  height: 72,
                  semanticLabel: 'Pocket Speech waveform',
                  animate: true,
                ),
                SizedBox(height: context.spacing.lg),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.offline_bolt_rounded,
                        size: 14,
                        color: scheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Works offline',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: context.spacing.xl),
          Text(
            'Your voice, kept close.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              height: 1.05,
            ),
          ),
          SizedBox(height: context.spacing.md),
          Text(
            'Create a personal Voice Profile and turn your words into speech without giving up ownership of your files.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          SizedBox(height: context.spacing.lg),
          PSCard(
            padding: EdgeInsets.all(context.spacing.md),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 18, color: scheme.primary),
                SizedBox(width: context.spacing.sm),
                Expanded(
                  child: Text(
                    'Private by design — no account, no cloud, no telemetry',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyPage extends StatelessWidget {
  const _PrivacyPage();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.spacing.xl),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              Icons.mobile_friendly_rounded,
              size: 42,
              color: scheme.onPrimaryContainer,
            ),
          ),
          SizedBox(height: context.spacing.lg),
          Text(
            'Private by design',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          SizedBox(height: context.spacing.sm),
          Text(
            'Everything stays on your device. You control your voice.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          SizedBox(height: context.spacing.xl),
          const _PrivacyPoint(
            icon: Icons.folder_outlined,
            title: 'Files stay on this device',
            body:
                'Voice Profiles and generated audio remain in app-private storage.',
          ),
          const _PrivacyPoint(
            icon: Icons.offline_bolt_outlined,
            title: 'On-device generation',
            body: 'After one model download, speech works without internet.',
          ),
          const _PrivacyPoint(
            icon: Icons.verified_user_outlined,
            title: 'Your voice, with consent',
            body: 'Creating a Voice Profile requires an ownership attestation.',
          ),
          SizedBox(height: context.spacing.md),
          Container(
            padding: EdgeInsets.all(context.spacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFFDFF5E1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFB6E3B9)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_rounded,
                  size: 18,
                  color: Color(0xFF1B5E20),
                ),
                SizedBox(width: context.spacing.sm),
                Expanded(
                  child: Text(
                    'You can delete any voice or audio instantly. No traces left behind.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF1B5E20),
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: context.spacing.lg),
      child: PSCard(
        padding: EdgeInsets.all(context.spacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: scheme.onPrimaryContainer, size: 20),
            ),
            SizedBox(width: context.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: context.spacing.xs),
                  Text(
                    body,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
