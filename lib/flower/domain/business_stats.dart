import 'flower_order.dart';

enum StatsPeriod { week, month, quarter, year }

class StatsWindow {
  const StatsWindow(this.period, this.start, this.end);

  factory StatsWindow.at(StatsPeriod period, DateTime date) {
    final start = switch (period) {
      StatsPeriod.week => DateTime(
        date.year,
        date.month,
        date.day - date.weekday + DateTime.monday,
      ),
      StatsPeriod.month => DateTime(date.year, date.month),
      StatsPeriod.quarter => DateTime(
        date.year,
        ((date.month - 1) ~/ 3) * 3 + 1,
      ),
      StatsPeriod.year => DateTime(date.year),
    };
    final end = switch (period) {
      StatsPeriod.week => DateTime(start.year, start.month, start.day + 7),
      StatsPeriod.month => DateTime(start.year, start.month + 1),
      StatsPeriod.quarter => DateTime(start.year, start.month + 3),
      StatsPeriod.year => DateTime(start.year + 1),
    };
    return StatsWindow(period, start, end);
  }

  final StatsPeriod period;
  final DateTime start;
  final DateTime end;

  bool contains(DateTime date) => !date.isBefore(start) && date.isBefore(end);

  StatsWindow shift(int steps) {
    final date = switch (period) {
      StatsPeriod.week => DateTime(
        start.year,
        start.month,
        start.day + 7 * steps,
      ),
      StatsPeriod.month => DateTime(start.year, start.month + steps),
      StatsPeriod.quarter => DateTime(start.year, start.month + 3 * steps),
      StatsPeriod.year => DateTime(start.year + steps),
    };
    return StatsWindow.at(period, date);
  }
}

class OrderPayment {
  const OrderPayment({required this.amount, required this.occurredAt});

  final int amount;
  final DateTime occurredAt;
}

class ProductRank {
  const ProductRank({required this.name, required this.quantity});

  final String name;
  final int quantity;
}

class StatsBucket {
  const StatsBucket({required this.label, required this.revenue});

  final String label;
  final int revenue;
}

class BusinessStats {
  const BusinessStats({
    required this.window,
    required this.orderCount,
    required this.deliveredCount,
    required this.pendingCount,
    required this.deliveredRevenue,
    required this.bookedRevenue,
    required this.outstanding,
    required this.receipts,
    required this.refunds,
    required this.repeatCustomers,
    required this.topProducts,
    required this.busiestWeekday,
    required this.busiestDaypart,
    required this.buckets,
  });

  final StatsWindow window;
  final int orderCount;
  final int deliveredCount;
  final int pendingCount;
  final int deliveredRevenue;
  final int bookedRevenue;
  final int outstanding;
  final int receipts;
  final int refunds;
  final int repeatCustomers;
  final List<ProductRank> topProducts;
  final int? busiestWeekday;
  final String? busiestDaypart;
  final List<StatsBucket> buckets;

  int get netCash => receipts - refunds;
}

BusinessStats calculateBusinessStats(
  Iterable<FlowerOrder> orders,
  Iterable<OrderPayment> payments,
  StatsWindow window,
) {
  final activeAll = orders
      .where((order) => order.status != OrderStatus.cancelled)
      .toList();
  final inWindow = activeAll
      .where((order) => window.contains(order.deliveryAt))
      .toList();
  final delivered = inWindow
      .where((order) => order.status == OrderStatus.delivered)
      .toList();
  final productCounts = <String, int>{};
  for (final order in delivered) {
    for (final item in order.effectiveItems) {
      final name = item.name.trim();
      productCounts[name] = (productCounts[name] ?? 0) + item.quantity;
    }
  }
  final topProducts =
      [
        for (final entry in productCounts.entries)
          ProductRank(name: entry.key, quantity: entry.value),
      ]..sort((a, b) {
        final count = b.quantity.compareTo(a.quantity);
        return count != 0 ? count : a.name.compareTo(b.name);
      });

  final customerCounts = <String, int>{};
  for (final order in activeAll) {
    final key =
        '${order.customerName.trim().toLowerCase()}|${order.phone.trim()}';
    customerCounts[key] = (customerCounts[key] ?? 0) + 1;
  }
  final repeatKeys = <String>{};
  for (final order in inWindow) {
    final key =
        '${order.customerName.trim().toLowerCase()}|${order.phone.trim()}';
    if ((customerCounts[key] ?? 0) > 1) {
      repeatKeys.add(key);
    }
  }

  final weekdayCounts = <int, int>{};
  final daypartCounts = <String, int>{};
  for (final order in inWindow) {
    weekdayCounts.update(
      order.deliveryAt.weekday,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
    final part = order.deliveryAt.hour < 12
        ? 'Sáng'
        : order.deliveryAt.hour < 18
        ? 'Chiều'
        : 'Tối';
    daypartCounts.update(part, (value) => value + 1, ifAbsent: () => 1);
  }
  final weekdays = weekdayCounts.keys.toList()
    ..sort((a, b) {
      final count = weekdayCounts[b]!.compareTo(weekdayCounts[a]!);
      return count != 0 ? count : a.compareTo(b);
    });
  final dayparts = daypartCounts.keys.toList()
    ..sort((a, b) {
      final count = daypartCounts[b]!.compareTo(daypartCounts[a]!);
      return count != 0
          ? count
          : [
              'Sáng',
              'Chiều',
              'Tối',
            ].indexOf(a).compareTo(['Sáng', 'Chiều', 'Tối'].indexOf(b));
    });

  var receipts = 0;
  var refunds = 0;
  for (final payment in payments.where(
    (entry) => window.contains(entry.occurredAt),
  )) {
    if (payment.amount >= 0) {
      receipts += payment.amount;
    } else {
      refunds -= payment.amount;
    }
  }

  return BusinessStats(
    window: window,
    orderCount: inWindow.length,
    deliveredCount: delivered.length,
    pendingCount: inWindow.length - delivered.length,
    deliveredRevenue: delivered.fold(0, (sum, order) => sum + order.total),
    bookedRevenue: inWindow.fold(0, (sum, order) => sum + order.total),
    outstanding: inWindow.fold(0, (sum, order) => sum + order.remaining),
    receipts: receipts,
    refunds: refunds,
    repeatCustomers: repeatKeys.length,
    topProducts: topProducts.take(3).toList(),
    busiestWeekday: weekdays.isEmpty ? null : weekdays.first,
    busiestDaypart: dayparts.isEmpty ? null : dayparts.first,
    buckets: _buckets(delivered, window),
  );
}

List<StatsBucket> _buckets(List<FlowerOrder> delivered, StatsWindow window) {
  final starts = <DateTime>[];
  final labels = <String>[];
  switch (window.period) {
    case StatsPeriod.week:
      for (var day = 0; day < 7; day++) {
        final date = DateTime(
          window.start.year,
          window.start.month,
          window.start.day + day,
        );
        starts.add(date);
        labels.add('${date.day}/${date.month}');
      }
    case StatsPeriod.month:
      for (
        var day = 1;
        day < window.end.subtract(const Duration(days: 1)).day + 1;
        day += 7
      ) {
        starts.add(DateTime(window.start.year, window.start.month, day));
        labels.add(
          '$day–${(day + 6).clamp(1, window.end.subtract(const Duration(days: 1)).day)}',
        );
      }
    case StatsPeriod.quarter:
      for (var month = 0; month < 3; month++) {
        final date = DateTime(window.start.year, window.start.month + month);
        starts.add(date);
        labels.add('T${date.month}');
      }
    case StatsPeriod.year:
      for (var month = 1; month <= 12; month++) {
        starts.add(DateTime(window.start.year, month));
        labels.add('T$month');
      }
  }
  return [
    for (var index = 0; index < starts.length; index++)
      StatsBucket(
        label: labels[index],
        revenue: delivered
            .where(
              (order) =>
                  !order.deliveryAt.isBefore(starts[index]) &&
                  order.deliveryAt.isBefore(
                    index + 1 < starts.length ? starts[index + 1] : window.end,
                  ),
            )
            .fold(0, (sum, order) => sum + order.total),
      ),
  ];
}
