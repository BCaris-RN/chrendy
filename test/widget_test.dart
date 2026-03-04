import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:android_app_template/app.dart';
import 'package:android_app_template/data/providers.dart';

void main() {
  testWidgets('Home view renders Caris shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          connectivityChangesProvider.overrideWithValue(
            const Stream<bool>.empty(),
          ),
        ],
        child: const CarisApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chrendy Journal'), findsOneWidget);
    expect(find.text('Journal today'), findsOneWidget);
  });
}
