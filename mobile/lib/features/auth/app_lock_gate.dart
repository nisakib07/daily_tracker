import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_lock_controller.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/aurora_background.dart';

/// Wraps the signed-in app with an optional biometric/device-credential
/// lock screen. Locks on cold start (if enabled) and whenever the app
/// returns from being fully backgrounded.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  bool _locked = false;
  bool _appliedInitialState = false;
  bool _authenticating = false;
  bool _pendingRelock = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!ref.read(appLockProvider).enabled) return;

    if (state == AppLifecycleState.paused) {
      _pendingRelock = true;
    } else if (state == AppLifecycleState.resumed && _pendingRelock) {
      _pendingRelock = false;
      _lockAndPrompt();
    }
  }

  void _lockAndPrompt() {
    setState(() => _locked = true);
    _promptSoon();
  }

  void _promptSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _locked && !_authenticating) _unlock();
    });
  }

  Future<void> _unlock() async {
    if (_authenticating) return;
    setState(() => _authenticating = true);
    final success = await ref.read(appLockProvider.notifier).authenticate();
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      if (success) _locked = false;
    });
  }

  Future<void> _signOut() async {
    // The one way out if biometrics/device credential stop working while
    // app-lock is enabled — signing out ends the local session (Supabase
    // auth + RLS remain the real security boundary), and AuthGate swaps
    // this whole screen out for SignInScreen once the session clears.
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appLockProvider);

    if (!settings.loaded) {
      return const _AppLockSplash();
    }

    if (!_appliedInitialState) {
      _appliedInitialState = true;
      _locked = settings.enabled;
      if (_locked) _promptSoon();
    }

    if (!_locked) return widget.child;

    return _LockScreen(
      isAuthenticating: _authenticating,
      onUnlock: _unlock,
      onSignOut: _signOut,
    );
  }
}

class _AppLockSplash extends StatelessWidget {
  const _AppLockSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.voidBlack,
      body: SizedBox.shrink(),
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({
    required this.isAuthenticating,
    required this.onUnlock,
    required this.onSignOut,
  });

  final bool isAuthenticating;
  final VoidCallback onUnlock;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.dark(),
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned.fill(child: AuroraBackground()),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppTheme.neonEmerald, AppTheme.neonCyan],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.neonEmerald.withValues(
                                  alpha: 0.4,
                                ),
                                blurRadius: 28,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.lock_outline,
                            color: Color(0xFF04231A),
                            size: 38,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Money Master is locked',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Unlock to see your balances and activity.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: isAuthenticating ? null : onUnlock,
                            icon: isAuthenticating
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.fingerprint),
                            label: Text(
                              isAuthenticating ? 'Checking...' : 'Unlock',
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: isAuthenticating ? null : onSignOut,
                          child: const Text('Sign out instead'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
