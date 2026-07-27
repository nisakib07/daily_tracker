import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

const _reminderEnabledPrefsKey = 'dmt_daily_reminder_enabled';
const _reminderHourPrefsKey = 'dmt_daily_reminder_hour';
const _reminderMinutePrefsKey = 'dmt_daily_reminder_minute';

const TimeOfDay kDefaultReminderTime = TimeOfDay(hour: 20, minute: 0);

class DailyReminderSettings {
  const DailyReminderSettings({
    required this.loaded,
    required this.enabled,
    required this.time,
  });

  final bool loaded;
  final bool enabled;
  final TimeOfDay time;

  DailyReminderSettings copyWith({
    bool? loaded,
    bool? enabled,
    TimeOfDay? time,
  }) {
    return DailyReminderSettings(
      loaded: loaded ?? this.loaded,
      enabled: enabled ?? this.enabled,
      time: time ?? this.time,
    );
  }
}

class DailyReminderController extends Notifier<DailyReminderSettings> {
  @override
  DailyReminderSettings build() {
    unawaited(_restore());
    return const DailyReminderSettings(
      loaded: false,
      enabled: false,
      time: kDefaultReminderTime,
    );
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    var enabled = prefs.getBool(_reminderEnabledPrefsKey) ?? false;
    final hour =
        prefs.getInt(_reminderHourPrefsKey) ?? kDefaultReminderTime.hour;
    final minute =
        prefs.getInt(_reminderMinutePrefsKey) ?? kDefaultReminderTime.minute;

    if (enabled &&
        !await NotificationService.instance.arePermissionsGranted()) {
      // The OS-level permission was revoked (e.g. from system settings)
      // since the reminder was enabled; reflect that instead of silently
      // keeping a reminder "on" that will never actually fire.
      enabled = false;
      await prefs.setBool(_reminderEnabledPrefsKey, false);
    }

    state = DailyReminderSettings(
      loaded: true,
      enabled: enabled,
      time: TimeOfDay(hour: hour, minute: minute),
    );
    if (enabled) {
      await NotificationService.instance.scheduleDailyReminder(
        hour: hour,
        minute: minute,
      );
    }
  }

  /// Returns false if the user declined the notification permission.
  Future<bool> setEnabled(bool enabled) async {
    if (enabled) {
      final granted = await NotificationService.instance.requestPermission();
      if (!granted) return false;
      await NotificationService.instance.scheduleDailyReminder(
        hour: state.time.hour,
        minute: state.time.minute,
      );
    } else {
      await NotificationService.instance.cancelDailyReminder();
    }

    state = state.copyWith(enabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reminderEnabledPrefsKey, enabled);
    return true;
  }

  Future<void> setTime(TimeOfDay time) async {
    state = state.copyWith(time: time);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_reminderHourPrefsKey, time.hour);
    await prefs.setInt(_reminderMinutePrefsKey, time.minute);

    if (state.enabled) {
      await NotificationService.instance.scheduleDailyReminder(
        hour: time.hour,
        minute: time.minute,
      );
    }
  }
}

final dailyReminderProvider =
    NotifierProvider<DailyReminderController, DailyReminderSettings>(
      DailyReminderController.new,
    );
