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
  Future<bool> remindersEnabled() async => false;

  @override
  Future<List<FlowerOrder>> all() async => items;
}

/// The first tab opens on today's list; the month calendar is one tap away.
Future<void> openCalendar(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Lịch giao theo tháng'));
  await tester.pumpAndSettle();
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
      await openCalendar(tester);
      for (var i = 0; i < 13 - now.month; i++) {
        await tester.tap(find.byTooltip('Tháng sau'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Tháng 1, ${january.year}'), findsWidgets);
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Lịch giao 01/01/${january.year}'),
        200,
        scrollable: scrollable,
      );
      await tester.scrollUntilVisible(
        find.byTooltip('Tháng trước'),
        -200,
        scrollable: scrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tháng trước'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Lịch giao 01/12/${now.year}'),
        200,
        scrollable: scrollable,
      );
    },
  );

  testWidgets('month tiles show fanned order cards with a count badge', (
    tester,
  ) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final day = today.add(const Duration(days: 1));
    final nextMonth = DateTime(today.year, today.month + 1);
    await tester.pumpWidget(
      FlowerApp(
        repository: FakeCalendarRepository([
          for (var i = 0; i < 4; i++)
            sampleOrder(deliveryAt: day.add(Duration(hours: 9 + i))),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    await openCalendar(tester);
    if (day.month == today.month) {
      expect(
        find.bySemanticsLabel(RegExp('^${day.day}/${day.month}, 4 đơn')),
        findsOneWidget,
      );
      expect(find.text('4'), findsWidgets);
    }
    await tester.tap(find.byTooltip('Tháng sau'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Lịch giao ${dayLabel(nextMonth)}'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      find.text('Tạo đơn cho ngày này'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Tạo đơn cho ngày này'), findsOneWidget);
  });

  testWidgets('tapping a day with orders enlarges its cards', (tester) async {
    final today = DateUtils.dateOnly(DateTime.now());
    await tester.pumpWidget(
      FlowerApp(
        repository: FakeCalendarRepository([
          sampleOrder(
            deliveryAt: today.add(const Duration(hours: 23, minutes: 59)),
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    await openCalendar(tester);
    final cell = find.bySemanticsLabel(
      RegExp('^${today.day}/${today.month}, hôm nay'),
    );
    await tester.ensureVisible(cell);
    await tester.pumpAndSettle();
    await tester.tap(cell);
    // The popup waits (at most 150 ms) for its photos to decode first.
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('^Mở đơn Lan, 23:59')), findsOneWidget);
    expect(find.textContaining('Chạm card để mở đơn'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('^Mở đơn Lan')), findsNothing);
  });

  testWidgets('overdue orders show in the attention sheet', (tester) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await tester.pumpWidget(
      FlowerApp(
        repository: FakeCalendarRepository([
          sampleOrder(deliveryAt: yesterday),
        ]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('1 đơn quá hạn'), findsOneWidget);
    // Today's list shows it too, before the calendar is opened.
    expect(find.textContaining('Quá hạn'), findsNothing);
    expect(find.text('Lan'), findsWidgets);
    await openCalendar(tester);
    await tester.tap(find.byTooltip('Đơn cần chú ý'));
    await tester.pumpAndSettle();
    expect(find.text('Đơn cần chú ý'), findsWidgets);
    expect(find.textContaining('Quá hạn ·'), findsOneWidget);
  });

  testWidgets('create action is disabled when calendar selects a past day', (
    tester,
  ) async {
    await tester.pumpWidget(FlowerApp(repository: FakeCalendarRepository([])));
    await tester.pumpAndSettle();
    await openCalendar(tester);
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    final create = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(create.onPressed, isNull);
    await tester.tap(find.byTooltip('Đơn hàng'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('create button offers a counter sale or a pre-order', (
    tester,
  ) async {
    await tester.pumpWidget(FlowerApp(repository: FakeCalendarRepository([])));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tạo đơn'));
    await tester.pumpAndSettle();
    expect(find.text('Bán nhanh tại quầy'), findsOneWidget);
    expect(find.text('Tạo đơn đặt trước'), findsOneWidget);
  });
}
