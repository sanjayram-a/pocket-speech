import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controllers.dart';
import '../../app/app_theme.dart';
import '../../shared/ui.dart';
import '../model/model_install_card.dart';
import 'export_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themePreferenceProvider);
    return Scaffold(
      body: PageBody(
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
          SizedBox(height: context.spacing.sm),
          Text(
            'Local-only preferences and storage',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SectionTitle('Voice engine'),
          const ModelInstallCard(allowRemoval: true),
          const SectionTitle('Storage'),
          const _DownloadLocationTile(),
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
          const AppListTile(
            leading: Icons.record_voice_over_outlined,
            title: 'Built-in voices',
            subtitle:
                'Alba (CC BY 4.0, Alba MacKenna), Fantine (CC BY 4.0, VCTK), '
                'Javert (CC0, Kyutai voice donation), Bill Boerst '
                'and Caro Davy (CC0, LibriVox via Voice-Zero).',
          ),
          AppListTile(
            leading: Icons.replay,
            title: 'Replay onboarding',
            subtitle: 'Review local storage and offline processing.',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => ref.read(onboardingCompleteProvider.notifier).replay(),
          ),
          SizedBox(height: context.spacing.sm),
          const AppListTile(
            leading: Icons.privacy_tip_outlined,
            title: 'Privacy summary',
            subtitle:
                'Reference recordings, generated speech, and text remain on '
                'this device. Uninstalling or clearing app data removes local '
                'content and the downloaded voice engine.',
          ),
          SizedBox(height: context.spacing.xl),
          Text(
            'Pocket Speech 1.0.0',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          SizedBox(height: context.spacing.xl),
        ],
      ),
    );
  }
}

class _DownloadLocationTile extends ConsumerWidget {
  const _DownloadLocationTile();

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final destination = await ref
          .read(exportRepositoryProvider)
          .selectDestination();
      ref.invalidate(exportDestinationProvider);
      if (destination != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Exports will be saved to ${destination.name}'),
          ),
        );
      }
    } on ExportException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _manage(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_folder_upload_outlined),
              title: const Text('Change folder'),
              onTap: () => Navigator.pop(sheetContext, 'change'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_off_outlined),
              title: const Text('Clear location'),
              onTap: () => Navigator.pop(sheetContext, 'clear'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    final messenger = ScaffoldMessenger.of(context);
    if (action == 'change') {
      await _pick(context, ref);
      return;
    }
    try {
      await ref.read(exportRepositoryProvider).clearDestination();
      ref.invalidate(exportDestinationProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Download location cleared')),
      );
    } on Object {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('The download location could not be cleared.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = ref.watch(exportDestinationProvider);
    final hasDestination = destination.value != null;
    final subtitle = destination.when(
      data: (value) => value?.name ?? 'Choose where exported audio is saved',
      loading: () => 'Checking saved location...',
      error: (_, _) => 'Choose where exported audio is saved',
    );
    return AppListTile(
      key: const Key('download_location_tile'),
      leading: Icons.folder_outlined,
      title: 'Download location',
      subtitle: subtitle,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => hasDestination ? _manage(context, ref) : _pick(context, ref),
    );
  }
}
