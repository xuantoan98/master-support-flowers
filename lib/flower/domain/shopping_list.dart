import 'flower_order.dart';

class ShoppingItem {
  const ShoppingItem({
    required this.name,
    required this.unit,
    required this.quantity,
  });

  final String name;
  final String unit;
  final int quantity;

  String get key => '${name.trim().toLowerCase()}|${unit.trim().toLowerCase()}';
}

class ShoppingList {
  const ShoppingList({required this.items, required this.ordersWithoutRecipe});

  final List<ShoppingItem> items;
  final int ordersWithoutRecipe;
}

ShoppingList buildShoppingList(
  Iterable<FlowerOrder> orders,
  DateTime start,
  DateTime end,
) {
  final totals = <String, ShoppingItem>{};
  var missing = 0;
  for (final order in orders) {
    if (order.status == OrderStatus.cancelled ||
        order.status == OrderStatus.delivered ||
        order.deliveryAt.isBefore(start) ||
        !order.deliveryAt.isBefore(end)) {
      continue;
    }
    if (order.components.isEmpty) {
      missing++;
    }
    for (final component in order.components) {
      final key =
          '${component.name.trim().toLowerCase()}|${component.unit.trim().toLowerCase()}';
      final previous = totals[key];
      totals[key] = ShoppingItem(
        name: previous?.name ?? component.name.trim(),
        unit: previous?.unit ?? component.unit.trim(),
        quantity: (previous?.quantity ?? 0) + component.quantity,
      );
    }
  }
  final items = totals.values.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return ShoppingList(items: items, ordersWithoutRecipe: missing);
}
