import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_config.dart';
import '../../data/cached_money_data_source.dart';
import '../../data/money_repository.dart';
import '../dashboard/dashboard_screen.dart';
import 'sign_in_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _subscription;
  User? _user;
  CachedMoneyDataSource? _dataSource;

  @override
  void initState() {
    super.initState();
    if (!AppConfig.hasSupabaseConfig) return;

    final client = Supabase.instance.client;
    _user = client.auth.currentUser;
    if (_user != null) {
      _dataSource = _createDataSource(_user!);
    }
    _subscription = client.auth.onAuthStateChange.listen((event) {
      final nextUser = event.session?.user;
      if (nextUser?.id == _user?.id) {
        if (mounted) setState(() => _user = nextUser);
        return;
      }

      final previousDataSource = _dataSource;
      final nextDataSource = nextUser == null
          ? null
          : _createDataSource(nextUser);
      if (mounted) {
        setState(() {
          _user = nextUser;
          _dataSource = nextDataSource;
        });
      }
      unawaited(previousDataSource?.close());
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    unawaited(_dataSource?.close());
    super.dispose();
  }

  CachedMoneyDataSource _createDataSource(User user) {
    return CachedMoneyDataSource(
      MoneyRepository(Supabase.instance.client),
      cacheKey: user.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.hasSupabaseConfig) {
      return const MissingConfigScreen();
    }

    if (_user == null) {
      return const SignInScreen();
    }

    // App lock is applied above the Navigator by MoneyMasterApp, so it also
    // covers screens pushed on top of the dashboard.
    return DashboardScreen(user: _user!, dataSource: _dataSource);
  }
}

class MissingConfigScreen extends StatelessWidget {
  const MissingConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        color: colorScheme.primary,
                        size: 34,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Money Master',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Supabase keys are needed before sign in can run.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      const _CodeLine('SUPABASE_URL'),
                      const SizedBox(height: 8),
                      const _CodeLine('SUPABASE_ANON_KEY'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CodeLine extends StatelessWidget {
  const _CodeLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(fontFamily: 'monospace')),
    );
  }
}
