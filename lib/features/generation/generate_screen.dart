import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controllers.dart';
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
  final _focusNode = FocusNode();
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _focusNode.dispose();
    _textController
      ..removeListener(_onTextChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _generate(
    PocketTtsModelPaths model,
    String referenceAudioPath,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _generating = true;
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
            speed: ref.read(generationSpeedProvider),
            numSteps: ref.read(generationStepsProvider),
            temperature: ref.read(generationTemperatureProvider),
            sentenceChunkChars: ref.read(sentenceChunkCharsProvider),
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
        _generating = false;
        _textController.clear();
      });
      messenger.showSnackBar(
        const SnackBar(
          key: Key('generation_saved_snackbar'),
          content: Text('Audio saved — check it out in History'),
          duration: Duration(seconds: 3),
        ),
      );
    } on LocalTtsException catch (error) {
      if (!mounted) return;
      setState(() => _generating = false);
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } on GenerationHistoryException catch (error) {
      if (!mounted) return;
      setState(() => _generating = false);
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } on Object {
      if (!mounted) return;
      setState(() => _generating = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Speech could not be generated.')),
      );
    }
  }

  void _showVoicePicker({
    required List<InstalledBuiltinVoice> builtins,
    required List<VoiceProfile> profiles,
    required String? effectiveId,
  }) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.shapes.cardRadius),
        ),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.62,
          minChildSize: 0.42,
          maxChildSize: 0.88,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.spacing.lg,
                    0,
                    context.spacing.lg,
                    context.spacing.md,
                  ),
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
                          Icons.record_voice_over,
                          color: scheme.onPrimaryContainer,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: context.spacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choose a voice',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Tap to select • Works offline',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: scheme.outlineVariant),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(
                      context.spacing.lg,
                      context.spacing.md,
                      context.spacing.lg,
                      context.spacing.xl,
                    ),
                    children: [
                      if (builtins.isNotEmpty) ...[
                        Text(
                          'Built-in voices',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: scheme.onSurfaceVariant,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        SizedBox(height: context.spacing.sm),
                        ...builtins.map((b) {
                          final isSelected = effectiveId == b.selectId;
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: context.spacing.sm,
                            ),
                            child: _VoiceOptionTile(
                              title: b.voice.label,
                              subtitle:
                                  '${b.voice.license} • ${(b.durationMs / 1000).toStringAsFixed(1)}s',
                              leadingIcon: Icons.stars_rounded,
                              selected: isSelected,
                              onTap: () {
                                ref
                                    .read(selectedVoiceIdProvider.notifier)
                                    .select(b.selectId);
                                Navigator.pop(sheetContext);
                              },
                            ),
                          );
                        }),
                        SizedBox(height: context.spacing.lg),
                      ],
                      if (profiles.isNotEmpty) ...[
                        Text(
                          'Your Voice Profiles',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: scheme.onSurfaceVariant,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        SizedBox(height: context.spacing.sm),
                        ...profiles.map((p) {
                          final isSelected = effectiveId == p.id;
                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: context.spacing.sm,
                            ),
                            child: _VoiceOptionTile(
                              title: p.name,
                              subtitle:
                                  '${(p.durationMs / 1000).toStringAsFixed(1)}s • ${p.sampleRate} Hz • Custom',
                              leadingIcon: Icons.person_rounded,
                              selected: isSelected,
                              onTap: () {
                                ref
                                    .read(selectedVoiceIdProvider.notifier)
                                    .select(p.id);
                                Navigator.pop(sheetContext);
                              },
                            ),
                          );
                        }),
                      ],
                      if (builtins.isEmpty && profiles.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: context.spacing.xl,
                          ),
                          child: EmptyStateCard(
                            icon: Icons.voicemail_outlined,
                            title: 'No voices yet',
                            message:
                                'Voices appear after the engine finishes installing.',
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _textController.text.characters.length;
    final scheme = Theme.of(context).colorScheme;
    final remaining = _generationCharacterLimit - count;
    final progress = (count / _generationCharacterLimit).clamp(0.0, 1.0);
    final modelState = ref.watch(modelInstallControllerProvider).value;
    final model = modelState?.paths;
    final modelReady = model != null;
    final profilesAsync = ref.watch(voiceProfilesProvider);
    final profileItems = profilesAsync.value ?? const <VoiceProfile>[];
    final builtins = ref.watch(builtinVoicesProvider).value ?? const [];
    final selectedId = ref.watch(selectedVoiceIdProvider);

    // Resolve to an id that actually exists in available items.
    final availableIds = <String>{
      for (final b in builtins) b.selectId,
      for (final p in profileItems) p.id,
    };
    String? effectiveSelectedId;
    if (selectedId != null && availableIds.contains(selectedId)) {
      effectiveSelectedId = selectedId;
    } else if (builtins.isNotEmpty) {
      effectiveSelectedId = builtins.first.selectId;
    } else if (profileItems.isNotEmpty) {
      effectiveSelectedId = profileItems.first.id;
    }

    String? referencePath;
    String? selectedLabel;
    String? selectedSubtitle;
    IconData selectedIcon = Icons.record_voice_over_outlined;

    if (effectiveSelectedId != null) {
      for (final builtin in builtins) {
        if (builtin.selectId == effectiveSelectedId) {
          referencePath = builtin.path;
          selectedLabel = '${builtin.voice.label} (built-in)';
          selectedSubtitle = builtin.voice.license;
          selectedIcon = Icons.stars_rounded;
          break;
        }
      }
      if (referencePath == null) {
        for (final profile in profileItems) {
          if (profile.id == effectiveSelectedId) {
            referencePath = profile.referencePath;
            selectedLabel = profile.name;
            selectedSubtitle =
                '${(profile.durationMs / 1000).toStringAsFixed(1)}s • Custom voice';
            selectedIcon = Icons.person_rounded;
            break;
          }
        }
      }
    }
    if (referencePath == null && builtins.isNotEmpty) {
      referencePath = builtins.first.path;
      selectedLabel ??= '${builtins.first.voice.label} (built-in)';
      selectedSubtitle ??= builtins.first.voice.license;
    }

    final canGenerate =
        modelReady &&
        referencePath != null &&
        !_generating &&
        _textController.text.trim().isNotEmpty;
    final isLimitNear = remaining <= 80;

    Widget header() => Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        BrandMark(size: 46, animated: false),
        SizedBox(width: context.spacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Generate',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              Text(
                'Private speech, on this device',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    Widget composer({required bool expand}) {
      final field = TextField(
        key: const Key('generation_text_field'),
        controller: _textController,
        focusNode: _focusNode,
        expands: expand,
        minLines: expand ? null : 5,
        maxLines: expand ? null : 8,
        maxLength: _generationCharacterLimit,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        inputFormatters: [
          LengthLimitingTextInputFormatter(_generationCharacterLimit),
        ],
        textAlignVertical: expand
            ? TextAlignVertical.top
            : TextAlignVertical.center,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55),
        decoration: InputDecoration(
          hintText: 'Write what you want the voice to say…',
          hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.62),
          ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.all(context.spacing.lg),
          counterText: '',
        ),
      );

      final footer = Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacing.md,
          vertical: context.spacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.edit_note_rounded,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ),
            SizedBox(width: context.spacing.sm),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: scheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isLimitNear ? scheme.error : scheme.primary,
                  ),
                ),
              ),
            ),
            SizedBox(width: context.spacing.md),
            Text(
              '${_formatCount(count)} / ${_formatCount(_generationCharacterLimit)}',
              key: const Key('generation_character_counter'),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isLimitNear ? scheme.error : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );

      final card = PSCard(
        padding: EdgeInsets.zero,
        child: expand
            ? Column(
                children: [
                  Expanded(
                    child: Semantics(
                      textField: true,
                      label: 'Text to generate as speech',
                      child: field,
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: scheme.outlineVariant.withValues(alpha: 0.7),
                  ),
                  footer,
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    textField: true,
                    label: 'Text to generate as speech',
                    child: field,
                  ),
                  Divider(
                    height: 1,
                    color: scheme.outlineVariant.withValues(alpha: 0.7),
                  ),
                  footer,
                ],
              ),
      );
      return expand ? card : card;
    }

    Widget voiceSection() {
      if (profilesAsync.isLoading && builtins.isEmpty) {
        return PSCard(
          child: Row(
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
        );
      }
      if (profilesAsync.hasError) {
        return EmptyStateCard(
          icon: Icons.error_outline,
          title: 'Voice Profiles unavailable',
          message: profilesAsync.error is VoiceProfileException
              ? (profilesAsync.error! as VoiceProfileException).message
              : 'Voice Profiles could not be opened.',
        );
      }
      if (builtins.isEmpty && profileItems.isEmpty) {
        return PSCard(
          padding: EdgeInsets.all(context.spacing.lg),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.record_voice_over_outlined,
                  color: scheme.onSurfaceVariant,
                  size: 22,
                ),
              ),
              SizedBox(width: context.spacing.md),
              Expanded(
                child: Text(
                  'Voices appear here after the engine finishes installing.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return PSCard(
        padding: EdgeInsets.all(context.spacing.sm),
        onTap: () => _showVoicePicker(
          builtins: builtins,
          profiles: profileItems,
          effectiveId: effectiveSelectedId,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                selectedIcon,
                color: scheme.onPrimaryContainer,
                size: 21,
              ),
            ),
            SizedBox(width: context.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedLabel ?? 'Select a voice',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (selectedSubtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      selectedSubtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: const Icon(Icons.unfold_more_rounded, size: 17),
            ),
          ],
        ),
      );
    }

    Widget generateButton() => Semantics(
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
              // ignore: unnecessary_non_null_assertion
              ? () => _generate(model!, referencePath!)
              : null,
          icon: _generating
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.onPrimary,
                  ),
                )
              : const Icon(Icons.auto_awesome_rounded, size: 20),
          label: Text(_generating ? 'Generating…' : 'Generate speech'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );

    Widget privacyNote() => Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.lock_outline_rounded,
          size: 13,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Never leaves this device.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );

    // Engine not installed yet: allow scrolling so the install card and its
    // progress are fully reachable.
    if (!modelReady) {
      return Scaffold(
        body: PageBody(
          children: [
            header(),
            SizedBox(height: context.spacing.xl),
            const ModelInstallCard(),
            SectionTitle('Text'),
            composer(expand: false),
            SectionTitle('Voice'),
            voiceSection(),
            if (_generating) ...[
              SizedBox(height: context.spacing.md),
              Center(
                child: Text(
                  'Generating…',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            SizedBox(height: context.spacing.xl),
            generateButton(),
            SizedBox(height: context.spacing.md),
            privacyNote(),
          ],
        ),
      );
    }

    // Engine ready: scrollable container, but content is sized to exactly
    // fill the viewport so it never visibly scrolls. The composer keeps its
    // full height while the keyboard is open — the voice picker, generate
    // button, and privacy note simply sit under the keyboard.
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      context.spacing.lg,
                      context.spacing.lg,
                      context.spacing.lg,
                      0,
                    ),
                    child: Column(
                      children: [
                        header(),
                        SizedBox(height: context.spacing.md),
                        Expanded(child: composer(expand: true)),
                        if (!keyboardVisible) ...[
                          SizedBox(height: context.spacing.md),
                          voiceSection(),
                          SizedBox(height: context.spacing.md),
                          generateButton(),
                          SizedBox(height: context.spacing.sm),
                          privacyNote(),
                          SizedBox(
                            height: MediaQuery.paddingOf(context).bottom + 100,
                          ),
                        ],
                      ],
                    ),
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

class _VoiceOptionTile extends StatelessWidget {
  const _VoiceOptionTile({
    required this.title,
    required this.subtitle,
    required this.leadingIcon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData leadingIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.72)
          : scheme.surfaceContainer.withValues(alpha: 0.75),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: context.spacing.md,
            vertical: context.spacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.85)
                  : scheme.outlineVariant.withValues(alpha: 0.8),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected ? scheme.primary : scheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? Colors.transparent
                        : scheme.outlineVariant,
                  ),
                ),
                child: Icon(
                  leadingIcon,
                  size: 20,
                  color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                ),
              ),
              SizedBox(width: context.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: selected
                            ? scheme.onPrimaryContainer.withValues(alpha: 0.82)
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: context.spacing.sm),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 22,
                color: selected ? scheme.primary : scheme.outline,
              ),
            ],
          ),
        ),
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
