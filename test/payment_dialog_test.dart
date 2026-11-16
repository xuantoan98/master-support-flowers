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
  Future<void> addPayment(int orderId, int amount, {String note = ''}) async {
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
}
