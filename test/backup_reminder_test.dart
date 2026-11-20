import 'package:flower_orders/flower/data/order_repository.dart';
import 'package:flower_orders/flower/domain/flower_order.dart';
import 'package:flower_orders/flower/presentation/flower_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

class _BackupRepository extends OrderRepository {
  _BackupRepository({required int orderCount, this.backedUpAt})
    : items = [
        for (var i = 0; i < orderCount; i++)
          FlowerOrder(
            id: i + 1,
            customerName: 'Khách $i',
            phone: '',
            productName: 'Bó hồng',
            price: 200000,
            shippingFee: 0,
            paid: 200000,
            deliveryAt: DateTime.now().add(Duration(days: 2 + i)),
            address: '',
          ),
      ];

  final List<FlowerOrder> items;
  final DateTime? backedUpAt;
  bool dismissed = false;

  @override
  Future<bool> remindersEnabled() async => false;

  @override
  Future<List<FlowerOrder>> all() async => items;

  @override
  Future<DateTime?> lastBackupAt() async => backedUpAt;

  @override
  Future<bool> backupReminderDismissed() async => dismissed;

  @override
  Future<void> setBackupReminderDismissed() async => dismissed = true;
}

Future<void> pumpApp(WidgetTester tester, OrderRepository repository) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(FlowerApp(repository: repository));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async => initializeDateFormatting('vi'));

  testWidgets('no backup reminder before the shop has 10 orders', (
    tester,
  ) async {
    await pumpApp(tester, _BackupRepository(orderCount: 9));
    expect(find.text('Sao lưu dữ liệu tiệm'), findsNothing);
  });

  testWidgets('no backup reminder once a backup exists', (tester) async {
    await pumpApp(
      tester,
      _BackupRepository(orderCount: 12, backedUpAt: DateTime(2026, 11)),
    );
    expect(find.text('Sao lưu dữ liệu tiệm'), findsNothing);
  });

  testWidgets('reminder shows at 10 orders and "Để sau" hides it for good', (
    tester,
  ) async {
    final repository = _BackupRepository(orderCount: 10);
    await pumpApp(tester, repository);
    expect(find.text('Sao lưu dữ liệu tiệm'), findsOneWidget);
    expect(find.text('Sao lưu ngay'), findsOneWidget);

    await tester.tap(find.text('Để sau'));
    await tester.pumpAndSettle();
    expect(find.text('Sao lưu dữ liệu tiệm'), findsNothing);
    expect(repository.dismissed, isTrue);

    // Still hidden after the next reload.
    await pumpApp(tester, repository);
    expect(find.text('Sao lưu dữ liệu tiệm'), findsNothing);
  });
}
