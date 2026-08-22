import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controllers.dart';
import '../../app/app_theme.dart';
import '../../core/api/usage_repository.dart';
import '../../shared/ui.dart';
import '../auth/auth.dart';
import '../subscription/pro_preview_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themePreferenceProvider);
    final user = ref.watch(authControllerProvider).user;
    final usage = ref.watch(usageOverviewProvider);
    final usageOverview = usage.value;
    return Scaffold(
      body: PageBody(
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
          SizedBox(height: context.spacing.sm),
          Text(
            user?.email ?? 'Signed in',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          SectionTitle(
            usageOverview == null
                ? 'Plan usage'
                : '${_planName(usageOverview.planKey)} plan usage',
          ),
          usage.when(
            data: (overview) => _UsageCard(overview: overview),
            loading: () => const _UsageLoadingCard(),
            error: (error, stackTrace) => _UsageErrorCard(
              message: error is UsageFailure
                  ? error.message
                  : 'Usage could not be loaded.',
              onRetry: error is! UsageFailure || error.retryable
                  ? () => ref.invalidate(usageOverviewProvider)
                  : null,
            ),
          ),
          SizedBox(height: context.spacing.md),
          AppListTile(
            leading: Icons.workspace_premium_outlined,
            title: 'Pocket Speech Pro',
            subtitle: 'Coming soon',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              appPageRoute<void>(
                context,
                builder: (context) => ProPreviewScreen(
                  onClose: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
          const SectionTitle('Storage'),
          const AppListTile(
            leading: Icons.folder_outlined,
            title: 'Download location',
            subtitle: 'Export setup is next. App-private audio remains safe.',
            trailing: Icon(Icons.lock_clock_outlined),
            enabled: false,
          ),
          const SectionTitle('Appearance'),
          Semantics(
            label: 'Appearance selection',
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_outlined),
                    label: Text('System'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('Light'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('Dark'),
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: (selection) => ref
                    .read(themePreferenceProvider.notifier)
                    .setMode(selection.single),
              ),
            ),
          ),
          const SectionTitle('Guidance and privacy'),
          AppListTile(
            leading: Icons.replay,
            title: 'Replay onboarding',
            subtitle: 'Review local storage and temporary processing.',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => ref.read(onboardingCompleteProvider.notifier).replay(),
          ),
          SizedBox(height: context.spacing.sm),
          const AppListTile(
            leading: Icons.privacy_tip_outlined,
            title: 'Privacy summary',
            subtitle:
                'Voice Profiles and generated audio stay on-device. '
                'Reference recordings, text, and results are processed '
                'temporarily and are not retained by the backend. Uninstalling '
                'or clearing app data can permanently remove local content.',
          ),
          const SectionTitle('Account'),
          AppListTile(
            leading: Icons.logout,
            title: 'Sign out',
            subtitle: 'Local content remains isolated to this Google identity.',
            onTap: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
          SizedBox(height: context.spacing.xl),
          Text(
            'Pocket Speech 1.0.0 • Voice model not installed',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          SizedBox(height: context.spacing.xl),
        ],
      ),
    );
  }
}

String _planName(String planKey) {
  if (planKey.isEmpty) return 'Current';
  return '${planKey[0].toUpperCase()}${planKey.substring(1)}';
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.overview});

  final UsageOverview overview;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(context.spacing.lg),
        child: Column(
          children: [
            _UsageRow(
              icon: Icons.timelapse,
              label: 'Generated duration',
              value: _seconds(overview.usage.generatedMs),
              limit: 'of ${_seconds(overview.policy.monthlyGenerationLimitMs)}',
            ),
            const Divider(height: 28),
            _UsageRow(
              icon: Icons.mic_none,
              label: 'Monthly clones',
              value: '${overview.usage.successfulClones}',
              limit: 'of ${overview.policy.monthlyCloneLimit}',
            ),
            const Divider(height: 28),
            _UsageRow(
              icon: Icons.record_voice_over_outlined,
              label: 'Active Voice Profiles',
              value: '${overview.usage.activeVoices}',
              limit: 'of ${overview.policy.activeVoiceLimit}',
            ),
            const Divider(height: 28),
            _UsageRow(
              icon: Icons.event_repeat,
              label: 'Renews',
              value: _date(overview.usage.periodEnd),
              limit: 'UTC',
            ),
          ],
        ),
      ),
    );
  }

  static String _seconds(int milliseconds) =>
      '${milliseconds ~/ Duration.millisecondsPerSecond} sec';

  static String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class _UsageLoadingCard extends StatelessWidget {
  const _UsageLoadingCard();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: EdgeInsets.all(context.spacing.xl),
      child: Center(
        child: Semantics(
          label: 'Loading plan usage',
          child: const CircularProgressIndicator(),
        ),
      ),
    ),
  );
}

class _UsageErrorCard extends StatelessWidget {
  const _UsageErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(context.spacing.lg),
        child: Column(
          children: [
            Icon(Icons.cloud_off_outlined, color: scheme.error),
            SizedBox(height: context.spacing.sm),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              SizedBox(height: context.spacing.md),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UsageRow extends StatelessWidget {
  const _UsageRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.limit,
  });

  final IconData icon;
  final String label;
  final String value;
  final String limit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: scheme.primary),
        SizedBox(width: context.spacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              SizedBox(height: context.spacing.xs),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TextSpan(
                      text: ' $limit',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
