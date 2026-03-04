import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:android_app_template/features/habits/presentation/view.dart';
import 'package:android_app_template/features/journal/presentation/view.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/journal',
    routes: <RouteBase>[
      GoRoute(
        path: '/journal',
        builder: (context, state) => const JournalView(),
      ),
      GoRoute(path: '/habits', builder: (context, state) => const HabitsView()),
    ],
  );
});
