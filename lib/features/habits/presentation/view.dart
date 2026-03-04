import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:android_app_template/core/design_tokens.dart';
import 'package:android_app_template/data/providers.dart';
import 'package:android_app_template/shared/widgets/action_button.dart';

import 'viewmodel.dart';

class HabitsView extends ConsumerWidget {
  const HabitsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(phoenixSyncWorkerProvider);

    final state = ref.watch(habitsViewModelProvider);
    final viewModel = ref.read(habitsViewModelProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Chrendy Habits', style: theme.textTheme.labelMedium),
        actions: <Widget>[
          TextButton(
            onPressed: () => context.go('/journal'),
            child: const Text('Journal'),
          ),
        ],
      ),
      body: HookBuilder(
        builder: (context) {
          final habitController = useTextEditingController(
            text: state.habitName,
          );
          final noteController = useTextEditingController(text: state.note);

          useEffect(() {
            Future<void>.microtask(viewModel.restoreLocalState);
            return null;
          }, const []);

          useEffect(() {
            if (habitController.text != state.habitName) {
              habitController.value = TextEditingValue(
                text: state.habitName,
                selection: TextSelection.collapsed(
                  offset: state.habitName.length,
                ),
              );
            }
            if (noteController.text != state.note) {
              noteController.value = TextEditingValue(
                text: state.note,
                selection: TextSelection.collapsed(offset: state.note.length),
              );
            }
            return null;
          }, <Object?>[state.habitName, state.note]);

          return Padding(
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: ListView(
              children: <Widget>[
                Text('Habit logging', style: theme.textTheme.displayMedium),
                const SizedBox(height: AppSpacing.x3),
                Text(
                  'Offline-first completion events queued for Phoenix sync.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.x4),
                TextField(
                  controller: habitController,
                  onChanged: (value) {
                    unawaited(viewModel.updateHabitName(value));
                  },
                  decoration: const InputDecoration(
                    labelText: 'Habit name',
                    hintText: 'Example: Hydration',
                  ),
                ),
                const SizedBox(height: AppSpacing.x3),
                SwitchListTile(
                  title: const Text('Completed today'),
                  value: state.completed,
                  onChanged: state.isSyncing
                      ? null
                      : (value) {
                          unawaited(viewModel.updateCompleted(value));
                        },
                ),
                TextField(
                  controller: noteController,
                  minLines: 2,
                  maxLines: 5,
                  onChanged: (value) {
                    unawaited(viewModel.updateNote(value));
                  },
                  decoration: const InputDecoration(
                    labelText: 'Optional note',
                    hintText: 'Context for this habit event.',
                  ),
                ),
                const SizedBox(height: AppSpacing.x3),
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
                  label: state.isSyncing ? 'Syncing...' : 'Save + Sync Habit',
                  onPressed: state.isSyncing ? null : viewModel.submitHabitLog,
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
