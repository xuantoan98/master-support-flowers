class FlowerComponent {
  const FlowerComponent({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.isMain,
  });

  factory FlowerComponent.fromJson(Map<String, dynamic> json) =>
      FlowerComponent(
        name: json['name'] as String? ?? '',
        quantity: json['quantity'] as int? ?? 0,
        unit: json['unit'] as String? ?? '',
        isMain: json['isMain'] as bool? ?? true,
      );

  final String name;
  final int quantity;
  final String unit;
  final bool isMain;

  Map<String, Object?> toJson() => {
    'name': name.trim(),
    'quantity': quantity,
    'unit': unit.trim(),
    'isMain': isMain,
  };
}

class CatalogProduct {
  const CatalogProduct({
    this.id,
    required this.name,
    required this.price,
    this.imagePath = '',
    this.components = const [],
  });

  final int? id;
  final String name;
  final int price;
  final String imagePath;
  final List<FlowerComponent> components;

  String? validate() {
    if (name.trim().isEmpty) {
      return 'Vui lòng nhập tên mẫu hoa';
    }
    if (price <= 0) {
      return 'Giá mẫu hoa phải lớn hơn 0';
    }
    for (final component in components) {
      if (component.name.trim().isEmpty ||
          component.quantity <= 0 ||
          component.unit.trim().isEmpty) {
        return 'Tên, số lượng và đơn vị hoa cần hợp lệ';
      }
    }
    return null;
  }
}
