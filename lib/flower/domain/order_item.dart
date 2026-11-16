import 'catalog_product.dart';

class OrderItem {
  const OrderItem({
    this.catalogProductId,
    required this.name,
    required this.unitPrice,
    this.quantity = 1,
    this.components = const [],
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    catalogProductId: json['catalogProductId'] as int?,
    name: json['name'] as String? ?? '',
    unitPrice: json['unitPrice'] as int? ?? 0,
    quantity: json['quantity'] as int? ?? 1,
    components: (json['components'] as List<dynamic>? ?? [])
        .map((value) => FlowerComponent.fromJson(value as Map<String, dynamic>))
        .toList(),
  );

  final int? catalogProductId;
  final String name;
  final int unitPrice;
  final int quantity;
  final List<FlowerComponent> components;

  int get total => unitPrice * quantity;

  OrderItem withQuantity(int value) => OrderItem(
    catalogProductId: catalogProductId,
    name: name,
    unitPrice: unitPrice,
    quantity: value,
    components: components,
  );

  Map<String, Object?> toJson() => {
    'catalogProductId': catalogProductId,
    'name': name.trim(),
    'unitPrice': unitPrice,
    'quantity': quantity,
    'components': components.map((value) => value.toJson()).toList(),
  };
}

int orderItemsTotal(Iterable<OrderItem> items) =>
    items.fold(0, (sum, item) => sum + item.total);

List<FlowerComponent> orderItemsComponents(Iterable<OrderItem> items) {
  final totals = <(String, String, bool), int>{};
  for (final item in items) {
    for (final component in item.components) {
      final key = (
        component.name.trim(),
        component.unit.trim(),
        component.isMain,
      );
      totals[key] = (totals[key] ?? 0) + component.quantity * item.quantity;
    }
  }
  return [
    for (final entry in totals.entries)
      FlowerComponent(
        name: entry.key.$1,
        unit: entry.key.$2,
        isMain: entry.key.$3,
        quantity: entry.value,
      ),
  ];
}

String orderItemsLabel(List<OrderItem> items) => items.length == 1
    ? items.single.name
    : '${items.first.name} + ${items.length - 1} mẫu khác';
