import 'flower_order.dart';

class LiveDelivery {
  const LiveDelivery({required this.orderId, required this.deliveryAt});

  final int orderId;
  final DateTime deliveryAt;

  Map<String, Object> toChannelMap() => {
    'orderId': orderId,
    'deliveryAtEpochMillis': deliveryAt.millisecondsSinceEpoch,
  };
}

List<LiveDelivery> planLiveDeliveries(Iterable<FlowerOrder> orders) {
  final deliveries =
      orders
          .where(
            (order) =>
                order.id != null && order.status == OrderStatus.delivering,
          )
          .map(
            (order) =>
                LiveDelivery(orderId: order.id!, deliveryAt: order.deliveryAt),
          )
          .toList()
        ..sort((a, b) => a.deliveryAt.compareTo(b.deliveryAt));
  return deliveries.take(3).toList();
}
