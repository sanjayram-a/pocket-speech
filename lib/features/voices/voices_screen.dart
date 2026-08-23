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

  Future<void> _togglePreview(VoiceProfile profile) async {
    try {
      final player = _player ??= AudioPlayer();
      _playerSubscription ??= player.playerStateStream.listen((state) {
        if (!mounted) return;
        if (state.processingState == ProcessingState.completed) {
          player.seek(Duration.zero);
          player.pause();
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Voice Profile?'),
        content: Text(
          '${profile.name} and its reference recording will be permanently '
          'deleted. Existing generated audio will remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
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
    return Scaffold(
      body: PageBody(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Voice Profiles',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    SizedBox(height: context.spacing.sm),
                    Text(
                      'Private reference recordings stored on this device.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filled(
                tooltip: 'Create Voice Profile',
                onPressed: _createVoice,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          if (_failure case final failure?) ...[
            SizedBox(height: context.spacing.md),
            Text(
              failure,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          SizedBox(height: context.spacing.xl),
          SizedBox(height: context.spacing.lg),
          SectionTitle('Your Voice Profiles'),
          switch (profiles) {
            AsyncData(value: final items) when items.isEmpty => EmptyStateCard(
              icon: Icons.record_voice_over_outlined,
              title: 'Make this voice yours',
              message:
                  'Record 5-12 seconds of clear speech to create a local '
                  'Voice Profile.',
              action: FilledButton.icon(
                onPressed: _createVoice,
                icon: const Icon(Icons.mic),
                label: const Text('Record Voice Profile'),
              ),
            ),
            AsyncData(value: final items) => Column(
              children: items
                  .map(
                    (profile) => Card(
                      child: ListTile(
                        onTap: () => ref
                            .read(selectedVoiceIdProvider.notifier)
                            .select(profile.id),
                        leading: IconButton.filledTonal(
                          tooltip:
                              _playingId == profile.id &&
                                  (_player?.playing ?? false)
                              ? 'Pause reference'
                              : 'Play reference',
                          onPressed: () => _togglePreview(profile),
                          icon: Icon(
                            _playingId == profile.id &&
                                    (_player?.playing ?? false)
                                ? Icons.pause
                                : Icons.play_arrow,
                          ),
                        ),
                        title: Text(profile.name),
                        subtitle: Text(
                          '${(profile.durationMs / 1000).toStringAsFixed(1)} '
                          'seconds - ${profile.sampleRate} Hz',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (selectedId == profile.id)
                              const Icon(Icons.check_circle),
                            IconButton(
                              tooltip: 'Delete ${profile.name}',
                              onPressed: () => _deleteVoice(profile),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            AsyncError(error: final error) => EmptyStateCard(
              icon: Icons.error_outline,
              title: 'Voice Profiles unavailable',
              message: error is VoiceProfileException
                  ? error.message
                  : 'Voice Profiles could not be opened.',
              action: OutlinedButton.icon(
                onPressed: () => ref.invalidate(voiceProfilesProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ],
      ),
    );
  }
}
