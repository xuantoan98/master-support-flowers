import 'package:flower_orders/flower/data/order_repository.dart';
import 'package:flower_orders/flower/domain/catalog_product.dart';
import 'package:flower_orders/flower/domain/flower_order.dart';
import 'package:flower_orders/flower/domain/order_media.dart';
import 'package:flower_orders/flower/domain/shop_profile.dart';
import 'package:flower_orders/flower/presentation/flower_app.dart';
import 'package:flower_orders/flower/presentation/shop_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// In-memory repository for the retail flows.
class RetailFakeRepository extends OrderRepository {
  RetailFakeRepository([List<FlowerOrder>? initial])
    : orders = initial ?? <FlowerOrder>[];

  final List<FlowerOrder> orders;
  final methods = <PaymentMethod?>[];
  final statuses = <OrderStatus>[];
  bool skip = false;
  Map<String, dynamic>? draft;

  @override
  Future<bool> remindersEnabled() async => false;

  @override
  Future<bool> skipApproval() async => skip;

  @override
  Future<void> setSkipApproval(bool enabled) async => skip = enabled;

  @override
  Future<List<FlowerOrder>> all() async => orders;

  @override
  Future<int> add(FlowerOrder order, {PaymentMethod? paymentMethod}) async {
    orders.add(order);
    methods.add(paymentMethod);
    return orders.length;
  }

  @override
  Future<void> updateStatus(FlowerOrder order, OrderStatus status) async {
    statuses.add(status);
  }

  @override
  Future<List<CustomerSummary>> customers({String query = ''}) async => [];

  @override
  Future<Map<String, dynamic>?> loadDraft() async => draft;

  @override
  Future<void> saveDraft(Map<String, dynamic> value) async => draft = value;

  @override
  Future<void> clearDraft() async => draft = null;

  @override
  Future<ShopProfile> loadShopProfile() async => const ShopProfile(
    bankBin: '970436',
    accountNumber: '0123456789',
    accountHolder: 'NGUYEN LAN',
  );

  @override
  Future<List<PaymentEntry>> paymentsForOrder(int orderId) async => [];

  /// The status the order starts with in a detail test.
  OrderStatus initialStatus = OrderStatus.newOrder;

  @override
  Future<List<StatusEntry>> statusHistory(int orderId) async => [
    for (final status in [...statuses.reversed, initialStatus])
      StatusEntry(status: status, changedAt: DateTime(2026)),
  ];

  @override
  Future<List<OrderChangeEntry>> orderChanges(int orderId) async => [];

  @override
  Future<List<OrderMedia>> mediaForOrder(int orderId) async => [];

  @override
  Future<List<CatalogProduct>> listProducts() async => const [
    CatalogProduct(
      id: 1,
      name: 'Bó hồng',
      price: 200000,
      components: [
        FlowerComponent(
          name: 'Hồng đỏ',
          quantity: 10,
          unit: 'cành',
          isMain: true,
        ),
      ],
    ),
    CatalogProduct(id: 2, name: 'Bó cúc', price: 150000),
  ];
}

FlowerOrder _order({
  int id = 1,
  required DateTime deliveryAt,
  OrderStatus status = OrderStatus.newOrder,
  int paid = 0,
  String phone = '',
}) => FlowerOrder(
  id: id,
  customerName: 'Lan',
  phone: phone,
  productName: 'Bó hồng',
  price: 200000,
  shippingFee: 0,
  paid: paid,
  deliveryAt: deliveryAt,
  address: '12 Hoa Mai',
  status: status,
  components: const [
    FlowerComponent(name: 'Hồng đỏ', quantity: 10, unit: 'cành', isMain: true),
  ],
);

Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async => initializeDateFormatting('vi'));

  testWidgets('quick sale saves a paid, finished counter order', (
    tester,
  ) async {
    final repository = RetailFakeRepository();
    await tester.pumpWidget(FlowerApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bán nhanh'));
    await tester.pumpAndSettle();
    expect(find.text('Bán nhanh tại quầy'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp('^Bó hồng, 200.000 đ')));
    await tester.tap(find.bySemanticsLabel(RegExp('^Bó hồng, 200.000 đ')));
    await tester.pumpAndSettle();
    final discount = find.widgetWithText(
      TextField,
      'Giảm giá (đ, không bắt buộc)',
    );
    await reveal(tester, discount);
    await tester.enterText(discount, '20000');
    await tester.pumpAndSettle();
    expect(find.text('380.000 đ'), findsOneWidget);

    await tester.tap(find.text('Thu tiền & xong'));
    await tester.pumpAndSettle();

    final sale = repository.orders.single;
    expect(sale.fulfillment, FulfillmentType.counter);
    expect(sale.status, OrderStatus.delivered);
    expect(sale.customerName, 'Khách lẻ');
    expect(sale.items.single.quantity, 2);
    expect(sale.discount, 20000);
    expect(sale.paid, 380000);
    expect(sale.remaining, 0);
    expect(repository.methods.single, PaymentMethod.cash);
    // Let the confirmation toast finish.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('transfer sale shows a VietQR before saving', (tester) async {
    final repository = RetailFakeRepository();
    await tester.pumpWidget(
      MaterialApp(home: QuickSaleScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp('^Bó cúc')));
    await reveal(tester, find.text('Chuyển khoản'));
    await tester.tap(find.text('Chuyển khoản'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hiện mã QR'));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp('^Mã VietQR chuyển khoản 150')),
      findsOneWidget,
    );
    expect(repository.orders, isEmpty, reason: 'not saved before payment');
    await tester.tap(find.text('Đã nhận tiền'));
    await tester.pumpAndSettle();
    expect(repository.orders.single.paid, 150000);
    expect(repository.methods.single, PaymentMethod.transfer);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('gift order collected at the shop needs no address', (
    tester,
  ) async {
    final repository = RetailFakeRepository();
    await tester.pumpWidget(
      MaterialApp(home: CreateOrderScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Lan');
    await tester.tap(find.text('Đơn tặng người khác'));
    await tester.pumpAndSettle();
    // Name, phone, then recipient name and phone.
    await tester.enterText(find.byType(TextField).at(2), 'Mai');
    await tester.enterText(find.byType(TextField).at(3), '0902000000');
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thêm từ mẫu hoa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bó hồng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Khách tới lấy'));
    await tester.pumpAndSettle();
    expect(find.text('Địa chỉ giao'), findsNothing);
    final card = find.widgetWithText(
      TextField,
      'Lời thiệp / banner (không bắt buộc)',
    );
    await reveal(tester, card);
    await tester.enterText(card, 'Chúc mừng sinh nhật');
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();

    // Pickup: no shipping fee field; a 10% discount.
    expect(find.text('Phí giao (đ)'), findsNothing);
    await tester.tap(find.text('%'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Giảm giá (%)'),
      '10',
    );
    await tester.pumpAndSettle();
    expect(find.text('Tổng: 180.000 đ'), findsOneWidget);
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(find.text('Khách tới lấy'), findsOneWidget);
    expect(find.text('“Chúc mừng sinh nhật”'), findsOneWidget);

    await tester.tap(find.text('Xác nhận tạo đơn'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    final order = repository.orders.single;
    expect(order.fulfillment, FulfillmentType.pickup);
    expect(order.address, isEmpty);
    expect(order.shippingFee, 0);
    expect(order.recipientName, 'Mai');
    expect(order.recipientPhone, '0902000000');
    expect(order.cardMessage, 'Chúc mừng sinh nhật');
    expect(order.discount, 20000);
    expect(order.total, 180000);
  });

  testWidgets('today shows work, money owed and flowers for tomorrow', (
    tester,
  ) async {
    final now = DateTime.now();
    final tomorrow = DateUtils.dateOnly(
      now,
    ).add(const Duration(days: 1, hours: 9));
    final repository = RetailFakeRepository([
      _order(
        deliveryAt: DateUtils.dateOnly(
          now,
        ).add(const Duration(hours: 23, minutes: 59)),
      ),
      _order(id: 2, deliveryAt: tomorrow, paid: 50000),
    ]);
    await tester.pumpWidget(FlowerApp(repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('Đơn hôm nay'), findsOneWidget);
    expect(find.textContaining('1 đơn cần làm'), findsOneWidget);
    await reveal(tester, find.text('10 cành'));
    // Both orders still owe money: 200.000 + 150.000.
    expect(find.text('350.000 đ'), findsOneWidget);
    expect(find.text('Hồng đỏ'), findsOneWidget);
    expect(find.text('10 cành'), findsOneWidget);
  });

  testWidgets('detail can skip approval and undo a status change', (
    tester,
  ) async {
    final repository = RetailFakeRepository()
      ..initialStatus = OrderStatus.making;
    await tester.pumpWidget(
      MaterialApp(
        home: OrderDetailScreen(
          order: _order(
            deliveryAt: DateTime(2026, 11, 20),
            status: OrderStatus.making,
            phone: '0901234567',
          ),
          repository: repository,
          onChanged: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Gọi Lan'), findsOneWidget);
    expect(find.bySemanticsLabel('Nhắn Zalo cho Lan'), findsOneWidget);

    await reveal(tester, find.text('Quay lại: Mới'));
    final skip = find.text('Bỏ qua chờ duyệt → Đang giao');
    await tester.ensureVisible(skip);
    await tester.pumpAndSettle();
    await tester.tap(skip);
    await tester.pumpAndSettle();
    expect(repository.statuses, [OrderStatus.delivering]);

    await reveal(tester, find.text('Quay lại: Đang làm'));
    await tester.tap(find.text('Quay lại: Đang làm'));
    await tester.pumpAndSettle();
    expect(repository.statuses, [OrderStatus.delivering, OrderStatus.making]);
  });

  testWidgets('picking a bank closes the sheet without a framework error', (
    tester,
  ) async {
    // Regression: the search field was disposed while the sheet was still
    // animating out, which showed a red error screen on the device.
    await tester.pumpWidget(
      MaterialApp(home: ShopProfileScreen(repository: RetailFakeRepository())),
    );
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Vietcombank'));
    await tester.tap(find.text('Vietcombank'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'techcom');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Techcombank'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Techcombank'), findsOneWidget);
    expect(find.text('Kỹ thương Việt Nam'), findsOneWidget);
  });
}
