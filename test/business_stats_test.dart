import 'dart:io';

import 'package:flower_orders/flower/data/order_repository.dart';
import 'package:flower_orders/flower/domain/business_stats.dart';
import 'package:flower_orders/flower/domain/flower_order.dart';
import 'package:flower_orders/flower/domain/order_item.dart';
import 'package:flower_orders/flower/presentation/flower_app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

FlowerOrder sample(
  int id,
  DateTime at,
  OrderStatus status, {
  int price = 100000,
  int paid = 0,
  String customer = 'Mai',
  List<OrderItem> items = const [],
}) => FlowerOrder(
  id: id,
  customerName: customer,
  phone: '0900000000',
  productName: items.isEmpty ? 'Bó hoa' : items.first.name,
  price: price,
  shippingFee: 0,
  paid: paid,
  deliveryAt: at,
  address: 'Địa chỉ',
  status: status,
  items: items,
);

class _StatsRepository extends OrderRepository {
  _StatsRepository(this.items, this.entries);

  final List<FlowerOrder> items;
  final List<OrderPayment> entries;

  @override
  Future<List<FlowerOrder>> all() async => items;

  @override
  Future<List<OrderPayment>> allPayments() async => entries;

  @override
  Future<bool> remindersEnabled() async => false;
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('vi');
  });

  test('period boundaries cover week, month, quarter and year', () {
    final date = DateTime(2026, 11, 20, 14);
    final week = StatsWindow.at(StatsPeriod.week, date);
    expect(week.start, DateTime(2026, 11, 16));
    expect(week.end, DateTime(2026, 11, 23));
    expect(week.contains(DateTime(2026, 11, 22, 23, 59)), isTrue);
    expect(week.contains(week.end), isFalse);
    expect(week.shift(1).start, week.end);
    final month = StatsWindow.at(StatsPeriod.month, date);
    expect(month.start, DateTime(2026, 11));
    expect(month.end, DateTime(2026, 12));
    expect(month.shift(-1).start, DateTime(2026, 10));
    final quarter = StatsWindow.at(StatsPeriod.quarter, date);
    expect(quarter.start, DateTime(2026, 10));
    expect(quarter.end, DateTime(2027));
    expect(quarter.shift(1).start, DateTime(2027));
    final year = StatsWindow.at(StatsPeriod.year, date);
    expect(year.start, DateTime(2026));
    expect(year.end, DateTime(2027));
  });

  test('separates delivered revenue, booked value and cash ledger', () {
    final orders = [
      sample(
        1,
        DateTime(2026, 11, 20, 9),
        OrderStatus.delivered,
        price: 200000,
        paid: 50000,
        customer: 'Lan',
        items: const [
          OrderItem(name: 'Hồng', unitPrice: 75000, quantity: 2),
          OrderItem(name: 'Ly', unitPrice: 50000),
        ],
      ),
      sample(
        2,
        DateTime(2026, 11, 21, 13),
        OrderStatus.delivered,
        paid: 100000,
        customer: 'Lan',
        items: const [OrderItem(name: 'Hồng', unitPrice: 100000)],
      ),
      sample(
        3,
        DateTime(2026, 11, 22, 18),
        OrderStatus.making,
        price: 300000,
        paid: 100000,
      ),
      sample(4, DateTime(2026, 11, 23), OrderStatus.cancelled, price: 400000),
      sample(
        5,
        DateTime(2026, 12),
        OrderStatus.delivered,
        price: 500000,
        customer: 'Nhi',
      ),
    ];
    final payments = [
      for (final amount in [50000, 100000, 100000, 100000, -100000, 50000])
        OrderPayment(amount: amount, occurredAt: DateTime(2026, 11, 19)),
      OrderPayment(amount: 90000, occurredAt: DateTime(2026, 12)),
    ];
    final report = calculateBusinessStats(
      orders,
      payments,
      StatsWindow.at(StatsPeriod.month, DateTime(2026, 11)),
    );
    expect(report.orderCount, 3);
    expect(report.deliveredCount, 2);
    expect(report.pendingCount, 1);
    expect(report.deliveredRevenue, 300000);
    expect(report.bookedRevenue, 600000);
    expect(report.outstanding, 350000);
    expect(report.receipts, 400000);
    expect(report.refunds, 100000);
    expect(report.netCash, 300000);
    expect(report.repeatCustomers, 1);
    expect(report.topProducts.map((item) => '${item.name}:${item.quantity}'), [
      'Hồng:3',
      'Ly:1',
    ]);
    expect(report.busiestWeekday, DateTime.friday);
    expect(report.busiestDaypart, 'Sáng');
    expect(
      report.buckets.fold(0, (sum, bucket) => sum + bucket.revenue),
      300000,
    );
  });

  test('empty period returns zero and no rankings', () {
    final report = calculateBusinessStats(
      [],
      [],
      StatsWindow.at(StatsPeriod.year, DateTime(2026)),
    );
    expect(report.orderCount, 0);
    expect(report.netCash, 0);
    expect(report.busiestWeekday, isNull);
    expect(report.topProducts, isEmpty);
    expect(report.buckets, hasLength(12));
  });

  test('repository returns positive deposits and negative refunds', () async {
    final directory = await Directory.systemTemp.createTemp('flower_stats_');
    final repository = OrderRepository(now: () => DateTime(2026, 11, 19));
    try {
      await repository.open(databasePath: '${directory.path}/orders.db');
      final id = await repository.add(
        sample(1, DateTime(2026, 11, 20), OrderStatus.newOrder, paid: 50000),
      );
      await repository.addPayment(id, -20000);
      final entries = await repository.allPayments();
      expect(entries.map((entry) => entry.amount).toSet(), {50000, -20000});
      expect(entries.every((entry) => entry.occurredAt.year >= 2026), isTrue);
    } finally {
      await repository.close();
      await directory.delete(recursive: true);
    }
  });

  testWidgets('statistics tab loads ledger and changes period', (tester) async {
    final repository = _StatsRepository(
      [sample(1, DateTime.now(), OrderStatus.delivered, paid: 100000)],
      [OrderPayment(amount: 100000, occurredAt: DateTime.now())],
    );
    await tester.pumpWidget(FlowerApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Thống kê'));
    await tester.pumpAndSettle();
    expect(find.text('Thống kê cửa hàng'), findsOneWidget);
    expect(find.text('Doanh thu đã giao'), findsWidgets);
    expect(find.text('100.000 đ'), findsWidgets);
    await tester.tap(find.text('Quý'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Quý '), findsOneWidget);
    await tester.tap(find.text('Tuần'));
    await tester.pumpAndSettle();
    final today = DateTime.now();
    final monday = StatsWindow.at(StatsPeriod.week, today).start;
    final sunday = DateTime(monday.year, monday.month, monday.day + 6);
    expect(
      find.text('${dayLabel(monday)} – ${dayLabel(sunday)}'),
      findsOneWidget,
    );
  });
}
