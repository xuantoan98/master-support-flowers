import 'dart:io';

import 'package:flower_orders/flower/data/order_repository.dart';
import 'package:flower_orders/flower/domain/flower_order.dart';
import 'package:flower_orders/flower/domain/order_reminder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final now = DateTime(2026, 11, 20, 9);
  FlowerOrder order({
    int id = 4,
    OrderStatus status = OrderStatus.making,
    int paid = 0,
    DateTime? deliveryAt,
  }) => FlowerOrder(
    id: id,
    customerName: 'Lan',
    phone: '',
    productName: 'Hoa',
    price: 100000,
    shippingFee: 0,
    paid: paid,
    deliveryAt: deliveryAt ?? now.add(const Duration(hours: 2)),
    address: 'Hà Nội',
    status: status,
  );

  test('plans delivery and payment checks without personal details', () {
    final reminders = planOrderReminders([order()], now: now);
    expect(reminders.map((r) => r.kind), [
      ReminderKind.beforeDelivery,
      ReminderKind.overdueDelivery,
      ReminderKind.outstandingPayment,
    ]);
    expect(reminders.first.at, now.add(const Duration(hours: 1)));
    expect(reminders.first.title, isNot(contains('Lan')));
    expect(reminders.first.notificationId, 100000040);
  });

  test('status and payment changes remove obsolete reminders', () {
    expect(
      planOrderReminders([order(status: OrderStatus.cancelled)], now: now),
      isEmpty,
    );
    expect(
      planOrderReminders([
        order(status: OrderStatus.delivered),
      ], now: now).map((r) => r.kind),
      [ReminderKind.outstandingPayment],
    );
    expect(
      planOrderReminders([
        order(status: OrderStatus.delivered, paid: 100000),
      ], now: now),
      isEmpty,
    );
  });

  test('moving delivery time moves every pending reminder', () {
    final original = planOrderReminders([order()], now: now);
    final moved = planOrderReminders([
      order(deliveryAt: now.add(const Duration(hours: 26))),
    ], now: now);
    final originalByKind = {
      for (final reminder in original) reminder.kind: reminder,
    };
    for (final reminder in moved) {
      final prior = originalByKind[reminder.kind]!;
      expect(reminder.notificationId, prior.notificationId);
      expect(reminder.at.difference(prior.at), const Duration(days: 1));
      expect(reminder.body, isNot(contains('Lan')));
    }
  });

  test('past reminders are skipped and pending list is capped', () {
    final past = order(deliveryAt: now.subtract(const Duration(days: 2)));
    expect(planOrderReminders([past], now: now), isEmpty);
    final many = List.generate(40, (index) => order(id: index + 1));
    expect(planOrderReminders(many, now: now), hasLength(60));
  });

  test('v12 migration adds durable opt-in reminder setting', () async {
    final directory = await Directory.systemTemp.createTemp('flower_remind_');
    final path = '${directory.path}/orders.db';
    final old = await openDatabase(
      path,
      version: 12,
      onCreate: (db, _) async {
        await db.execute('CREATE TABLE old_marker (value TEXT NOT NULL)');
        await db.insert('old_marker', {'value': 'kept'});
      },
    );
    await old.close();
    final repository = OrderRepository();
    try {
      await repository.open(databasePath: path);
      expect(await repository.remindersEnabled(), isFalse);
      await repository.setRemindersEnabled(true);
      await repository.close();
      await repository.open(databasePath: path);
      expect(await repository.remindersEnabled(), isTrue);
      expect((await repository.db.query('old_marker')).single['value'], 'kept');
    } finally {
      await repository.close();
      await directory.delete(recursive: true);
    }
  });
}
