import 'flower_order.dart';

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Monday of the week containing [day].
DateTime startOfWeek(DateTime day) {
  final date = dateOnly(day);
  return DateTime(date.year, date.month, date.day - (date.weekday - 1));
}

List<DateTime> weekOf(DateTime day) {
  final start = startOfWeek(day);
  return [
    for (var i = 0; i < 7; i++)
      DateTime(start.year, start.month, start.day + i),
  ];
}

/// `Tháng 11, 2026`
String monthTitle(DateTime month) => 'Tháng ${month.month}, ${month.year}';

String greetingFor(DateTime now) {
  if (now.hour < 12) {
    return 'Chào buổi sáng';
  }
  if (now.hour < 18) {
    return 'Chào buổi chiều';
  }
  return 'Chào buổi tối';
}

bool isUnfinished(FlowerOrder order) =>
    order.status != OrderStatus.delivered &&
    order.status != OrderStatus.cancelled;

/// Delivery day already passed but the order is still open.
bool isOverdue(FlowerOrder order, DateTime now) =>
    isUnfinished(order) && dateOnly(order.deliveryAt).isBefore(dateOnly(now));

/// Orders the shop should look at now: overdue ones first, then today's open
/// orders, both by delivery time.
List<FlowerOrder> ordersNeedingAttention(
  Iterable<FlowerOrder> orders,
  DateTime now,
) {
  final today = dateOnly(now);
  return orders
      .where(
        (order) =>
            isUnfinished(order) && !dateOnly(order.deliveryAt).isAfter(today),
      )
      .toList()
    ..sort((a, b) => a.deliveryAt.compareTo(b.deliveryAt));
}

Map<DateTime, List<FlowerOrder>> groupByDeliveryDay(
  Iterable<FlowerOrder> orders,
) {
  final result = <DateTime, List<FlowerOrder>>{};
  for (final order in orders) {
    result.putIfAbsent(dateOnly(order.deliveryAt), () => []).add(order);
  }
  return result;
}

/// The next forward status for a quick swipe; never cancels.
OrderStatus? nextForwardStatus(OrderStatus status) {
  for (final next in status.allowedNext) {
    if (next != OrderStatus.cancelled) {
      return next;
    }
  }
  return null;
}

/// Calendar dot groups requested by the shop: not started, in progress, done.
enum CalendarDotKind { notStarted, inProgress, delivered }

CalendarDotKind? calendarDotKind(OrderStatus status) => switch (status) {
  OrderStatus.newOrder => CalendarDotKind.notStarted,
  OrderStatus.making ||
  OrderStatus.awaitingApproval ||
  OrderStatus.delivering => CalendarDotKind.inProgress,
  OrderStatus.delivered => CalendarDotKind.delivered,
  OrderStatus.cancelled => null,
};

/// `↑ 12% so với T10`, or null when there is nothing to compare with.
String? revenueComparison(int current, int previous, DateTime previousMonth) {
  final label = 'so với T${previousMonth.month}';
  if (previous <= 0) {
    return null;
  }
  final percent = ((current - previous) * 100 / previous).round();
  if (percent > 0) {
    return '↑ $percent% $label';
  }
  if (percent < 0) {
    return '↓ ${-percent}% $label';
  }
  return '= $label';
}

/// Revenue of non-cancelled orders per Monday-start week that overlaps
/// [month], counting only deliveries inside the month.
List<int> weeklyRevenue(Iterable<FlowerOrder> orders, DateTime month) {
  final first = DateTime(month.year, month.month);
  final last = DateTime(month.year, month.month + 1, 0);
  final firstWeek = startOfWeek(first);
  final weeks = (last.difference(firstWeek).inDays ~/ 7) + 1;
  final totals = List<int>.filled(weeks, 0);
  for (final order in orders) {
    if (order.status == OrderStatus.cancelled ||
        order.deliveryAt.year != month.year ||
        order.deliveryAt.month != month.month) {
      continue;
    }
    final index =
        startOfWeek(order.deliveryAt).difference(firstWeek).inDays ~/ 7;
    totals[index] += order.total;
  }
  return totals;
}

/// Peak flower-selling occasions in Vietnam.
enum FlowerOccasion {
  tet,
  valentine,
  womensDay,
  vietnameseWomensDay,
  teachersDay,
}

/// Lunar New Year (Mùng 1 Tết) dates.
final _tetDays = [
  DateTime(2025, 1, 29),
  DateTime(2026, 2, 17),
  DateTime(2027, 2, 6),
  DateTime(2028, 1, 26),
  DateTime(2029, 2, 13),
  DateTime(2030, 2, 3),
  DateTime(2031, 1, 23),
  DateTime(2032, 2, 11),
];

class OccasionWindow {
  const OccasionWindow(this.occasion, this.day, this.daysLeft);

  final FlowerOccasion occasion;
  final DateTime day;

  /// 0 on the day itself, negative during the days after Tết.
  final int daysLeft;
}

/// The occasion whose busy season covers [now]: 10 days before each holiday
/// (14 before Tết, which also lasts 3 days after).
OccasionWindow? currentOccasion(DateTime now) {
  final today = dateOnly(now);
  final candidates = <(FlowerOccasion, DateTime, int, int)>[
    for (final year in [today.year, today.year + 1]) ...[
      (FlowerOccasion.valentine, DateTime(year, 2, 14), 10, 0),
      (FlowerOccasion.womensDay, DateTime(year, 3, 8), 10, 0),
      (FlowerOccasion.vietnameseWomensDay, DateTime(year, 10, 20), 10, 0),
      (FlowerOccasion.teachersDay, DateTime(year, 11, 20), 10, 0),
    ],
    for (final day in _tetDays) (FlowerOccasion.tet, day, 14, 3),
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  for (final (occasion, day, before, after) in candidates) {
    final start = DateTime(day.year, day.month, day.day - before);
    final end = DateTime(day.year, day.month, day.day + after);
    if (!today.isBefore(start) && !today.isAfter(end)) {
      return OccasionWindow(occasion, day, day.difference(today).inDays);
    }
  }
  return null;
}

extension FlowerOccasionName on FlowerOccasion {
  String get label => switch (this) {
    FlowerOccasion.tet => 'Tết Nguyên Đán',
    FlowerOccasion.valentine => 'Valentine 14/2',
    FlowerOccasion.womensDay => 'Quốc tế Phụ nữ 8/3',
    FlowerOccasion.vietnameseWomensDay => 'Phụ nữ Việt Nam 20/10',
    FlowerOccasion.teachersDay => 'Nhà giáo Việt Nam 20/11',
  };
}

/// The big flower days from [from] (inclusive) onwards, nearest first.
List<(FlowerOccasion, DateTime)> upcomingOccasions(
  DateTime from, {
  int withinDays = 400,
}) {
  final start = dateOnly(from);
  final end = start.add(Duration(days: withinDays));
  final days = <(FlowerOccasion, DateTime)>[
    for (final year in [start.year, start.year + 1]) ...[
      (FlowerOccasion.valentine, DateTime(year, 2, 14)),
      (FlowerOccasion.womensDay, DateTime(year, 3, 8)),
      (FlowerOccasion.vietnameseWomensDay, DateTime(year, 10, 20)),
      (FlowerOccasion.teachersDay, DateTime(year, 11, 20)),
    ],
    for (final day in _tetDays) (FlowerOccasion.tet, day),
  ];
  return days.where((d) => !d.$2.isBefore(start) && !d.$2.isAfter(end)).toList()
    ..sort((a, b) => a.$2.compareTo(b.$2));
}
