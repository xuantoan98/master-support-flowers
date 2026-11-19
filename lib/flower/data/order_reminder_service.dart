import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/flower_order.dart';
import '../domain/order_reminder.dart';

class OrderReminderService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> _initialize() async {
    if (_initialized) {
      return;
    }
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    await _initialize();
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null ||
          await android.requestNotificationsPermission() != true) {
        return false;
      }
      return await android.requestExactAlarmsPermission() ?? false;
    }
    if (Platform.isIOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, sound: true) ??
          false;
    }
    return false;
  }

  Future<void> sync(
    Iterable<FlowerOrder> orders, {
    required bool enabled,
  }) async {
    await _initialize();
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (request.id >= 100000000 && request.id < 200000000) {
        await _plugin.cancel(id: request.id);
      }
    }
    if (!enabled) {
      return;
    }
    final reminders = planOrderReminders(orders, now: DateTime.now());
    for (final reminder in reminders) {
      await _plugin.zonedSchedule(
        id: reminder.notificationId,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: tz.TZDateTime.from(reminder.at.toUtc(), tz.UTC),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'flower_orders',
            'Nhắc đơn hoa',
            channelDescription: 'Giờ giao hàng và công nợ đơn hoa',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }
}
