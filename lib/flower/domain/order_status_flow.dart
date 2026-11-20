import 'flower_order.dart';

/// The steps an order goes through for its kind of hand-over, in order.
///
/// "Chờ duyệt" (customer approves a photo) is part of every prepared order
/// but can be skipped; pickup orders never go "Đang giao"; counter sales are
/// handed over at once.
List<OrderStatus> statusChain(FulfillmentType fulfillment) =>
    switch (fulfillment) {
      FulfillmentType.delivery => const [
        OrderStatus.newOrder,
        OrderStatus.making,
        OrderStatus.awaitingApproval,
        OrderStatus.delivering,
        OrderStatus.delivered,
      ],
      FulfillmentType.pickup => const [
        OrderStatus.newOrder,
        OrderStatus.making,
        OrderStatus.awaitingApproval,
        OrderStatus.delivered,
      ],
      FulfillmentType.counter => const [OrderStatus.delivered],
    };

/// The chain shown to the shop: without "Chờ duyệt" when it is skipped,
/// unless the order is already waiting for approval.
List<OrderStatus> visibleStatusChain(
  FlowerOrder order, {
  bool skipApproval = false,
}) => [
  for (final status in statusChain(order.fulfillment))
    if (!skipApproval ||
        status != OrderStatus.awaitingApproval ||
        order.status == OrderStatus.awaitingApproval)
      status,
];

/// The step a quick action (button, swipe) moves the order to; never cancels.
OrderStatus? nextStatusFor(FlowerOrder order, {bool skipApproval = false}) {
  final chain = visibleStatusChain(order, skipApproval: skipApproval);
  final index = chain.indexOf(order.status);
  if (index < 0 || index + 1 >= chain.length) {
    return null;
  }
  return chain[index + 1];
}

/// The step before the current one, to undo a mistaken change.
OrderStatus? previousStatusFor(FlowerOrder order, {bool skipApproval = false}) {
  final chain = visibleStatusChain(order, skipApproval: skipApproval);
  final index = chain.indexOf(order.status);
  if (index <= 0) {
    return null;
  }
  return chain[index - 1];
}

/// Whether the shop may move an order from [from] to [to].
///
/// Any step of the order's chain is allowed, forwards (skipping steps) or
/// backwards (fixing a mistake). Cancelling is allowed until the flowers are
/// handed over; a cancelled order stays cancelled.
bool canChangeStatus(
  FulfillmentType fulfillment,
  OrderStatus from,
  OrderStatus to,
) {
  if (from == to || from == OrderStatus.cancelled) {
    return false;
  }
  if (to == OrderStatus.cancelled) {
    return from != OrderStatus.delivered;
  }
  // `from` may be outside the chain when the hand-over kind was edited later
  // (e.g. "Đang giao" on an order switched to pickup); any chain step fixes it.
  return statusChain(fulfillment).contains(to);
}
