import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../core/model/pocket_tts_model.dart';
import '../../shared/ui.dart';
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
    final scheme = Theme.of(context).colorScheme;

    return PSCard(
      padding: EdgeInsets.all(context.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: ready
                      ? const Color(0xFFDFF5E1)
                      : scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  ready
                      ? Icons.offline_bolt
                      : Icons.download_for_offline_outlined,
                  color: ready
                      ? const Color(0xFF1B5E20)
                      : scheme.onPrimaryContainer,
                  size: 24,
                ),
              ),
              SizedBox(width: context.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Offline Voice Engine',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _statusText(asyncState),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (ready)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDFF5E1),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 14,
                        color: Color(0xFF1B5E20),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Ready',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF1B5E20),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (installing || asyncState.isLoading) ...[
            SizedBox(height: context.spacing.lg),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                key: const Key('model_install_progress'),
                value: state?.phase == ModelInstallPhase.downloading
                    ? state?.progress
                    : null,
                minHeight: 6,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
              ),
            ),
            if (state?.phase == ModelInstallPhase.downloading) ...[
              SizedBox(height: context.spacing.sm),
              Text(
                '${_megabytes(state!.downloadedBytes)} / ${_megabytes(state.totalBytes)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
          if (error != null) ...[
            SizedBox(height: context.spacing.md),
            Container(
              padding: EdgeInsets.all(context.spacing.md),
              decoration: BoxDecoration(
                color: scheme.errorContainer.withValues(alpha: 0.52),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.error.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error_outline, size: 16, color: scheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          error is ModelInstallException
                              ? error.message
                              : 'The voice engine could not be installed.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: scheme.onErrorContainer,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                  if (error is ModelInstallException &&
                      error.detail != null) ...[
                    SizedBox(height: context.spacing.sm),
                    SelectableText(
                      _truncate(error.detail!, 220),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (!ready && !installing && !asyncState.isLoading) ...[
            SizedBox(height: context.spacing.lg),
            FilledButton.icon(
              key: const Key('install_model_button'),
              onPressed: () =>
                  ref.read(modelInstallControllerProvider.notifier).install(),
              icon: const Icon(Icons.download_rounded, size: 20),
              label: Text(error == null ? 'Download engine' : 'Try again'),
            ),
            SizedBox(height: context.spacing.sm),
            Text(
              'One-time download • Works offline after install',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
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
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Remove engine'),
            ),
          ],
        ],
      ),
    );
  }

  String _statusText(AsyncValue<ModelInstallState> asyncState) {
    if (asyncState.isLoading) return 'Checking local installation…';
    if (asyncState.hasError) return 'Installation did not complete.';
    final state = asyncState.value;
    return switch (state?.phase) {
      ModelInstallPhase.downloading =>
        '${_megabytes(state!.downloadedBytes)} of ${_megabytes(state.totalBytes)} downloaded',
      ModelInstallPhase.verifying => 'Verifying download integrity…',
      ModelInstallPhase.installing => 'Installing model files…',
      ModelInstallPhase.ready =>
        'Installed • ${pocketTtsModel.version} • Offline ready',
      ModelInstallPhase.failed => 'Installation failed',
      _ =>
        'Download ${_megabytes(pocketTtsModel.archiveBytes)} once, then '
            'generate completely offline. Optional high-fidelity decoder adds '
            '${_megabytes(pocketTtsFp32Decoder.bytes)}.',
    };
  }

  String _megabytes(int bytes) =>
      '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';

  String _truncate(String value, int maxLength) =>
      value.length <= maxLength ? value : '${value.substring(0, maxLength)}…';
}
