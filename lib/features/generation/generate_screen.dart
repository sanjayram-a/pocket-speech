import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../core/model/pocket_tts_model.dart';
import '../../shared/brand.dart';
import '../../shared/ui.dart';
import '../history/generation_history_repository.dart';
import '../model/model_install_card.dart';
import '../voices/builtin_voice_repository.dart';
import '../voices/voice_profile_repository.dart';
import 'local_tts_service.dart';

const _generationCharacterLimit = 1000;

class GenerateScreen extends ConsumerStatefulWidget {
  const GenerateScreen({super.key});

  @override
  ConsumerState<GenerateScreen> createState() => _GenerateScreenState();
}

class _GenerateScreenState extends ConsumerState<GenerateScreen> {
  final _textController = TextEditingController(
    text: 'Hello from Pocket Speech. This voice was generated on this device.',
  );
  bool _generating = false;
  String? _savedMessage;
  String? _failure;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _textController
      ..removeListener(_onTextChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _generate(
    PocketTtsModelPaths model,
    String referenceAudioPath,
  ) async {
    setState(() {
      _generating = true;
      _savedMessage = null;
      _failure = null;
    });
    try {
      final outputPath = await ref
          .read(pocketTtsModelRepositoryProvider)
          .createGenerationOutputPath();
      final result = await ref
          .read(localTtsServiceProvider)
          .generate(
            model: model,
            text: _textController.text.trim(),
            referenceAudioPath: referenceAudioPath,
            outputPath: outputPath,
          );
      if (!mounted) return;
      final createdAt = DateTime.now();
      try {
        await ref
            .read(generationHistoryRepositoryProvider)
            .add(
              GenerationRecord(
                id: createdAt.microsecondsSinceEpoch.toString(),
                audioPath: result.path,
                durationMs: result.duration.inMilliseconds,
                sampleRate: result.sampleRate,
                createdAt: createdAt,
              ),
            );
      } on Object {
        final output = File(result.path);
        if (await output.exists()) await output.delete();
        rethrow;
      }
      ref.invalidate(generationHistoryProvider);
      setState(() {
        _savedMessage = 'Saved ${result.duration.inSeconds}s';
        _textController.clear();
      });
    } on LocalTtsException catch (error) {
      if (mounted) setState(() => _failure = error.message);
    } on GenerationHistoryException catch (error) {
      if (mounted) setState(() => _failure = error.message);
    } on Object {
      if (mounted) {
        setState(() => _failure = 'Speech could not be generated.');
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _textController.text.characters.length;
    final scheme = Theme.of(context).colorScheme;
    final modelState = ref.watch(modelInstallControllerProvider).value;
    final model = modelState?.paths;
    final profiles = ref.watch(voiceProfilesProvider);
    final profileItems = profiles.value ?? const <VoiceProfile>[];
    final builtins = ref.watch(builtinVoicesProvider).value ?? const [];
    final selectedId = ref.watch(selectedVoiceIdProvider);

    // Resolve the selected voice: 'builtin:<id>' or a profile id. Falls back
    // to Alba so generation works immediately after engine install.
    String? referencePath;
    for (final builtin in builtins) {
      if (builtin.selectId == selectedId) {
        referencePath = builtin.path;
        break;
      }
    }
    if (referencePath == null && selectedId != null) {
      for (final profile in profileItems) {
        if (profile.id == selectedId) {
          referencePath = profile.referencePath;
          break;
        }
      }
    }
    if (referencePath == null && builtins.isNotEmpty) {
      referencePath = builtins.first.path;
    }

    final canGenerate =
        model != null &&
        referencePath != null &&
        !_generating &&
        _textController.text.trim().isNotEmpty;

    return Scaffold(
      body: PageBody(
        children: [
          Row(
            children: [
              const BrandMark(size: 44),
              SizedBox(width: context.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Generate',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      'Private speech, generated on this device',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: context.spacing.xl),
          const ModelInstallCard(),
          const SectionTitle('Text'),
          Semantics(
            textField: true,
            label: 'Text to generate as speech',
            child: TextField(
              key: const Key('generation_text_field'),
              controller: _textController,
              minLines: 7,
              maxLines: 12,
              maxLength: _generationCharacterLimit,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              inputFormatters: [
                LengthLimitingTextInputFormatter(_generationCharacterLimit),
              ],
              decoration: const InputDecoration(
                hintText: 'Write what you want the voice to say...',
                counterText: '',
              ),
            ),
          ),
          SizedBox(height: context.spacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Local generation limit',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                '${_formatCount(count)} / '
                '${_formatCount(_generationCharacterLimit)}',
                key: const Key('generation_character_counter'),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
          const SectionTitle('Voice'),
          if (profiles.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (profiles.hasError)
            EmptyStateCard(
              icon: Icons.error_outline,
              title: 'Voice Profiles unavailable',
              message: profiles.error is VoiceProfileException
                  ? (profiles.error! as VoiceProfileException).message
                  : 'Voice Profiles could not be opened.',
            )
          else if (builtins.isEmpty && profileItems.isEmpty)
            const EmptyStateCard(
              icon: Icons.mic_none,
              title: 'Voices are on their way',
              message:
                  'Built-in voices appear here after the engine finishes '
                  'installing. You can also record your own Voice Profile.',
            )
          else ...[
            DropdownButtonFormField<String>(
              key: ValueKey(referencePath),
              initialValue:
                  selectedId ??
                  (builtins.isNotEmpty ? builtins.first.selectId : null),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.record_voice_over_outlined),
                labelText: 'Voice',
              ),
              items: [
                for (final builtin in builtins)
                  DropdownMenuItem(
                    value: builtin.selectId,
                    child: Text('${builtin.voice.label} (built-in)'),
                  ),
                for (final profile in profileItems)
                  DropdownMenuItem(
                    value: profile.id,
                    child: Text(profile.name),
                  ),
              ],
              onChanged: (id) =>
                  ref.read(selectedVoiceIdProvider.notifier).select(id),
            ),
          ],
          if (model == null)
            const EmptyStateCard(
              icon: Icons.download_for_offline_outlined,
              title: 'Install the voice engine first',
              message:
                  'The one-time model download is required before local speech '
                  'generation can start.',
            ),
          if (_generating) ...[
            SizedBox(height: context.spacing.lg),
            Semantics(
              liveRegion: true,
              child: const Text('Generating', textAlign: TextAlign.center),
            ),
          ],
          if (_failure case final failure?) ...[
            SizedBox(height: context.spacing.lg),
            Text(
              failure,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.error),
            ),
          ],
          if (_savedMessage case final saved?) ...[
            SizedBox(height: context.spacing.lg),
            Semantics(
              liveRegion: true,
              child: Text(saved, textAlign: TextAlign.center),
            ),
            SizedBox(height: context.spacing.sm),
            Text(
              'Find it in History.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          SizedBox(height: context.spacing.xl),
          Semantics(
            button: true,
            enabled: canGenerate,
            label: canGenerate
                ? 'Generate speech locally'
                : 'Generate speech unavailable',
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('generate_speech_button'),
                onPressed: canGenerate
                    ? () => _generate(model, referencePath!)
                    : null,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate speech'),
              ),
            ),
          ),
          SizedBox(height: context.spacing.lg),
          Text(
            'Text, reference audio, and generated speech never leave this '
            'device.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

String _formatCount(int count) {
  if (count < 1000) return '$count';
  final thousands = count ~/ 1000;
  final remainder = count % 1000;
  return '$thousands,${remainder.toString().padLeft(3, '0')}';
}
