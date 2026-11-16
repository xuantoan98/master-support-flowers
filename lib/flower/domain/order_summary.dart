import 'flower_order.dart';

class OrderSummary {
  const OrderSummary({
    required this.orderCount,
    required this.pendingCount,
    required this.projectedRevenue,
    required this.paid,
  });

  final int orderCount;
  final int pendingCount;
  final int projectedRevenue;
  final int paid;

  int get remaining => projectedRevenue - paid;
}

OrderSummary summarizeOrders(
  Iterable<FlowerOrder> orders, {
  DateTime? deliveryMonth,
}) {
  var orderCount = 0;
  var pendingCount = 0;
  var projectedRevenue = 0;
  var paid = 0;
  for (final order in orders) {
    if (order.status == OrderStatus.cancelled ||
        (deliveryMonth != null &&
            (order.deliveryAt.year != deliveryMonth.year ||
                order.deliveryAt.month != deliveryMonth.month))) {
      continue;
    }
    orderCount++;
    if (order.status != OrderStatus.delivered) {
      pendingCount++;
    }
    projectedRevenue += order.total;
    paid += order.paid;
  }
  return OrderSummary(
    orderCount: orderCount,
    pendingCount: pendingCount,
    projectedRevenue: projectedRevenue,
    paid: paid,
  );
}
