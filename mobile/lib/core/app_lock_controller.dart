import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _appLockEnabledPrefsKey = 'dmt_app_lock_enabled';

class AppLockSettings {
  const AppLockSettings({
    required this.loaded,
    required this.enabled,
    required this.isSupported,
  });

  /// True once the saved preference has finished loading from disk.
  final bool loaded;
  final bool enabled;

  /// Whether this device has a biometric or device-credential lock the
  /// feature can rely on at all.
  final bool isSupported;

  AppLockSettings copyWith({bool? loaded, bool? enabled, bool? isSupported}) {
    return AppLockSettings(
      loaded: loaded ?? this.loaded,
      enabled: enabled ?? this.enabled,
      isSupported: isSupported ?? this.isSupported,
    );
  }
}

class AppLockController extends Notifier<AppLockSettings> {
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  AppLockSettings build() {
    unawaited(_restore());
    return const AppLockSettings(
      loaded: false,
      enabled: false,
      isSupported: true,
    );
  }

  Future<void> _restore() async {
    bool supported;
    try {
      supported = await _auth.isDeviceSupported();
    } catch (_) {
      supported = false;
    }

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_appLockEnabledPrefsKey) ?? false;
    state = AppLockSettings(
      loaded: true,
      enabled: saved && supported,
      isSupported: supported,
    );
  }

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appLockEnabledPrefsKey, enabled);
  }

  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock Money Master',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}

final appLockProvider = NotifierProvider<AppLockController, AppLockSettings>(
  AppLockController.new,
);
