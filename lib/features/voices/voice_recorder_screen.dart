import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';

import '../../app/app_theme.dart';
import '../../shared/ui.dart';
import 'voice_profile_repository.dart';

class VoiceRecorderScreen extends ConsumerStatefulWidget {
  const VoiceRecorderScreen({super.key});

  @override
  ConsumerState<VoiceRecorderScreen> createState() =>
      _VoiceRecorderScreenState();
}

class _VoiceRecorderScreenState extends ConsumerState<VoiceRecorderScreen> {
  final _recorder = AudioRecorder();
  final _nameController = TextEditingController(text: 'My voice');
  late final VoiceProfileRepository _repository;
  AudioPlayer? _player;
  Timer? _timer;
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  String? _recordingPath;
  String? _failure;
  bool _recording = false;
  bool _saving = false;
  bool _consent = false;

  bool get _canSave =>
      !_recording &&
      !_saving &&
      _recordingPath != null &&
      _elapsed >= minimumReferenceDuration &&
      _elapsed <= maximumReferenceDuration + const Duration(milliseconds: 250);

  @override
  void initState() {
    super.initState();
    _repository = ref.read(voiceProfileRepositoryProvider);
  }

  Future<void> _start() async {
    setState(() => _failure = null);
    await _discardRecording();
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        setState(() {
          _failure =
              'Microphone permission is required to create a Voice '
              'Profile.';
        });
      }
      return;
    }
    try {
      final recordingPath = await _repository.createRecordingPath();
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 24000,
          numChannels: 1,
          autoGain: false,
          echoCancel: false,
          noiseSuppress: false,
        ),
        path: recordingPath,
      );
      _startedAt = DateTime.now();
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        final elapsed = DateTime.now().difference(_startedAt!);
        if (elapsed >= maximumReferenceDuration) {
          unawaited(_stop());
        } else if (mounted) {
          setState(() => _elapsed = elapsed);
        }
      });
      if (mounted) {
        setState(() {
          _recordingPath = recordingPath;
          _recording = true;
          _elapsed = Duration.zero;
        });
      }
    } on Object {
      if (mounted) {
        setState(() => _failure = 'Recording could not start on this device.');
      }
    }
  }

  Future<void> _stop() async {
    if (!_recording) return;
    _timer?.cancel();
    _timer = null;
    try {
      final savedPath = await _recorder.stop();
      final elapsed = DateTime.now().difference(_startedAt!);
      if (mounted) {
        setState(() {
          _recording = false;
          _elapsed = elapsed > maximumReferenceDuration
              ? maximumReferenceDuration
              : elapsed;
          _recordingPath = savedPath;
          if (_elapsed < minimumReferenceDuration) {
            _failure = 'Keep speaking for at least 5 seconds.';
          }
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _recording = false;
          _failure = 'Recording could not be completed.';
        });
      }
    }
  }

  Future<void> _preview() async {
    final recordingPath = _recordingPath;
    if (recordingPath == null) return;
    try {
      final player = _player ??= AudioPlayer();
      await player.stop();
      await player.setFilePath(recordingPath);
      await player.play();
    } on Object {
      if (mounted) setState(() => _failure = 'Preview could not be played.');
    }
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await _player?.stop();
      final profile = await _repository.saveRecording(
        name: _nameController.text,
        temporaryPath: _recordingPath!,
      );
      _recordingPath = null;
      if (mounted) Navigator.pop(context, profile);
    } on VoiceProfileException catch (error) {
      if (mounted) setState(() => _failure = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _discardRecording() async {
    _timer?.cancel();
    _timer = null;
    if (_recording) await _recorder.cancel();
    await _player?.stop();
    await _repository.discardRecording(_recordingPath);
    _recordingPath = null;
    _recording = false;
    _elapsed = Duration.zero;
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_disposeResources());
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _disposeResources() async {
    if (_recording) await _recorder.cancel();
    await _player?.dispose();
    await _repository.discardRecording(_recordingPath);
    await _recorder.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = (_elapsed.inMilliseconds / 1000).toStringAsFixed(1);
    return Scaffold(
      appBar: AppBar(title: const Text('New Voice Profile')),
      body: PageBody(
        children: [
          Text(
            _recording ? '$seconds seconds' : 'Record your voice',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall,
          ),
          SizedBox(height: context.spacing.md),
          const Text(
            'Speak naturally in a quiet room for 5-12 seconds. The recording '
            'stays on this device and becomes your Voice Profile.',
            textAlign: TextAlign.center,
          ),
          SizedBox(height: context.spacing.xl),
          CheckboxListTile(
            value: _consent,
            onChanged: _recording || _saving
                ? null
                : (value) => setState(() => _consent = value ?? false),
            title: const Text('I have permission to use this voice'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          SizedBox(height: context.spacing.md),
          if (_recording)
            FilledButton.icon(
              onPressed: _stop,
              icon: const Icon(Icons.stop),
              label: const Text('Stop recording'),
            )
          else if (_recordingPath == null)
            FilledButton.icon(
              key: const Key('start_voice_recording_button'),
              onPressed: _consent ? _start : null,
              icon: const Icon(Icons.mic),
              label: const Text('Start recording'),
            )
          else ...[
            TextField(
              controller: _nameController,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'Profile name'),
            ),
            SizedBox(height: context.spacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _preview,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Preview'),
                  ),
                ),
                SizedBox(width: context.spacing.md),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await _discardRecording();
                      if (mounted) setState(() => _failure = null);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retake'),
                  ),
                ),
              ],
            ),
            SizedBox(height: context.spacing.md),
            FilledButton.icon(
              key: const Key('save_voice_profile_button'),
              onPressed: _canSave ? _save : null,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('Save Voice Profile'),
            ),
          ],
          if (_failure case final failure?) ...[
            SizedBox(height: context.spacing.md),
            Semantics(
              liveRegion: true,
              child: Text(
                failure,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
