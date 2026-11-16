import 'dart:io';

import 'package:flower_orders/flower/data/order_media_store.dart';
import 'package:flower_orders/flower/data/order_repository.dart';
import 'package:flower_orders/flower/domain/flower_order.dart';
import 'package:flower_orders/flower/domain/order_media.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('saved order image survives reopen and deletes with its file', () async {
    final directory = await Directory.systemTemp.createTemp('flower_media_');
    final path = '${directory.path}/orders.db';
    final source = File('${directory.path}/source.jpg');
    await source.writeAsBytes([0xff, 0xd8, 0xff, 0xd9]);
    final repository = OrderRepository(now: () => DateTime(2026, 11, 16));
    await repository.open(databasePath: path);
    final id = await repository.add(
      FlowerOrder(
        customerName: 'Lan',
        phone: '',
        productName: 'Bó hồng',
        price: 200000,
        shippingFee: 0,
        paid: 0,
        deliveryAt: DateTime(2026, 11, 20),
        address: '12 Hoa Mai',
      ),
    );
    final store = OrderMediaStore(repository, rootDirectory: directory);
    await store.save(id, OrderMediaType.finished, XFile(source.path));
    await repository.close();

    final reopened = OrderRepository();
    await reopened.open(databasePath: path);
    try {
      final media = (await reopened.mediaForOrder(id)).single;
      expect(media.type, OrderMediaType.finished);
      final reopenedStore = OrderMediaStore(reopened, rootDirectory: directory);
      expect((await reopenedStore.fileFor(media)).readAsBytesSync(), [
        0xff,
        0xd8,
        0xff,
        0xd9,
      ]);
      await reopenedStore.delete(media);
      expect(await reopened.mediaForOrder(id), isEmpty);
      expect((await reopenedStore.fileFor(media)).existsSync(), isFalse);
    } finally {
      await reopened.close();
      await directory.delete(recursive: true);
    }
  });
}
