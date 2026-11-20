import 'flower_order.dart';

/// The shipping fee the shop charges most often on its recent delivery
/// orders, so a new order starts with it. 0 when there is no history.
int usualShippingFee(Iterable<FlowerOrder> orders, {int recent = 30}) {
  final deliveries =
      orders
          .where(
            (o) =>
                o.fulfillment == FulfillmentType.delivery &&
                o.status != OrderStatus.cancelled &&
                o.shippingFee > 0,
          )
          .toList()
        ..sort((a, b) => b.deliveryAt.compareTo(a.deliveryAt));
  final counts = <int, int>{};
  for (final order in deliveries.take(recent)) {
    counts[order.shippingFee] = (counts[order.shippingFee] ?? 0) + 1;
  }
  if (counts.isEmpty) {
    return 0;
  }
  // Most frequent; on a tie the more recent fee wins.
  var best = deliveries.first.shippingFee;
  for (final entry in counts.entries) {
    if (entry.value > counts[best]!) {
      best = entry.key;
    }
  }
  return best;
}

/// The customer's latest order that was not cancelled, matched on name and
/// phone like the customer list does.
FlowerOrder? lastOrderOf(
  Iterable<FlowerOrder> orders,
  String name,
  String phone,
) {
  final key = name.trim().toLowerCase();
  final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (key.isEmpty) {
    return null;
  }
  FlowerOrder? latest;
  for (final order in orders) {
    if (order.status == OrderStatus.cancelled ||
        order.customerName.trim().toLowerCase() != key ||
        order.phone.replaceAll(RegExp(r'[^0-9]'), '') != digits) {
      continue;
    }
    if (latest == null || order.deliveryAt.isAfter(latest.deliveryAt)) {
      latest = order;
    }
  }
  return latest;
}

/// [time] moved up to the next half hour (10:07 → 10:30, 10:30 stays).
DateTime roundUpToHalfHour(DateTime time) {
  final base = DateTime(time.year, time.month, time.day, time.hour);
  final minutes =
      time.minute + (time.second > 0 || time.millisecond > 0 ? 1 : 0);
  if (minutes == 0) {
    return base;
  }
  return base.add(Duration(minutes: minutes <= 30 ? 30 : 60));
}

/// Quick delivery times: the start of each part of the day.
const deliverySlots = <({String label, int hour})>[
  (label: 'Sáng', hour: 8),
  (label: 'Trưa', hour: 11),
  (label: 'Chiều', hour: 15),
  (label: 'Tối', hour: 19),
];

/// What a customer has bought and still owes.
class CustomerTotals {
  const CustomerTotals({
    required this.orderCount,
    required this.spent,
    required this.owed,
    required this.addresses,
  });

  /// Orders that were not cancelled.
  final int orderCount;

  /// Total of the orders that were not cancelled.
  final int spent;

  /// Money still to collect on those orders.
  final int owed;

  /// Delivery addresses used, most recent first, without repeats.
  final List<String> addresses;
}

CustomerTotals customerTotals(Iterable<FlowerOrder> orders) {
  final live = orders.where((o) => o.status != OrderStatus.cancelled).toList()
    ..sort((a, b) => b.deliveryAt.compareTo(a.deliveryAt));
  final addresses = <String>[];
  final seen = <String>{};
  for (final order in live) {
    final address = order.address.trim();
    if (address.isNotEmpty && seen.add(address.toLowerCase())) {
      addresses.add(address);
    }
  }
  return CustomerTotals(
    orderCount: live.length,
    spent: live.fold(0, (sum, o) => sum + o.total),
    owed: live.fold(0, (sum, o) => sum + o.remaining),
    addresses: addresses,
  );
}
