import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'order_repository.dart';

/// Folders under the app's documents directory that hold the shop's photos.
const backupMediaFolders = ['order_media', 'catalog_images', 'payment_qr'];

const _manifestName = 'manifest.json';
const _databaseName = 'flower_orders.db';
const _format = 'tiem-hoa-backup';

/// What a backup file holds, read before the shop agrees to restore it.
class BackupInfo {
  const BackupInfo({
    required this.createdAt,
    required this.schemaVersion,
    required this.orderCount,
    required this.fileCount,
  });

  final DateTime createdAt;
  final int schemaVersion;
  final int orderCount;
  final int fileCount;
}

/// Thrown with a message the shop can read.
class BackupException implements Exception {
  const BackupException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Writes the whole shop (orders, customers, catalog, settings and photos)
/// into one zip file and restores it on this or another phone.
class BackupService {
  BackupService(
    this.repository, {
    Future<Directory> Function()? documentsDirectory,
    Future<Directory> Function()? temporaryDirectory,
    DateTime Function()? now,
  }) : _documents = documentsDirectory ?? getApplicationDocumentsDirectory,
       _temporary = temporaryDirectory ?? getTemporaryDirectory,
       _now = now ?? DateTime.now;

  final OrderRepository repository;
  final Future<Directory> Function() _documents;
  final Future<Directory> Function() _temporary;
  final DateTime Function() _now;

  /// `TiemHoa_saoluu_20261120_1530.zip`
  String fileNameFor(DateTime at) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'TiemHoa_saoluu_${at.year}${two(at.month)}${two(at.day)}_'
        '${two(at.hour)}${two(at.minute)}.zip';
  }

  Future<File> createBackup() async {
    final dbPath = repository.databasePath;
    if (dbPath == null) {
      throw const BackupException('Dữ liệu chưa được mở');
    }
    // Move pending WAL pages into the main file so the copy is complete.
    try {
      await repository.db.rawQuery('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (_) {
      // Not in WAL mode: the file is already complete.
    }
    final orderCount =
        Sqflite.firstIntValue(
          await repository.db.rawQuery('SELECT COUNT(*) FROM orders'),
        ) ??
        0;
    final documents = await _documents();
    final archive = Archive()
      ..addFile(
        ArchiveFile.bytes(_databaseName, await File(dbPath).readAsBytes()),
      );
    var fileCount = 0;
    for (final folder in backupMediaFolders) {
      final directory = Directory(p.join(documents.path, folder));
      if (!directory.existsSync()) {
        continue;
      }
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          final relative = p
              .relative(entity.path, from: documents.path)
              .replaceAll(r'\', '/');
          archive.addFile(
            ArchiveFile.bytes('files/$relative', await entity.readAsBytes()),
          );
          fileCount++;
        }
      }
    }
    final createdAt = _now();
    final manifest = utf8.encode(
      jsonEncode({
        'format': _format,
        'version': 1,
        'schemaVersion': OrderRepository.schemaVersion,
        'createdAt': createdAt.toIso8601String(),
        'documentsRoot': documents.path,
        'orderCount': orderCount,
        'fileCount': fileCount,
      }),
    );
    archive.addFile(ArchiveFile.bytes(_manifestName, manifest));
    final temporary = await _temporary();
    final target = File(p.join(temporary.path, fileNameFor(createdAt)));
    await target.writeAsBytes(ZipEncoder().encodeBytes(archive), flush: true);
    return target;
  }

  Future<BackupInfo> inspect(File file) async {
    final (_, manifest) = await _read(file);
    return _info(manifest);
  }

  /// Replaces all current data with [file]. The current database is kept as
  /// `flower_orders.before_restore.db` next to it in case the shop changes
  /// its mind.
  Future<BackupInfo> restore(File file) async {
    final (archive, manifest) = await _read(file);
    final info = _info(manifest);
    final dbPath = repository.databasePath;
    if (dbPath == null) {
      throw const BackupException('Dữ liệu chưa được mở');
    }
    final databaseEntry = archive.findFile(_databaseName);
    if (databaseEntry == null) {
      throw const BackupException('File sao lưu thiếu dữ liệu đơn hàng');
    }
    final documents = await _documents();

    // 1. Unpack everything next to the live data first: a broken file must
    //    not leave the shop with half of its data.
    final staging = Directory(p.join(documents.path, '.restore_staging'));
    if (staging.existsSync()) {
      await staging.delete(recursive: true);
    }
    await staging.create(recursive: true);
    final stagedDb = File('$dbPath.restoring');
    try {
      await stagedDb.writeAsBytes(databaseEntry.content, flush: true);
      for (final entry in archive.files) {
        if (!entry.isFile || !entry.name.startsWith('files/')) {
          continue;
        }
        final relative = entry.name.substring('files/'.length);
        final target = p.normalize(p.join(staging.path, relative));
        // Never write outside the known photo folders.
        final allowed = backupMediaFolders.any(
          (folder) => p.isWithin(p.join(staging.path, folder), target),
        );
        if (!allowed) {
          continue;
        }
        final output = File(target);
        await output.parent.create(recursive: true);
        await output.writeAsBytes(entry.content, flush: true);
      }
    } catch (_) {
      await staging.delete(recursive: true);
      if (stagedDb.existsSync()) {
        await stagedDb.delete();
      }
      throw const BackupException('Không giải nén được file sao lưu');
    }

    // 2. Swap the staged data in.
    await repository.close();
    try {
      final current = File(dbPath);
      if (current.existsSync()) {
        await current.copy(
          p.join(p.dirname(dbPath), 'flower_orders.before_restore.db'),
        );
      }
      for (final suffix in ['-wal', '-shm', '-journal']) {
        final sidecar = File('$dbPath$suffix');
        if (sidecar.existsSync()) {
          await sidecar.delete();
        }
      }
      await stagedDb.rename(dbPath);
      for (final folder in backupMediaFolders) {
        final live = Directory(p.join(documents.path, folder));
        if (live.existsSync()) {
          await live.delete(recursive: true);
        }
        final staged = Directory(p.join(staging.path, folder));
        if (staged.existsSync()) {
          await staged.rename(live.path);
        }
      }
    } finally {
      if (staging.existsSync()) {
        await staging.delete(recursive: true);
      }
      await repository.open(databasePath: dbPath);
    }

    // Catalog and QR photos are stored with absolute paths, which differ
    // between phones and reinstalls.
    final oldRoot = manifest['documentsRoot'] as String? ?? '';
    if (oldRoot.isNotEmpty && oldRoot != documents.path) {
      await _rebasePaths(oldRoot, documents.path);
    }
    return info;
  }

  Future<void> _rebasePaths(String oldRoot, String newRoot) async {
    final db = repository.db;
    for (final (table, column) in [
      ('products', 'image_path'),
      ('shop_profile', 'qr_image_path'),
    ]) {
      await db.rawUpdate(
        'UPDATE $table SET $column = ? || substr($column, ?) '
        'WHERE substr($column, 1, ?) = ?',
        [newRoot, oldRoot.length + 1, oldRoot.length, oldRoot],
      );
    }
  }

  Future<(Archive, Map<String, dynamic>)> _read(File file) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(await file.readAsBytes());
    } catch (_) {
      throw const BackupException('File này không phải bản sao lưu Sổ Hoa');
    }
    final manifestEntry = archive.findFile(_manifestName);
    if (manifestEntry == null) {
      throw const BackupException('File này không phải bản sao lưu Sổ Hoa');
    }
    final Map<String, dynamic> manifest;
    try {
      manifest =
          jsonDecode(utf8.decode(manifestEntry.content))
              as Map<String, dynamic>;
    } catch (_) {
      throw const BackupException('File sao lưu bị hỏng');
    }
    if (manifest['format'] != _format) {
      throw const BackupException('File này không phải bản sao lưu Sổ Hoa');
    }
    final schema = manifest['schemaVersion'] as int? ?? 0;
    if (schema > OrderRepository.schemaVersion) {
      throw const BackupException(
        'Bản sao lưu từ phiên bản app mới hơn. Hãy cập nhật app trước.',
      );
    }
    return (archive, manifest);
  }

  BackupInfo _info(Map<String, dynamic> manifest) => BackupInfo(
    createdAt:
        DateTime.tryParse(manifest['createdAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
    schemaVersion: manifest['schemaVersion'] as int? ?? 0,
    orderCount: manifest['orderCount'] as int? ?? 0,
    fileCount: manifest['fileCount'] as int? ?? 0,
  );
}
