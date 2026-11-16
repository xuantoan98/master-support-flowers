import 'dart:io';

import 'package:flower_orders/flower/data/order_repository.dart';
import 'package:flower_orders/flower/domain/catalog_product.dart';
import 'package:flower_orders/flower/domain/flower_order.dart';
import 'package:flower_orders/flower/domain/shopping_list.dart';
import 'package:flower_orders/flower/presentation/shopping_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

FlowerOrder order(
  int day,
  List<FlowerComponent> components, {
  OrderStatus status = OrderStatus.newOrder,
}) => FlowerOrder(
  customerName: 'Lan',
  phone: '',
  productName: 'Bó hoa',
  price: 200000,
  shippingFee: 0,
  paid: 0,
  deliveryAt: DateTime(2026, 11, day, 10),
  address: '12 Hoa Mai',
  components: components,
  status: status,
);

class FakeShoppingRepository extends OrderRepository {
  FakeShoppingRepository(this.orders);
  final List<FlowerOrder> orders;
  final Map<String, int> checks = {};

  @override
  Future<List<FlowerOrder>> all() async => orders;

  @override
  Future<Map<String, int>> shoppingChecks(DateTime start, DateTime end) async =>
      checks;

  @override
  Future<void> setShoppingChecked(
    DateTime start,
    DateTime end,
    ShoppingItem item,
    bool checked,
  ) async {
    if (checked) {
      checks[item.key] = item.quantity;
    } else {
      checks.remove(item.key);
    }
  }
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('vi');
  });

  test(
    'shopping list sums matching flowers and warns about missing recipes',
    () {
      final list = buildShoppingList(
        [
          order(20, const [
            FlowerComponent(
              name: 'Hồng đỏ',
              quantity: 12,
              unit: 'cành',
              isMain: true,
            ),
          ]),
          order(20, const [
            FlowerComponent(
              name: 'hồng đỏ',
              quantity: 8,
              unit: 'cành',
              isMain: false,
            ),
          ]),
          order(20, const []),
          order(20, const [
            FlowerComponent(
              name: 'Cúc',
              quantity: 4,
              unit: 'cành',
              isMain: true,
            ),
          ], status: OrderStatus.cancelled),
          order(21, const [
            FlowerComponent(
              name: 'Cúc',
              quantity: 4,
              unit: 'cành',
              isMain: true,
            ),
          ]),
        ],
        DateTime(2026, 11, 20),
        DateTime(2026, 11, 21),
      );
      expect(list.items, hasLength(1));
      expect(list.items.single.quantity, 20);
      expect(list.ordersWithoutRecipe, 1);
    },
  );

  test(
    'shopping check persists but quantity mismatch invalidates it',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'flower_shopping_',
      );
      final path = '${directory.path}/orders.db';
      final repository = OrderRepository();
      await repository.open(databasePath: path);
      final start = DateTime(2026, 11, 20);
      final end = DateTime(2026, 11, 21);
      const item = ShoppingItem(name: 'Hồng đỏ', unit: 'cành', quantity: 12);
      await repository.setShoppingChecked(start, end, item, true);
      await repository.close();
      final reopened = OrderRepository();
      await reopened.open(databasePath: path);
      try {
        final checks = await reopened.shoppingChecks(start, end);
        expect(checks[item.key], item.quantity);
        expect(checks[item.key] == 20, isFalse);
        await reopened.setShoppingChecked(start, end, item, false);
        expect(await reopened.shoppingChecks(start, end), isEmpty);
      } finally {
        await reopened.close();
        await directory.delete(recursive: true);
      }
    },
  );

  testWidgets('shopping checkbox refreshes after saving', (tester) async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final repository = FakeShoppingRepository([
      FlowerOrder(
        customerName: 'Lan',
        phone: '',
        productName: 'Bó hồng',
        price: 200000,
        shippingFee: 0,
        paid: 0,
        deliveryAt: tomorrow,
        address: '12 Hoa Mai',
        components: const [
          FlowerComponent(
            name: 'Hồng đỏ',
            quantity: 12,
            unit: 'cành',
            isMain: true,
          ),
        ],
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(home: ShoppingListScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ngày mai'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isTrue,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
