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
      _playerSubscription ??= player.playerStateStream.listen((state) {
        if (!mounted) return;
        if (state.processingState == ProcessingState.completed) {
          player.seek(Duration.zero);
          player.pause();
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
    return Scaffold(
      body: PageBody(
        children: [
          Text('History', style: Theme.of(context).textTheme.headlineMedium),
          SizedBox(height: context.spacing.sm),
          Text(
            'Generated WAV audio saved locally on this device.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (_failure case final failure?) ...[
            SizedBox(height: context.spacing.lg),
            Text(
              failure,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          SizedBox(height: context.spacing.xl),
          switch (history) {
            AsyncData(value: final records) when records.isEmpty =>
              const EmptyStateCard(
                icon: Icons.queue_music_outlined,
                title: 'Your audio will live here',
                message:
                    'Completed Generations will be available to play and '
                    'delete.',
              ),
            AsyncData(value: final records) => Column(
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
            AsyncError(error: final error) => EmptyStateCard(
              icon: Icons.error_outline,
              title: 'History unavailable',
              message: error is GenerationHistoryException
                  ? error.message
                  : 'Saved audio history could not be opened.',
              action: OutlinedButton.icon(
                onPressed: () => ref.invalidate(generationHistoryProvider),
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
    return Card(
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: context.spacing.md,
          vertical: context.spacing.sm,
        ),
        leading: IconButton.filledTonal(
          tooltip: playing ? 'Pause audio' : 'Play audio',
          onPressed: onPlay,
          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
        ),
        title: Text(_title(record.createdAt)),
        subtitle: Text(
          '${_duration(record.durationMs)} - ${record.sampleRate} Hz WAV',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Export audio',
              onPressed: onExport,
              icon: const Icon(Icons.save_alt),
            ),
            IconButton(
              tooltip: 'Delete audio',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

  String _title(DateTime value) {
    final local = value.toLocal();
    return 'Generation ${local.year}-${_two(local.month)}-${_two(local.day)} '
        '${_two(local.hour)}:${_two(local.minute)}';
  }

  String _duration(int milliseconds) {
    final seconds = (milliseconds / 1000).ceil();
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '$minutes:${_two(remainder)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}
