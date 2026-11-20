import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/order_repository.dart';
import '../domain/flower_order.dart';
import '../domain/shopping_list.dart';
import 'app_toast.dart';
import 'flower_template_theme.dart';
import 'flower_template_widgets.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({
    super.key,
    required this.repository,
    this.initialPeriod = 0,
  });

  final OrderRepository repository;

  /// 0 = today, 1 = tomorrow, 2 = next 7 days.
  final int initialPeriod;

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingData {
  const _ShoppingData(
    this.list,
    this.checks,
    this.start,
    this.end,
    this.orders,
  );
  final ShoppingList list;
  final List<FlowerOrder> orders;
  final Map<String, int> checks;
  final DateTime start;
  final DateTime end;
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  late int period = widget.initialPeriod;
  late Future<_ShoppingData> data = load();

  Future<_ShoppingData> load() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = period == 1 ? today.add(const Duration(days: 1)) : today;
    final end = start.add(Duration(days: period == 2 ? 7 : 1));
    final orders = await widget.repository.all();
    final checks = await widget.repository.shoppingChecks(start, end);
    return _ShoppingData(
      buildShoppingList(orders, start, end),
      checks,
      start,
      end,
      orders,
    );
  }

  void showOrders(_ShoppingData current, ShoppingItem item) {
    final needing = ordersNeeding(
      current.orders,
      item,
      current.start,
      current.end,
    );
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
              '${item.name} · ${item.quantity} ${item.unit}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text('Dùng cho ${needing.length} đơn'),
            const SizedBox(height: 8),
            for (final (order, count) in needing)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  order.id == null
                      ? order.customerName
                      : '#${order.id} · ${order.customerName}',
                ),
                subtitle: Text(
                  '${DateFormat('HH:mm dd/MM', 'vi').format(order.deliveryAt)} · ${order.productName}',
                ),
                trailing: Text(
                  '$count ${item.unit}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void refresh() => setState(() {
    data = load();
  });

  Future<void> toggle(
    _ShoppingData current,
    ShoppingItem item,
    bool checked,
  ) async {
    try {
      await widget.repository.setShoppingChecked(
        current.start,
        current.end,
        item,
        checked,
      );
      if (mounted) {
        refresh();
      }
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Không thể cập nhật danh sách mua hoa');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Danh sách mua hoa')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TemplateSectionHeading(
                eyebrow: 'CHUẨN BỊ',
                title: 'Danh sách mua hoa',
              ),
              const SizedBox(height: 18),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 0, label: Text('Hôm nay')),
                  ButtonSegment(value: 1, label: Text('Ngày mai')),
                  ButtonSegment(value: 2, label: Text('7 ngày')),
                ],
                selected: {period},
                onSelectionChanged: (selection) {
                  setState(() {
                    period = selection.single;
                    data = load();
                  });
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<_ShoppingData>(
            future: data,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: TextButton(
                    onPressed: refresh,
                    child: const Text('Không thể tải danh sách · Thử lại'),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final current = snapshot.data!;
              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                children: [
                  Text(
                    '${DateFormat('dd/MM', 'vi').format(current.start)} – ${DateFormat('dd/MM', 'vi').format(current.end.subtract(const Duration(days: 1)))}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.palette.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Mua xong loại nào thì tích loại đó. Nếu có thêm đơn cần '
                    'loại hoa đã tích, dấu tích tự bỏ và ghi số cần mua thêm.',
                    style: TextStyle(color: context.palette.muted),
                  ),
                  const SizedBox(height: 12),
                  if (current.list.ordersWithoutRecipe > 0)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.warning_amber_outlined),
                        title: Text(
                          '${current.list.ordersWithoutRecipe} đơn chưa có định lượng hoa',
                        ),
                        subtitle: const Text(
                          'Các đơn này chưa được tính vào danh sách.',
                        ),
                      ),
                    ),
                  if (current.list.items.isEmpty)
                    const TemplateEmptyState(
                      message: 'Chưa có hoa cần mua trong khoảng này',
                      icon: Icons.shopping_basket_outlined,
                    ),
                  // Still to buy first, bought ones at the bottom.
                  for (final item in [
                    ...current.list.items.where(
                      (i) => !shoppingDone(i, current.checks[i.key]),
                    ),
                    ...current.list.items.where(
                      (i) => shoppingDone(i, current.checks[i.key]),
                    ),
                  ])
                    _itemTile(current, item),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );

  Widget _itemTile(_ShoppingData current, ShoppingItem item) {
    final palette = context.palette;
    final bought = current.checks[item.key];
    final done = shoppingDone(item, bought);
    final String subtitle;
    if (done) {
      subtitle = 'Đã mua ${item.quantity} ${item.unit}';
    } else if (bought != null) {
      subtitle =
          'Cần ${item.quantity} ${item.unit} · đã mua $bought, '
          'cần thêm ${item.quantity - bought}';
    } else {
      subtitle = 'Cần ${item.quantity} ${item.unit}';
    }
    return Card(
      child: CheckboxListTile(
        value: done,
        controlAffinity: ListTileControlAffinity.leading,
        onChanged: (value) => toggle(current, item, value ?? false),
        title: Text(
          item.name,
          style: TextStyle(
            decoration: done ? TextDecoration.lineThrough : null,
            color: done ? palette.muted : null,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: bought != null && !done ? palette.accent : palette.muted,
            fontWeight: bought != null && !done ? FontWeight.w700 : null,
          ),
        ),
        secondary: IconButton(
          tooltip: 'Đơn cần ${item.name}',
          onPressed: () => showOrders(current, item),
          icon: const Icon(Icons.receipt_long_outlined),
        ),
      ),
    );
  }
}
