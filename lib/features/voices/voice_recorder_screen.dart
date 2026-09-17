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

class _VoiceRecorderScreenState extends ConsumerState<VoiceRecorderScreen>
    with SingleTickerProviderStateMixin {
  final _recorder = AudioRecorder();
  final _nameController = TextEditingController(text: 'My voice');
  final _nameFocusNode = FocusNode();
  late final VoiceProfileRepository _repository;
  late final AnimationController _pulseController;
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

  bool get _isTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    _repository = ref.read(voiceProfileRepositoryProvider);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (!_isTest) {
      _pulseController.repeat(reverse: true);
    }
  }

  Future<void> _start() async {
    setState(() => _failure = null);
    await _discardRecording();
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        setState(() {
          _failure =
              'Microphone permission is required to create a Voice Profile.';
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
      _nameFocusNode.unfocus();
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
    _pulseController.dispose();
    _timer?.cancel();
    unawaited(_disposeResources());
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _disposeResources() async {
    if (_recording) await _recorder.cancel();
    await _player?.dispose();
    await _repository.discardRecording(_recordingPath);
    await _recorder.dispose();
  }

  String _formatTimer(Duration d) {
    final seconds = d.inSeconds;
    final tenths = (d.inMilliseconds % 1000) ~/ 100;
    return '$seconds.${tenths}s';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress =
        (_elapsed.inMilliseconds / maximumReferenceDuration.inMilliseconds)
            .clamp(0.0, 1.0);
    final isValidLength =
        _elapsed >= minimumReferenceDuration &&
        _elapsed <= maximumReferenceDuration;
    final remaining = maximumReferenceDuration - _elapsed;
    final remainingSeconds = remaining.isNegative ? 0 : remaining.inSeconds;

    Widget failureBanner({double? topGap}) {
      if (_failure == null) return const SizedBox.shrink();
      return Container(
        margin: EdgeInsets.only(top: topGap ?? context.spacing.sm),
        padding: EdgeInsets.all(context.spacing.sm),
        decoration: BoxDecoration(
          color: scheme.errorContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.error.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, size: 16, color: scheme.error),
            SizedBox(width: context.spacing.sm),
            Expanded(
              child: Text(
                _failure!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget heroCard(bool compact) => PSCard(
      padding: EdgeInsets.all(
        compact ? context.spacing.md : context.spacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              if (_recording)
                FadeTransition(
                  opacity: _pulseController,
                  child: Container(
                    width: compact ? 84 : 96,
                    height: compact ? 84 : 96,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              if (_recording)
                ScaleTransition(
                  scale: Tween<double>(begin: 1, end: 1.14).animate(
                    CurvedAnimation(
                      parent: _pulseController,
                      curve: Curves.easeInOut,
                    ),
                  ),
                  child: Container(
                    width: compact ? 68 : 78,
                    height: compact ? 68 : 78,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              Container(
                width: compact ? 56 : 64,
                height: compact ? 56 : 64,
                decoration: BoxDecoration(
                  color: _recording ? scheme.primary : scheme.surfaceContainer,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _recording
                        ? Colors.transparent
                        : scheme.outlineVariant,
                    width: 1,
                  ),
                  boxShadow: _recording
                      ? [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  _recording ? Icons.mic_rounded : Icons.mic_none_rounded,
                  color: _recording
                      ? scheme.onPrimary
                      : scheme.onSurfaceVariant,
                  size: compact ? 24 : 28,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? context.spacing.md : context.spacing.lg),
          Text(
            _recording
                ? _formatTimer(_elapsed)
                : (_recordingPath == null
                      ? 'Record your voice'
                      : 'Review & save'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              height: 1.05,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: _recording ? scheme.primary : scheme.onSurface,
            ),
          ),
          SizedBox(height: context.spacing.xs),
          Text(
            _recording
                ? 'Speak naturally… $remainingSeconds s left'
                : 'Speak naturally in a quiet room for 5–12 seconds. The recording stays on this device.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: compact ? context.spacing.md : context.spacing.lg),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: _recording || _recordingPath != null ? progress : 0,
              minHeight: compact ? 5 : 6,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                isValidLength ? const Color(0xFF2E7D32) : scheme.primary,
              ),
            ),
          ),
          SizedBox(height: context.spacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0s',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Text(
                '5s min',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isValidLength
                      ? const Color(0xFF2E7D32)
                      : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '12s max',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    Widget consentCard() => PSCard(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.md,
        vertical: context.spacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Checkbox(
            value: _consent,
            onChanged: _recording || _saving
                ? null
                : (value) => setState(() => _consent = value ?? false),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          SizedBox(width: context.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'I have permission to use this voice',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'You confirm you own this voice or have explicit consent.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.3,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    Widget stopButton() => SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _stop,
        icon: const Icon(Icons.stop_rounded),
        label: const Text('Stop recording'),
        style: FilledButton.styleFrom(
          backgroundColor: scheme.error,
          foregroundColor: scheme.onError,
          minimumSize: const Size(double.infinity, 52),
        ),
      ),
    );

    Widget startButton() => SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        key: const Key('start_voice_recording_button'),
        onPressed: _consent ? _start : null,
        icon: const Icon(Icons.mic_rounded),
        label: const Text('Start recording'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
        ),
      ),
    );

    Widget reviewCard(bool compact) => PSCard(
      padding: EdgeInsets.all(
        compact ? context.spacing.md : context.spacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isValidLength
                      ? const Color(0xFFDFF5E1)
                      : scheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isValidLength
                      ? Icons.check_rounded
                      : Icons.warning_amber_rounded,
                  size: 16,
                  color: isValidLength
                      ? const Color(0xFF1B5E20)
                      : scheme.onErrorContainer,
                ),
              ),
              SizedBox(width: context.spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isValidLength
                          ? 'Good length • Ready to save'
                          : 'Adjust length to 5–12 seconds',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${_formatTimer(_elapsed)} recorded',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: context.spacing.md),
          TextField(
            controller: _nameController,
            focusNode: _nameFocusNode,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Profile name',
              hintText: 'e.g. My warm voice',
              prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
              counterText: '${_nameController.text.characters.length} / 40',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(height: context.spacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _preview,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Preview', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    minimumSize: const Size(0, 40),
                  ),
                ),
              ),
              SizedBox(width: context.spacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    _nameFocusNode.unfocus();
                    await _discardRecording();
                    if (mounted) setState(() => _failure = null);
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retake', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    minimumSize: const Size(0, 40),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.spacing.sm),
          FilledButton.icon(
            key: const Key('save_voice_profile_button'),
            onPressed: _canSave ? _save : null,
            icon: _saving
                ? SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(
              _canSave ? 'Save Voice Profile' : 'Record 5–12s to save',
              style: const TextStyle(fontSize: 13),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Voice Profile'),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 700;

            // ONE stable tree — never swapped on keyboard inset changes, so
            // the TextField keeps its focus/IME connection while typing.
            // Scrollable container + minHeight = viewport means it fits
            // exactly (no visible scrolling) and simply scrolls if content
            // plus keyboard padding ever exceeds the screen.
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.spacing.lg,
                    context.spacing.md,
                    context.spacing.lg,
                    MediaQuery.viewInsetsOf(context).bottom +
                        context.spacing.md,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      heroCard(compact),
                      SizedBox(height: context.spacing.sm),
                      consentCard(),
                      SizedBox(height: context.spacing.sm),
                      if (_recording)
                        stopButton()
                      else if (_recordingPath == null)
                        startButton()
                      else
                        reviewCard(compact),
                      failureBanner(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
