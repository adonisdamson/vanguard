import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vanguard/features/members/presentation/screens/registration_screen.dart';
import 'package:vanguard/shared/theme/app_theme.dart';

// Renders the REAL registration screen (Supabase deliberately uninitialized,
// so every lookup provider errors — the worst case) and proves the pinned
// action bar with Continue/Back is present and on-screen for every step.
// This is the regression test for "no continue button on the Electoral tab".
void main() {
  Future<TabController> pumpWizard(WidgetTester tester) async {
    // MUST use the real app theme: the production bug (infinite
    // OutlinedButton minimumSize blowing up Row layout in release) is
    // invisible under the default test theme.
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(theme: AppTheme.light, home: const RegistrationScreen()),
    ));
    await tester.pump();
    return tester.widget<TabBarView>(find.byType(TabBarView)).controller!;
  }

  Rect continueRect(WidgetTester tester) =>
      tester.getRect(find.text('Continue'));

  testWidgets('Personal step shows a pinned, on-screen Continue button',
      (tester) async {
    await pumpWizard(tester);
    expect(find.text('Continue'), findsOneWidget);
    final screen = tester.getSize(find.byType(MaterialApp));
    expect(continueRect(tester).bottom, lessThanOrEqualTo(screen.height));
  });

  testWidgets('Electoral step shows Continue + Back even when lookups error',
      (tester) async {
    final tabs = await pumpWizard(tester);
    tabs.index = 1; // jump straight to Electoral, bypassing validation
    await tester.pumpAndSettle();

    expect(find.text('Continue'), findsOneWidget,
        reason: 'Electoral step must always have a visible Continue');
    final screen = tester.getSize(find.byType(MaterialApp));
    final rect = continueRect(tester);
    expect(rect.bottom, lessThanOrEqualTo(screen.height),
        reason: 'Continue must be within the visible screen');
    expect(rect.height, greaterThan(0));

    // Back button (OutlinedButton) appears from step 2 onward
    expect(find.byType(OutlinedButton), findsWidgets);

    // Tapping Continue with nothing selected must SAY something, not no-op
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Complete the required fields'),
      findsOneWidget,
      reason: 'validation failure must surface in the pinned bar',
    );
  });

  testWidgets('Party step shows Submit + Save & add another', (tester) async {
    final tabs = await pumpWizard(tester);
    tabs.index = 2;
    await tester.pumpAndSettle();

    expect(find.text('Submit'), findsOneWidget);
    expect(find.text('Save & add another'), findsOneWidget);
    final screen = tester.getSize(find.byType(MaterialApp));
    expect(tester.getRect(find.text('Submit')).bottom,
        lessThanOrEqualTo(screen.height));
  });
}
