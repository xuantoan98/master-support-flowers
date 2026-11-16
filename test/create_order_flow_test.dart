import 'package:flower_orders/flower/data/order_repository.dart';
import 'package:flower_orders/flower/domain/catalog_product.dart';
import 'package:flower_orders/flower/domain/flower_order.dart';
import 'package:flower_orders/flower/presentation/app_toast.dart';
import 'package:flower_orders/flower/presentation/flower_app.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class FakeOrderRepository extends OrderRepository {
  final orders = <FlowerOrder>[];
  Map<String, dynamic>? draft;

  @override
  Future<List<FlowerOrder>> all() async => orders;

  @override
  Future<int> add(FlowerOrder order) async {
    orders.add(order);
    draft = null;
    return orders.length;
  }

  @override
  Future<List<CustomerSummary>> customers({String query = ''}) async => [];

  @override
  Future<Map<String, dynamic>?> loadDraft() async => draft;

  @override
  Future<void> saveDraft(Map<String, dynamic> value) async {
    draft = value;
  }

  @override
  Future<void> clearDraft() async {
    draft = null;
  }

  @override
  Future<List<CatalogProduct>> listProducts() async => const [
    CatalogProduct(id: 1, name: 'Bó hồng', price: 200000),
    CatalogProduct(id: 2, name: 'Bó cúc', price: 150000),
  ];
}

void main() {
  setUpAll(() async => initializeDateFormatting('vi'));

  testWidgets('create an order through all four steps', (tester) async {
    final repository = FakeOrderRepository();
    await tester.pumpWidget(FlowerApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tạo đơn'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Lan');
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Bó hồng');
    await tester.enterText(find.byType(TextField).at(1), '200000');
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '12 Hoa Mai');
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '30000');
    await tester.enterText(find.byType(TextField).at(1), '50000');
    await tester.tap(find.text('Lưu đơn'));
    await tester.pumpAndSettle();

    expect(repository.orders, hasLength(1));
    expect(repository.orders.single.customerName, 'Lan');
    expect(repository.orders.single.remaining, 180000);
  });

  testWidgets('adds multiple catalog products with quantities', (tester) async {
    final repository = FakeOrderRepository();
    await tester.pumpWidget(FlowerApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo đơn'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Lan');
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm từ mẫu hoa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bó hồng').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm từ mẫu hoa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bó cúc').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tăng số lượng Bó hồng'));
    await tester.pumpAndSettle();
    expect(find.text('Tiền sản phẩm: 550.000 đ'), findsOneWidget);
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '12 Hoa Mai');
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu đơn'));
    await tester.pumpAndSettle();
    expect(repository.orders.single.items, hasLength(2));
    expect(repository.orders.single.items.first.quantity, 2);
    expect(repository.orders.single.price, 550000);
  });

  testWidgets('calendar day is carried into the new order form', (
    tester,
  ) async {
    final repository = FakeOrderRepository();
    final today = DateUtils.dateOnly(DateTime.now());
    final day = today.add(const Duration(days: 3));
    await tester.pumpWidget(FlowerApp(repository: repository));
    await tester.pumpAndSettle();
    if (day.month != today.month) {
      await tester.tap(find.byIcon(Icons.chevron_right).first);
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('${day.day}').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('${day.day}').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo đơn'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Lan');
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Bó hồng');
    await tester.enterText(find.byType(TextField).at(1), '200000');
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(find.text(dayLabel(day)), findsOneWidget);
  });

  testWidgets('calendar day also wins when an old draft is restored', (
    tester,
  ) async {
    final repository = FakeOrderRepository();
    final today = DateUtils.dateOnly(DateTime.now());
    final day = today.add(const Duration(days: 3));
    repository.draft = {
      'name': 'Lan',
      'delivery': today.add(const Duration(days: 1)).toIso8601String(),
      'step': 2,
    };
    await tester.pumpWidget(FlowerApp(repository: repository));
    await tester.pumpAndSettle();
    if (day.month != today.month) {
      await tester.tap(find.byIcon(Icons.chevron_right).first);
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('${day.day}').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('${day.day}').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo đơn'));
    await tester.pumpAndSettle();
    expect(find.text(dayLabel(day)), findsOneWidget);
  });

  testWidgets('delivery selects date before showing time-only picker', (
    tester,
  ) async {
    final repository = FakeOrderRepository();
    await tester.pumpWidget(FlowerApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo đơn'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Lan');
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Bó hồng');
    await tester.enterText(find.byType(TextField).at(1), '200000');
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ngày giao *'));
    await tester.pumpAndSettle();
    expect(find.text('CHỌN NGÀY GIAO'), findsOneWidget);
    expect(find.byType(CupertinoDatePicker), findsNothing);
    await tester.tap(find.text('TIẾP THEO'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    expect(
      tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker)).mode,
      CupertinoDatePickerMode.time,
    );
  });

  testWidgets('required fields have a red star and errors use a toast', (
    tester,
  ) async {
    final repository = FakeOrderRepository();
    await tester.pumpWidget(FlowerApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo đơn'));
    await tester.pumpAndSettle();
    expect(find.text('Tên khách hàng *'), findsOneWidget);
    expect(find.text('Số điện thoại (không bắt buộc)'), findsOneWidget);
    final requiredText = tester.widget<Text>(
      find.descendant(
        of: find.byType(RequiredLabel).first,
        matching: find.byType(Text),
      ),
    );
    final star =
        (requiredText.textSpan! as TextSpan).children!.last as TextSpan;
    expect(star.style!.color, Colors.red);
    await tester.tap(find.text('Tiếp tục'));
    await tester.pump();
    expect(find.text('Vui lòng nhập tên khách hàng'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Vui lòng nhập tên khách hàng'), findsNothing);
  });

  testWidgets('restores an unfinished order form', (tester) async {
    final repository = FakeOrderRepository();
    await tester.pumpWidget(FlowerApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo đơn'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Khách thử');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo đơn'));
    await tester.pumpAndSettle();
    expect(find.text('Khách thử'), findsOneWidget);
    await tester.tap(find.byTooltip('Xóa bản nháp'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa').last);
    await tester.pumpAndSettle();
    expect(repository.draft, isNull);
    expect(find.text('Khách thử'), findsNothing);
  });

  testWidgets('restored draft cannot continue with a past delivery time', (
    tester,
  ) async {
    final repository = FakeOrderRepository();
    repository.draft = {
      'name': 'Lan',
      'product': 'Bó hồng',
      'price': '200000',
      'address': '12 Hoa Mai',
      'delivery': DateTime.now()
          .subtract(const Duration(minutes: 1))
          .toIso8601String(),
      'step': 2,
    };
    await tester.pumpWidget(FlowerApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đơn hàng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo đơn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    expect(
      find.text('Thời gian giao phải sau thời điểm hiện tại'),
      findsOneWidget,
    );
    expect(find.text('Bước 3/4'), findsOneWidget);
    expect(repository.orders, isEmpty);
    await tester.tap(find.text('Ngày giao *'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('save is disabled when delivery time expires in a draft', (
    tester,
  ) async {
    final repository = FakeOrderRepository();
    repository.draft = {
      'name': 'Lan',
      'product': 'Bó hồng',
      'price': '200000',
      'address': '12 Hoa Mai',
      'delivery': DateTime.now()
          .subtract(const Duration(minutes: 1))
          .toIso8601String(),
      'step': 3,
    };
    await tester.pumpWidget(FlowerApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đơn hàng'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo đơn'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn lại giờ giao'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Lưu đơn'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Lưu đơn'),
    );
    expect(button.onPressed, isNull);
    expect(repository.orders, isEmpty);
  });
}
