import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_config.dart';
import '../../core/app_lock_controller.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/aurora_background.dart';

/// Covers the whole app with a biometric/device-credential lock screen while
/// someone is signed in and app lock is on. Locks on cold start and whenever
/// the app returns from the background.
///
/// It wraps the Navigator (see MoneyMasterApp's builder) rather than a page:
/// a lock inside the dashboard page left every screen pushed above it
/// (Analytics, Settings, forms, dialogs) visible on return. While locked the
/// app underneath is not painted, hit-tested, focused or read out.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({
    super.key,
    required this.child,
    required this.navigatorKey,
    this.signedIn,
  });

  final Widget child;

  /// Used to close every open screen when the user signs out, so nothing
  /// from the previous session stays on top of the sign-in screen.
  final GlobalKey<NavigatorState> navigatorKey;

  /// Whether someone is signed in. Defaults to following Supabase auth.
  final ValueListenable<bool>? signedIn;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  late final ValueListenable<bool> _signedIn;
  _SupabaseSignedIn? _ownedSignedIn;
  late bool _wasSignedIn;
  bool _locked = false;
  bool _appliedInitialState = false;
  bool _authenticating = false;
  bool _pendingRelock = false;

  @override
  void initState() {
    super.initState();
    _signedIn = widget.signedIn ?? (_ownedSignedIn = _SupabaseSignedIn());
    _wasSignedIn = _signedIn.value;
    _signedIn.addListener(_onSessionChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _signedIn.removeListener(_onSessionChanged);
    _ownedSignedIn?.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    final signedIn = _signedIn.value;
    if (signedIn == _wasSignedIn) return;
    _wasSignedIn = signedIn;
    if (!signedIn) {
      widget.navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
    // Signing in has just proved who this is, so don't ask again straight
    // away; signing out leaves nothing to protect.
    setState(() {
      _appliedInitialState = true;
      _locked = false;
      _pendingRelock = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_signedIn.value || !ref.read(appLockProvider).enabled) return;

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
    // auth + RLS remain the real security boundary), and _onSessionChanged
    // then closes every open screen and removes the lock.
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = _signedIn.value;
    Widget? cover;

    // Settings are only read while signed in: nobody signed out needs a
    // lock, and it keeps platform lookups out of the signed-out app.
    if (signedIn) {
      final settings = ref.watch(appLockProvider);
      if (!settings.loaded) {
        // Don't flash balances before it's known whether to lock them.
        cover = const _AppLockSplash();
      } else {
        if (!_appliedInitialState) {
          _appliedInitialState = true;
          _locked = settings.enabled;
          if (_locked) _promptSoon();
        }
        if (_locked) {
          cover = _LockScreen(
            isAuthenticating: _authenticating,
            onUnlock: _unlock,
            onSignOut: _signOut,
          );
        }
      }
    }

    final hidden = cover != null;
    // The app stays at the same place in the tree whether covered or not, so
    // the Navigator and every open screen keep their state across locking.
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeFocus(
          excluding: hidden,
          child: Visibility(
            visible: !hidden,
            maintainState: true,
            child: widget.child,
          ),
        ),
        ?cover,
      ],
    );
  }
}

/// Follows whether a Supabase session exists.
class _SupabaseSignedIn extends ValueNotifier<bool> {
  _SupabaseSignedIn()
    : super(
        AppConfig.hasSupabaseConfig &&
            Supabase.instance.client.auth.currentSession != null,
      ) {
    if (!AppConfig.hasSupabaseConfig) return;
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (event) => value = event.session != null,
    );
  }

  StreamSubscription<AuthState>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
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
