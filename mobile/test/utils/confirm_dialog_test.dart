import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:service_marketplace/utils/utils.dart';

/// The "Sign out?" / "Delete your account?" dialog (Utils.confirm).
void main() {
  Future<Future<bool>> open(WidgetTester tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: Scaffold()));

    final answer = Utils.confirm(
      title: 'Sign out?',
      message: 'You will need your password again.',
      confirmLabel: 'Sign out',
      destructive: true,
    );
    await tester.pumpAndSettle();

    return answer;
  }

  testWidgets('the confirm button says yes', (tester) async {
    final answer = await open(tester);

    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirmOk')));
    await tester.pumpAndSettle();

    expect(await answer, isTrue);
  });

  testWidgets('Cancel says no', (tester) async {
    final answer = await open(tester);

    await tester.tap(find.byKey(const ValueKey('confirmCancel')));
    await tester.pumpAndSettle();

    expect(await answer, isFalse);
  });
}
