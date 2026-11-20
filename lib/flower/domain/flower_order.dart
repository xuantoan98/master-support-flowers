import 'catalog_product.dart';
import 'order_item.dart';

enum OrderStatus {
  newOrder,
  making,
  awaitingApproval,
  delivering,
  delivered,
  cancelled,
}

/// How the customer gets the flowers.
enum FulfillmentType {
  /// The shop delivers to an address.
  delivery,

  /// The customer collects a prepared order at the shop.
  pickup,

  /// Sold and handed over at the counter right away.
  counter,
}

extension FulfillmentTypeLabel on FulfillmentType {
  String get label => switch (this) {
    FulfillmentType.delivery => 'Giao tận nơi',
    FulfillmentType.pickup => 'Khách tới lấy',
    FulfillmentType.counter => 'Mua tại quầy',
  };

  /// Stored in SQLite; stable even if the enum is reordered.
  String get key => name;

  static FulfillmentType parse(Object? value) =>
      FulfillmentType.values.firstWhere(
        (type) => type.name == value,
        orElse: () => FulfillmentType.delivery,
      );
}

/// How a payment was made. Older payments have no method recorded.
enum PaymentMethod { cash, transfer, cod }

extension PaymentMethodLabel on PaymentMethod {
  String get label => switch (this) {
    PaymentMethod.cash => 'Tiền mặt',
    PaymentMethod.transfer => 'Chuyển khoản',
    PaymentMethod.cod => 'Shipper thu hộ (COD)',
  };

  static PaymentMethod? parse(Object? value) {
    for (final method in PaymentMethod.values) {
      if (method.name == value) {
        return method;
      }
    }
    return null;
  }
}

class PaymentEntry {
  const PaymentEntry({
    required this.amount,
    required this.occurredAt,
    required this.note,
    this.method,
  });

  /// Positive for money received, negative for a refund.
  final int amount;
  final DateTime occurredAt;
  final String note;

  /// Null for payments recorded before methods existed.
  final PaymentMethod? method;
}

class CustomerSummary {
  const CustomerSummary({
    required this.id,
    required this.name,
    required this.phone,
    required this.orderCount,
  });

  final int id;
  final String name;
  final String phone;
  final int orderCount;
}

extension OrderStatusLabel on OrderStatus {
  String get label => switch (this) {
    OrderStatus.newOrder => 'Mới',
    OrderStatus.making => 'Đang làm',
    OrderStatus.awaitingApproval => 'Chờ duyệt',
    OrderStatus.delivering => 'Đang giao',
    OrderStatus.delivered => 'Đã giao',
    OrderStatus.cancelled => 'Đã hủy',
  };

  List<OrderStatus> get allowedNext => switch (this) {
    OrderStatus.newOrder => [OrderStatus.making, OrderStatus.cancelled],
    OrderStatus.making => [OrderStatus.awaitingApproval, OrderStatus.cancelled],
    OrderStatus.awaitingApproval => [
      OrderStatus.delivering,
      OrderStatus.cancelled,
    ],
    OrderStatus.delivering => [OrderStatus.delivered, OrderStatus.cancelled],
    OrderStatus.delivered || OrderStatus.cancelled => [],
  };
}

class StatusEntry {
  const StatusEntry({required this.status, required this.changedAt});

  final OrderStatus status;
  final DateTime changedAt;
}

class OrderChangeEntry {
  const OrderChangeEntry({required this.details, required this.changedAt});

  final String details;
  final DateTime changedAt;
}

String? deliveryTimeIssue(DateTime deliveryAt, {DateTime? now}) =>
    deliveryAt.isAfter(now ?? DateTime.now())
    ? null
    : 'Thời gian giao phải sau thời điểm hiện tại';

class FlowerOrder {
  const FlowerOrder({
    this.id,
    required this.customerName,
    required this.phone,
    required this.productName,
    required this.price,
    required this.shippingFee,
    required this.paid,
    required this.deliveryAt,
    required this.address,
    this.components = const [],
    this.items = const [],
    this.note = '',
    this.status = OrderStatus.newOrder,
    this.fulfillment = FulfillmentType.delivery,
    this.recipientName = '',
    this.recipientPhone = '',
    this.cardMessage = '',
    this.anonymousSender = false,
    this.discount = 0,
    this.surcharge = 0,
  });

  final int? id;
  final String customerName;
  final String phone;
  final String productName;
  final int price;
  final int shippingFee;
  final int paid;
  final DateTime deliveryAt;
  final String address;
  final List<FlowerComponent> components;
  final List<OrderItem> items;

  List<OrderItem> get effectiveItems => items.isNotEmpty
      ? items
      : [
          OrderItem(
            name: productName,
            unitPrice: price,
            components: components,
          ),
        ];
  final String note;
  final OrderStatus status;
  final FulfillmentType fulfillment;

  /// Who receives a gift order; empty when the buyer receives it.
  final String recipientName;
  final String recipientPhone;

  /// Words for the card or banner attached to the flowers.
  final String cardMessage;

  /// Hide the buyer's name from the recipient (card, delivery slip).
  final bool anonymousSender;

  /// Money taken off the order, in đồng.
  final int discount;

  /// Extra charge such as a holiday surcharge, in đồng.
  final int surcharge;

  bool get isGift => recipientName.trim().isNotEmpty;
  bool get needsAddress => fulfillment == FulfillmentType.delivery;

  /// The person the shop contacts at hand-over time.
  String get contactName => isGift ? recipientName : customerName;
  String get contactPhone => isGift ? recipientPhone : phone;

  int get total => price + shippingFee + surcharge - discount;
  int get remaining => (total - paid).clamp(0, total < 0 ? 0 : total);

  /// "Đã giao" only makes sense when the shop delivered the flowers.
  String get statusLabel =>
      status == OrderStatus.delivered && fulfillment != FulfillmentType.delivery
      ? 'Hoàn tất'
      : status.label;

  FlowerOrder copyWith({
    OrderStatus? status,
    int? paid,
    DateTime? deliveryAt,
    String? address,
  }) => FlowerOrder(
    id: id,
    customerName: customerName,
    phone: phone,
    productName: productName,
    price: price,
    shippingFee: shippingFee,
    paid: paid ?? this.paid,
    deliveryAt: deliveryAt ?? this.deliveryAt,
    address: address ?? this.address,
    components: components,
    items: items,
    note: note,
    status: status ?? this.status,
    fulfillment: fulfillment,
    recipientName: recipientName,
    recipientPhone: recipientPhone,
    cardMessage: cardMessage,
    anonymousSender: anonymousSender,
    discount: discount,
    surcharge: surcharge,
  );

  String? validate() {
    if (customerName.trim().isEmpty) {
      return 'Vui lòng nhập tên khách hàng';
    }
    if (productName.trim().isEmpty) {
      return 'Vui lòng nhập tên sản phẩm';
    }
    if (price <= 0) {
      return 'Giá sản phẩm phải lớn hơn 0';
    }
    if (items.isNotEmpty &&
        (items.any(
              (item) =>
                  item.name.trim().isEmpty ||
                  item.unitPrice <= 0 ||
                  item.quantity <= 0,
            ) ||
            orderItemsTotal(items) != price)) {
      return 'Danh sách sản phẩm không hợp lệ';
    }
    if (discount < 0 || surcharge < 0) {
      return 'Giảm giá hoặc phụ thu không hợp lệ';
    }
    if (discount > price + surcharge) {
      return 'Giảm giá không vượt quá tiền hàng';
    }
    if (shippingFee < 0 || paid < 0 || paid > total) {
      return 'Phí giao hoặc tiền đã thu không hợp lệ';
    }
    if (needsAddress && address.trim().isEmpty) {
      return 'Vui lòng nhập địa chỉ giao';
    }
    for (final component in components) {
      if (component.name.trim().isEmpty ||
          component.quantity <= 0 ||
          component.unit.trim().isEmpty) {
        return 'Thành phần hoa không hợp lệ';
      }
    }
    return null;
  }
}

List<FlowerOrder> filterOrders(
  Iterable<FlowerOrder> orders, {
  String query = '',
  OrderStatus? status,
  DateTime? deliveryDay,
}) {
  final term = query.trim().toLowerCase();
  return orders.where((order) {
    if (status != null && order.status != status) {
      return false;
    }
    if (deliveryDay != null &&
        (order.deliveryAt.year != deliveryDay.year ||
            order.deliveryAt.month != deliveryDay.month ||
            order.deliveryAt.day != deliveryDay.day)) {
      return false;
    }
    return term.isEmpty ||
        order.customerName.toLowerCase().contains(term) ||
        order.phone.toLowerCase().contains(term) ||
        order.productName.toLowerCase().contains(term) ||
        order.effectiveItems.any(
          (item) => item.name.toLowerCase().contains(term),
        ) ||
        order.address.toLowerCase().contains(term) ||
        order.recipientName.toLowerCase().contains(term) ||
        order.recipientPhone.toLowerCase().contains(term) ||
        order.id?.toString() == term;
  }).toList();
}

/// Half of [total] rounded up to the next 1.000 đ, the usual deposit.
int depositHalf(int total) {
  if (total <= 0) {
    return 0;
  }
  final half = (total + 1) ~/ 2;
  return ((half + 999) ~/ 1000) * 1000;
}
