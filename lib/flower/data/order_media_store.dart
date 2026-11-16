import 'dart:io';
import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/order_media.dart';
import 'order_repository.dart';

class OrderMediaStore {
  OrderMediaStore(this.repository, {this.rootDirectory});

  final OrderRepository repository;
  final Directory? rootDirectory;

  Future<Directory> _root() async =>
      rootDirectory ?? getApplicationDocumentsDirectory();

  Future<File> fileFor(OrderMedia media) async {
    final root = await _root();
    return File(p.join(root.path, media.relativePath));
  }

  Future<void> save(int orderId, OrderMediaType type, XFile picked) async {
    final root = await _root();
    final folder = Directory(p.join(root.path, 'order_media', '$orderId'));
    await folder.create(recursive: true);
    final extension = p.extension(picked.path).toLowerCase();
    final safeExtension =
        {'.jpg', '.jpeg', '.png', '.webp', '.heic'}.contains(extension)
        ? extension
        : '.jpg';
    final filename =
        '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}$safeExtension';
    final relativePath = p.join('order_media', '$orderId', filename);
    final target = File(p.join(root.path, relativePath));
    await picked.saveTo(target.path);
    try {
      await repository.addMedia(orderId, type, relativePath);
    } catch (_) {
      if (target.existsSync()) {
        await target.delete();
      }
      rethrow;
    }
  }

  Future<void> delete(OrderMedia media) async {
    await repository.deleteMedia(media.id);
    final file = await fileFor(media);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
