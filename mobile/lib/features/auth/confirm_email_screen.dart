import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/error_messages.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_form_page.dart';
import '../../shared/widgets/app_state_widgets.dart';

/// The auth calls confirming a new account makes, behind an interface so
/// widget tests can drive the screen without a live Supabase project.
abstract interface class EmailConfirmationAuth {
  /// Confirms the account and signs in if [code] is valid.
  Future<void> verify({required String email, required String code});

  Future<void> resend(String email);
}

class SupabaseEmailConfirmationAuth implements EmailConfirmationAuth {
  const SupabaseEmailConfirmationAuth();

  GoTrueClient get _auth => Supabase.instance.client.auth;

  @override
  Future<void> verify({required String email, required String code}) async {
    await _auth.verifyOTP(email: email, token: code, type: OtpType.signup);
  }

  @override
  Future<void> resend(String email) async {
    await _auth.resend(type: OtpType.signup, email: email);
  }
}

/// Shown after signing up when the project requires confirming the email.
/// Sign-up used to end with nothing on screen, and the email's link opened
/// the website, which can't finish a sign-up started in the app (the same
/// PKCE problem as the old password reset). Entering the emailed code here
/// confirms the account and signs in; the link still works as a fallback.
///
/// Verifying signs the user in, which swaps AuthGate to the dashboard
/// underneath this route; it then pops back to it.
class ConfirmEmailScreen extends StatefulWidget {
  const ConfirmEmailScreen({
    super.key,
    required this.email,
    this.auth = const SupabaseEmailConfirmationAuth(),
  });

  final String email;
  final EmailConfirmationAuth auth;

  @override
  State<ConfirmEmailScreen> createState() => _ConfirmEmailScreenState();
}

class _ConfirmEmailScreenState extends State<ConfirmEmailScreen> {
  // Supabase refuses another email to the same address within a minute.
  static const _resendCooldownSeconds = 60;

  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isBusy = false;
  int _resendSecondsLeft = _resendCooldownSeconds;
  Timer? _resendTimer;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _startResendCooldown();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    _resendSecondsLeft = _resendCooldownSeconds;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _resendSecondsLeft--);
      if (_resendSecondsLeft <= 0) timer.cancel();
    });
  }

  Future<void> _confirm() async {
    if (!_formKey.currentState!.validate()) return;
    final confirmed = await _run(
      () => widget.auth.verify(
        email: widget.email,
        code: _codeController.text.trim(),
      ),
    );
    if (!confirmed || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Email confirmed. Welcome to Money Master!'),
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _resend() async {
    final sent = await _run(() => widget.auth.resend(widget.email));
    if (!sent || !mounted) return;
    setState(() {
      _notice = 'New code sent. Use the code from the newest email.';
      _startResendCooldown();
    });
  }

  Future<bool> _run(Future<void> Function() action) async {
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await action();
      return true;
    } on AuthException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.code == ErrorCode.otpExpired.code
              ? 'That code is wrong or has expired. Check the newest email, '
                    'or send a new code.'
              : error.message,
        );
      }
      return false;
    } catch (error) {
      if (mounted) setState(() => _error = friendlyErrorMessage(error));
      return false;
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppFormPage(
      title: 'Confirm your email',
      accent: AppTheme.neonEmerald,
      child: SingleChildScrollView(
        padding: appFormContentPadding(context),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppFormHeader(
                title: 'Check your email',
                subtitle:
                    'Enter the code we sent to ${widget.email} to finish '
                    'creating your account',
                icon: Icons.mark_email_unread_outlined,
                color: AppTheme.neonEmerald,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                autofocus: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(
                  labelText: 'Confirmation code',
                  prefixIcon: Icon(Icons.pin_outlined),
                ),
                onFieldSubmitted: (_) => _confirm(),
                validator: (value) {
                  final code = value?.trim() ?? '';
                  if (code.isEmpty) return 'Enter the code from the email';
                  if (code.length < 6) return 'The code has at least 6 digits';
                  return null;
                },
              ),
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
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _isBusy ? null : _confirm,
                icon: _isBusy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_outlined),
                label: Text(_isBusy ? 'Checking...' : 'Confirm'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isBusy || _resendSecondsLeft > 0 ? null : _resend,
                child: Text(
                  _resendSecondsLeft > 0
                      ? 'Resend code in ${_resendSecondsLeft}s'
                      : 'Resend code',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "No code in the email? Open its link instead, then come back "
                'and sign in with your email and password.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
