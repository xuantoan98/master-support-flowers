import 'dart:io';

import 'package:flower_orders/flower/data/backup_service.dart';
import 'package:flower_orders/flower/data/order_repository.dart';
import 'package:flower_orders/flower/domain/flower_order.dart';
import 'package:flower_orders/flower/domain/order_status_flow.dart';
import 'package:flower_orders/flower/domain/vietqr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

FlowerOrder _order({
  FulfillmentType fulfillment = FulfillmentType.delivery,
  OrderStatus status = OrderStatus.newOrder,
  String address = '12 Hoa Mai',
  int price = 300000,
  int shippingFee = 0,
  int discount = 0,
  int surcharge = 0,
  int paid = 0,
  DateTime? deliveryAt,
}) => FlowerOrder(
  customerName: 'Lan',
  phone: '0901234567',
  productName: 'Bó hồng',
  price: price,
  shippingFee: shippingFee,
  paid: paid,
  deliveryAt: deliveryAt ?? DateTime(2026, 11, 20, 9),
  address: address,
  fulfillment: fulfillment,
  status: status,
  discount: discount,
  surcharge: surcharge,
);

void main() {
  test('half deposit rounds up to the next thousand', () {
    expect(depositHalf(180000), 90000);
    expect(depositHalf(251000), 126000);
    expect(depositHalf(1000), 1000);
    expect(depositHalf(0), 0);
  });

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('order money', () {
    test('discount and surcharge change the total', () {
      final order = _order(
        shippingFee: 30000,
        discount: 20000,
        surcharge: 50000,
      );
      expect(order.total, 360000);
      expect(order.validate(), isNull);
    });

    test('discount cannot exceed goods plus surcharge', () {
      expect(_order(discount: 300001).validate(), isNotNull);
      expect(_order(discount: 350000, surcharge: 50000).validate(), isNull);
      expect(_order(discount: -1).validate(), isNotNull);
    });

    test('only delivery orders need an address', () {
      expect(_order(address: '').validate(), isNotNull);
      expect(
        _order(address: '', fulfillment: FulfillmentType.pickup).validate(),
        isNull,
      );
      expect(
        _order(address: '', fulfillment: FulfillmentType.counter).validate(),
        isNull,
      );
    });

    test('gift orders contact the recipient', () {
      final gift = FlowerOrder(
        customerName: 'Lan',
        phone: '0901',
        productName: 'Bó hồng',
        price: 1,
        shippingFee: 0,
        paid: 0,
        deliveryAt: DateTime(2026),
        address: 'x',
        recipientName: 'Mai',
        recipientPhone: '0902',
      );
      expect(gift.isGift, isTrue);
      expect(gift.contactName, 'Mai');
      expect(gift.contactPhone, '0902');
    });

    test('hand-over orders read "Hoàn tất" instead of "Đã giao"', () {
      expect(_order(status: OrderStatus.delivered).statusLabel, 'Đã giao');
      expect(
        _order(
          status: OrderStatus.delivered,
          fulfillment: FulfillmentType.pickup,
        ).statusLabel,
        'Hoàn tất',
      );
    });
  });

  group('status flow', () {
    test('delivery orders step through approval unless skipped', () {
      final making = _order(status: OrderStatus.making);
      expect(nextStatusFor(making), OrderStatus.awaitingApproval);
      expect(nextStatusFor(making, skipApproval: true), OrderStatus.delivering);
      expect(previousStatusFor(making), OrderStatus.newOrder);
    });

    test('an order already waiting for approval keeps that step', () {
      final waiting = _order(status: OrderStatus.awaitingApproval);
      expect(
        nextStatusFor(waiting, skipApproval: true),
        OrderStatus.delivering,
      );
      expect(
        previousStatusFor(waiting, skipApproval: true),
        OrderStatus.making,
      );
    });

    test('pickup orders never go out for delivery', () {
      final making = _order(
        status: OrderStatus.making,
        fulfillment: FulfillmentType.pickup,
      );
      expect(nextStatusFor(making, skipApproval: true), OrderStatus.delivered);
      expect(
        canChangeStatus(
          FulfillmentType.pickup,
          OrderStatus.making,
          OrderStatus.delivering,
        ),
        isFalse,
      );
    });

    test('steps can be skipped and undone, cancellation is final', () {
      const d = FulfillmentType.delivery;
      expect(
        canChangeStatus(d, OrderStatus.newOrder, OrderStatus.delivered),
        isTrue,
      );
      expect(
        canChangeStatus(d, OrderStatus.delivered, OrderStatus.delivering),
        isTrue,
      );
      expect(
        canChangeStatus(d, OrderStatus.delivered, OrderStatus.cancelled),
        isFalse,
      );
      expect(
        canChangeStatus(d, OrderStatus.cancelled, OrderStatus.newOrder),
        isFalse,
      );
      expect(
        canChangeStatus(d, OrderStatus.making, OrderStatus.making),
        isFalse,
      );
    });

    test('counter sales have no further steps', () {
      final sale = _order(
        status: OrderStatus.delivered,
        fulfillment: FulfillmentType.counter,
      );
      expect(nextStatusFor(sale), isNull);
      expect(previousStatusFor(sale), isNull);
    });
  });

  group('VietQR', () {
    test('CRC matches the CCITT-FALSE check value', () {
      expect(crc16Ccitt('123456789'), 0x29B1);
    });

    test('payload carries bank, account, amount and note', () {
      final payload = buildVietQrPayload(
        bankBin: '970436',
        accountNumber: '0123 456 789',
        amount: 250000,
        note: 'DH12',
      )!;
      expect(payload, startsWith('000201010212'));
      expect(payload, contains('0010A000000727'));
      expect(payload, contains('0006970436'));
      expect(payload, contains('01100123456789'));
      expect(payload, contains('5406250000'));
      expect(payload, contains('62080804DH12'));
      final body = payload.substring(0, payload.length - 4);
      expect(
        payload.substring(payload.length - 4),
        crc16Ccitt(body).toRadixString(16).toUpperCase().padLeft(4, '0'),
      );
    });

    test('without an amount the QR is static', () {
      final payload = buildVietQrPayload(
        bankBin: '970436',
        accountNumber: '0123456789',
      )!;
      expect(payload, startsWith('000201010211'));
      // Currency (53) is followed directly by country (58): no amount (54).
      expect(payload, contains('53037045802VN'));
    });

    test('missing bank details give no QR', () {
      expect(buildVietQrPayload(bankBin: '', accountNumber: '0123'), isNull);
      expect(buildVietQrPayload(bankBin: '970436', accountNumber: ''), isNull);
    });

    test('notes are made safe for banks', () {
      expect(vietQrSafeText('Đơn hoa Hồng #12!'), 'Don hoa Hong 12');
      expect(vietQrSafeText('a' * 40).length, 25);
    });
  });

  group('repository v14', () {
    late Directory directory;
    late OrderRepository repository;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('flower_retail_');
      repository = OrderRepository(now: () => DateTime(2026, 11, 16, 10));
      await repository.open(databasePath: p.join(directory.path, 'orders.db'));
    });

    tearDown(() async {
      await repository.close();
      await directory.delete(recursive: true);
    });

    test('gift, hand-over and discount fields survive a round trip', () async {
      final id = await repository.add(
        FlowerOrder(
          customerName: 'Lan',
          phone: '0901',
          productName: 'Giỏ hoa',
          price: 500000,
          shippingFee: 0,
          paid: 0,
          deliveryAt: DateTime(2026, 11, 20, 9),
          address: '',
          fulfillment: FulfillmentType.pickup,
          recipientName: 'Mai',
          recipientPhone: '0902',
          cardMessage: 'Chúc mừng sinh nhật',
          anonymousSender: true,
          discount: 50000,
          surcharge: 20000,
        ),
      );
      final stored = (await repository.getById(id))!;
      expect(stored.fulfillment, FulfillmentType.pickup);
      expect(stored.recipientName, 'Mai');
      expect(stored.recipientPhone, '0902');
      expect(stored.cardMessage, 'Chúc mừng sinh nhật');
      expect(stored.anonymousSender, isTrue);
      expect(stored.total, 470000);
    });

    test('counter sales are saved now, paid in full and finished', () async {
      final id = await repository.add(
        _order(
          fulfillment: FulfillmentType.counter,
          status: OrderStatus.delivered,
          address: '',
          paid: 300000,
          // In the past relative to the repository clock.
          deliveryAt: DateTime(2026, 11, 16, 9),
        ),
        paymentMethod: PaymentMethod.cash,
      );
      final payments = await repository.paymentsForOrder(id);
      expect(payments.single.method, PaymentMethod.cash);
      expect(payments.single.note, 'Thanh toán đủ');
      expect((await repository.getById(id))!.remaining, 0);
    });

    test('payments respect discounts and record the method', () async {
      final id = await repository.add(_order(discount: 100000));
      await expectLater(repository.addPayment(id, 200001), throwsArgumentError);
      await repository.addPayment(id, 200000, method: PaymentMethod.transfer);
      final payment = (await repository.paymentsForOrder(id)).single;
      expect(payment.method, PaymentMethod.transfer);
    });

    test('pickup orders cannot be sent out for delivery', () async {
      final id = await repository.add(
        _order(fulfillment: FulfillmentType.pickup, address: ''),
      );
      final order = (await repository.getById(id))!;
      await expectLater(
        repository.updateStatus(order, OrderStatus.delivering),
        throwsArgumentError,
      );
      await repository.updateStatus(order, OrderStatus.delivered);
      expect((await repository.getById(id))!.statusLabel, 'Hoàn tất');
    });

    test('skip approval setting is stored', () async {
      expect(await repository.skipApproval(), isFalse);
      await repository.setSkipApproval(true);
      expect(await repository.skipApproval(), isTrue);
    });
  });

  test('schema v13 gains the retail columns without losing orders', () async {
    final directory = await Directory.systemTemp.createTemp('flower_v13_');
    final path = p.join(directory.path, 'orders.db');
    final oldDb = await openDatabase(
      path,
      version: 13,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT, customer_name TEXT NOT NULL,
            phone TEXT NOT NULL, product_name TEXT NOT NULL,
            price INTEGER NOT NULL, shipping_fee INTEGER NOT NULL,
            paid INTEGER NOT NULL, delivery_at TEXT NOT NULL,
            address TEXT NOT NULL, note TEXT NOT NULL, status INTEGER NOT NULL,
            recipe_json TEXT NOT NULL DEFAULT '[]',
            items_json TEXT NOT NULL DEFAULT '[]', created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE payments (
            id INTEGER PRIMARY KEY AUTOINCREMENT, order_id INTEGER NOT NULL,
            amount INTEGER NOT NULL, occurred_at TEXT NOT NULL,
            note TEXT NOT NULL DEFAULT ''
          )
        ''');
        await db.insert('orders', {
          'id': 3,
          'customer_name': 'Lan',
          'phone': '',
          'product_name': 'Bó hồng',
          'price': 200000,
          'shipping_fee': 20000,
          'paid': 0,
          'delivery_at': DateTime(2026, 11, 20).toIso8601String(),
          'address': '12 Hoa Mai',
          'note': '',
          'status': 0,
          'created_at': DateTime(2026, 11, 16).toIso8601String(),
        });
        await db.insert('payments', {
          'order_id': 3,
          'amount': 50000,
          'occurred_at': DateTime(2026, 11, 16).toIso8601String(),
          'note': 'Tiền cọc',
        });
      },
    );
    await oldDb.close();

    final repository = OrderRepository();
    await repository.open(databasePath: path);
    final order = (await repository.all()).single;
    expect(order.fulfillment, FulfillmentType.delivery);
    expect(order.discount, 0);
    expect(order.total, 220000);
    expect(order.remaining, 170000);
    expect((await repository.paymentsForOrder(3)).single.method, isNull);
    await repository.close();
    await directory.delete(recursive: true);
  });

  test('backup restores orders and photos, replacing newer data', () async {
    final root = await Directory.systemTemp.createTemp('flower_backup_');
    final documents = Directory(p.join(root.path, 'documents'))..createSync();
    final temporary = Directory(p.join(root.path, 'tmp'))..createSync();
    final dbPath = p.join(root.path, 'db', 'orders.db');
    Directory(p.dirname(dbPath)).createSync();

    final repository = OrderRepository(now: () => DateTime(2026, 11, 16));
    await repository.open(databasePath: dbPath);
    final keptId = await repository.add(_order());
    final photo =
        File(p.join(documents.path, 'order_media', '$keptId', 'a.jpg'))
          ..createSync(recursive: true)
          ..writeAsStringSync('photo');
    final qr = File(p.join(documents.path, 'payment_qr', 'qr.png'))
      ..createSync(recursive: true)
      ..writeAsStringSync('qr');
    await repository.db.insert('shop_profile', {
      'id': 1,
      'name': 'Tiệm',
      'phone': '',
      'address': '',
      'bank_bin': '',
      'bank_name': '',
      'account_number': '',
      'account_holder': '',
      'qr_image_path': qr.path,
    });

    final service = BackupService(
      repository,
      documentsDirectory: () async => documents,
      temporaryDirectory: () async => temporary,
      now: () => DateTime(2026, 11, 20, 15, 30),
    );
    final backup = await service.createBackup();
    expect(p.basename(backup.path), 'TiemHoa_saoluu_20261120_1530.zip');
    final info = await service.inspect(backup);
    expect(info.orderCount, 1);
    expect(info.fileCount, 2);

    // Changes after the backup are replaced by the restore.
    await repository.add(_order());
    photo.deleteSync();
    File(p.join(documents.path, 'order_media', '99', 'new.jpg'))
      ..createSync(recursive: true)
      ..writeAsStringSync('new');

    // Restore on "another phone" whose documents folder differs.
    final otherDocuments = Directory(p.join(root.path, 'other_documents'))
      ..createSync();
    final otherService = BackupService(
      repository,
      documentsDirectory: () async => otherDocuments,
      temporaryDirectory: () async => temporary,
    );
    await otherService.restore(backup);

    final orders = await repository.all();
    expect(orders.map((o) => o.id), [keptId]);
    expect(
      File(
        p.join(otherDocuments.path, 'order_media', '$keptId', 'a.jpg'),
      ).readAsStringSync(),
      'photo',
    );
    final profile = await repository.loadShopProfile();
    expect(
      profile.qrImagePath,
      p.join(otherDocuments.path, 'payment_qr', 'qr.png'),
    );
    expect(File(profile.qrImagePath).existsSync(), isTrue);
    expect(
      File(
        p.join(p.dirname(dbPath), 'flower_orders.before_restore.db'),
      ).existsSync(),
      isTrue,
    );

    await expectLater(
      otherService.restore(qr),
      throwsA(isA<BackupException>()),
    );
    expect(await repository.all(), hasLength(1));

    await repository.close();
    await root.delete(recursive: true);
  });
}
