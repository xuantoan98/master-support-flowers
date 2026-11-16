import 'dart:io';
import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CatalogImageStore {
  Future<String> save(XFile picked) async {
    final root = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(root.path, 'catalog_images'));
    await folder.create(recursive: true);
    final extension = p.extension(picked.path).toLowerCase();
    final safeExtension =
        {'.jpg', '.jpeg', '.png', '.webp', '.heic'}.contains(extension)
        ? extension
        : '.jpg';
    final filename =
        '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}$safeExtension';
    final target = File(p.join(folder.path, filename));
    await picked.saveTo(target.path);
    return target.path;
  }
}
