import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:android_app_template/core/design_tokens.dart';

import 'viewmodel.dart';
import 'widgets/action_button.dart';

class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeViewModelProvider);
    final viewModel = ref.read(homeViewModelProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Chrendy', style: theme.textTheme.labelMedium),
      ),
      body: HookBuilder(
        builder: (context) {
          final controller = useTextEditingController(text: state.draftText);

          useEffect(() {
            Future<void>.microtask(viewModel.restoreDraft);
            return null;
          }, const []);

          useEffect(() {
            if (controller.text == state.draftText) {
              return null;
            }
            controller.value = TextEditingValue(
              text: state.draftText,
              selection: TextSelection.collapsed(
                offset: state.draftText.length,
              ),
            );
            return null;
          }, <Object?>[state.draftText]);

          return Padding(
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: ListView(
              children: <Widget>[
                Text(
                  'Offline-first journaling',
                  style: theme.textTheme.displayMedium,
                ),
                const SizedBox(height: AppSpacing.x3),
                Text(
                  'Every keystroke is persisted locally before network sync.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.x4),
                TextField(
                  controller: controller,
                  minLines: 4,
                  maxLines: 8,
                  onChanged: viewModel.updateDraft,
                  decoration: const InputDecoration(
                    labelText: 'Journal entry',
                    hintText: 'Write now, sync later.',
                  ),
                ),
                const SizedBox(height: AppSpacing.x3),
                Text(
                  'Mood: ${state.moodScore}/5',
                  style: theme.textTheme.bodyMedium,
                ),
                Slider(
                  value: state.moodScore.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: '${state.moodScore}',
                  onChanged: state.isSubmitting
                      ? null
                      : (value) => viewModel.updateMoodScore(value.round()),
                ),
                Text(
                  'Pending sync queue: ${state.outboxCount}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.x2),
                if (state.statusMessage != null)
                  Text(
                    'Status: ${state.statusMessage}',
                    style: theme.textTheme.bodyMedium,
                  ),
                if (state.errorMessage != null)
                  Text(
                    state.errorMessage!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                const SizedBox(height: AppSpacing.x4),
                ActionButton(
                  label: state.isSubmitting ? 'Syncing...' : 'Save + Sync',
                  onPressed: state.isSubmitting ? null : viewModel.submitDraft,
                ),
                const SizedBox(height: AppSpacing.x3),
                ActionButton(
                  label: 'Retry Pending',
                  onPressed: state.isSubmitting || state.outboxCount == 0
                      ? null
                      : viewModel.retryPendingSync,
                ),
                const SizedBox(height: AppSpacing.x3),
                ActionButton(
                  label: 'Clear Draft',
                  onPressed: state.isSubmitting
                      ? null
                      : viewModel.clearLocalDraft,
                  primary: false,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
