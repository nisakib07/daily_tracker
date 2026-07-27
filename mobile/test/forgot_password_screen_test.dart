import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/features/auth/forgot_password_screen.dart';
import 'package:money_master/shared/theme/app_theme.dart';

void main() {
  testWidgets('renders the request form and validates the email field', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark(), home: const ForgotPasswordScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Forgot your password?'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Send reset link'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Send reset link'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'not-an-email');
    await tester.tap(find.widgetWithText(FilledButton, 'Send reset link'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark(), home: const ForgotPasswordScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reset password'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
