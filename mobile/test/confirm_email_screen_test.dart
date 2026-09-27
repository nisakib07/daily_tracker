import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_master/features/auth/confirm_email_screen.dart';
import 'package:money_master/shared/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakeConfirmationAuth implements EmailConfirmationAuth {
  final calls = <String>[];
  Object? verifyError;

  @override
  Future<void> verify({required String email, required String code}) async {
    calls.add('verify:$email:$code');
    final error = verifyError;
    if (error != null) throw error;
  }

  @override
  Future<void> resend(String email) async {
    calls.add('resend:$email');
  }
}

const _email = 'new@example.com';

Future<void> _open(WidgetTester tester, EmailConfirmationAuth auth) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ConfirmEmailScreen(email: _email, auth: auth),
                ),
              ),
              child: const Text('Sign up'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Sign up'));
  await tester.pumpAndSettle();
}

Finder get _codeField =>
    find.widgetWithText(TextFormField, 'Confirmation code');
Finder get _confirm => find.widgetWithText(FilledButton, 'Confirm');

void main() {
  testWidgets('says where the code went and validates it', (tester) async {
    final auth = _FakeConfirmationAuth();
    await _open(tester, auth);

    expect(find.textContaining(_email), findsOneWidget);

    await tester.tap(_confirm);
    await tester.pumpAndSettle();
    expect(find.text('Enter the code from the email'), findsOneWidget);

    await tester.enterText(_codeField, '12ab3');
    await tester.tap(_confirm);
    await tester.pumpAndSettle();
    expect(find.text('The code has at least 6 digits'), findsOneWidget);
    expect(auth.calls, isEmpty);
  });

  testWidgets('a valid code confirms, signs in and goes back', (tester) async {
    final auth = _FakeConfirmationAuth();
    await _open(tester, auth);

    await tester.enterText(_codeField, '123456');
    await tester.tap(_confirm);
    await tester.pumpAndSettle();

    expect(auth.calls, ['verify:$_email:123456']);
    expect(find.byType(ConfirmEmailScreen), findsNothing);
    expect(
      find.text('Email confirmed. Welcome to Money Master!'),
      findsOneWidget,
    );
  });

  testWidgets('explains a wrong or expired code', (tester) async {
    final auth = _FakeConfirmationAuth()
      ..verifyError = const AuthException(
        'Token has expired or is invalid',
        statusCode: '403',
        code: 'otp_expired',
      );
    await _open(tester, auth);

    await tester.enterText(_codeField, '123456');
    await tester.tap(_confirm);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('That code is wrong or has expired'),
      findsOneWidget,
    );
    expect(find.byType(ConfirmEmailScreen), findsOneWidget);
  });

  testWidgets('allows resending once a minute', (tester) async {
    final auth = _FakeConfirmationAuth();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: ConfirmEmailScreen(email: _email, auth: auth),
      ),
    );
    // Plain pumps: the countdown ticks every second.
    await tester.pump();

    final waiting = find.widgetWithText(TextButton, 'Resend code in 60s');
    expect(tester.widget<TextButton>(waiting).onPressed, isNull);

    await tester.pump(const Duration(seconds: 60));
    final ready = find.widgetWithText(TextButton, 'Resend code');
    await tester.ensureVisible(ready);
    await tester.tap(ready);
    await tester.pump();
    await tester.pump();

    expect(auth.calls, ['resend:$_email']);
    expect(
      find.text('New code sent. Use the code from the newest email.'),
      findsOneWidget,
    );
    expect(find.text('Resend code in 60s'), findsOneWidget);
  });

  for (final size in const [Size(320, 568), Size(1440, 900)]) {
    testWidgets('fits at ${size.width.toInt()}x${size.height.toInt()}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _open(tester, _FakeConfirmationAuth());
      await tester.tap(_confirm);
      await tester.pumpAndSettle();

      expect(find.text('Confirm your email'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
