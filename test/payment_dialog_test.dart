import 'package:flower_orders/flower/data/order_repository.dart';
import 'package:flower_orders/flower/domain/flower_order.dart';
import 'package:flower_orders/flower/domain/order_media.dart';
import 'package:flower_orders/flower/presentation/flower_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class FakePaymentRepository extends OrderRepository {
  int paid = 50000;

  @override
  Future<void> addPayment(
    int orderId,
    int amount, {
    String note = '',
    PaymentMethod? method,
  }) async {
    paid += amount;
  }

  @override
  Future<List<PaymentEntry>> paymentsForOrder(int orderId) async => [];

  @override
  Future<List<StatusEntry>> statusHistory(int orderId) async => [];

  @override
  Future<List<OrderChangeEntry>> orderChanges(int orderId) async => [];

  @override
  Future<List<OrderMedia>> mediaForOrder(int orderId) async => [];

  final statuses = <OrderStatus>[];

  @override
  Future<void> updateStatus(FlowerOrder order, OrderStatus status) async {
    statuses.add(status);
  }
}

void main() {
  setUpAll(() async => initializeDateFormatting('vi'));

  testWidgets(
    'refund closes dialog and updates detail without framework error',
    (tester) async {
      final repository = FakePaymentRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: OrderDetailScreen(
            order: FlowerOrder(
              id: 2,
              customerName: 'Lan',
              phone: '',
              productName: 'Bó hồng',
              price: 200000,
              shippingFee: 0,
              paid: 50000,
              deliveryAt: DateTime(2026, 11, 20),
              address: '12 Hoa Mai',
            ),
            repository: repository,
            onChanged: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Hoàn tiền'), 300);
      await tester.tap(find.text('Hoàn tiền'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '50000');
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(repository.paid, 0);
      expect(find.text('0 đ'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('status stepper advances one step and can cancel', (
    tester,
  ) async {
    final repository = FakePaymentRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: OrderDetailScreen(
          order: FlowerOrder(
            id: 3,
            customerName: 'Lan',
            phone: '',
            productName: 'Bó hồng',
            price: 200000,
            shippingFee: 0,
            paid: 0,
            deliveryAt: DateTime(2026, 11, 20),
            address: '12 Hoa Mai',
          ),
          repository: repository,
          onChanged: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Hủy đơn'), 200);
    await tester.ensureVisible(find.text('Chuyển sang: Đang làm'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Mới, đang ở bước này'), findsOneWidget);
    await tester.tap(find.text('Chuyển sang: Đang làm'));
    await tester.pumpAndSettle();
    expect(repository.statuses, [OrderStatus.making]);
    expect(find.bySemanticsLabel('Mới, đã xong'), findsOneWidget);
    expect(find.text('Chuyển sang: Chờ duyệt'), findsOneWidget);

    await tester.ensureVisible(find.text('Hủy đơn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy đơn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giữ đơn'));
    await tester.pumpAndSettle();
    expect(repository.statuses, [OrderStatus.making]);
  });
}
