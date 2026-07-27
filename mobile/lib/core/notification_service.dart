import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Schedules the daily "log your spending" reminder. A thin wrapper around
/// flutter_local_notifications so the rest of the app only deals with a
/// simple enable/disable + time-of-day API. Every public method degrades
/// gracefully (returns false / no-ops) rather than throwing if the native
/// plugin channel is unavailable, since a failed reminder should never
/// crash the rest of the app.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _dailyReminderId = 1001;
  static const _channelId = 'daily_reminder';
  static const _channelName = 'Daily reminder';
  static const _channelDescription =
      "Reminds you to log today's income and expenses";

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;

    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (error, stackTrace) {
      debugPrint('Could not resolve local timezone: $error\n$stackTrace');
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        ),
      );
      _initialized = true;
      return true;
    } catch (error, stackTrace) {
      debugPrint('Could not initialize notifications: $error\n$stackTrace');
      return false;
    }
  }

  Future<bool> requestPermission() async {
    if (!await _ensureInitialized()) return false;

    try {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        // null means the runtime POST_NOTIFICATIONS permission doesn't apply
        // on this OS version (Android < 13), not that it was denied — fall
        // back to whether notifications are actually enabled for the app.
        if (granted != null) return granted;
        return await androidPlugin.areNotificationsEnabled() ?? true;
      }

      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (iosPlugin != null) {
        return await iosPlugin.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      }

      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'Could not request notification permission: $error\n$stackTrace',
      );
      return false;
    }
  }

  /// Checks current permission status without prompting the user. Used to
  /// detect a permission that was revoked from system settings after the
  /// reminder was enabled, so the app doesn't keep believing it's active.
  Future<bool> arePermissionsGranted() async {
    if (!await _ensureInitialized()) return false;

    try {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        return await androidPlugin.areNotificationsEnabled() ?? true;
      }

      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (iosPlugin != null) {
        final status = await iosPlugin.checkPermissions();
        return status?.isEnabled ?? true;
      }

      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'Could not check notification permission: $error\n$stackTrace',
      );
      return true;
    }
  }

  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    if (!await _ensureInitialized()) return;

    try {
      await _plugin.zonedSchedule(
        id: _dailyReminderId,
        title: "Log today's spending",
        body: "Take a minute to add today's income and expenses.",
        scheduledDate: _nextInstanceOf(hour, minute),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (error, stackTrace) {
      debugPrint('Could not schedule daily reminder: $error\n$stackTrace');
    }
  }

  Future<void> cancelDailyReminder() async {
    if (!await _ensureInitialized()) return;

    try {
      await _plugin.cancel(id: _dailyReminderId);
    } catch (error, stackTrace) {
      debugPrint('Could not cancel daily reminder: $error\n$stackTrace');
    }
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
