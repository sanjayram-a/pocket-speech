import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../app/app_theme.dart';
import '../../shared/ui.dart';
import '../settings/export_repository.dart';
import 'generation_history_repository.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _playerSubscription;
  String? _activeId;
  String? _failure;

  bool get _isPlaying => _player?.playing ?? false;

  Future<void> _toggle(GenerationRecord record) async {
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

      if (_activeId == record.id) {
        if (player.playing) {
          await player.pause();
        } else {
          await player.play();
        }
      } else {
        await player.stop();
        await player.setFilePath(record.audioPath);
        _activeId = record.id;
        if (mounted) setState(() => _failure = null);
        await player.play();
      }
    } on Object {
      if (mounted) {
        setState(() => _failure = 'This audio file could not be played.');
      }
    }
  }

  Future<void> _export(GenerationRecord record) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repository = ref.read(exportRepositoryProvider);
      var destination = await repository.current();
      destination ??= await repository.selectDestination();
      if (destination == null) return;
      if (!mounted) return;
      ref.invalidate(exportDestinationProvider);
      final fileName = await repository.exportWav(
        fileName: _exportFileName(record),
        bytes: await File(record.audioPath).readAsBytes(),
        destination: destination,
      );
      messenger.showSnackBar(
        SnackBar(content: Text('Saved $fileName to ${destination.name}')),
      );
    } on ExportException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('Audio could not be exported.')),
      );
    }
  }

  Future<void> _delete(GenerationRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Delete generation?'),
          content: Text(
            'This audio will be permanently removed from this device.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    try {
      if (_activeId == record.id) {
        await _player?.stop();
        _activeId = null;
      }
      await ref.read(generationHistoryRepositoryProvider).delete(record);
      ref.invalidate(generationHistoryProvider);
    } on GenerationHistoryException catch (error) {
      if (mounted) setState(() => _failure = error.message);
    }
  }

  @override
  void dispose() {
    unawaited(_playerSubscription?.cancel());
    unawaited(_player?.dispose());
    super.dispose();
  }

  String _exportFileName(GenerationRecord record) {
    final local = record.createdAt.toLocal();
    final stamp =
        '${local.year}${_two(local.month)}${_two(local.day)}-'
        '${_two(local.hour)}${_two(local.minute)}';
    return 'pocket-speech-$stamp.wav';
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(generationHistoryProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: PageBody(
        children: [
          PageHeader(
            title: 'History',
            subtitle: 'Generated WAV audio saved locally on this device.',
            icon: Icons.history_rounded,
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
          switch (history) {
            AsyncData(value: final records) when records.isEmpty =>
              EmptyStateCard(
                icon: Icons.queue_music_outlined,
                title: 'Your audio will live here',
                message:
                    'Completed generations will be available to play, export, and delete. Nothing leaves the device.',
              ),
            AsyncData(value: final records) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        '${records.length} file${records.length == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Private • On-device',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.spacing.md),
                // FIX: SeparatedColumn with gap prevents top/bottom blend; each card is distinct with shadow + gap.
                SeparatedColumn(
                  gap: 14,
                  children: records
                      .map(
                        (record) => _HistoryCard(
                          record: record,
                          playing: _activeId == record.id && _isPlaying,
                          onPlay: () => _toggle(record),
                          onDelete: () => _delete(record),
                          onExport: () => _export(record),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
            AsyncError(error: final error) => EmptyStateCard(
              icon: Icons.error_outline,
              title: 'History unavailable',
              message: error is GenerationHistoryException
                  ? error.message
                  : 'Saved audio history could not be opened.',
              action: OutlinedButton.icon(
                onPressed: () => ref.invalidate(generationHistoryProvider),
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
                    'Loading history…',
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

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.record,
    required this.playing,
    required this.onPlay,
    required this.onDelete,
    required this.onExport,
  });

  final GenerationRecord record;
  final bool playing;
  final VoidCallback onPlay;
  final VoidCallback onDelete;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PSCard(
      padding: EdgeInsets.all(context.spacing.md),
      child: Row(
        children: [
          Material(
            color: playing ? scheme.primary : scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onPlay,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: playing ? Colors.transparent : scheme.outlineVariant,
                    width: 1,
                  ),
                ),
                child: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 26,
                  color: playing ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
            ),
          ),
          SizedBox(width: context.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title(record.createdAt),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                      _duration(record.durationMs),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                      '${record.sampleRate} Hz',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'WAV',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          color: scheme.onSurfaceVariant,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _relativeTime(record.createdAt),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: context.spacing.sm),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RoundIconButton(
                icon: Icons.save_alt_rounded,
                tooltip: 'Export audio',
                onPressed: onExport,
              ),
              SizedBox(width: context.spacing.sm),
              _RoundIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Delete audio',
                onPressed: onDelete,
                destructive: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _title(DateTime value) {
    final local = value.toLocal();
    return 'Generation ${local.year}-${_two(local.month)}-${_two(local.day)} ${_two(local.hour)}:${_two(local.minute)}';
  }

  String _duration(int milliseconds) {
    final seconds = (milliseconds / 1000).ceil();
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '$minutes:${_two(remainder)}';
  }

  String _relativeTime(DateTime value) {
    final now = DateTime.now();
    final diff = now.difference(value);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${value.toLocal().day}/${value.toLocal().month}/${value.toLocal().year}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: destructive
            ? scheme.errorContainer.withValues(alpha: 0.55)
            : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: destructive
                    ? scheme.error.withValues(alpha: 0.18)
                    : scheme.outlineVariant,
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: destructive ? scheme.error : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
