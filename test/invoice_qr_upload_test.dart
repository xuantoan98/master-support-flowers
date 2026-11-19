import 'dart:convert';
import 'dart:io';

import 'package:flower_orders/flower/data/order_repository.dart';
import 'package:flower_orders/flower/data/payment_qr_store.dart';
import 'package:flower_orders/flower/domain/flower_order.dart';
import 'package:flower_orders/flower/domain/shop_profile.dart';
import 'package:flower_orders/flower/presentation/invoice_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('vi');
  });

  const shop = ShopProfile(
    name: 'Hoa Mai',
    bankName: 'Ngân hàng',
    accountNumber: '0011012345678',
    accountHolder: 'NGUYEN VAN A',
  );

  test('shop profile permits QR image without bank code or account text', () {
    expect(shop.validate(), isNull);
    expect(const ShopProfile().validate(), isNull);
    expect(const ShopProfile(name: '').validate(), isNotNull);
  });

  test(
    'uploaded QR is copied out of picker cache and can be removed',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'flower_qr_store_',
      );
      final source = File('${directory.path}/picked.png');
      await source.writeAsBytes([137, 80, 78, 71]);
      final store = PaymentQrStore(documentsDirectory: () async => directory);
      try {
        final savedPath = await store.save(XFile(source.path));
        await source.delete();
        expect(File(savedPath).existsSync(), isTrue);
        await store.delete(savedPath);
        expect(File(savedPath).existsSync(), isFalse);
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test('migration from v10 adds durable shop profile', () async {
    final directory = await Directory.systemTemp.createTemp('flower_shop_');
    final databasePath = '${directory.path}/orders.db';
    final old = await openDatabase(
      databasePath,
      version: 10,
      onCreate: (db, _) async {
        await db.execute('CREATE TABLE old_marker (value TEXT NOT NULL)');
        await db.insert('old_marker', {'value': 'kept'});
      },
    );
    await old.close();

    final repository = OrderRepository();
    try {
      await repository.open(databasePath: databasePath);
      expect((await repository.loadShopProfile()).name, 'Tiệm Hoa');
      await repository.saveShopProfile(shop);
      await repository.close();
      await repository.open(databasePath: databasePath);
      expect(
        (await repository.loadShopProfile()).accountNumber,
        shop.accountNumber,
      );
      expect((await repository.db.query('old_marker')).single['value'], 'kept');
    } finally {
      await repository.close();
      await directory.delete(recursive: true);
    }
  });

  test(
    'migration from v11 preserves bank details and adds image path',
    () async {
      final directory = await Directory.systemTemp.createTemp('flower_qr_');
      final databasePath = '${directory.path}/orders.db';
      final old = await openDatabase(
        databasePath,
        version: 11,
        onCreate: (db, _) async {
          await db.execute('''
        CREATE TABLE shop_profile (
          id INTEGER PRIMARY KEY CHECK(id = 1),
          name TEXT NOT NULL,
          phone TEXT NOT NULL,
          address TEXT NOT NULL,
          bank_bin TEXT NOT NULL,
          bank_name TEXT NOT NULL,
          account_number TEXT NOT NULL,
          account_holder TEXT NOT NULL
        )
      ''');
          await db.insert(
            'shop_profile',
            {'id': 1, ...shop.toMap()}..remove('qr_image_path'),
          );
        },
      );
      await old.close();
      final repository = OrderRepository();
      try {
        await repository.open(databasePath: databasePath);
        final migrated = await repository.loadShopProfile();
        expect(migrated.accountNumber, shop.accountNumber);
        expect(migrated.qrImagePath, isEmpty);
        await repository.saveShopProfile(
          const ShopProfile(name: 'Hoa Mai', qrImagePath: '/local/qr.png'),
        );
        await repository.close();
        await repository.open(databasePath: databasePath);
        expect(
          (await repository.loadShopProfile()).qrImagePath,
          '/local/qr.png',
        );
      } finally {
        await repository.close();
        await directory.delete(recursive: true);
      }
    },
  );

  testWidgets('invoice shows uploaded QR but omits internal order note', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync('flower_qr_image_');
    final imageFile = File('${directory.path}/qr.png');
    imageFile.writeAsBytesSync(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: InvoiceScreen(
          repository: _InvoiceRepository(
            ShopProfile(name: shop.name, qrImagePath: imageFile.path),
          ),
          order: FlowerOrder(
            id: 1,
            customerName: 'Mai',
            phone: '0901234567',
            productName: 'Bó hoa',
            price: 200000,
            shippingFee: 0,
            paid: 20000,
            deliveryAt: DateTime(2026, 11, 20, 9),
            address: '12 Hoa Mai',
            note: 'Ghi chú nội bộ: ưu tiên khách VIP',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Ghi chú nội bộ'), findsNothing);
    expect(find.text('Ảnh QR ngân hàng do shop cung cấp'), findsOneWidget);
    expect(find.text('180.000 đ'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
    directory.deleteSync(recursive: true);
  });
}

class _InvoiceRepository extends OrderRepository {
  _InvoiceRepository(this.profile);

  final ShopProfile profile;

  @override
  Future<ShopProfile> loadShopProfile() async => profile;
}
