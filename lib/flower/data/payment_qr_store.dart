import 'dart:io';
import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PaymentQrStore {
  PaymentQrStore({Future<Directory> Function()? documentsDirectory})
    : _documentsDirectory =
          documentsDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectory;

  Future<Directory> _folder() async {
    final root = await _documentsDirectory();
    return Directory(p.join(root.path, 'payment_qr'));
  }

  Future<String> save(XFile picked) async {
    final extension = p.extension(picked.path).toLowerCase();
    if (!{'.png', '.jpg', '.jpeg', '.webp'}.contains(extension)) {
      throw ArgumentError('Chỉ hỗ trợ ảnh PNG, JPG hoặc WebP');
    }
    final folder = await _folder();
    await folder.create(recursive: true);
    final filename =
        '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}$extension';
    final target = File(p.join(folder.path, filename));
    await picked.saveTo(target.path);
    return target.path;
  }

  Future<void> delete(String path) async {
    if (path.isEmpty) {
      return;
    }
    final folder = await _folder();
    if (!p.isWithin(folder.path, path)) {
      return;
    }
    final file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
