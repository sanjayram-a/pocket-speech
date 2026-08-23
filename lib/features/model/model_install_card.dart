import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../core/model/pocket_tts_model.dart';
import '../generation/local_tts_service.dart';

class ModelInstallCard extends ConsumerWidget {
  const ModelInstallCard({super.key, this.allowRemoval = false});

  final bool allowRemoval;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(modelInstallControllerProvider);
    final state = asyncState.value;
    final installing =
        !asyncState.hasError &&
        (state?.phase == ModelInstallPhase.downloading ||
            state?.phase == ModelInstallPhase.verifying ||
            state?.phase == ModelInstallPhase.installing);
    final ready = state?.phase == ModelInstallPhase.ready;
    final error = asyncState.error;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(context.spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  ready
                      ? Icons.offline_bolt
                      : Icons.download_for_offline_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: context.spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Offline Voice Engine',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        _statusText(asyncState),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (installing || asyncState.isLoading) ...[
              SizedBox(height: context.spacing.md),
              LinearProgressIndicator(
                key: const Key('model_install_progress'),
                value: state?.phase == ModelInstallPhase.downloading
                    ? state?.progress
                    : null,
              ),
            ],
            if (error != null) ...[
              SizedBox(height: context.spacing.md),
              Semantics(
                liveRegion: true,
                child: Text(
                  error is ModelInstallException
                      ? error.message
                      : 'The voice engine could not be installed.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
              if (error is ModelInstallException && error.detail != null)
                SelectableText(
                  _truncate(error.detail!, 220),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
            if (!ready && !installing && !asyncState.isLoading) ...[
              SizedBox(height: context.spacing.md),
              FilledButton.icon(
                key: const Key('install_model_button'),
                onPressed: () =>
                    ref.read(modelInstallControllerProvider.notifier).install(),
                icon: const Icon(Icons.download),
                label: Text(error == null ? 'Download engine' : 'Try again'),
              ),
            ],
            if (ready && allowRemoval) ...[
              SizedBox(height: context.spacing.md),
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(localTtsServiceProvider).dispose();
                  await ref
                      .read(modelInstallControllerProvider.notifier)
                      .remove();
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove engine'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusText(AsyncValue<ModelInstallState> asyncState) {
    if (asyncState.isLoading) return 'Checking local installation...';
    if (asyncState.hasError) return 'Installation did not complete.';
    final state = asyncState.value;
    return switch (state?.phase) {
      ModelInstallPhase.downloading =>
        '${_megabytes(state!.downloadedBytes)} of '
            '${_megabytes(state.totalBytes)} downloaded',
      ModelInstallPhase.verifying => 'Verifying download integrity...',
      ModelInstallPhase.installing => 'Installing model files...',
      ModelInstallPhase.ready => 'Installed - ${pocketTtsModel.version}',
      ModelInstallPhase.failed => 'Installation failed',
      _ =>
        'Download ${_megabytes(pocketTtsModel.archiveBytes)} once, then '
            'generate completely offline.',
    };
  }

  String _megabytes(int bytes) =>
      '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';

  String _truncate(String value, int maxLength) =>
      value.length <= maxLength ? value : '${value.substring(0, maxLength)}...';
}
