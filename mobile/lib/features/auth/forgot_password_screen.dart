import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_config.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_form_page.dart';
import '../../shared/widgets/app_state_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSending = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _emailController.text.trim(),
        redirectTo:
            '${AppConfig.webAppUrl}/auth/callback?next=/auth/reset-password',
      );
      if (mounted) setState(() => _sent = true);
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppFormPage(
      title: 'Reset password',
      accent: AppTheme.neonCyan,
      child: SingleChildScrollView(
        padding: appFormContentPadding(context),
        child: _sent ? _buildSentState(context) : _buildFormState(context),
      ),
    );
  }

  Widget _buildSentState(BuildContext context) {
    return AppEmptyState(
      icon: Icons.mark_email_read_outlined,
      title: 'Check your email',
      message:
          "We've sent a password reset link to ${_emailController.text.trim()}. "
          'Open it on this device to finish resetting your password, then '
          'come back and sign in.',
      color: AppTheme.neonCyan,
      actionLabel: 'Back to sign in',
      onAction: () => Navigator.of(context).pop(),
    );
  }

  Widget _buildFormState(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppFormHeader(
            title: 'Forgot your password?',
            subtitle: "Enter your email and we'll send you a reset link",
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
            onFieldSubmitted: (_) => _sendResetLink(),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) return 'Enter your email';
              if (!email.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
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
            onPressed: _isSending ? null : _sendResetLink,
            icon: _isSending
                ? Semantics(
                    label: 'Sending',
                    child: const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(_isSending ? 'Sending...' : 'Send reset link'),
          ),
        ],
      ),
    );
  }
}
