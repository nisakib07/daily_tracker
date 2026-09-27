import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_form_page.dart';
import '../../shared/widgets/app_state_widgets.dart';

/// The auth calls the reset flow makes, behind an interface so widget tests
/// can drive the flow without a live Supabase project.
abstract interface class PasswordResetAuth {
  Future<void> sendCode(String email);

  /// Signs the user in if [code] is valid. Codes are single-use.
  Future<void> verifyCode({required String email, required String code});

  Future<void> setNewPassword(String password);
}

class SupabasePasswordResetAuth implements PasswordResetAuth {
  const SupabasePasswordResetAuth();

  GoTrueClient get _auth => Supabase.instance.client.auth;

  @override
  Future<void> sendCode(String email) => _auth.resetPasswordForEmail(email);

  @override
  Future<void> verifyCode({required String email, required String code}) async {
    await _auth.verifyOTP(email: email, token: code, type: OtpType.recovery);
  }

  @override
  Future<void> setNewPassword(String password) async {
    await _auth.updateUser(UserAttributes(password: password));
  }
}

/// Resets the password entirely inside the app, using the code from the
/// reset email rather than its link. supabase_flutter starts the reset with
/// PKCE, so the secret needed to finish it is stored in this app, and the
/// website that the link opens has no way to complete it.
///
/// Verifying the code signs the user in, which swaps AuthGate to the
/// dashboard underneath this route; the route stays on top until the new
/// password is saved, then pops back to the dashboard.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.auth = const SupabasePasswordResetAuth(),
  });

  final PasswordResetAuth auth;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

enum _ResetStep { email, code }

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Supabase refuses a new reset email for the same address within a minute.
  static const _resendCooldownSeconds = 60;

  final _emailFormKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  _ResetStep _step = _ResetStep.email;
  bool _isBusy = false;
  // Once a code is accepted it can't be used again, so a failed password
  // save is retried without verifying a second time.
  bool _codeVerified = false;
  int _resendSecondsLeft = 0;
  Timer? _resendTimer;
  String? _error;
  String? _notice;

  String get _email => _emailController.text.trim();

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_emailFormKey.currentState!.validate()) return;
    final sent = await _run(() => widget.auth.sendCode(_email));
    if (!sent || !mounted) return;
    setState(() => _step = _ResetStep.code);
    _startResendCooldown();
  }

  Future<void> _resendCode() async {
    final sent = await _run(() => widget.auth.sendCode(_email));
    if (!sent || !mounted) return;
    setState(
      () => _notice = 'New code sent. Use the code from the newest email.',
    );
    _startResendCooldown();
  }

  Future<void> _resetPassword() async {
    if (!_codeFormKey.currentState!.validate()) return;
    final saved = await _run(() async {
      if (!_codeVerified) {
        await widget.auth.verifyCode(
          email: _email,
          code: _codeController.text.trim(),
        );
        if (mounted) setState(() => _codeVerified = true);
      }
      await widget.auth.setNewPassword(_passwordController.text);
    });
    if (!saved || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Password updated. You're signed in.")),
    );
    Navigator.of(context).pop();
  }

  void _changeEmail() {
    _resendTimer?.cancel();
    setState(() {
      _step = _ResetStep.email;
      _resendSecondsLeft = 0;
      _error = null;
      _notice = null;
      _codeController.clear();
    });
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSecondsLeft = _resendCooldownSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _resendSecondsLeft--);
      if (_resendSecondsLeft <= 0) timer.cancel();
    });
  }

  /// Runs [action] with the busy state and error handling every step
  /// shares. Returns whether it succeeded.
  Future<bool> _run(Future<void> Function() action) async {
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await action();
      return true;
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = _describe(error));
      return false;
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
      return false;
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  String _describe(AuthException error) {
    return switch (ErrorCode.fromCode(error.code ?? '')) {
      ErrorCode.otpExpired =>
        'That code is wrong or has expired. Check the newest email, or send '
            'a new code.',
      ErrorCode.samePassword =>
        'Choose a password that is different from your old one.',
      _ => error.message,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AppFormPage(
      title: 'Reset password',
      accent: AppTheme.neonCyan,
      child: SingleChildScrollView(
        padding: appFormContentPadding(context),
        child: switch (_step) {
          _ResetStep.email => _buildEmailStep(),
          _ResetStep.code => _buildCodeStep(),
        },
      ),
    );
  }

  Widget _buildEmailStep() {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppFormHeader(
            title: 'Forgot your password?',
            subtitle: "Enter your email and we'll send you a reset code",
            icon: Icons.lock_reset,
            color: AppTheme.neonCyan,
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            onFieldSubmitted: (_) => _sendCode(),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) return 'Enter your email';
              if (!email.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          ..._buildMessages(),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _isBusy ? null : _sendCode,
            icon: _isBusy
                ? _busyIndicator('Sending')
                : const Icon(Icons.send_outlined),
            label: Text(_isBusy ? 'Sending...' : 'Send code'),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeStep() {
    return Form(
      key: _codeFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppFormHeader(
            title: 'Check your email',
            subtitle:
                'Enter the code we sent to $_email and choose a new password',
            icon: Icons.mark_email_read_outlined,
            color: AppTheme.neonCyan,
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _codeController,
            enabled: !_codeVerified,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.oneTimeCode],
            autofocus: true,
            // Supabase codes are 6 digits by default, and up to 10 when the
            // project's OTP length is raised.
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: InputDecoration(
              labelText: 'Reset code',
              prefixIcon: const Icon(Icons.pin_outlined),
              suffixIcon: _codeVerified
                  ? const Icon(Icons.check_circle, color: AppTheme.neonEmerald)
                  : null,
            ),
            validator: (value) {
              if (_codeVerified) return null;
              final code = value?.trim() ?? '';
              if (code.isEmpty) return 'Enter the code from the email';
              if (code.length < 6) return 'The code has at least 6 digits';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(
              labelText: 'New password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            validator: (value) {
              if ((value ?? '').length < 6) return 'Use at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(
              labelText: 'Confirm new password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            onFieldSubmitted: (_) => _resetPassword(),
            validator: (value) {
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          ..._buildMessages(),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _isBusy ? null : _resetPassword,
            icon: _isBusy
                ? _busyIndicator('Saving')
                : const Icon(Icons.lock_reset),
            label: Text(_isBusy ? 'Saving...' : 'Reset password'),
          ),
          if (!_codeVerified) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isBusy || _resendSecondsLeft > 0 ? null : _resendCode,
              child: Text(
                _resendSecondsLeft > 0
                    ? 'Resend code in ${_resendSecondsLeft}s'
                    : 'Resend code',
              ),
            ),
            TextButton(
              onPressed: _isBusy ? null : _changeEmail,
              child: const Text('Use a different email'),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildMessages() {
    return [
      if (_notice != null) ...[
        const SizedBox(height: 12),
        AppInlineNotice(
          icon: Icons.info_outline,
          message: _notice!,
          color: AppTheme.neonCyan,
        ),
      ],
      if (_error != null) ...[
        const SizedBox(height: 12),
        AppInlineNotice(
          icon: Icons.error_outline,
          message: _error!,
          color: AppTheme.neonRose,
        ),
      ],
    ];
  }

  Widget _busyIndicator(String label) {
    return Semantics(
      label: label,
      child: const SizedBox.square(
        dimension: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
