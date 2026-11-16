import 'package:flower_orders/flower/data/order_repository.dart';
import 'package:flower_orders/flower/domain/flower_order.dart';
import 'package:flower_orders/flower/domain/order_summary.dart';
import 'package:flower_orders/flower/presentation/flower_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

FlowerOrder sampleOrder({
  required DateTime deliveryAt,
  int price = 200000,
  int paid = 50000,
  OrderStatus status = OrderStatus.newOrder,
}) => FlowerOrder(
  id: 1,
  customerName: 'Lan',
  phone: '',
  productName: 'Bó hồng',
  price: price,
  shippingFee: 20000,
  paid: paid,
  deliveryAt: deliveryAt,
  address: '12 Hoa Mai',
  status: status,
);

class FakeCalendarRepository extends OrderRepository {
  FakeCalendarRepository(this.items);

  final List<FlowerOrder> items;

  @override
  Future<List<FlowerOrder>> all() async => items;
}

void main() {
  setUpAll(() async => initializeDateFormatting('vi'));

  test(
    'dashboard totals follow delivery month and exclude cancelled orders',
    () {
      final orders = [
        sampleOrder(deliveryAt: DateTime(2026, 12)),
        sampleOrder(
          deliveryAt: DateTime(2026, 12, 2),
          price: 300000,
          paid: 320000,
          status: OrderStatus.delivered,
        ),
        sampleOrder(
          deliveryAt: DateTime(2026, 12, 3),
          price: 400000,
          paid: 100000,
          status: OrderStatus.cancelled,
        ),
        sampleOrder(deliveryAt: DateTime(2027), price: 100000, paid: 0),
      ];
      final december = summarizeOrders(
        orders,
        deliveryMonth: DateTime(2026, 12),
      );
      expect(december.orderCount, 2);
      expect(december.pendingCount, 1);
      expect(december.projectedRevenue, 540000);
      expect(december.paid, 370000);
      expect(december.remaining, 170000);
      final all = summarizeOrders(orders);
      expect(all.orderCount, 3);
      expect(all.projectedRevenue, 660000);
    },
  );

  testWidgets(
    'calendar month arrows update selected day across year boundary',
    (tester) async {
      final now = DateTime.now();
      final january = DateTime(now.year + 1);
      final repository = FakeCalendarRepository([
        sampleOrder(deliveryAt: DateTime(january.year, january.month, 2)),
      ]);
      await tester.pumpWidget(FlowerApp(repository: repository));
      await tester.pumpAndSettle();
      for (var i = 0; i < 13 - now.month; i++) {
        await tester.tap(find.byIcon(Icons.chevron_right));
        await tester.pumpAndSettle();
      }
      await tester.drag(find.byType(ListView).first, const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(find.text('Lịch giao 01/01/${january.year}'), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, 700));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(find.text('Lịch giao 01/12/${now.year}'), findsOneWidget);
    },
  );

  testWidgets('create action is disabled when calendar selects a past day', (
    tester,
  ) async {
    await tester.pumpWidget(FlowerApp(repository: FakeCalendarRepository([])));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    final create = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(create.onPressed, isNull);
    await tester.tap(find.text('Đơn hàng'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .onPressed,
      isNotNull,
    );
  });
}
