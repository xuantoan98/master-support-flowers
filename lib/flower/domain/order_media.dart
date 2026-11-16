enum OrderMediaType { sample, finished, delivery, feedback }

extension OrderMediaTypeLabel on OrderMediaType {
  String get label => switch (this) {
    OrderMediaType.sample => 'Ảnh mẫu',
    OrderMediaType.finished => 'Thành phẩm',
    OrderMediaType.delivery => 'Lúc giao',
    OrderMediaType.feedback => 'Phản hồi',
  };
}

class OrderMedia {
  const OrderMedia({
    required this.id,
    required this.orderId,
    required this.type,
    required this.relativePath,
    required this.createdAt,
  });

  final int id;
  final int orderId;
  final OrderMediaType type;
  final String relativePath;
  final DateTime createdAt;
}
