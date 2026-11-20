import 'dart:io';

import 'package:flower_orders/flower/data/order_repository.dart';
import 'package:flower_orders/flower/domain/catalog_product.dart';
import 'package:flower_orders/flower/domain/flower_order.dart';
import 'package:flower_orders/flower/domain/order_defaults.dart';
import 'package:flower_orders/flower/domain/order_reminder.dart';
import 'package:flower_orders/flower/domain/shop_profile.dart';
import 'package:flower_orders/flower/presentation/flower_app.dart';
import 'package:flower_orders/flower/presentation/setup_wizard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Repository extends OrderRepository {
  _Repository(this.orders);

  final List<FlowerOrder> orders;
  final added = <FlowerOrder>[];

  @override
  Future<List<FlowerOrder>> all() async => orders;

  @override
  Future<int> add(FlowerOrder order, {PaymentMethod? paymentMethod}) async {
    added.add(order);
    return 99;
  }

  @override
  Future<List<CustomerSummary>> customers({String query = ''}) async => [];

  @override
  Future<Map<String, dynamic>?> loadDraft() async => null;

  @override
  Future<void> saveDraft(Map<String, dynamic> value) async {}

  @override
  Future<void> clearDraft() async {}

  List<CatalogProduct> products = const [];
  ShopProfile? savedProfile;
  final archived = <int>[];
  bool setup = false;

  @override
  Future<void> saveShopProfile(ShopProfile profile) async =>
      savedProfile = profile;

  @override
  Future<void> archiveProduct(int id) async => archived.add(id);

  @override
  Future<void> setSetupDone() async => setup = true;

  @override
  Future<bool> needsSetup() async => !setup;

  @override
  Future<List<CatalogProduct>> listProducts() async => products;
}

FlowerOrder _order({
  String name = 'Lan',
  String phone = '0901234567',
  int fee = 15000,
  required DateTime at,
  FulfillmentType fulfillment = FulfillmentType.delivery,
  OrderStatus status = OrderStatus.delivered,
  String product = 'Bó hồng',
  List<FlowerComponent> components = const [],
  String cardMessage = '',
}) => FlowerOrder(
  components: components,
  cardMessage: cardMessage,
  customerName: name,
  phone: phone,
  productName: product,
  price: 200000,
  shippingFee: fee,
  paid: 0,
  deliveryAt: at,
  address: '12 Hoa Mai',
  status: status,
  fulfillment: fulfillment,
);

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('vi');
  });

  test('daily reminders: evening prep, morning market, holiday', () {
    final now = DateTime(2026, 11, 20, 10);
    final orders = [
      _order(
        at: DateTime(2026, 11, 21, 9),
        status: OrderStatus.newOrder,
        components: const [
          FlowerComponent(
            name: 'Hồng đỏ',
            quantity: 10,
            unit: 'cành',
            isMain: true,
          ),
        ],
        cardMessage: 'Chúc mừng',
      ),
      _order(at: DateTime(2026, 11, 21, 15), status: OrderStatus.cancelled),
    ];
    final reminders = planDailyReminders(orders, now: now);
    final evening = reminders.singleWhere(
      (r) => r.at == DateTime(2026, 11, 20, 20),
    );
    expect(evening.title, 'Ngày mai có 1 đơn');
    expect(evening.body, contains('1 đơn có lời thiệp'));
    final market = reminders.singleWhere(
      (r) => r.at == DateTime(2026, 11, 21, 6),
    );
    expect(market.title, 'Đi chợ hoa: 1 loại cần mua');
    expect(market.body, 'Hồng đỏ 10 cành');
    // Today's 6:00 is already past, and empty days stay quiet.
    expect(reminders.where((r) => r.at.hour == 6), hasLength(1));
    expect(reminders.where((r) => r.at.hour == 20), hasLength(1));

    final early = planDailyReminders([], now: DateTime(2027, 1, 20));
    final tet = early.singleWhere((r) => r.title.contains('Tết'));
    expect(tet.at, DateTime(2027, 1, 30, 9));
    final ids = reminders.map((r) => r.notificationId).toSet();
    expect(ids, hasLength(reminders.length));
  });

  test('only a brand-new install needs setup', () async {
    final directory = await Directory.systemTemp.createTemp('flower_setup_');
    final repository = OrderRepository();
    await repository.open(databasePath: p.join(directory.path, 'o.db'));
    try {
      expect(await repository.needsSetup(), isTrue);
      await repository.saveShopProfile(const ShopProfile(name: 'Tiệm Lan'));
      // A shop that already has its own name is not asked again.
      expect(await repository.needsSetup(), isFalse);
      expect(await repository.setupDone(), isTrue);
    } finally {
      await repository.close();
      await directory.delete(recursive: true);
    }
  });

  testWidgets('setup saves the shop, skips the bank and trims samples', (
    tester,
  ) async {
    final repository = _Repository([])
      ..products = const [
        CatalogProduct(id: 1, name: 'Bó hồng', price: 200000),
        CatalogProduct(id: 2, name: 'Bó cúc', price: 150000),
      ];
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SetupWizardScreen(
          repository: repository,
          onDone: () => done = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập tên tiệm'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Tiệm Hoa Lan');
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(find.text('Tài khoản ngân hàng'), findsOneWidget);
    await tester.tap(find.text('Bỏ qua'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bó cúc'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bắt đầu bán'));
    await tester.pumpAndSettle();
    expect(done, isTrue);
    expect(repository.savedProfile?.name, 'Tiệm Hoa Lan');
    expect(repository.savedProfile?.hasVietQr, isFalse);
    expect(repository.archived, [2]);
    expect(repository.setup, isTrue);
    await tester.pump(const Duration(seconds: 4));
  });

  group('catalog', () {
    test('category, size and sold out survive a round trip', () async {
      final directory = await Directory.systemTemp.createTemp('flower_v15_');
      final repository = OrderRepository();
      await repository.open(databasePath: p.join(directory.path, 'o.db'));
      try {
        final id = await repository.saveProduct(
          const CatalogProduct(
            name: 'Giỏ lan',
            price: 500000,
            category: ProductCategory.basket,
            size: 'L',
          ),
        );
        await repository.setProductSoldOut(id, true);
        final saved = (await repository.listProducts()).singleWhere(
          (product) => product.id == id,
        );
        expect(saved.category, ProductCategory.basket);
        expect(saved.size, 'L');
        expect(saved.soldOut, isTrue);
        expect(saved.displayName, 'Giỏ lan (cỡ L)');
        // Seeded bouquets got a category from their name.
        expect(
          (await repository.listProducts())
              .where((product) => product.name.startsWith('Bó'))
              .every((product) => product.category == ProductCategory.bouquet),
          isTrue,
        );
      } finally {
        await repository.close();
        await directory.delete(recursive: true);
      }
    });

    test('v14 products get category columns and a guessed category', () async {
      final directory = await Directory.systemTemp.createTemp('flower_v14_');
      final path = p.join(directory.path, 'o.db');
      final repository = OrderRepository();
      await repository.open(databasePath: path);
      await repository.db.execute('ALTER TABLE products DROP COLUMN category');
      await repository.db.execute('ALTER TABLE products DROP COLUMN size');
      await repository.db.execute('ALTER TABLE products DROP COLUMN sold_out');
      await repository.db.setVersion(14);
      await repository.close();
      final reopened = OrderRepository();
      await reopened.open(databasePath: path);
      try {
        final products = await reopened.listProducts();
        expect(products, isNotEmpty);
        expect(products.every((product) => !product.soldOut), isTrue);
        expect(
          products.where((product) => product.category != null),
          isNotEmpty,
        );
      } finally {
        await reopened.close();
        await directory.delete(recursive: true);
      }
    });

    test('search looks at name, size, category and flowers', () {
      const product = CatalogProduct(
        name: 'Bó pastel',
        price: 300000,
        category: ProductCategory.bouquet,
        size: 'M',
        components: [
          FlowerComponent(
            name: 'Cát tường',
            quantity: 5,
            unit: 'cành',
            isMain: false,
          ),
        ],
      );
      expect(product.matches('PASTEL'), isTrue);
      expect(product.matches('cỡ m'), isTrue);
      expect(product.matches('bó hoa'), isTrue);
      expect(product.matches('cát'), isTrue);
      expect(product.matches('giỏ'), isFalse);
    });
  });

  testWidgets('order picker hides sold-out products and filters', (
    tester,
  ) async {
    final repository = _Repository([])
      ..products = const [
        CatalogProduct(
          id: 1,
          name: 'Bó hồng',
          price: 200000,
          category: ProductCategory.bouquet,
        ),
        CatalogProduct(
          id: 2,
          name: 'Giỏ lan',
          price: 500000,
          category: ProductCategory.basket,
        ),
        CatalogProduct(
          id: 3,
          name: 'Bó cúc',
          price: 150000,
          category: ProductCategory.bouquet,
          soldOut: true,
        ),
      ];
    await tester.pumpWidget(
      MaterialApp(home: CreateOrderScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Hoa');
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm từ mẫu hoa'));
    await tester.pumpAndSettle();
    expect(find.text('Bó cúc'), findsNothing);
    expect(find.text('Giỏ lan'), findsOneWidget);
    await tester.tap(find.text('Giỏ'));
    await tester.pumpAndSettle();
    expect(find.text('Bó hồng'), findsNothing);
    await tester.tap(find.text('Giỏ lan'));
    await tester.pumpAndSettle();
    expect(find.text('Giỏ lan'), findsOneWidget);
  });

  group('order defaults', () {
    test('usual shipping fee is the most common recent one', () {
      expect(usualShippingFee([]), 0);
      expect(
        usualShippingFee([
          _order(fee: 20000, at: DateTime(2026, 11, 10)),
          _order(fee: 30000, at: DateTime(2026, 11, 2)),
          _order(fee: 30000, at: DateTime(2026, 11, 3)),
          _order(fee: 0, at: DateTime(2026, 11, 4)),
          _order(
            fee: 50000,
            at: DateTime(2026, 11, 5),
            status: OrderStatus.cancelled,
          ),
        ]),
        30000,
      );
      // A tie goes to the latest fee.
      expect(
        usualShippingFee([
          _order(fee: 20000, at: DateTime(2026, 11, 8)),
          _order(fee: 25000, at: DateTime(2026, 11, 9)),
        ]),
        25000,
      );
    });

    test('last order matches name and phone, skipping cancelled', () {
      final orders = [
        _order(at: DateTime(2026, 10, 10), product: 'Cũ'),
        _order(at: DateTime(2026, 11, 3), product: 'Mới'),
        _order(
          at: DateTime(2026, 11, 5),
          product: 'Hủy',
          status: OrderStatus.cancelled,
        ),
        _order(name: 'Mai', at: DateTime(2026, 11, 9), product: 'Khác'),
      ];
      expect(lastOrderOf(orders, ' lan ', '090 123 4567')?.productName, 'Mới');
      expect(lastOrderOf(orders, 'Lan', '0909'), isNull);
      expect(lastOrderOf(orders, '', ''), isNull);
    });

    test('customer totals skip cancelled orders and repeat addresses', () {
      final orders = [
        _order(at: DateTime(2026, 11, 3)),
        _order(at: DateTime(2026, 11, 9)).copyWith(paid: 215000),
        _order(
          at: DateTime(2026, 11, 5),
          status: OrderStatus.cancelled,
        ).copyWith(address: '9 Đào Tấn'),
        _order(at: DateTime(2026, 11, 7)).copyWith(address: '5 Kim Mã'),
      ];
      final totals = customerTotals(orders);
      expect(totals.orderCount, 3);
      expect(totals.spent, 3 * 215000);
      expect(totals.owed, 2 * 215000);
      expect(totals.addresses, ['12 Hoa Mai', '5 Kim Mã']);
    });

    test('delivery time rounds up to the next half hour', () {
      expect(
        roundUpToHalfHour(DateTime(2026, 11, 21, 10, 7)),
        DateTime(2026, 11, 21, 10, 30),
      );
      expect(
        roundUpToHalfHour(DateTime(2026, 11, 21, 10, 30)),
        DateTime(2026, 11, 21, 10, 30),
      );
      expect(
        roundUpToHalfHour(DateTime(2026, 11, 21, 10, 31)),
        DateTime(2026, 11, 21, 11),
      );
      expect(
        roundUpToHalfHour(DateTime(2026, 11, 21, 23, 45)),
        DateTime(2026, 11, 22),
      );
    });
  });

  testWidgets('order again, evening slot and early review', (tester) async {
    final repository = _Repository([
      _order(fee: 30000, at: DateTime.now().subtract(const Duration(days: 20))),
    ]);
    await tester.pumpWidget(
      MaterialApp(home: CreateOrderScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Lan');
    await tester.enterText(find.byType(TextField).at(1), '0901234567');
    await tester.pumpAndSettle();
    expect(find.textContaining('Lần trước'), findsOneWidget);
    await tester.tap(find.text('Đặt lại'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(find.text('Bó hồng'), findsOneWidget);
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();

    // The evening slot sets 19:00 on the chosen day (tomorrow by default).
    await tester.tap(find.text('Tối 19h'));
    await tester.pumpAndSettle();
    expect(find.text('19:00'), findsOneWidget);

    // Address and fee came from last time, so the summary is one tap away.
    final early = find.text('Đủ thông tin · Xem lại đơn');
    await tester.scrollUntilVisible(
      early,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(early);
    await tester.pumpAndSettle();
    expect(find.text('Xác nhận tạo đơn'), findsOneWidget, reason: 'review');
    await tester.tap(find.text('Xác nhận tạo đơn'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    final order = repository.added.single;
    expect(order.productName, 'Bó hồng');
    expect(order.address, '12 Hoa Mai');
    expect(order.shippingFee, 30000);
    expect(order.deliveryAt.hour, 19);
    expect(order.paid, 0);
  });

  testWidgets('a new order starts with the usual shipping fee', (tester) async {
    final repository = _Repository([
      _order(fee: 25000, at: DateTime(2026, 11, 10)),
      _order(fee: 25000, at: DateTime(2026, 11, 2), name: 'Mai'),
    ]);
    await tester.pumpWidget(
      MaterialApp(home: CreateOrderScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Hoa');
    await tester.pumpAndSettle();
    // A new customer: nothing to order again.
    expect(find.textContaining('Lần trước'), findsNothing);
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    // Manual product name, then its price.
    await tester.enterText(find.byType(TextField).at(0), 'Giỏ hoa');
    await tester.enterText(find.byType(TextField).at(1), '300000');
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    final address = find.byType(TextField).first;
    await tester.enterText(address, '5 Lý Thường Kiệt');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    // The shipping fee field comes first on the payment step.
    final fee = tester.widget<TextField>(find.byType(TextField).first);
    expect(fee.controller!.text.replaceAll(RegExp('[^0-9]'), ''), '25000');
    // Separator depends on the default locale of the test run.
    expect(
      find.textContaining(RegExp(r'^Tổng: 325[.,]000 đ$')),
      findsOneWidget,
    );
  });
}
