import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/features/auth/forgot_password_screen.dart';
import 'package:money_master/shared/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeResetAuth implements PasswordResetAuth {
  final calls = <String>[];
  Object? verifyError;
  Object? passwordError;

  @override
  Future<void> sendCode(String email) async {
    calls.add('send:$email');
  }

  @override
  Future<void> verifyCode({required String email, required String code}) async {
    calls.add('verify:$email:$code');
    final error = verifyError;
    if (error != null) throw error;
  }

  @override
  Future<void> setNewPassword(String password) async {
    calls.add('password:$password');
    final error = passwordError;
    if (error != null) throw error;
  }
}

const _email = 'me@example.com';

/// Opens the screen from a host page, the way SignInScreen does, so tests
/// can check that a finished reset pops back.
Future<void> _openScreen(WidgetTester tester, PasswordResetAuth auth) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ForgotPasswordScreen(auth: auth),
                ),
              ),
              child: const Text('Open reset'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open reset'));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

Future<void> _sendCodeTo(WidgetTester tester, String email) async {
  await tester.enterText(_field('Email'), email);
  await _tap(tester, find.widgetWithText(FilledButton, 'Send code'));
}

Future<void> _fillCodeStep(
  WidgetTester tester, {
  String code = '123456',
  String password = 'newpass1',
  String? confirm,
}) async {
  await tester.enterText(_field('Reset code'), code);
  await tester.enterText(_field('New password'), password);
  await tester.enterText(_field('Confirm new password'), confirm ?? password);
}

Finder get _resetButton => find.widgetWithText(FilledButton, 'Reset password');

void main() {
  testWidgets('validates the email before sending a code', (tester) async {
    final auth = _FakeResetAuth();
    await _openScreen(tester, auth);

    expect(find.text('Forgot your password?'), findsOneWidget);

    await _tap(tester, find.widgetWithText(FilledButton, 'Send code'));
    expect(find.text('Enter your email'), findsOneWidget);

    await _sendCodeTo(tester, 'not-an-email');
    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(auth.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sends a code and moves to the code step', (tester) async {
    final auth = _FakeResetAuth();
    await _openScreen(tester, auth);

    await _sendCodeTo(tester, '  $_email ');

    expect(auth.calls, ['send:$_email']);
    expect(find.text('Check your email'), findsOneWidget);
    expect(find.textContaining(_email), findsOneWidget);
    expect(_field('Reset code'), findsOneWidget);
    expect(_resetButton, findsOneWidget);
  });

  testWidgets('validates the code and the new password', (tester) async {
    final auth = _FakeResetAuth();
    await _openScreen(tester, auth);
    await _sendCodeTo(tester, _email);

    await _tap(tester, _resetButton);
    expect(find.text('Enter the code from the email'), findsOneWidget);
    expect(find.text('Use at least 6 characters'), findsOneWidget);

    await _fillCodeStep(
      tester,
      code: '12ab3',
      password: 'newpass1',
      confirm: 'newpass2',
    );
    await _tap(tester, _resetButton);
    // Letters are filtered out of the code as it is typed.
    expect(find.text('123'), findsOneWidget);
    expect(find.text('The code has at least 6 digits'), findsOneWidget);
    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(auth.calls, ['send:$_email']);
  });

  testWidgets('verifies the code, saves the password, and pops back', (
    tester,
  ) async {
    final auth = _FakeResetAuth();
    await _openScreen(tester, auth);
    await _sendCodeTo(tester, _email);

    await _fillCodeStep(tester);
    await _tap(tester, _resetButton);

    expect(auth.calls, [
      'send:$_email',
      'verify:$_email:123456',
      'password:newpass1',
    ]);
    expect(find.byType(ForgotPasswordScreen), findsNothing);
    expect(find.text('Open reset'), findsOneWidget);
    expect(find.text("Password updated. You're signed in."), findsOneWidget);
  });

  testWidgets('explains a wrong or expired code without saving', (
    tester,
  ) async {
    final auth = _FakeResetAuth()
      ..verifyError = const AuthException(
        'Token has expired or is invalid',
        statusCode: '403',
        code: 'otp_expired',
      );
    await _openScreen(tester, auth);
    await _sendCodeTo(tester, _email);

    await _fillCodeStep(tester);
    await _tap(tester, _resetButton);

    expect(
      find.textContaining('That code is wrong or has expired'),
      findsOneWidget,
    );
    expect(auth.calls, ['send:$_email', 'verify:$_email:123456']);
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
  });

  testWidgets('retries a failed password save without reusing the code', (
    tester,
  ) async {
    final auth = _FakeResetAuth()
      ..passwordError = const AuthException(
        'New password should be different from the old password.',
        statusCode: '422',
        code: 'same_password',
      );
    await _openScreen(tester, auth);
    await _sendCodeTo(tester, _email);

    await _fillCodeStep(tester);
    await _tap(tester, _resetButton);

    expect(
      find.text('Choose a password that is different from your old one.'),
      findsOneWidget,
    );
    final codeField = tester.widget<TextField>(
      find.descendant(
        of: _field('Reset code'),
        matching: find.byType(TextField),
      ),
    );
    expect(codeField.enabled, isFalse);
    expect(find.text('Use a different email'), findsNothing);

    auth.passwordError = null;
    await tester.enterText(_field('New password'), 'another1');
    await tester.enterText(_field('Confirm new password'), 'another1');
    await _tap(tester, _resetButton);

    expect(auth.calls, [
      'send:$_email',
      'verify:$_email:123456',
      'password:newpass1',
      'password:another1',
    ]);
    expect(find.byType(ForgotPasswordScreen), findsNothing);
  });

  testWidgets('allows resending the code once a minute', (tester) async {
    final auth = _FakeResetAuth();
    await _openScreen(tester, auth);

    await tester.enterText(_field('Email'), _email);
    await tester.tap(find.widgetWithText(FilledButton, 'Send code'));
    // Plain pumps, not pumpAndSettle: the countdown ticks every second and
    // pumpAndSettle would run it to the end.
    await tester.pump();
    await tester.pump();

    final waiting = find.widgetWithText(TextButton, 'Resend code in 60s');
    expect(waiting, findsOneWidget);
    expect(tester.widget<TextButton>(waiting).onPressed, isNull);

    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Resend code in 30s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    final ready = find.widgetWithText(TextButton, 'Resend code');
    expect(ready, findsOneWidget);

    await tester.ensureVisible(ready);
    await tester.tap(ready);
    await tester.pump();
    await tester.pump();

    expect(auth.calls, ['send:$_email', 'send:$_email']);
    expect(
      find.text('New code sent. Use the code from the newest email.'),
      findsOneWidget,
    );
    expect(find.text('Resend code in 60s'), findsOneWidget);
  });

  testWidgets('can go back and use a different email', (tester) async {
    final auth = _FakeResetAuth();
    await _openScreen(tester, auth);
    await _sendCodeTo(tester, _email);

    await _tap(
      tester,
      find.widgetWithText(TextButton, 'Use a different email'),
    );

    expect(find.text('Forgot your password?'), findsOneWidget);
    await _sendCodeTo(tester, 'other@example.com');
    expect(auth.calls, ['send:$_email', 'send:other@example.com']);
  });

  for (final size in const [Size(320, 568), Size(1440, 900)]) {
    testWidgets('both steps fit at ${size.width.toInt()}x'
        '${size.height.toInt()}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final auth = _FakeResetAuth();
      await _openScreen(tester, auth);
      expect(find.text('Reset password'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _sendCodeTo(tester, _email);
      await _tap(tester, _resetButton);
      expect(find.text('Enter the code from the email'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
