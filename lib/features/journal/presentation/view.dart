import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:android_app_template/core/design_tokens.dart';
import 'package:android_app_template/data/providers.dart';
import 'package:android_app_template/shared/widgets/action_button.dart';

import 'viewmodel.dart';

class JournalView extends ConsumerWidget {
  const JournalView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(phoenixSyncWorkerProvider);

    final state = ref.watch(journalViewModelProvider);
    final viewModel = ref.read(journalViewModelProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Chrendy Journal', style: theme.textTheme.labelMedium),
        actions: <Widget>[
          TextButton(
            onPressed: () => context.go('/habits'),
            child: const Text('Habits'),
          ),
        ],
      ),
      body: HookBuilder(
        builder: (context) {
          final controller = useTextEditingController(text: state.draftText);

          useEffect(() {
            Future<void>.microtask(viewModel.restoreLocalState);
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
                Text('Journal today', style: theme.textTheme.displayMedium),
                const SizedBox(height: AppSpacing.x3),
                Text(
                  'Draft-first recovery with offline sync guarantees.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.x4),
                TextField(
                  controller: controller,
                  minLines: 5,
                  maxLines: 10,
                  onChanged: (value) {
                    unawaited(viewModel.updateDraft(value));
                  },
                  decoration: const InputDecoration(
                    labelText: 'Entry',
                    hintText: 'Capture your thoughts, even offline.',
                  ),
                ),
                const SizedBox(height: AppSpacing.x3),
                Text(
                  'Mood: ${state.moodScore}/5',
                  style: theme.textTheme.bodyMedium,
                ),
                Slider(
                  min: 1,
                  max: 5,
                  divisions: 4,
                  value: state.moodScore.toDouble(),
                  label: '${state.moodScore}',
                  onChanged: state.isSyncing
                      ? null
                      : (value) {
                          unawaited(viewModel.updateMoodScore(value.round()));
                        },
                ),
                Text(
                  'Pending sync: ${state.pendingSyncCount}',
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
                  label: state.isSyncing ? 'Syncing...' : 'Save + Sync Entry',
                  onPressed: state.isSyncing ? null : viewModel.submitEntry,
                ),
                const SizedBox(height: AppSpacing.x3),
                ActionButton(
                  label: 'Retry Pending Sync',
                  onPressed: state.isSyncing || state.pendingSyncCount == 0
                      ? null
                      : viewModel.retryPendingSync,
                ),
                const SizedBox(height: AppSpacing.x3),
                ActionButton(
                  label: 'Clear Draft',
                  onPressed: state.isSyncing ? null : viewModel.clearLocalDraft,
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
