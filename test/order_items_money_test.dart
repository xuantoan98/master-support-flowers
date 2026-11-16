import 'dart:io';

import 'package:flower_orders/flower/data/order_repository.dart';
import 'package:flower_orders/flower/domain/catalog_product.dart';
import 'package:flower_orders/flower/domain/flower_order.dart';
import 'package:flower_orders/flower/domain/order_item.dart';
import 'package:flower_orders/flower/presentation/money_input_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('multi-product order persists quantities and flower totals', () async {
    final directory = await Directory.systemTemp.createTemp('flower_items_');
    final repository = OrderRepository();
    await repository.open(databasePath: '${directory.path}/orders.db');
    try {
      const items = [
        OrderItem(
          name: 'Bó hồng',
          unitPrice: 200000,
          quantity: 2,
          components: [
            FlowerComponent(
              name: 'Hồng',
              quantity: 10,
              unit: 'cành',
              isMain: true,
            ),
          ],
        ),
        OrderItem(
          name: 'Bó cúc',
          unitPrice: 150000,
          components: [
            FlowerComponent(
              name: 'Cúc',
              quantity: 5,
              unit: 'cành',
              isMain: true,
            ),
          ],
        ),
      ];
      final id = await repository.add(
        FlowerOrder(
          customerName: 'Lan',
          phone: '',
          productName: orderItemsLabel(items),
          price: orderItemsTotal(items),
          shippingFee: 20000,
          paid: 0,
          deliveryAt: DateTime.now().add(const Duration(days: 1)),
          address: '12 Hoa Mai',
          items: items,
          components: orderItemsComponents(items),
        ),
      );
      final stored = (await repository.getById(id))!;
      expect(stored.items.map((item) => item.quantity), [2, 1]);
      expect(stored.total, 570000);
      expect(stored.components.map((item) => item.quantity), [20, 5]);
    } finally {
      await repository.close();
      await directory.delete(recursive: true);
    }
  });

  test('currency input groups digits by locale and preserves cursor', () {
    final vi = MoneyInputFormatter('vi');
    const raw = TextEditingValue(
      text: '1234567',
      selection: TextSelection.collapsed(offset: 7),
    );
    final formatted = vi.formatEditUpdate(TextEditingValue.empty, raw);
    expect(formatted.text, '1.234.567');
    expect(formatted.selection.baseOffset, formatted.text.length);
    expect(parseCurrencyInput(formatted.text), 1234567);
    expect(
      MoneyInputFormatter(
        'en',
      ).formatEditUpdate(TextEditingValue.empty, raw).text,
      '1,234,567',
    );
  });

  test('schema v9 keeps a saved single-product order', () async {
    final directory = await Directory.systemTemp.createTemp('flower_v9_items_');
    final path = '${directory.path}/orders.db';
    final oldDatabase = await openDatabase(
      path,
      version: 9,
      onCreate: (db, _) async {
        await db.execute('''
        CREATE TABLE orders (
        id INTEGER PRIMARY KEY, customer_name TEXT, phone TEXT,
        product_name TEXT, price INTEGER, shipping_fee INTEGER, paid INTEGER,
        delivery_at TEXT, address TEXT, note TEXT, status INTEGER,
        recipe_json TEXT, created_at TEXT)''');
        await db.execute(
          'CREATE TABLE payments (order_id INTEGER, amount INTEGER)',
        );
        await db.insert('orders', {
          'id': 1,
          'customer_name': 'Lan',
          'phone': '',
          'product_name': 'Bó hồng',
          'price': 200000,
          'shipping_fee': 0,
          'paid': 0,
          'delivery_at': '2026-11-20T10:00:00.000',
          'address': '12 Hoa Mai',
          'note': '',
          'status': 0,
          'recipe_json': '[]',
          'created_at': '2026-11-16T10:00:00.000',
        });
      },
    );
    await oldDatabase.close();
    final repository = OrderRepository();
    try {
      await repository.open(databasePath: path);
      final oldOrder = (await repository.getById(1))!;
      expect(oldOrder.effectiveItems.single.name, 'Bó hồng');
      expect(oldOrder.effectiveItems.single.quantity, 1);
      expect(oldOrder.price, 200000);
    } finally {
      await repository.close();
      await directory.delete(recursive: true);
    }
  });
}
