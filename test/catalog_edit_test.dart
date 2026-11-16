import 'dart:io';

import 'package:flower_orders/flower/data/order_repository.dart';
import 'package:flower_orders/flower/domain/catalog_placeholders.dart';
import 'package:flower_orders/flower/domain/catalog_product.dart';
import 'package:flower_orders/flower/domain/flower_order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('catalog edits and archive do not change an existing order', () async {
    final directory = await Directory.systemTemp.createTemp('flower_catalog_');
    final repository = OrderRepository(now: () => DateTime(2026, 11, 16));
    await repository.open(databasePath: '${directory.path}/orders.db');
    try {
      const original = CatalogProduct(
        name: 'Bó hồng',
        price: 200000,
        components: [
          FlowerComponent(
            name: 'Hồng đỏ',
            quantity: 12,
            unit: 'cành',
            isMain: true,
          ),
          FlowerComponent(name: 'Baby', quantity: 2, unit: 'bó', isMain: false),
        ],
      );
      final productId = await repository.saveProduct(original);
      final product = (await repository.listProducts()).singleWhere(
        (item) => item.id == productId,
      );
      expect(catalogPlaceholders, contains(product.imagePath));
      expect(product.components.last.isMain, isFalse);
      final orderId = await repository.add(
        FlowerOrder(
          customerName: 'Lan',
          phone: '',
          productName: product.name,
          price: product.price,
          shippingFee: 0,
          paid: 50000,
          deliveryAt: DateTime(2026, 11, 20),
          address: '12 Hoa Mai',
          components: product.components,
        ),
      );
      await repository.saveProduct(
        CatalogProduct(
          id: productId,
          name: 'Bó hồng mới',
          price: 250000,
          components: const [
            FlowerComponent(
              name: 'Hồng trắng',
              quantity: 8,
              unit: 'cành',
              isMain: true,
            ),
          ],
        ),
      );
      expect((await repository.getById(orderId))!.productName, 'Bó hồng');
      expect(
        (await repository.getById(orderId))!.components.first.name,
        'Hồng đỏ',
      );
      await repository.archiveProduct(productId);
      expect(
        (await repository.listProducts()).where((item) => item.id == productId),
        isEmpty,
      );
      expect((await repository.getById(orderId))!.components, hasLength(2));
    } finally {
      await repository.close();
      await directory.delete(recursive: true);
    }
  });

  test('editing an order preserves payment ledger and status', () async {
    final directory = await Directory.systemTemp.createTemp('flower_edit_');
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
      await repository.addPayment(id, 30000);
      await repository.updateStatus(
        (await repository.getById(id))!,
        OrderStatus.making,
      );
      await repository.updateOrder(
        FlowerOrder(
          id: id,
          customerName: 'Lan Anh',
          phone: '',
          productName: 'Bó cúc',
          price: 250000,
          shippingFee: 10000,
          paid: 0,
          deliveryAt: DateTime(2026, 11, 21),
          address: '24 Hoa Mai',
        ),
      );
      final updated = (await repository.getById(id))!;
      expect(updated.customerName, 'Lan Anh');
      expect(updated.paid, 80000);
      expect(updated.status, OrderStatus.making);
      expect(await repository.paymentsForOrder(id), hasLength(2));
      final changes = await repository.orderChanges(id);
      expect(changes, hasLength(1));
      expect(changes.single.details, contains('Giờ giao'));
      expect(changes.single.details, contains('Giá hoa'));
      expect(changes.single.details, contains('Khách hàng'));
      await expectLater(
        repository.updateOrder(
          FlowerOrder(
            id: id,
            customerName: 'Lan Anh',
            phone: '',
            productName: 'Bó cúc',
            price: 50000,
            shippingFee: 0,
            paid: 0,
            deliveryAt: DateTime(2026, 11, 21),
            address: '24 Hoa Mai',
          ),
        ),
        throwsArgumentError,
      );
      expect((await repository.getById(id))!.total, 260000);
    } finally {
      await repository.close();
      await directory.delete(recursive: true);
    }
  });

  test('new catalog has ten editable samples and six image choices', () async {
    final directory = await Directory.systemTemp.createTemp('flower_seed_');
    final repository = OrderRepository();
    await repository.open(databasePath: '${directory.path}/orders.db');
    try {
      final products = await repository.listProducts();
      expect(products, hasLength(10));
      expect(
        products.map((item) => item.imagePath).toSet(),
        catalogPlaceholders.toSet(),
      );
      expect(
        products.singleWhere((item) => item.name == 'Bó hồng đỏ').imagePath,
        catalogPlaceholders[5],
      );
      expect(
        products.singleWhere((item) => item.name == 'Bó cúc vàng').imagePath,
        catalogPlaceholders[2],
      );
      expect(products.every((item) => item.components.length == 2), isTrue);
      final addedId = await repository.saveProduct(
        const CatalogProduct(name: 'Mẫu không ảnh', price: 100000),
      );
      final added = (await repository.listProducts()).singleWhere(
        (item) => item.id == addedId,
      );
      expect(catalogPlaceholders, contains(added.imagePath));
      await repository.saveProduct(
        CatalogProduct(
          id: addedId,
          name: added.name,
          price: added.price,
          imagePath: added.imagePath,
        ),
      );
      expect(
        (await repository.listProducts())
            .singleWhere((item) => item.id == addedId)
            .imagePath,
        added.imagePath,
      );
    } finally {
      await repository.close();
      await directory.delete(recursive: true);
    }
  });

  test('schema v6 preserves catalog rows and adds sample images', () async {
    final directory = await Directory.systemTemp.createTemp('flower_v6_');
    final path = '${directory.path}/orders.db';
    final oldDb = await openDatabase(
      path,
      version: 6,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
            price INTEGER NOT NULL, active INTEGER NOT NULL DEFAULT 1,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE product_flowers (
            id INTEGER PRIMARY KEY AUTOINCREMENT, product_id INTEGER NOT NULL,
            name TEXT NOT NULL, quantity INTEGER NOT NULL, unit TEXT NOT NULL,
            is_main INTEGER NOT NULL
          )
        ''');
        await db.insert('products', {
          'name': 'Mẫu cũ',
          'price': 180000,
          'updated_at': DateTime(2026, 11).toIso8601String(),
        });
        await db.insert('product_flowers', {
          'product_id': 1,
          'name': 'Hồng trắng',
          'quantity': 5,
          'unit': 'cành',
          'is_main': 1,
        });
      },
    );
    await oldDb.close();
    final repository = OrderRepository();
    await repository.open(databasePath: path);
    try {
      final products = await repository.listProducts();
      expect(products, hasLength(11));
      final original = products.singleWhere((item) => item.name == 'Mẫu cũ');
      expect(original.components.single.name, 'Hồng trắng');
      expect(catalogPlaceholders, contains(original.imagePath));
    } finally {
      await repository.close();
      await directory.delete(recursive: true);
    }
  });

  test('schema v8 adds order edit history without touching orders', () async {
    final directory = await Directory.systemTemp.createTemp('flower_v8_');
    final path = '${directory.path}/orders.db';
    final oldDb = await openDatabase(
      path,
      version: 8,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE orders (
            id INTEGER PRIMARY KEY, product_name TEXT NOT NULL
          )
        ''');
        await db.insert('orders', {'id': 7, 'product_name': 'Mẫu cũ'});
      },
    );
    await oldDb.close();
    final repository = OrderRepository();
    await repository.open(databasePath: path);
    try {
      expect(await repository.orderChanges(7), isEmpty);
      final rows = await repository.db.query('orders');
      expect(rows.single['product_name'], 'Mẫu cũ');
    } finally {
      await repository.close();
      await directory.delete(recursive: true);
    }
  });

  test('schema v3 adds catalog and keeps existing orders', () async {
    final directory = await Directory.systemTemp.createTemp('flower_v3_');
    final path = '${directory.path}/orders.db';
    final oldDb = await openDatabase(
      path,
      version: 3,
      onCreate: (db, _) async {
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
          'id': 5,
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
          'order_id': 5,
          'amount': 50000,
          'occurred_at': DateTime(2026, 11, 16).toIso8601String(),
          'note': 'Tiền cọc',
        });
      },
    );
    await oldDb.close();
    final repository = OrderRepository();
    await repository.open(databasePath: path);
    try {
      final order = (await repository.all()).single;
      expect(order.id, 5);
      expect(order.paid, 50000);
      expect(order.components, isEmpty);
      await repository.saveProduct(
        const CatalogProduct(name: 'Mẫu mới', price: 100000),
      );
      expect(await repository.listProducts(), hasLength(11));
    } finally {
      await repository.close();
      await directory.delete(recursive: true);
    }
  });
}
