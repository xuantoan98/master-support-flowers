import 'dart:io';

import 'package:flower_orders/flower/data/order_repository.dart';
import 'package:flower_orders/flower/domain/flower_order.dart';
import 'package:flower_orders/flower/domain/live_delivery.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  FlowerOrder order(int id, DateTime at, OrderStatus status) => FlowerOrder(
    id: id,
    customerName: 'Tên riêng tư',
    phone: '0900000000',
    productName: 'Hoa',
    price: 100000,
    shippingFee: 0,
    paid: 0,
    deliveryAt: at,
    address: 'Địa chỉ riêng tư',
    status: status,
  );

  test(
    'selects only three nearest delivering orders without customer data',
    () {
      final at = DateTime(2026, 11, 20, 14);
      final deliveries = planLiveDeliveries([
        order(1, at.add(const Duration(hours: 3)), OrderStatus.delivering),
        order(2, at, OrderStatus.delivered),
        order(3, at.add(const Duration(hours: 1)), OrderStatus.delivering),
        order(4, at.add(const Duration(hours: 2)), OrderStatus.delivering),
        order(5, at, OrderStatus.delivering),
        order(6, at, OrderStatus.cancelled),
      ]);
      expect(deliveries.map((item) => item.orderId), [5, 3, 4]);
      expect(deliveries.first.toChannelMap(), {
        'orderId': 5,
        'deliveryAtEpochMillis': at.millisecondsSinceEpoch,
      });
      expect(
        deliveries.first.toChannelMap().toString(),
        isNot(contains('riêng tư')),
      );
    },
  );

  test('live activity opt-in persists independently of reminders', () async {
    final directory = await Directory.systemTemp.createTemp('flower_live_');
    final repository = OrderRepository();
    try {
      await repository.open(databasePath: '${directory.path}/orders.db');
      expect(await repository.liveActivityEnabled(), isFalse);
      await repository.setLiveActivityEnabled(true);
      await repository.close();
      await repository.open(databasePath: '${directory.path}/orders.db');
      expect(await repository.liveActivityEnabled(), isTrue);
      expect(await repository.remindersEnabled(), isFalse);
    } finally {
      await repository.close();
      await directory.delete(recursive: true);
    }
  });
}
