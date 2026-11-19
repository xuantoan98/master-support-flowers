import 'package:flower_orders/flower/domain/calendar_overview.dart';
import 'package:flower_orders/flower/domain/flower_order.dart';
import 'package:flower_orders/flower/presentation/calendar_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

FlowerOrder _order(DateTime deliveryAt, OrderStatus status) => FlowerOrder(
  id: 1,
  customerName: 'Lan',
  phone: '',
  productName: 'Bó hồng',
  price: 100000,
  shippingFee: 0,
  paid: 0,
  deliveryAt: deliveryAt,
  address: '',
  status: status,
);

void main() {
  occasionTests();
  test('day badge caps the order count at 9+', () {
    expect(orderCountLabel(2), '2');
    expect(orderCountLabel(9), '9');
    expect(orderCountLabel(10), '9+');
    expect(orderCountLabel(42), '9+');
  });
  test('week starts on Monday and crosses month boundaries', () {
    final week = weekOf(DateTime(2026, 12, 2, 15));
    expect(week.first, DateTime(2026, 11, 30));
    expect(week.last, DateTime(2026, 12, 6));
    expect(startOfWeek(DateTime(2026, 11, 30)), DateTime(2026, 11, 30));
  });

  test('month title and greeting are formatted for the shop', () {
    expect(monthTitle(DateTime(2026, 11)), 'Tháng 11, 2026');
    expect(greetingFor(DateTime(2026, 1, 1, 8)), 'Chào buổi sáng');
    expect(greetingFor(DateTime(2026, 1, 1, 14)), 'Chào buổi chiều');
    expect(greetingFor(DateTime(2026, 1, 1, 20)), 'Chào buổi tối');
  });

  test('attention list holds overdue and open orders for today only', () {
    final now = DateTime(2026, 11, 19, 10);
    final overdue = _order(DateTime(2026, 11, 17, 9), OrderStatus.making);
    final doneYesterday = _order(
      DateTime(2026, 11, 18, 9),
      OrderStatus.delivered,
    );
    final today = _order(DateTime(2026, 11, 19, 16), OrderStatus.newOrder);
    final tomorrow = _order(DateTime(2026, 11, 20, 9), OrderStatus.newOrder);
    final result = ordersNeedingAttention([
      tomorrow,
      today,
      doneYesterday,
      overdue,
    ], now);
    expect(result, [overdue, today]);
    expect(isOverdue(overdue, now), isTrue);
    expect(isOverdue(today, now), isFalse);
  });

  test('swipe moves forward but never cancels', () {
    expect(nextForwardStatus(OrderStatus.newOrder), OrderStatus.making);
    expect(nextForwardStatus(OrderStatus.delivering), OrderStatus.delivered);
    expect(nextForwardStatus(OrderStatus.delivered), isNull);
    expect(nextForwardStatus(OrderStatus.cancelled), isNull);
  });

  test('revenue comparison against previous month', () {
    final october = DateTime(2026, 10);
    expect(revenueComparison(112, 100, october), '↑ 12% so với T10');
    expect(revenueComparison(80, 100, october), '↓ 20% so với T10');
    expect(revenueComparison(100, 100, october), '= so với T10');
    expect(revenueComparison(100, 0, october), isNull);
  });

  test('calendar dots group statuses into three colours', () {
    expect(calendarDotKind(OrderStatus.newOrder), CalendarDotKind.notStarted);
    expect(calendarDotKind(OrderStatus.making), CalendarDotKind.inProgress);
    expect(calendarDotKind(OrderStatus.delivered), CalendarDotKind.delivered);
    expect(calendarDotKind(OrderStatus.cancelled), isNull);
  });
}

void occasionTests() {
  test('weekly revenue buckets follow Monday weeks inside the month', () {
    final orders = [
      _order(DateTime(2026, 11, 1, 9), OrderStatus.delivered),
      _order(DateTime(2026, 11, 2, 9), OrderStatus.newOrder),
      _order(DateTime(2026, 11, 30, 9), OrderStatus.newOrder),
      _order(DateTime(2026, 11, 30, 10), OrderStatus.cancelled),
      _order(DateTime(2026, 12, 1, 9), OrderStatus.newOrder),
    ];
    // Nov 2026: Sun 1 is in the week of Mon 26/10; Mon 30 starts week 6.
    expect(weeklyRevenue(orders, DateTime(2026, 11)), [
      100000,
      100000,
      0,
      0,
      0,
      100000,
    ]);
  });

  test('occasion season covers the 10 days before each holiday', () {
    final teachers = currentOccasion(DateTime(2026, 11, 19, 15))!;
    expect(teachers.occasion, FlowerOccasion.teachersDay);
    expect(teachers.daysLeft, 1);
    expect(currentOccasion(DateTime(2026, 11, 21)), isNull);
    expect(currentOccasion(DateTime(2026, 9, 2)), isNull);
    final tet = currentOccasion(DateTime(2027, 2, 8))!;
    expect(tet.occasion, FlowerOccasion.tet);
    expect(tet.daysLeft, -2);
    expect(
      currentOccasion(DateTime(2027, 2, 10))!.occasion,
      FlowerOccasion.valentine,
    );
  });
}
