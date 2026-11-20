import 'dart:io';

import 'package:flower_orders/flower/data/order_repository.dart';
import 'package:flower_orders/flower/domain/flower_order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('order totals and validation use integer VND', () {
    final order = FlowerOrder(
      customerName: 'Lan',
      phone: '',
      productName: 'Bó hồng',
      price: 200000,
      shippingFee: 30000,
      paid: 50000,
      deliveryAt: DateTime(2026, 11, 20),
      address: '12 Hoa Mai',
    );
    expect(order.total, 230000);
    expect(order.remaining, 180000);
    expect(order.validate(), isNull);
    expect(
      FlowerOrder(
        customerName: '',
        phone: '',
        productName: 'Bó hồng',
        price: 200000,
        shippingFee: 0,
        paid: 0,
        deliveryAt: DateTime(2026, 11, 20),
        address: '12 Hoa Mai',
      ).validate(),
      isNotNull,
    );
  });

  test('delivery time must be strictly later than the current second', () {
    final now = DateTime(2026, 11, 20, 10, 30, 45);
    expect(deliveryTimeIssue(now, now: now), isNotNull);
    expect(
      deliveryTimeIssue(now.subtract(const Duration(seconds: 1)), now: now),
      isNotNull,
    );
    expect(
      deliveryTimeIssue(now.add(const Duration(seconds: 1)), now: now),
      isNull,
    );
  });

  test(
    'repository rejects past creation and reschedule, permits old edits',
    () async {
      final directory = await Directory.systemTemp.createTemp('flower_time_');
      var now = DateTime(2026, 11, 20, 10, 30, 45);
      final repository = OrderRepository(now: () => now);
      await repository.open(databasePath: '${directory.path}/orders.db');
      try {
        final order = FlowerOrder(
          customerName: 'Lan',
          phone: '',
          productName: 'Bó hồng',
          price: 200000,
          shippingFee: 0,
          paid: 0,
          deliveryAt: now.add(const Duration(seconds: 1)),
          address: '12 Hoa Mai',
        );
        await expectLater(
          repository.add(order.copyWith(deliveryAt: now)),
          throwsArgumentError,
        );
        final id = await repository.add(order);
        now = now.add(const Duration(minutes: 5));
        final stored = (await repository.getById(id))!;
        await repository.updateOrder(stored.copyWith(address: '24 Hoa Mai'));
        await expectLater(
          repository.updateOrder(
            stored.copyWith(
              deliveryAt: now.subtract(const Duration(seconds: 1)),
            ),
          ),
          throwsArgumentError,
        );
        expect((await repository.getById(id))!.address, '24 Hoa Mai');
        expect(
          (await repository.orderChanges(id)).single.details,
          contains('Địa chỉ'),
        );
      } finally {
        await repository.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test('filters orders by search, status and delivery day', () {
    final orders = [
      FlowerOrder(
        id: 12,
        customerName: 'Lan',
        phone: '0901234567',
        productName: 'Bó hồng',
        price: 200000,
        shippingFee: 0,
        paid: 0,
        deliveryAt: DateTime(2026, 11, 20, 9),
        address: '12 Hoa Mai',
        status: OrderStatus.making,
      ),
      FlowerOrder(
        id: 13,
        customerName: 'Mai',
        phone: '0912345678',
        productName: 'Bó cúc',
        price: 100000,
        shippingFee: 0,
        paid: 0,
        deliveryAt: DateTime(2026, 11, 21, 10),
        address: '24 Hoa Mai',
      ),
    ];
    expect(filterOrders(orders, query: 'hỒnG').single.id, 12);
    expect(filterOrders(orders, query: '0912').single.id, 13);
    expect(filterOrders(orders, query: '13').single.id, 13);
    expect(filterOrders(orders, status: OrderStatus.making).single.id, 12);
    expect(
      filterOrders(orders, deliveryDay: DateTime(2026, 11, 21)).single.id,
      13,
    );
    expect(
      filterOrders(orders, query: 'Lan', status: OrderStatus.newOrder),
      isEmpty,
    );
  });

  test('order survives close and reopen; status is persisted', () async {
    final directory = await Directory.systemTemp.createTemp(
      'flower_orders_test_',
    );
    final path = '${directory.path}/orders.db';
    final repository = OrderRepository(now: () => DateTime(2026, 11, 16));
    await repository.open(databasePath: path);
    final id = await repository.add(
      FlowerOrder(
        customerName: 'Lan',
        phone: '0901234567',
        productName: 'Bó hồng',
        price: 200000,
        shippingFee: 30000,
        paid: 50000,
        deliveryAt: DateTime(2026, 11, 20, 9),
        address: '12 Hoa Mai',
      ),
    );
    expect(id, greaterThan(0));
    await repository.close();

    final reopened = OrderRepository();
    await reopened.open(databasePath: path);
    final orders = await reopened.all();
    expect(orders, hasLength(1));
    expect(orders.single.remaining, 180000);
    expect(orders.single.customerName, 'Lan');
    expect((await reopened.customers(query: 'Lan')).single.orderCount, 1);
    expect(
      (await reopened.customers(query: '0901')).single.phone,
      '0901234567',
    );
    await reopened.updateStatus(orders.single, OrderStatus.making);
    expect((await reopened.all()).single.status, OrderStatus.making);
    expect(await reopened.statusHistory(id), hasLength(2));
    // Steps can be skipped forwards and undone backwards…
    await reopened.updateStatus(orders.single, OrderStatus.delivered);
    await reopened.updateStatus(orders.single, OrderStatus.making);
    expect((await reopened.all()).single.status, OrderStatus.making);
    // …but not "changed" to the status the order already has.
    await expectLater(
      reopened.updateStatus(orders.single, OrderStatus.making),
      throwsArgumentError,
    );
    await reopened.addPayment(id, 30000, note: 'Thu thêm');
    expect((await reopened.all()).single.paid, 80000);
    await reopened.addPayment(id, -10000, note: 'Hoàn tiền');
    expect((await reopened.all()).single.remaining, 160000);
    expect(await reopened.paymentsForOrder(id), hasLength(3));
    await expectLater(reopened.addPayment(id, 200000), throwsArgumentError);
    await reopened.close();
    await directory.delete(recursive: true);
  });

  test('cancelled order only allows refunds and keeps ledger', () async {
    final directory = await Directory.systemTemp.createTemp('flower_cancel_');
    final repository = OrderRepository(now: () => DateTime(2026, 11, 16));
    await repository.open(databasePath: '${directory.path}/orders.db');
    try {
      final id = await repository.add(
        FlowerOrder(
          customerName: 'Lan',
          phone: '',
          productName: 'Bó hồng',
          price: 200000,
          shippingFee: 0,
          paid: 50000,
          deliveryAt: DateTime(2026, 11, 20),
          address: '12 Hoa Mai',
        ),
      );
      await repository.updateStatus(
        (await repository.getById(id))!,
        OrderStatus.cancelled,
      );
      await expectLater(repository.addPayment(id, 10000), throwsArgumentError);
      await repository.addPayment(id, -50000, note: 'Hoàn cọc đơn hủy');
      final cancelled = (await repository.getById(id))!;
      expect(cancelled.status, OrderStatus.cancelled);
      expect(cancelled.paid, 0);
      expect(await repository.paymentsForOrder(id), hasLength(2));
      expect(await repository.statusHistory(id), hasLength(2));
    } finally {
      await repository.close();
      await directory.delete(recursive: true);
    }
  });

  test('schema v1 deposit is backfilled into payment ledger', () async {
    final directory = await Directory.systemTemp.createTemp(
      'flower_migration_',
    );
    final path = '${directory.path}/orders.db';
    final oldDb = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE orders (
            id INTEGER PRIMARY KEY, customer_name TEXT NOT NULL,
            phone TEXT NOT NULL, product_name TEXT NOT NULL,
            price INTEGER NOT NULL, shipping_fee INTEGER NOT NULL,
            paid INTEGER NOT NULL, delivery_at TEXT NOT NULL,
            address TEXT NOT NULL, note TEXT NOT NULL,
            status INTEGER NOT NULL, created_at TEXT NOT NULL
          )
        ''');
        await db.insert('orders', {
          'id': 7,
          'customer_name': 'Lan',
          'phone': '',
          'product_name': 'Bó hồng',
          'price': 200000,
          'shipping_fee': 0,
          'paid': 50000,
          'delivery_at': DateTime(2026, 11, 20).toIso8601String(),
          'address': '12 Hoa Mai',
          'note': '',
          'status': 0,
          'created_at': DateTime(2026, 11, 16).toIso8601String(),
        });
      },
    );
    await oldDb.close();

    final repository = OrderRepository();
    await repository.open(databasePath: path);
    expect((await repository.all()).single.paid, 50000);
    expect((await repository.paymentsForOrder(7)).single.amount, 50000);
    await repository.close();
    await directory.delete(recursive: true);
  });

  test('draft survives reopen and is cleared after saving an order', () async {
    final directory = await Directory.systemTemp.createTemp('flower_draft_');
    final path = '${directory.path}/orders.db';
    final repository = OrderRepository();
    await repository.open(databasePath: path);
    await repository.saveDraft({'name': 'Lan', 'step': 2});
    await repository.close();

    final reopened = OrderRepository(now: () => DateTime(2026, 11, 16));
    await reopened.open(databasePath: path);
    expect((await reopened.loadDraft())?['name'], 'Lan');
    await reopened.add(
      FlowerOrder(
        customerName: 'Lan',
        phone: '',
        productName: 'Bó hồng',
        price: 200000,
        shippingFee: 0,
        paid: 0,
        deliveryAt: DateTime(2026, 11, 20),
        address: '12 Hoa Mai',
      ),
    );
    expect(await reopened.loadDraft(), isNull);
    await reopened.close();
    await directory.delete(recursive: true);
  });

  test('schema v2 upgrade keeps payment entries exactly once', () async {
    final directory = await Directory.systemTemp.createTemp('flower_v2_');
    final path = '${directory.path}/orders.db';
    final oldDb = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE orders (
          id INTEGER PRIMARY KEY, customer_name TEXT NOT NULL,
          phone TEXT NOT NULL, product_name TEXT NOT NULL,
          price INTEGER NOT NULL, shipping_fee INTEGER NOT NULL,
          paid INTEGER NOT NULL, delivery_at TEXT NOT NULL,
          address TEXT NOT NULL, note TEXT NOT NULL,
          status INTEGER NOT NULL, created_at TEXT NOT NULL
        )
      ''');
        await db.execute('''
        CREATE TABLE payments (
          id INTEGER PRIMARY KEY, order_id INTEGER NOT NULL,
          amount INTEGER NOT NULL, occurred_at TEXT NOT NULL,
          note TEXT NOT NULL
        )
      ''');
        await db.insert('orders', {
          'id': 9,
          'customer_name': 'Lan',
          'phone': '',
          'product_name': 'Bó hồng',
          'price': 200000,
          'shipping_fee': 0,
          'paid': 0,
          'delivery_at': DateTime(2026, 11, 20).toIso8601String(),
          'address': '12 Hoa Mai',
          'note': '',
          'status': 0,
          'created_at': DateTime(2026, 11, 16).toIso8601String(),
        });
        await db.insert('payments', {
          'order_id': 9,
          'amount': 50000,
          'occurred_at': DateTime(2026, 11, 16).toIso8601String(),
          'note': 'Tiền cọc',
        });
      },
    );
    await oldDb.close();

    final repository = OrderRepository();
    await repository.open(databasePath: path);
    expect((await repository.all()).single.paid, 50000);
    expect(await repository.paymentsForOrder(9), hasLength(1));
    expect(await repository.loadDraft(), isNull);
    await repository.close();
    await directory.delete(recursive: true);
  });

  test(
    'v1 with a preexisting payments table opens without duplicate deposit',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'flower_partial_',
      );
      final path = '${directory.path}/orders.db';
      final oldDb = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
        CREATE TABLE orders (
          id INTEGER PRIMARY KEY, customer_name TEXT NOT NULL,
          phone TEXT NOT NULL, product_name TEXT NOT NULL,
          price INTEGER NOT NULL, shipping_fee INTEGER NOT NULL,
          paid INTEGER NOT NULL, delivery_at TEXT NOT NULL,
          address TEXT NOT NULL, note TEXT NOT NULL,
          status INTEGER NOT NULL, created_at TEXT NOT NULL
        )
      ''');
          await db.execute('''
        CREATE TABLE payments (
          id INTEGER PRIMARY KEY, order_id INTEGER NOT NULL,
          amount INTEGER NOT NULL, occurred_at TEXT NOT NULL,
          note TEXT NOT NULL
        )
      ''');
          await db.insert('orders', {
            'id': 11,
            'customer_name': 'Lan',
            'phone': '',
            'product_name': 'Bó hồng',
            'price': 200000,
            'shipping_fee': 0,
            'paid': 50000,
            'delivery_at': DateTime(2026, 11, 20).toIso8601String(),
            'address': '12 Hoa Mai',
            'note': '',
            'status': 0,
            'created_at': DateTime(2026, 11, 16).toIso8601String(),
          });
          await db.insert('payments', {
            'order_id': 11,
            'amount': 50000,
            'occurred_at': DateTime(2026, 11, 16).toIso8601String(),
            'note': 'Tiền cọc',
          });
        },
      );
      await oldDb.close();

      final repository = OrderRepository();
      await repository.open(databasePath: path);
      expect((await repository.all()).single.paid, 50000);
      expect(await repository.paymentsForOrder(11), hasLength(1));
      await repository.close();
      await directory.delete(recursive: true);
    },
  );
}
