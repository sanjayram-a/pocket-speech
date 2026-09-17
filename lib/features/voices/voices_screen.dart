import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../app/app_theme.dart';
import '../../shared/ui.dart';
import '../generation/local_tts_service.dart';
import 'voice_profile_repository.dart';
import 'voice_recorder_screen.dart';

class VoicesScreen extends ConsumerStatefulWidget {
  const VoicesScreen({super.key});

  @override
  ConsumerState<VoicesScreen> createState() => _VoicesScreenState();
}

class _VoicesScreenState extends ConsumerState<VoicesScreen> {
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _playerSubscription;
  String? _playingId;
  String? _failure;

  Future<void> _createVoice() async {
    final profile = await Navigator.of(context).push<VoiceProfile>(
      MaterialPageRoute(builder: (_) => const VoiceRecorderScreen()),
    );
    if (profile == null) return;
    await ref.read(selectedVoiceIdProvider.notifier).select(profile.id);
    ref.invalidate(voiceProfilesProvider);
  }

  Future<void> _renameVoice(VoiceProfile profile) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initialName: profile.name),
    );
    if (result == null) return;
    final trimmed = result.trim();
    if (trimmed.isEmpty || trimmed == profile.name) return;
    try {
      await ref.read(voiceProfileRepositoryProvider).rename(profile, trimmed);
      ref.invalidate(voiceProfilesProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Renamed to “$trimmed”')));
      }
    } on VoiceProfileException catch (error) {
      if (mounted) setState(() => _failure = error.message);
    }
  }

  Future<void> _togglePreview(VoiceProfile profile) async {
    try {
      final player = _player ??= AudioPlayer();
      _playerSubscription ??= player.playerStateStream.listen((state) async {
        if (!mounted) return;
        if (state.processingState == ProcessingState.completed) {
          // Pause first, then rewind — seeking while still playing would
          // replay the start of the clip for a moment.
          await player.pause();
          await player.seek(Duration.zero);
        }
        setState(() {});
      });
      if (_playingId == profile.id) {
        if (player.playing) {
          await player.pause();
        } else {
          await player.play();
        }
      } else {
        await player.stop();
        await player.setFilePath(profile.referencePath);
        _playingId = profile.id;
        if (mounted) setState(() => _failure = null);
        await player.play();
      }
    } on Object {
      if (mounted) setState(() => _failure = 'The recording could not play.');
    }
  }

  Future<void> _deleteVoice(VoiceProfile profile) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.delete_outline_rounded,
            color: scheme.onErrorContainer,
          ),
        ),
        title: const Text('Delete Voice Profile?', textAlign: TextAlign.center),
        content: Text(
          '${profile.name} and its reference recording will be permanently deleted. Existing generated audio will remain.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      if (_playingId == profile.id) {
        await _player?.stop();
        _playingId = null;
      }
      await ref.read(localTtsServiceProvider).dispose();
      await ref.read(voiceProfileRepositoryProvider).delete(profile);
      if (ref.read(selectedVoiceIdProvider) == profile.id) {
        await ref.read(selectedVoiceIdProvider.notifier).select(null);
      }
      ref.invalidate(voiceProfilesProvider);
    } on VoiceProfileException catch (error) {
      if (mounted) setState(() => _failure = error.message);
    }
  }

  @override
  void dispose() {
    unawaited(_playerSubscription?.cancel());
    unawaited(_player?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(voiceProfilesProvider);
    final selectedId = ref.watch(selectedVoiceIdProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: PageBody(
        children: [
          PageHeader(
            title: 'Voice Profiles',
            subtitle:
                'Private reference recordings stored only on this device.',
            icon: Icons.record_voice_over_rounded,
            trailing: FilledButton.icon(
              onPressed: _createVoice,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('New'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                minimumSize: const Size(0, 44),
              ),
            ),
          ),
          if (_failure case final failure?) ...[
            SizedBox(height: context.spacing.md),
            Container(
              padding: EdgeInsets.all(context.spacing.md),
              decoration: BoxDecoration(
                color: scheme.errorContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.error.withValues(alpha: 0.16)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: scheme.error,
                    size: 18,
                  ),
                  SizedBox(width: context.spacing.sm),
                  Expanded(
                    child: Text(
                      failure,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => setState(() => _failure = null),
                    tooltip: 'Dismiss',
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: context.spacing.xl),
          switch (profiles) {
            AsyncData(value: final items) when items.isEmpty => EmptyStateCard(
              icon: Icons.record_voice_over_outlined,
              title: 'Make this voice yours',
              message:
                  'Record 5–12 seconds of clear speech in a quiet room to create a local Voice Profile.',
              action: FilledButton.icon(
                onPressed: _createVoice,
                icon: const Icon(Icons.mic_rounded),
                label: const Text('Record Voice Profile'),
              ),
            ),
            AsyncData(value: final items) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${items.length} profile${items.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                SizedBox(height: context.spacing.md),
                SeparatedColumn(
                  gap: 12,
                  children: items.map((profile) {
                    final isSelected = selectedId == profile.id;
                    final isPlaying =
                        _playingId == profile.id && (_player?.playing ?? false);
                    return PSCard(
                      padding: EdgeInsets.all(context.spacing.md),
                      child: Row(
                        children: [
                          // Play button
                          Material(
                            color: isPlaying
                                ? scheme.primary
                                : scheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: () => _togglePreview(profile),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isPlaying
                                        ? Colors.transparent
                                        : scheme.outlineVariant,
                                    width: 1,
                                  ),
                                ),
                                child: Icon(
                                  isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 26,
                                  color: isPlaying
                                      ? scheme.onPrimary
                                      : scheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: context.spacing.md),
                          Expanded(
                            child: InkWell(
                              onTap: () => ref
                                  .read(selectedVoiceIdProvider.notifier)
                                  .select(profile.id),
                              borderRadius: BorderRadius.circular(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          profile.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                height: 1.15,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isSelected)
                                        Container(
                                          margin: const EdgeInsets.only(
                                            left: 8,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: scheme.primary,
                                            borderRadius: BorderRadius.circular(
                                              100,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check_rounded,
                                                size: 12,
                                                color: scheme.onPrimary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Active',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: scheme.onPrimary,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 11,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.timer_outlined,
                                        size: 13,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${(profile.durationMs / 1000).toStringAsFixed(1)}s',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 3,
                                        height: 3,
                                        decoration: BoxDecoration(
                                          color: scheme.outline,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${profile.sampleRate} Hz',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 3,
                                        height: 3,
                                        decoration: BoxDecoration(
                                          color: scheme.outline,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'WAV',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                              letterSpacing: 0.8,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: context.spacing.sm),
                          PopupMenuButton<String>(
                            tooltip: 'More actions',
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            onSelected: (value) {
                              if (value == 'rename') {
                                _renameVoice(profile);
                              }
                              if (value == 'delete') {
                                _deleteVoice(profile);
                              }
                              if (value == 'select') {
                                ref
                                    .read(selectedVoiceIdProvider.notifier)
                                    .select(profile.id);
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'select',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 18,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 10),
                                    const Text('Use this voice'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'rename',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 10),
                                    const Text('Rename'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: scheme.error,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Delete',
                                      style: TextStyle(color: scheme.error),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: scheme.outlineVariant,
                                ),
                              ),
                              child: const Icon(
                                Icons.more_horiz_rounded,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: context.spacing.md),
                Container(
                  padding: EdgeInsets.all(context.spacing.md),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.6),
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
                          'Tap a profile to use it for generation. Active voice is remembered on device.',
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
            ),
            AsyncError(error: final error) => EmptyStateCard(
              icon: Icons.error_outline,
              title: 'Voice Profiles unavailable',
              message: error is VoiceProfileException
                  ? error.message
                  : 'Voice Profiles could not be opened.',
              action: OutlinedButton.icon(
                onPressed: () => ref.invalidate(voiceProfilesProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ),
            _ => PSCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  ),
                  SizedBox(width: context.spacing.md),
                  Text(
                    'Loading voices…',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          },
        ],
      ),
    );
  }
}

/// Owns its TextEditingController so it is disposed only when the dialog
/// route has fully left the tree (after the exit animation), never while the
/// TextField is still rebuilding.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.edit_rounded,
              size: 18,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          const Text('Rename voice'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Give your Voice Profile a clear, private name.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Profile name',
              hintText: 'e.g. My warm voice',
              counterText: '',
              prefixIcon: const Icon(Icons.person_outline_rounded),
              filled: true,
              fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
            ),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
