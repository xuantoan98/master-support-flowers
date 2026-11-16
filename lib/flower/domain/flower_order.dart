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

class PaymentEntry {
  const PaymentEntry({
    required this.amount,
    required this.occurredAt,
    required this.note,
  });

  /// Positive for money received, negative for a refund.
  final int amount;
  final DateTime occurredAt;
  final String note;
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

  int get total => price + shippingFee;
  int get remaining => (total - paid).clamp(0, total);

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
    if (shippingFee < 0 || paid < 0 || paid > total) {
      return 'Phí giao hoặc tiền đã thu không hợp lệ';
    }
    if (address.trim().isEmpty) {
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
        order.id?.toString() == term;
  }).toList();
}
