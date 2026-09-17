import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controllers.dart';
import '../../app/app_theme.dart';
import '../../core/model/pocket_tts_model.dart';
import '../../shared/ui.dart';
import '../history/generation_history_repository.dart';
import '../model/model_install_card.dart';
import 'export_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themePreferenceProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: PageBody(
        children: [
          PageHeader(
            title: 'Settings',
            subtitle: 'Local-only preferences and storage',
            icon: Icons.tune_rounded,
          ),
          SectionTitle('Voice engine'),
          const ModelInstallCard(allowRemoval: true),
          SectionTitle('Generation'),
          const _GenerationSettingsCard(),
          SizedBox(height: context.spacing.md),
          const _DecoderQualityCard(),
          SectionTitle('Storage'),
          const _DownloadLocationTile(),
          SizedBox(height: context.spacing.md),
          const _ClearHistoryTile(),
          SectionTitle('Appearance'),
          PSCard(
            padding: EdgeInsets.all(context.spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.palette_outlined,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    SizedBox(width: context.spacing.sm),
                    Text(
                      'Theme',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        themeMode.name.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.spacing.md),
                Semantics(
                  label: 'Appearance selection',
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    expandedInsets: EdgeInsets.zero,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return scheme.primaryContainer;
                        }
                        return scheme.surface;
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return scheme.onPrimaryContainer;
                        }
                        return scheme.onSurfaceVariant;
                      }),
                      side: WidgetStatePropertyAll(
                        BorderSide(color: scheme.outlineVariant),
                      ),
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_outlined, size: 18),
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined, size: 18),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined, size: 18),
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (selection) => ref
                        .read(themePreferenceProvider.notifier)
                        .setMode(selection.single),
                  ),
                ),
                SizedBox(height: context.spacing.sm),
                Text(
                  'System follows your device setting. Everything stays local.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          SectionTitle('Guidance and privacy'),
          PSCard(
            padding: EdgeInsets.all(context.spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.record_voice_over_rounded,
                        size: 18,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    SizedBox(width: context.spacing.md),
                    Text(
                      'Built-in voices',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.spacing.md),
                Text(
                  'Alba (CC BY 4.0, Alba MacKenna), Fantine (CC BY 4.0, VCTK), Javert (CC0, Kyutai voice donation), Bill Boerst and Caro Davy (CC0, LibriVox via Voice-Zero).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.55,
                  ),
                ),
                SizedBox(height: context.spacing.sm),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: context.spacing.sm,
                    vertical: context.spacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_outlined,
                        size: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Licensed for commercial use',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: context.spacing.md),
                Text(
                  'Voice engine: Pocket TTS © Kyutai (CC BY 4.0), running on '
                  'sherpa-onnx (Apache-2.0).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: context.spacing.md),
          AppListTile(
            leading: Icons.replay_rounded,
            title: 'Replay onboarding',
            subtitle: 'Review local storage and offline processing.',
            trailing: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Icon(Icons.chevron_right_rounded, size: 18),
            ),
            onTap: () => ref.read(onboardingCompleteProvider.notifier).replay(),
          ),
          SizedBox(height: context.spacing.md),
          PSCard(
            padding: EdgeInsets.all(context.spacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDFF5E1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.privacy_tip_rounded,
                    size: 20,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                SizedBox(width: context.spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Privacy summary',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: context.spacing.xs),
                      Text(
                        'Reference recordings, generated speech, and text remain on this device. Uninstalling or clearing app data removes local content and the downloaded voice engine.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: context.spacing.xl),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainer.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Pocket Speech 1.0.0',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
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
                    'On-device',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: context.spacing.md),
          Text(
            'No account • No telemetry • Private',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GenerationSettingsCard extends ConsumerWidget {
  const _GenerationSettingsCard();

  String _speedLabel(double speed) {
    if (speed < 0.85) return 'Slower (${speed.toStringAsFixed(2)}×)';
    if (speed > 1.15) return 'Faster (${speed.toStringAsFixed(2)}×)';
    return 'Natural (${speed.toStringAsFixed(2)}×)';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(generationSpeedProvider);
    final steps = ref.watch(generationStepsProvider);
    final temperature = ref.watch(generationTemperatureProvider);
    final sentenceChars = ref.watch(sentenceChunkCharsProvider);
    final scheme = Theme.of(context).colorScheme;

    return PSCard(
      key: const Key('generation_settings_card'),
      padding: EdgeInsets.all(context.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Speed
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.speed_rounded,
                  size: 18,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              SizedBox(width: context.spacing.md),
              Expanded(
                child: Text(
                  'Speech speed',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '${speed.toStringAsFixed(2)}×',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.spacing.sm),
          Semantics(
            label: 'Speech speed adjustment',
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                showValueIndicator: ShowValueIndicator.never,
              ),
              child: Slider(
                key: const Key('generation_speed_slider'),
                value: speed,
                min: minGenerationSpeed,
                max: maxGenerationSpeed,
                divisions: ((maxGenerationSpeed - minGenerationSpeed) / 0.05)
                    .round(),
                label: _speedLabel(speed),
                onChanged: (value) =>
                    ref.read(generationSpeedProvider.notifier).setSpeed(value),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Slower',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              Text(
                _speedLabel(speed),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Faster',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Divider(height: context.spacing.xl, color: scheme.outlineVariant),
          // Quality / steps
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              SizedBox(width: context.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quality (diffusion steps)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'More steps sound richer but generate slower.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$steps',
                  key: const Key('generation_steps_value'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.spacing.md),
          Semantics(
            label: 'Quality steps selection',
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                showValueIndicator: ShowValueIndicator.never,
              ),
              child: Slider(
                key: const Key('generation_steps_slider'),
                value: steps.toDouble(),
                min: minGenerationSteps.toDouble(),
                max: maxGenerationSteps.toDouble(),
                divisions: maxGenerationSteps - minGenerationSteps,
                label: '$steps steps',
                onChanged: (value) => ref
                    .read(generationStepsProvider.notifier)
                    .setSteps(value.round()),
              ),
            ),
          ),
          SizedBox(height: context.spacing.sm),
          Text(
            'Default is 5 — a good balance for most voices. Changes apply to '
            'the next generation.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          Divider(height: context.spacing.xl, color: scheme.outlineVariant),
          // Stability / temperature
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.graphic_eq_rounded,
                  size: 18,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              SizedBox(width: context.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stability',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Higher adds expressiveness; lower steadies pacing and '
                      'reduces glitches.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  temperature.toStringAsFixed(2),
                  key: const Key('generation_temperature_value'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.spacing.md),
          Semantics(
            label: 'Stability adjustment',
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                showValueIndicator: ShowValueIndicator.never,
              ),
              child: Slider(
                key: const Key('generation_temperature_slider'),
                value: temperature,
                min: minGenerationTemperature,
                max: maxGenerationTemperature,
                divisions:
                    ((maxGenerationTemperature - minGenerationTemperature) /
                            0.05)
                        .round(),
                label: temperature.toStringAsFixed(2),
                onChanged: (value) => ref
                    .read(generationTemperatureProvider.notifier)
                    .setTemperature(value),
              ),
            ),
          ),
          Divider(height: context.spacing.xl, color: scheme.outlineVariant),
          // Sentence chunk length
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.format_align_left_rounded,
                  size: 18,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              SizedBox(width: context.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sentence chunk length',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Long sentences are split into smaller pieces. Shorter '
                      'keeps long text pacing even.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$sentenceChars',
                  key: const Key('generation_sentence_chars_value'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.spacing.md),
          Semantics(
            label: 'Sentence chunk length selection',
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                showValueIndicator: ShowValueIndicator.never,
              ),
              child: Slider(
                key: const Key('generation_sentence_chars_slider'),
                value: sentenceChars.toDouble(),
                min: minSentenceChunkChars.toDouble(),
                max: maxSentenceChunkChars.toDouble(),
                divisions:
                    (maxSentenceChunkChars - minSentenceChunkChars) ~/ 20,
                label: '$sentenceChars characters',
                onChanged: (value) => ref
                    .read(sentenceChunkCharsProvider.notifier)
                    .setChars(value.round()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DecoderQualityCard extends ConsumerStatefulWidget {
  const _DecoderQualityCard();

  @override
  ConsumerState<_DecoderQualityCard> createState() =>
      _DecoderQualityCardState();
}

class _DecoderQualityCardState extends ConsumerState<_DecoderQualityCard> {
  bool _working = false;
  double? _progress;

  Future<void> _toggle(bool enable) async {
    if (_working) return;
    setState(() {
      _working = true;
      _progress = enable ? 0 : null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repository = ref.read(pocketTtsModelRepositoryProvider);
      if (enable) {
        await repository.ensureFp32Decoder(
          onProgress: (downloaded, total) {
            if (!mounted) return;
            setState(() {
              _progress = total <= 0 ? null : downloaded / total;
            });
          },
        );
      } else {
        await repository.removeFp32Decoder();
      }
      ref.invalidate(fp32DecoderProvider);
    } on ModelInstallException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } on Object {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('The high-fidelity decoder could not be updated.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final installed = ref.watch(fp32DecoderProvider).value ?? false;
    final modelReady =
        ref.watch(modelInstallControllerProvider).value?.phase ==
        ModelInstallPhase.ready;
    final scheme = Theme.of(context).colorScheme;
    final subtitle = !modelReady
        ? 'Install the voice engine first'
        : _working && _progress != null
        ? 'Downloading… ${(_progress! * 100).toStringAsFixed(0)}%'
        : installed
        ? 'Unquantized audio decoder in use for extra clarity'
        : 'Optional download (41 MB) — richer, clearer sound';

    return PSCard(
      key: const Key('decoder_quality_card'),
      padding: EdgeInsets.all(context.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.high_quality_rounded,
                  size: 18,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              SizedBox(width: context.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'High-fidelity audio',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: context.spacing.sm),
              Semantics(
                label: 'High-fidelity decoder toggle',
                child: Switch(
                  key: const Key('fp32_decoder_switch'),
                  value: installed,
                  onChanged: !modelReady || _working
                      ? null
                      : (value) => unawaited(_toggle(value)),
                ),
              ),
            ],
          ),
          if (_working && _progress != null) ...[
            SizedBox(height: context.spacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                key: const Key('fp32_decoder_progress'),
                value: _progress,
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClearHistoryTile extends ConsumerStatefulWidget {
  const _ClearHistoryTile();

  @override
  ConsumerState<_ClearHistoryTile> createState() => _ClearHistoryTileState();
}

class _ClearHistoryTileState extends ConsumerState<_ClearHistoryTile> {
  bool _clearing = false;

  Future<void> _confirmAndClear() async {
    final scheme = Theme.of(context).colorScheme;
    final history = ref.read(generationHistoryProvider).value ?? const [];
    if (history.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('History is already empty.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.delete_sweep_outlined,
            color: scheme.onErrorContainer,
          ),
        ),
        title: const Text('Delete all audio?', textAlign: TextAlign.center),
        content: Text(
          'All ${history.length} generated recording${history.length == 1 ? '' : 's'} '
          'will be permanently deleted from this device. This cannot be undone.',
          textAlign: TextAlign.center,
          style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            key: const Key('confirm_clear_history_button'),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _clearing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final deleted = await ref
          .read(generationHistoryRepositoryProvider)
          .deleteAll();
      ref.invalidate(generationHistoryProvider);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            deleted == 0
                ? 'History cleared.'
                : 'Deleted $deleted recording${deleted == 1 ? '' : 's'}.',
          ),
        ),
      );
    } on GenerationHistoryException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('Audio could not be deleted.')),
      );
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyCount =
        ref.watch(generationHistoryProvider).value?.length ?? 0;
    final scheme = Theme.of(context).colorScheme;
    final hasHistory = historyCount > 0;
    return PSCard(
      key: const Key('clear_history_tile'),
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.lg,
        vertical: context.spacing.md,
      ),
      onTap: _clearing ? null : _confirmAndClear,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: hasHistory
                  ? scheme.errorContainer.withValues(alpha: 0.6)
                  : scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.delete_sweep_outlined,
              color: hasHistory ? scheme.error : scheme.onSurfaceVariant,
              size: 20,
            ),
          ),
          SizedBox(width: context.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delete all audio',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _clearing
                      ? 'Deleting…'
                      : hasHistory
                      ? '$historyCount recording${historyCount == 1 ? '' : 's'} will be removed'
                      : 'No recordings in history',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: context.spacing.sm),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              shape: BoxShape.circle,
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: _clearing
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  )
                : Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
          ),
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
    final scheme = Theme.of(context).colorScheme;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.shapes.cardRadius),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(context.spacing.lg),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.folder_rounded,
                      color: scheme.onPrimaryContainer,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: context.spacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Download location',
                        style: Theme.of(sheetContext).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Where exported WAVs are saved',
                        style: Theme.of(sheetContext).textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.drive_folder_upload_outlined, size: 20),
              ),
              title: const Text('Change folder'),
              subtitle: const Text('Pick a new export location'),
              onTap: () => Navigator.pop(sheetContext, 'change'),
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.folder_off_outlined,
                  size: 20,
                  color: scheme.onErrorContainer,
                ),
              ),
              title: const Text('Clear location'),
              subtitle: const Text('Reset to system default'),
              onTap: () => Navigator.pop(sheetContext, 'clear'),
            ),
            SizedBox(height: context.spacing.lg),
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
    final scheme = Theme.of(context).colorScheme;
    final subtitle = destination.when(
      data: (value) => value?.name ?? 'Choose where exported audio is saved',
      loading: () => 'Checking saved location…',
      error: (_, _) => 'Choose where exported audio is saved',
    );
    return PSCard(
      key: const Key('download_location_tile'),
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.lg,
        vertical: context.spacing.md,
      ),
      onTap: () => hasDestination ? _manage(context, ref) : _pick(context, ref),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: hasDestination
                  ? scheme.primaryContainer
                  : scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.folder_outlined,
              color: hasDestination
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
              size: 20,
            ),
          ),
          SizedBox(width: context.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Download location',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: context.spacing.sm),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              shape: BoxShape.circle,
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Icon(
              hasDestination
                  ? Icons.more_horiz_rounded
                  : Icons.chevron_right_rounded,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
