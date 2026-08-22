import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_theme.dart';
import '../../core/api/usage_repository.dart';
import '../../shared/brand.dart';
import '../../shared/ui.dart';

class GenerateScreen extends ConsumerStatefulWidget {
  const GenerateScreen({super.key});

  @override
  ConsumerState<GenerateScreen> createState() => _GenerateScreenState();
}

class _GenerateScreenState extends ConsumerState<GenerateScreen> {
  final _textController = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    final count = _textController.text.characters.length;
    final scheme = Theme.of(context).colorScheme;
    final usage = ref.watch(usageOverviewProvider);
    final characterLimit = usage.value?.policy.generationCharacterLimit;
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
                      'Compose speech in your voice',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: context.spacing.xl),
          Semantics(
            textField: true,
            label: 'Text to generate as speech',
            child: TextField(
              key: const Key('generation_text_field'),
              controller: _textController,
              minLines: 7,
              maxLines: 12,
              maxLength: characterLimit,
              maxLengthEnforcement: characterLimit == null
                  ? MaxLengthEnforcement.none
                  : MaxLengthEnforcement.enforced,
              inputFormatters: [
                if (characterLimit != null)
                  LengthLimitingTextInputFormatter(characterLimit),
              ],
              decoration: const InputDecoration(
                hintText: 'Write what you want your Voice Profile to say...',
                counterText: '',
              ),
            ),
          ),
          SizedBox(height: context.spacing.sm),
          _GenerationLimitStatus(
            count: count,
            usage: usage,
            onRetry: () => ref.invalidate(usageOverviewProvider),
          ),
          const SectionTitle('Voice Profile'),
          const EmptyStateCard(
            icon: Icons.mic_none,
            title: 'No Voice Profile yet',
            message:
                'Create a Voice Profile before generating speech. Voice '
                'creation is the next feature to be connected.',
          ),
          SizedBox(height: context.spacing.xl),
          Semantics(
            button: true,
            enabled: false,
            label: 'Generate speech, unavailable until a Voice Profile exists',
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: null,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate speech'),
              ),
            ),
          ),
          SizedBox(height: context.spacing.lg),
          Text(
            'Text stays in this composer and is not retained after generation.',
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

class _GenerationLimitStatus extends StatelessWidget {
  const _GenerationLimitStatus({
    required this.count,
    required this.usage,
    required this.onRetry,
  });

  final int count;
  final AsyncValue<UsageOverview> usage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final overview = usage.value;
    final limit = overview?.policy.generationCharacterLimit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                overview == null
                    ? 'Plan generation limit'
                    : '${_planName(overview.planKey)} generation limit',
                style: textStyle,
              ),
            ),
            Semantics(
              liveRegion: true,
              label: limit == null
                  ? '$count characters used; plan limit unavailable'
                  : '$count of $limit characters used',
              child: Text(
                '${_formatCount(count)} / ${limit == null ? '--' : _formatCount(limit)}',
                key: const Key('generation_character_counter'),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
        ),
        if (usage.isLoading) ...[
          SizedBox(height: context.spacing.sm),
          const LinearProgressIndicator(key: Key('generation_policy_loading')),
        ] else if (usage.hasError) ...[
          SizedBox(height: context.spacing.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  usage.error is UsageFailure
                      ? (usage.error! as UsageFailure).message
                      : 'The plan limit could not be loaded.',
                  style: textStyle?.copyWith(color: scheme.error),
                ),
              ),
              if (usage.error is! UsageFailure ||
                  (usage.error! as UsageFailure).retryable)
                TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ],
      ],
    );
  }
}

String _planName(String planKey) {
  if (planKey.isEmpty) return 'Current';
  return '${planKey[0].toUpperCase()}${planKey.substring(1)}';
}

String _formatCount(int count) {
  if (count < 1000) return '$count';
  final thousands = count ~/ 1000;
  final remainder = count % 1000;
  return '$thousands,${remainder.toString().padLeft(3, '0')}';
}
