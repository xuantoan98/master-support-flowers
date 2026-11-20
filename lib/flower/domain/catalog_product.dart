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

/// Kinds of arrangement a retail shop sells.
enum ProductCategory {
  bouquet('bo', 'Bó hoa', 'Bó'),
  basket('gio', 'Giỏ hoa', 'Giỏ'),
  box('hop', 'Hộp hoa', 'Hộp'),
  stand('ke', 'Kệ khai trương', 'Kệ'),
  wedding('cuoi', 'Hoa cưới', 'Cưới'),
  funeral('tang', 'Hoa tang', 'Tang'),
  other('khac', 'Khác', 'Khác');

  const ProductCategory(this.key, this.label, this.short);

  final String key;
  final String label;

  /// For filter chips.
  final String short;

  static ProductCategory? parse(Object? value) {
    for (final category in values) {
      if (category.key == value) {
        return category;
      }
    }
    return null;
  }

  /// Best guess from a product name, for products made before categories.
  static ProductCategory? guess(String name) {
    final text = name.trim().toLowerCase();
    if (text.startsWith('bó')) {
      return bouquet;
    }
    if (text.startsWith('giỏ')) {
      return basket;
    }
    if (text.startsWith('hộp')) {
      return box;
    }
    if (text.startsWith('kệ') || text.contains('khai trương')) {
      return stand;
    }
    if (text.contains('cưới') || text.contains('cô dâu')) {
      return wedding;
    }
    if (text.contains('tang') || text.contains('viếng')) {
      return funeral;
    }
    return null;
  }
}

const productSizes = ['S', 'M', 'L'];

class CatalogProduct {
  const CatalogProduct({
    this.id,
    required this.name,
    required this.price,
    this.imagePath = '',
    this.components = const [],
    this.category,
    this.size = '',
    this.soldOut = false,
  });

  final int? id;
  final String name;
  final int price;
  final String imagePath;
  final List<FlowerComponent> components;
  final ProductCategory? category;

  /// S, M, L or empty when the shop does not size this product.
  final String size;

  /// Temporarily out of flowers: kept in the catalog, hidden when selling.
  final bool soldOut;

  /// Name as it goes on an order, with the size when there is one.
  String get displayName =>
      size.isEmpty ? name.trim() : '${name.trim()} (cỡ $size)';

  CatalogProduct copyWith({String? imagePath, bool? soldOut}) => CatalogProduct(
    id: id,
    name: name,
    price: price,
    imagePath: imagePath ?? this.imagePath,
    components: components,
    category: category,
    size: size,
    soldOut: soldOut ?? this.soldOut,
  );

  /// Search by name, category or flowers, ignoring case.
  bool matches(String query) {
    final text = query.trim().toLowerCase();
    if (text.isEmpty) {
      return true;
    }
    return displayName.toLowerCase().contains(text) ||
        (category?.label.toLowerCase().contains(text) ?? false) ||
        components.any((c) => c.name.toLowerCase().contains(text));
  }

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
