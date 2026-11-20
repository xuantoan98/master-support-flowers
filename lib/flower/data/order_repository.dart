import 'dart:convert';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/business_stats.dart';
import '../domain/catalog_placeholders.dart';
import '../domain/catalog_product.dart';
import '../domain/flower_order.dart';
import '../domain/order_item.dart';
import '../domain/order_media.dart';
import '../domain/order_status_flow.dart';
import '../domain/shop_profile.dart';
import '../domain/shopping_list.dart';

const _sampleImageIndex = <String, int>{
  'hong_do': 5,
  'hong_pastel': 0,
  'ly_trang': 1,
  'cuc_vang': 2,
  'cat_tuong': 3,
  'dong_tien': 4,
  'huong_duong': 2,
  'mix_hong_ly': 5,
  'mix_pastel': 0,
  'mix_ruc_ro': 4,
};

class OrderRepository {
  OrderRepository({Random? random, DateTime Function()? now})
    : _random = random ?? Random(),
      _now = now ?? DateTime.now;

  final Random _random;
  final DateTime Function() _now;
  Database? _db;
  String? _path;

  /// Schema version written by this build; backups from newer builds are
  /// refused on restore.
  static const schemaVersion = 14;

  /// File of the open database, used by backup and restore.
  String? get databasePath => _path;

  Future<void> open({String? databasePath}) async {
    final path =
        databasePath ?? p.join(await getDatabasesPath(), 'flower_orders.db');
    _path = path;
    _db = await openDatabase(
      path,
      version: schemaVersion,
      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE customers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          phone TEXT NOT NULL DEFAULT '',
          UNIQUE(name, phone)
        )
      ''');
        await db.execute('''
        CREATE TABLE orders (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_name TEXT NOT NULL,
          phone TEXT NOT NULL,
          product_name TEXT NOT NULL,
          price INTEGER NOT NULL,
          shipping_fee INTEGER NOT NULL,
          paid INTEGER NOT NULL,
          delivery_at TEXT NOT NULL,
          address TEXT NOT NULL,
          note TEXT NOT NULL,
          status INTEGER NOT NULL,
          recipe_json TEXT NOT NULL DEFAULT '[]',
          items_json TEXT NOT NULL DEFAULT '[]',
          created_at TEXT NOT NULL,
          fulfillment TEXT NOT NULL DEFAULT 'delivery',
          recipient_name TEXT NOT NULL DEFAULT '',
          recipient_phone TEXT NOT NULL DEFAULT '',
          card_message TEXT NOT NULL DEFAULT '',
          anonymous_sender INTEGER NOT NULL DEFAULT 0,
          discount INTEGER NOT NULL DEFAULT 0,
          surcharge INTEGER NOT NULL DEFAULT 0
        )
      ''');
        await db.execute(
          'CREATE INDEX orders_delivery_idx ON orders(delivery_at)',
        );
        await db.execute('CREATE INDEX orders_status_idx ON orders(status)');
        await db.execute('''
        CREATE TABLE status_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          order_id INTEGER NOT NULL REFERENCES orders(id),
          status INTEGER NOT NULL,
          changed_at TEXT NOT NULL
        )
      ''');
        await _createPaymentsTable(db);
        await _createDraftTable(db);
        await _createCatalogTables(db);
        await _seedCatalog(db);
        await _createMediaTable(db);
        await _createShoppingTable(db);
        await _createOrderChangesTable(db);
        await _createShopProfileTable(db);
        await _createSettingsTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createPaymentsTable(db);
          await db.execute('''
            INSERT INTO payments(order_id, amount, occurred_at, note)
            SELECT id, paid, created_at, 'Tiền cọc từ dữ liệu cũ'
            FROM orders
            WHERE paid > 0
              AND NOT EXISTS (
                SELECT 1 FROM payments WHERE payments.order_id = orders.id
              )
          ''');
        }
        if (oldVersion < 3) {
          await _createDraftTable(db);
        }
        if (oldVersion < 4) {
          final columns = await db.rawQuery('PRAGMA table_info(orders)');
          if (!columns.any((column) => column['name'] == 'recipe_json')) {
            await db.execute(
              "ALTER TABLE orders ADD COLUMN recipe_json TEXT NOT NULL DEFAULT '[]'",
            );
          }
          await _createCatalogTables(db);
        }
        if (oldVersion < 5) {
          await _createMediaTable(db);
        }
        if (oldVersion < 6) {
          await _createShoppingTable(db);
        }
        if (oldVersion < 7) {
          final columns = await db.rawQuery('PRAGMA table_info(products)');
          if (!columns.any((column) => column['name'] == 'image_path')) {
            await db.execute(
              "ALTER TABLE products ADD COLUMN image_path TEXT NOT NULL DEFAULT ''",
            );
          }
          if (!columns.any((column) => column['name'] == 'seed_key')) {
            await db.execute('ALTER TABLE products ADD COLUMN seed_key TEXT');
          }
          await db.execute(
            'CREATE UNIQUE INDEX IF NOT EXISTS products_seed_key_idx ON products(seed_key)',
          );
          final existing = await db.query('products', columns: ['id']);
          for (final row in existing) {
            await db.update(
              'products',
              {'image_path': _randomPlaceholder()},
              where: 'id = ?',
              whereArgs: [row['id']],
            );
          }
          await _seedCatalog(db);
        }
        if (oldVersion < 8) {
          for (final entry in _sampleImageIndex.entries) {
            await db.update(
              'products',
              {'image_path': catalogPlaceholders[entry.value]},
              where:
                  "seed_key = ? AND image_path LIKE 'assets/flowers/placeholders/%'",
              whereArgs: [entry.key],
            );
          }
        }
        if (oldVersion < 9) {
          await _createOrderChangesTable(db);
        }
        if (oldVersion < 10) {
          final columns = await db.rawQuery('PRAGMA table_info(orders)');
          if (columns.isNotEmpty &&
              !columns.any((column) => column['name'] == 'items_json')) {
            await db.execute(
              "ALTER TABLE orders ADD COLUMN items_json TEXT NOT NULL DEFAULT '[]'",
            );
          }
        }
        if (oldVersion < 11) {
          await _createShopProfileTable(db);
        }
        if (oldVersion < 12) {
          final columns = await db.rawQuery('PRAGMA table_info(shop_profile)');
          if (!columns.any((column) => column['name'] == 'qr_image_path')) {
            await db.execute(
              "ALTER TABLE shop_profile ADD COLUMN qr_image_path TEXT NOT NULL DEFAULT ''",
            );
          }
        }
        if (oldVersion < 13) {
          await _createSettingsTable(db);
        }
        if (oldVersion < 14) {
          await _addOrderRetailColumns(db);
        }
      },
    );
  }

  /// v14: gift orders, hand-over kind, discounts and payment methods.
  Future<void> _addOrderRetailColumns(DatabaseExecutor db) async {
    Future<void> addColumn(String table, String column, String ddl) async {
      final columns = await db.rawQuery('PRAGMA table_info($table)');
      if (columns.isNotEmpty && !columns.any((c) => c['name'] == column)) {
        await db.execute('ALTER TABLE $table ADD COLUMN $column $ddl');
      }
    }

    await addColumn(
      'orders',
      'fulfillment',
      "TEXT NOT NULL DEFAULT 'delivery'",
    );
    await addColumn('orders', 'recipient_name', "TEXT NOT NULL DEFAULT ''");
    await addColumn('orders', 'recipient_phone', "TEXT NOT NULL DEFAULT ''");
    await addColumn('orders', 'card_message', "TEXT NOT NULL DEFAULT ''");
    await addColumn('orders', 'anonymous_sender', 'INTEGER NOT NULL DEFAULT 0');
    await addColumn('orders', 'discount', 'INTEGER NOT NULL DEFAULT 0');
    await addColumn('orders', 'surcharge', 'INTEGER NOT NULL DEFAULT 0');
    await addColumn('payments', 'method', "TEXT NOT NULL DEFAULT ''");
  }

  Future<void> _createSettingsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<bool> remindersEnabled() async {
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['reminders_enabled'],
    );
    return rows.isNotEmpty && rows.first['value'] == '1';
  }

  Future<void> setRemindersEnabled(bool enabled) async {
    await db.insert('app_settings', {
      'key': 'reminders_enabled',
      'value': enabled ? '1' : '0',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// 'system', 'light' or 'dark'.
  Future<String> themePreference() async {
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['theme_mode'],
    );
    final value = rows.isEmpty ? null : rows.first['value'];
    return value == 'light' || value == 'dark' ? value! as String : 'system';
  }

  Future<void> setThemePreference(String value) async {
    await db.insert('app_settings', {
      'key': 'theme_mode',
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<bool> liveActivityEnabled() async {
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['live_activity_enabled'],
    );
    return rows.isNotEmpty && rows.first['value'] == '1';
  }

  /// When on, the quick status action goes from "Đang làm" straight to the
  /// next hand-over step without "Chờ duyệt".
  Future<bool> skipApproval() async {
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['skip_approval'],
    );
    return rows.isNotEmpty && rows.first['value'] == '1';
  }

  Future<void> setSkipApproval(bool enabled) async {
    await db.insert('app_settings', {
      'key': 'skip_approval',
      'value': enabled ? '1' : '0',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<DateTime?> lastBackupAt() async {
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['last_backup_at'],
    );
    return rows.isEmpty
        ? null
        : DateTime.tryParse(rows.first['value']! as String);
  }

  Future<void> setLastBackupAt(DateTime value) async {
    await db.insert('app_settings', {
      'key': 'last_backup_at',
      'value': value.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> setLiveActivityEnabled(bool enabled) async {
    await db.insert('app_settings', {
      'key': 'live_activity_enabled',
      'value': enabled ? '1' : '0',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _createShopProfileTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shop_profile (
        id INTEGER PRIMARY KEY CHECK(id = 1),
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        address TEXT NOT NULL,
        bank_bin TEXT NOT NULL,
        bank_name TEXT NOT NULL,
        account_number TEXT NOT NULL,
        account_holder TEXT NOT NULL,
        qr_image_path TEXT NOT NULL DEFAULT ''
      )
    ''');
  }

  Future<ShopProfile> loadShopProfile() async {
    final rows = await db.query('shop_profile', where: 'id = 1');
    return rows.isEmpty ? const ShopProfile() : ShopProfile.fromMap(rows.first);
  }

  Future<void> saveShopProfile(ShopProfile profile) async {
    final issue = profile.validate();
    if (issue != null) {
      throw ArgumentError(issue);
    }
    await db.insert('shop_profile', {
      'id': 1,
      ...profile.toMap(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _createPaymentsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL REFERENCES orders(id),
        amount INTEGER NOT NULL CHECK(amount != 0),
        occurred_at TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        method TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS payments_order_idx ON payments(order_id)',
    );
  }

  Future<void> _createDraftTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS order_draft (
        id INTEGER PRIMARY KEY CHECK(id = 1),
        payload TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createCatalogTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price INTEGER NOT NULL CHECK(price > 0),
        image_path TEXT NOT NULL DEFAULT '',
        seed_key TEXT,
        active INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_flowers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL REFERENCES products(id),
        name TEXT NOT NULL,
        quantity INTEGER NOT NULL CHECK(quantity > 0),
        unit TEXT NOT NULL,
        is_main INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS product_flowers_product_idx ON product_flowers(product_id)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS products_seed_key_idx ON products(seed_key)',
    );
  }

  String _randomPlaceholder() =>
      catalogPlaceholders[_random.nextInt(catalogPlaceholders.length)];

  Future<void> _seedCatalog(DatabaseExecutor db) async {
    const samples = <(String, String, int, String, int, String, int)>[
      ('hong_do', 'Bó hồng đỏ', 320000, 'Hồng đỏ', 12, 'Baby trắng', 3),
      (
        'hong_pastel',
        'Bó hồng pastel',
        350000,
        'Hồng pastel',
        12,
        'Baby trắng',
        3,
      ),
      ('ly_trang', 'Bó ly trắng', 420000, 'Ly trắng', 5, 'Lá bạc', 5),
      ('cuc_vang', 'Bó cúc vàng', 220000, 'Cúc vàng', 10, 'Baby trắng', 2),
      (
        'cat_tuong',
        'Bó cát tường tím',
        290000,
        'Cát tường tím',
        9,
        'Lá bạc',
        4,
      ),
      (
        'dong_tien',
        'Bó đồng tiền cam',
        260000,
        'Đồng tiền cam',
        10,
        'Baby trắng',
        2,
      ),
      ('huong_duong', 'Bó hướng dương', 280000, 'Hướng dương', 7, 'Lá bạc', 5),
      ('mix_hong_ly', 'Bó hồng và ly', 490000, 'Hồng đỏ', 10, 'Ly trắng', 3),
      (
        'mix_pastel',
        'Bó hoa pastel',
        390000,
        'Hồng pastel',
        8,
        'Cát tường tím',
        5,
      ),
      (
        'mix_ruc_ro',
        'Bó hoa rực rỡ',
        360000,
        'Đồng tiền cam',
        7,
        'Cúc vàng',
        6,
      ),
    ];
    for (var i = 0; i < samples.length; i++) {
      final (key, name, price, main, mainQuantity, extra, extraQuantity) =
          samples[i];
      final id = await db.insert('products', {
        'seed_key': key,
        'name': name,
        'price': price,
        'image_path': catalogPlaceholders[_sampleImageIndex[key]!],
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      if (id == 0) {
        continue;
      }
      await db.insert('product_flowers', {
        'product_id': id,
        'name': main,
        'quantity': mainQuantity,
        'unit': 'cành',
        'is_main': 1,
      });
      await db.insert('product_flowers', {
        'product_id': id,
        'name': extra,
        'quantity': extraQuantity,
        'unit': 'cành',
        'is_main': 0,
      });
    }
  }

  Future<void> _createMediaTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS order_media (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL REFERENCES orders(id),
        type INTEGER NOT NULL,
        relative_path TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS order_media_order_idx ON order_media(order_id)',
    );
  }

  Future<void> _createShoppingTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shopping_checks (
        scope_start TEXT NOT NULL,
        scope_end TEXT NOT NULL,
        item_key TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        checked_at TEXT NOT NULL,
        PRIMARY KEY(scope_start, scope_end, item_key)
      )
    ''');
  }

  Future<void> _createOrderChangesTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS order_changes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL REFERENCES orders(id),
        details TEXT NOT NULL,
        changed_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS order_changes_order_idx ON order_changes(order_id)',
    );
  }

  String _shoppingDate(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  Future<Map<String, int>> shoppingChecks(DateTime start, DateTime end) async {
    final rows = await db.query(
      'shopping_checks',
      where: 'scope_start = ? AND scope_end = ?',
      whereArgs: [_shoppingDate(start), _shoppingDate(end)],
    );
    return {
      for (final row in rows)
        row['item_key']! as String: row['quantity']! as int,
    };
  }

  Future<void> setShoppingChecked(
    DateTime start,
    DateTime end,
    ShoppingItem item,
    bool checked,
  ) async {
    final startText = _shoppingDate(start);
    final endText = _shoppingDate(end);
    if (checked) {
      await db.insert('shopping_checks', {
        'scope_start': startText,
        'scope_end': endText,
        'item_key': item.key,
        'quantity': item.quantity,
        'checked_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await db.delete(
        'shopping_checks',
        where: 'scope_start = ? AND scope_end = ? AND item_key = ?',
        whereArgs: [startText, endText, item.key],
      );
    }
  }

  Future<List<OrderMedia>> mediaForOrder(int orderId) async {
    final rows = await db.query(
      'order_media',
      where: 'order_id = ?',
      whereArgs: [orderId],
      orderBy: 'created_at DESC, id DESC',
    );
    return rows
        .map(
          (row) => OrderMedia(
            id: row['id']! as int,
            orderId: row['order_id']! as int,
            type: OrderMediaType.values[row['type']! as int],
            relativePath: row['relative_path']! as String,
            createdAt: DateTime.parse(row['created_at']! as String),
          ),
        )
        .toList();
  }

  Future<int> addMedia(
    int orderId,
    OrderMediaType type,
    String relativePath,
  ) async {
    if (relativePath.isEmpty ||
        relativePath.startsWith('/') ||
        relativePath.split('/').contains('..')) {
      throw ArgumentError('Invalid media path');
    }
    return db.insert('order_media', {
      'order_id': orderId,
      'type': type.index,
      'relative_path': relativePath,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteMedia(int id) async {
    await db.delete('order_media', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<CatalogProduct>> listProducts() async {
    final productRows = await db.query(
      'products',
      where: 'active = 1',
      orderBy: 'name COLLATE NOCASE, id',
    );
    final products = <CatalogProduct>[];
    for (final row in productRows) {
      final id = row['id']! as int;
      final flowerRows = await db.query(
        'product_flowers',
        where: 'product_id = ?',
        whereArgs: [id],
        orderBy: 'id',
      );
      products.add(
        CatalogProduct(
          id: id,
          name: row['name']! as String,
          price: row['price']! as int,
          imagePath: row['image_path']! as String,
          components: flowerRows
              .map(
                (flower) => FlowerComponent(
                  name: flower['name']! as String,
                  quantity: flower['quantity']! as int,
                  unit: flower['unit']! as String,
                  isMain: (flower['is_main']! as int) == 1,
                ),
              )
              .toList(),
        ),
      );
    }
    return products;
  }

  Future<int> saveProduct(CatalogProduct product) async {
    final error = product.validate();
    if (error != null) {
      throw ArgumentError(error);
    }
    return db.transaction((txn) async {
      final values = {
        'name': product.name.trim(),
        'price': product.price,
        'image_path': product.imagePath.trim().isEmpty
            ? _randomPlaceholder()
            : product.imagePath.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      final int id;
      if (product.id == null) {
        id = await txn.insert('products', values);
      } else {
        id = product.id!;
        final changed = await txn.update(
          'products',
          values,
          where: 'id = ? AND active = 1',
          whereArgs: [id],
        );
        if (changed != 1) {
          throw ArgumentError('Product does not exist');
        }
        await txn.delete(
          'product_flowers',
          where: 'product_id = ?',
          whereArgs: [id],
        );
      }
      for (final component in product.components) {
        await txn.insert('product_flowers', {
          'product_id': id,
          'name': component.name.trim(),
          'quantity': component.quantity,
          'unit': component.unit.trim(),
          'is_main': component.isMain ? 1 : 0,
        });
      }
      return id;
    });
  }

  Future<void> archiveProduct(int id) async {
    await db.update(
      'products',
      {'active': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>?> loadDraft() async {
    final rows = await db.query(
      'order_draft',
      columns: ['payload'],
      where: 'id = 1',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return jsonDecode(rows.single['payload']! as String)
        as Map<String, dynamic>;
  }

  Future<void> saveDraft(Map<String, dynamic> draft) async {
    await db.insert('order_draft', {
      'id': 1,
      'payload': jsonEncode(draft),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clearDraft() async {
    await db.delete('order_draft', where: 'id = 1');
  }

  Database get db => _db ?? (throw StateError('Database is not open'));

  Future<List<FlowerOrder>> all() async {
    final rows = await db.rawQuery('''
      SELECT orders.*, COALESCE(
        (SELECT SUM(amount) FROM payments WHERE order_id = orders.id), 0
      ) AS paid_total
      FROM orders ORDER BY delivery_at ASC, id ASC
    ''');
    return rows.map(_fromRow).toList();
  }

  Future<FlowerOrder?> getById(int id) async {
    final rows = await db.rawQuery(
      '''
      SELECT orders.*, COALESCE(
        (SELECT SUM(amount) FROM payments WHERE order_id = orders.id), 0
      ) AS paid_total
      FROM orders WHERE orders.id = ?
    ''',
      [id],
    );
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  Future<List<String>> customerNames(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }
    final rows = await db.query(
      'customers',
      columns: ['name'],
      where: 'name LIKE ?',
      whereArgs: ['%${query.trim()}%'],
      orderBy: 'name',
      limit: 8,
    );
    return rows.map((row) => row['name']! as String).toList();
  }

  Future<List<CustomerSummary>> customers({String query = ''}) async {
    final text = query.trim();
    final rows = await db.rawQuery(
      '''
      SELECT c.id, c.name, c.phone,
        (SELECT COUNT(*) FROM orders o
         WHERE o.customer_name = c.name AND o.phone = c.phone) AS order_count
      FROM customers c
      WHERE c.name LIKE ? OR c.phone LIKE ?
      ORDER BY c.name COLLATE NOCASE, c.id
      LIMIT 100
    ''',
      ['%$text%', '%$text%'],
    );
    return rows
        .map(
          (row) => CustomerSummary(
            id: row['id']! as int,
            name: row['name']! as String,
            phone: row['phone']! as String,
            orderCount: row['order_count']! as int,
          ),
        )
        .toList();
  }

  /// Saves a new order. [paymentMethod] describes the deposit in
  /// [FlowerOrder.paid], if any.
  Future<int> add(FlowerOrder order, {PaymentMethod? paymentMethod}) async {
    final error = order.validate();
    if (error != null) {
      throw ArgumentError(error);
    }
    return db.transaction((txn) async {
      // A counter sale is handed over now, so its time is never in the future.
      if (order.fulfillment != FulfillmentType.counter) {
        final timeIssue = deliveryTimeIssue(order.deliveryAt, now: _now());
        if (timeIssue != null) {
          throw ArgumentError(timeIssue);
        }
      }
      await txn.insert('customers', {
        'name': order.customerName.trim(),
        'phone': order.phone.trim(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      final id = await txn.insert('orders', {
        ..._toRow(order),
        'created_at': DateTime.now().toIso8601String(),
      });
      if (order.paid > 0) {
        await txn.insert('payments', {
          'order_id': id,
          'amount': order.paid,
          'occurred_at': DateTime.now().toIso8601String(),
          'note': order.paid >= order.total ? 'Thanh toán đủ' : 'Tiền cọc',
          'method': paymentMethod?.name ?? '',
        });
      }
      await txn.insert('status_history', {
        'order_id': id,
        'status': order.status.index,
        'changed_at': DateTime.now().toIso8601String(),
      });
      await txn.delete('order_draft', where: 'id = 1');
      return id;
    });
  }

  Future<void> updateOrder(FlowerOrder order) async {
    if (order.id == null) {
      throw ArgumentError('Order has no id');
    }
    await db.transaction((txn) async {
      final existing = await txn.query(
        'orders',
        where: 'id = ?',
        whereArgs: [order.id],
        limit: 1,
      );
      if (existing.isEmpty) {
        throw ArgumentError('Order does not exist');
      }
      final currentDelivery = DateTime.parse(
        existing.single['delivery_at']! as String,
      );
      if (order.deliveryAt != currentDelivery) {
        final timeIssue = deliveryTimeIssue(order.deliveryAt, now: _now());
        if (timeIssue != null) {
          throw ArgumentError(timeIssue);
        }
      }
      final paymentRows = await txn.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) AS paid FROM payments WHERE order_id = ?',
        [order.id],
      );
      final actualPaid = paymentRows.single['paid']! as int;
      final error = order.copyWith(paid: actualPaid).validate();
      if (error != null) {
        throw ArgumentError(error);
      }
      await txn.insert('customers', {
        'name': order.customerName.trim(),
        'phone': order.phone.trim(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      final values = _toRow(order)
        ..remove('paid')
        ..remove('status');
      final previous = existing.single;
      final changes = <String>[];
      const labels = <String, String>{
        'customer_name': 'Khách hàng',
        'phone': 'Số điện thoại',
        'product_name': 'Mẫu hoa',
        'price': 'Giá hoa',
        'shipping_fee': 'Phí giao',
        'delivery_at': 'Giờ giao',
        'address': 'Địa chỉ',
        'note': 'Ghi chú',
        'fulfillment': 'Hình thức nhận',
        'recipient_name': 'Người nhận',
        'recipient_phone': 'SĐT người nhận',
        'card_message': 'Lời thiệp',
        'anonymous_sender': 'Ẩn danh người tặng',
        'discount': 'Giảm giá',
        'surcharge': 'Phụ thu',
      };
      for (final entry in labels.entries) {
        if (previous[entry.key] != values[entry.key]) {
          changes.add(entry.value);
        }
      }
      if (previous['recipe_json'] != values['recipe_json']) {
        changes.add('Định lượng hoa');
      }
      if (previous['items_json'] != values['items_json']) {
        changes.add('Sản phẩm trong đơn');
      }
      await txn.update(
        'orders',
        values,
        where: 'id = ?',
        whereArgs: [order.id],
      );
      if (changes.isNotEmpty) {
        await txn.insert('order_changes', {
          'order_id': order.id,
          'details': 'Đã sửa: ${changes.join(', ')}',
          'changed_at': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  Future<void> updateStatus(FlowerOrder order, OrderStatus status) async {
    if (order.id == null) {
      throw ArgumentError('Order has no id');
    }
    await db.transaction((txn) async {
      final rows = await txn.query(
        'orders',
        columns: ['status', 'fulfillment'],
        where: 'id = ?',
        whereArgs: [order.id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw ArgumentError('Order does not exist');
      }
      final current = OrderStatus.values[rows.single['status']! as int];
      final fulfillment = FulfillmentTypeLabel.parse(
        rows.single['fulfillment'],
      );
      if (!canChangeStatus(fulfillment, current, status)) {
        throw ArgumentError('Invalid status transition');
      }
      await txn.update(
        'orders',
        {'status': status.index},
        where: 'id = ?',
        whereArgs: [order.id],
      );
      await txn.insert('status_history', {
        'order_id': order.id,
        'status': status.index,
        'changed_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<List<StatusEntry>> statusHistory(int orderId) async {
    final rows = await db.query(
      'status_history',
      where: 'order_id = ?',
      whereArgs: [orderId],
      orderBy: 'changed_at DESC, id DESC',
    );
    return rows
        .map(
          (row) => StatusEntry(
            status: OrderStatus.values[row['status']! as int],
            changedAt: DateTime.parse(row['changed_at']! as String),
          ),
        )
        .toList();
  }

  Future<List<OrderChangeEntry>> orderChanges(int orderId) async {
    final rows = await db.query(
      'order_changes',
      where: 'order_id = ?',
      whereArgs: [orderId],
      orderBy: 'changed_at DESC, id DESC',
    );
    return rows
        .map(
          (row) => OrderChangeEntry(
            details: row['details']! as String,
            changedAt: DateTime.parse(row['changed_at']! as String),
          ),
        )
        .toList();
  }

  Future<List<PaymentEntry>> paymentsForOrder(int orderId) async {
    final rows = await db.query(
      'payments',
      where: 'order_id = ?',
      whereArgs: [orderId],
      orderBy: 'occurred_at DESC, id DESC',
    );
    return rows
        .map(
          (row) => PaymentEntry(
            amount: row['amount']! as int,
            occurredAt: DateTime.parse(row['occurred_at']! as String),
            note: row['note']! as String,
            method: PaymentMethodLabel.parse(row['method']),
          ),
        )
        .toList();
  }

  Future<List<OrderPayment>> allPayments() async {
    final rows = await db.query('payments', columns: ['amount', 'occurred_at']);
    return rows
        .map(
          (row) => OrderPayment(
            amount: row['amount']! as int,
            occurredAt: DateTime.parse(row['occurred_at']! as String),
          ),
        )
        .toList();
  }

  Future<void> addPayment(
    int orderId,
    int amount, {
    String note = '',
    PaymentMethod? method,
  }) async {
    if (amount == 0) {
      throw ArgumentError('Payment amount cannot be zero');
    }
    await db.transaction((txn) async {
      final orderRows = await txn.query(
        'orders',
        columns: ['price', 'shipping_fee', 'discount', 'surcharge', 'status'],
        where: 'id = ?',
        whereArgs: [orderId],
        limit: 1,
      );
      if (orderRows.isEmpty) {
        throw ArgumentError('Order does not exist');
      }
      if (amount > 0 &&
          orderRows.single['status'] == OrderStatus.cancelled.index) {
        throw ArgumentError('Cannot collect payment for a cancelled order');
      }
      final row = orderRows.single;
      final total =
          (row['price']! as int) +
          (row['shipping_fee']! as int) +
          (row['surcharge']! as int) -
          (row['discount']! as int);
      final paidRows = await txn.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) AS paid FROM payments WHERE order_id = ?',
        [orderId],
      );
      final paid = paidRows.single['paid']! as int;
      if (paid + amount < 0 || paid + amount > total) {
        throw ArgumentError('Payment is outside the remaining balance');
      }
      await txn.insert('payments', {
        'order_id': orderId,
        'amount': amount,
        'occurred_at': DateTime.now().toIso8601String(),
        'note': note.trim(),
        'method': method?.name ?? '',
      });
    });
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Map<String, Object?> _toRow(FlowerOrder order) => {
    'customer_name': order.customerName.trim(),
    'phone': order.phone.trim(),
    'product_name': order.productName.trim(),
    'price': order.price,
    'shipping_fee': order.shippingFee,
    'paid': 0,
    'delivery_at': order.deliveryAt.toIso8601String(),
    'address': order.address.trim(),
    'note': order.note.trim(),
    'recipe_json': jsonEncode(
      order.components.map((item) => item.toJson()).toList(),
    ),
    'items_json': jsonEncode(order.items.map((item) => item.toJson()).toList()),
    'status': order.status.index,
    'fulfillment': order.fulfillment.key,
    'recipient_name': order.recipientName.trim(),
    'recipient_phone': order.recipientPhone.trim(),
    'card_message': order.cardMessage.trim(),
    'anonymous_sender': order.anonymousSender ? 1 : 0,
    'discount': order.discount,
    'surcharge': order.surcharge,
  };

  FlowerOrder _fromRow(Map<String, Object?> row) => FlowerOrder(
    id: row['id']! as int,
    customerName: row['customer_name']! as String,
    phone: row['phone']! as String,
    productName: row['product_name']! as String,
    price: row['price']! as int,
    shippingFee: row['shipping_fee']! as int,
    paid: row['paid_total']! as int,
    deliveryAt: DateTime.parse(row['delivery_at']! as String),
    address: row['address']! as String,
    note: row['note']! as String,
    components: (jsonDecode(row['recipe_json']! as String) as List<dynamic>)
        .map((item) => FlowerComponent.fromJson(item as Map<String, dynamic>))
        .toList(),
    items: (jsonDecode(row['items_json']! as String) as List<dynamic>)
        .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
        .toList(),
    status: OrderStatus.values[row['status']! as int],
    fulfillment: FulfillmentTypeLabel.parse(row['fulfillment']),
    recipientName: row['recipient_name'] as String? ?? '',
    recipientPhone: row['recipient_phone'] as String? ?? '',
    cardMessage: row['card_message'] as String? ?? '',
    anonymousSender: (row['anonymous_sender'] as int? ?? 0) == 1,
    discount: row['discount'] as int? ?? 0,
    surcharge: row['surcharge'] as int? ?? 0,
  );
}
