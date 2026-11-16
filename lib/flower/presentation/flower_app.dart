import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

import '../data/order_repository.dart';
import '../domain/catalog_placeholders.dart';
import '../domain/catalog_product.dart';
import '../domain/flower_order.dart';
import '../domain/order_item.dart';
import '../domain/order_summary.dart';
import 'app_toast.dart';
import 'catalog_product_image.dart';
import 'catalog_screen.dart';
import 'flower_template_theme.dart';
import 'flower_template_widgets.dart';
import 'money_input_formatter.dart';
import 'order_media_section.dart';
import 'shopping_list_screen.dart';

const _rose = FlowerTemplateTheme.navy;
const _ink = FlowerTemplateTheme.ink;
const _sage = FlowerTemplateTheme.muted;

String money(int value) =>
    '${NumberFormat.decimalPattern(Intl.getCurrentLocale()).format(value)} đ';
String dayLabel(DateTime value) => DateFormat('dd/MM/yyyy', 'vi').format(value);

String _orderThumbnail(FlowerOrder order) {
  final name = order.effectiveItems.first.name.toLowerCase();
  if (name.contains('cúc') || name.contains('hướng dương')) {
    return catalogPlaceholders[2];
  }
  if (name.contains('cát tường')) {
    return catalogPlaceholders[3];
  }
  if (name.contains('đồng tiền')) {
    return catalogPlaceholders[4];
  }
  if (name.contains('ly')) {
    return catalogPlaceholders[1];
  }
  if (name.contains('hồng đỏ') || name.contains('đỏ')) {
    return catalogPlaceholders[5];
  }
  return catalogPlaceholders.first;
}

Color _statusColor(OrderStatus status) => switch (status) {
  OrderStatus.newOrder => FlowerTemplateTheme.navy,
  OrderStatus.making => const Color(0xFFC0765B),
  OrderStatus.awaitingApproval => const Color(0xFF6975A2),
  OrderStatus.delivering => const Color(0xFF3E6C98),
  OrderStatus.delivered => FlowerTemplateTheme.deepSage,
  OrderStatus.cancelled => FlowerTemplateTheme.muted,
};

class FlowerApp extends StatelessWidget {
  const FlowerApp({
    super.key,
    required this.repository,
    this.locale = const Locale('vi'),
  });
  final OrderRepository repository;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    Intl.defaultLocale = locale.languageCode;
    return MaterialApp(
      title: 'Tiệm Hoa',
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: FlowerTemplateTheme.light(),
      home: FlowerHome(repository: repository),
    );
  }
}

class FlowerHome extends StatefulWidget {
  const FlowerHome({super.key, required this.repository});
  final OrderRepository repository;

  @override
  State<FlowerHome> createState() => _FlowerHomeState();
}

class _FlowerHomeState extends State<FlowerHome> {
  int tab = 0;
  final orderSearch = TextEditingController();
  OrderStatus? orderStatusFilter;
  DateTime? orderDayFilter;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime selected = DateTime.now();
  bool get selectedDayIsPast =>
      DateUtils.dateOnly(selected).isBefore(DateUtils.dateOnly(DateTime.now()));
  List<FlowerOrder> orders = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    orderSearch.dispose();
    super.dispose();
  }

  Future<void> pickOrderDay() async {
    final day = await showDatePicker(
      context: context,
      initialDate: orderDayFilter ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (day != null && mounted) {
      setState(() => orderDayFilter = day);
    }
  }

  void changeMonth(int offset) {
    final next = DateTime(month.year, month.month + offset);
    setState(() {
      month = next;
      selected = DateTime(next.year, next.month);
    });
  }

  Future<void> refresh() async {
    try {
      final result = await widget.repository.all();
      if (mounted) {
        setState(() {
          orders = result;
          loading = false;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Không thể tải đơn hàng';
        });
      }
    }
  }

  Future<void> createOrder() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateOrderScreen(
          repository: widget.repository,
          deliveryDay: tab == 0 ? selected : null,
        ),
      ),
    );
    if (saved ?? false) {
      await refresh();
    }
  }

  Future<void> showOrder(FlowerOrder order) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(
          order: order,
          repository: widget.repository,
          onChanged: refresh,
        ),
      ),
    );
    await refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        tab == 0
            ? 'Tiệm Hoa'
            : ['Lịch giao', 'Đơn hàng', 'Thống kê', 'Cá nhân'][tab],
      ),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error!),
                TextButton(onPressed: refresh, child: const Text('Thử lại')),
              ],
            ),
          )
        : switch (tab) {
            0 => _calendarView(),
            1 => _ordersView(),
            2 => _statsView(),
            _ => _profileView(),
          },
    floatingActionButton: tab <= 1
        ? Opacity(
            opacity: tab == 0 && selectedDayIsPast ? 0.4 : 1,
            child: FloatingActionButton.extended(
              onPressed: tab == 0 && selectedDayIsPast ? null : createOrder,
              icon: const Icon(Icons.add),
              label: const Text('Tạo đơn'),
            ),
          )
        : null,
    bottomNavigationBar: SafeArea(
      top: false,
      child: NavigationBar(
        height: 72,
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Lịch',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Đơn hàng',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Thống kê',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Cá nhân',
          ),
        ],
      ),
    ),
  );

  Widget _calendarView() {
    final active = orders
        .where((o) => o.status != OrderStatus.cancelled)
        .toList();
    final selectedOrders = active
        .where((o) => DateUtils.isSameDay(o.deliveryAt, selected))
        .toList();
    final summary = summarizeOrders(active, deliveryMonth: month);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 110),
      children: [
        TemplateSectionHeading(
          eyebrow: 'TỔNG QUAN',
          title: 'Lịch giao tháng ${month.month}',
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _metric(
                'Doanh thu dự kiến',
                money(summary.projectedRevenue),
                Icons.local_florist_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metric(
                'Đơn trong tháng',
                '${summary.orderCount}',
                Icons.inventory_2_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => changeMonth(-1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        DateFormat('MMMM yyyy', 'vi').format(month),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => changeMonth(1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                _calendarGrid(active),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        TemplateSectionHeading(
          eyebrow: 'ĐƠN THEO NGÀY',
          title: 'Lịch giao ${dayLabel(selected)}',
        ),
        const SizedBox(height: 14),
        if (selectedOrders.isEmpty)
          _empty('Chưa có đơn giao trong ngày này')
        else
          ...selectedOrders.map(_orderCard),
      ],
    );
  }

  Widget _calendarGrid(List<FlowerOrder> active) {
    final firstWeekday = DateTime(month.year, month.month).weekday - 1;
    final days = DateTime(month.year, month.month + 1, 0).day;
    return Column(
      children: [
        Row(
          children: [
            for (final day in ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'])
              Expanded(
                child: Center(
                  child: Text(day, style: const TextStyle(color: _sage)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
          ),
          itemCount: firstWeekday + days,
          itemBuilder: (_, index) {
            final day = index - firstWeekday + 1;
            if (day < 1) {
              return const SizedBox.shrink();
            }
            final date = DateTime(month.year, month.month, day);
            final hasOrder = active.any(
              (o) => DateUtils.isSameDay(o.deliveryAt, date),
            );
            final chosen = DateUtils.isSameDay(selected, date);
            return Opacity(
              opacity: date.isBefore(DateUtils.dateOnly(DateTime.now()))
                  ? 0.35
                  : 1,
              child: InkWell(
                borderRadius: BorderRadius.circular(40),
                onTap: () => setState(() => selected = date),
                child: Container(
                  decoration: BoxDecoration(
                    color: chosen ? FlowerTemplateTheme.hydrangea : null,
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          color: chosen ? FlowerTemplateTheme.navy : _ink,
                          fontWeight: chosen ? FontWeight.bold : null,
                        ),
                      ),
                      if (hasOrder)
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: chosen ? FlowerTemplateTheme.navy : _rose,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _ordersView() {
    final visible = filterOrders(
      orders,
      query: orderSearch.text,
      status: orderStatusFilter,
      deliveryDay: orderDayFilter,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 110),
      children: [
        TemplateSectionHeading(
          eyebrow: 'QUẢN LÝ',
          title: 'Đơn hàng của bạn',
          trailing: Text(
            '${visible.length} đơn',
            style: const TextStyle(color: _sage),
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: orderSearch,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Tìm khách, số điện thoại, hoa, mã đơn',
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<OrderStatus?>(
              value: orderStatusFilter,
              hint: const Text('Tất cả trạng thái'),
              items: [
                const DropdownMenuItem<OrderStatus?>(
                  child: Text('Tất cả trạng thái'),
                ),
                for (final status in OrderStatus.values)
                  DropdownMenuItem(value: status, child: Text(status.label)),
              ],
              onChanged: (value) => setState(() => orderStatusFilter = value),
            ),
            ActionChip(
              avatar: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(
                orderDayFilter == null
                    ? 'Ngày giao'
                    : dayLabel(orderDayFilter!),
              ),
              onPressed: pickOrderDay,
            ),
            if (orderDayFilter != null)
              IconButton(
                tooltip: 'Bỏ lọc ngày',
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => orderDayFilter = null),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (visible.isEmpty)
          _empty(
            orders.isEmpty
                ? 'Chưa có đơn hàng. Tạo đơn đầu tiên của bạn nhé!'
                : 'Không có đơn phù hợp',
          )
        else
          ...visible.map(_orderCard),
      ],
    );
  }

  Widget _statsView() {
    final summary = summarizeOrders(orders);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const TemplateSectionHeading(
          eyebrow: 'HIỆU QUẢ KINH DOANH',
          title: 'Tất cả đơn hàng',
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _metric(
                'Doanh thu dự kiến',
                money(summary.projectedRevenue),
                Icons.spa_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metric(
                'Đã thu',
                money(summary.paid),
                Icons.check_circle_outline,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _metric(
                'Còn phải thu',
                money(summary.remaining),
                Icons.payments_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metric(
                'Đơn chưa giao',
                '${summary.pendingCount}',
                Icons.local_shipping_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Số liệu tính từ đơn chưa hủy. Doanh thu dự kiến gồm cả đơn chưa giao.',
          style: TextStyle(color: _sage),
        ),
      ],
    );
  }

  Widget _profileView() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Center(
        child: TemplateIconBadge(icon: Icons.local_florist, size: 72),
      ),
      const SizedBox(height: 18),
      const Center(
        child: Text(
          'Tiệm Hoa',
          style: TextStyle(
            fontFamily: FlowerTemplateTheme.headingFont,
            fontSize: 24,
            height: 1.3,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      const SizedBox(height: 22),
      Card(
        child: ListTile(
          leading: const Icon(Icons.people_outline),
          title: const Text('Khách hàng'),
          subtitle: const Text('Xem khách cũ và lịch sử đơn'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => CustomerScreen(repository: widget.repository),
            ),
          ),
        ),
      ),
      Card(
        child: ListTile(
          leading: const Icon(Icons.local_florist_outlined),
          title: const Text('Mẫu hoa'),
          subtitle: const Text('Giá bán và thành phần hoa'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => CatalogScreen(repository: widget.repository),
            ),
          ),
        ),
      ),
      Card(
        child: ListTile(
          leading: const Icon(Icons.shopping_basket_outlined),
          title: const Text('Danh sách mua hoa'),
          subtitle: const Text('Tổng hợp hoa cần mua theo ngày giao'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => ShoppingListScreen(repository: widget.repository),
            ),
          ),
        ),
      ),
      const Card(
        child: ListTile(
          leading: Icon(Icons.lock_outline),
          title: Text('Dữ liệu lưu trên thiết bị'),
          subtitle: Text(
            'Không cần tài khoản hoặc kết nối mạng để quản lý đơn.',
          ),
        ),
      ),
      const Card(
        child: ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Phiên bản đầu'),
          subtitle: Text('Hóa đơn, nhắc việc và đồng bộ sẽ được bổ sung sau.'),
        ),
      ),
    ],
  );

  Widget _metric(String title, String value, IconData icon) => Card(
    child: Padding(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TemplateIconBadge(icon: icon),
          const SizedBox(height: 14),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            maxLines: 2,
            style: const TextStyle(color: _sage, fontSize: 12),
          ),
        ],
      ),
    ),
  );

  Widget _empty(String text) =>
      TemplateEmptyState(message: text, icon: Icons.local_florist_outlined);

  Widget _orderCard(FlowerOrder order) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => showOrder(order),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CatalogProductImage(path: _orderThumbnail(order), size: 80),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: FlowerTemplateTheme.headingFont,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${order.customerName} · ${DateFormat('HH:mm dd/MM', 'vi').format(order.deliveryAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _sage, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor(
                            order.status,
                          ).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          order.status.label,
                          style: TextStyle(
                            color: _statusColor(order.status),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        money(order.total),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key, required this.repository});

  final OrderRepository repository;

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Khách hàng')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 14),
          child: Column(
            children: [
              const TemplateSectionHeading(
                eyebrow: 'DANH BẠ',
                title: 'Khách hàng',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Tìm tên hoặc số điện thoại',
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<CustomerSummary>>(
            future: widget.repository.customers(query: search.text),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Không thể tải khách hàng'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.isEmpty) {
                return const Center(child: Text('Chưa có khách hàng phù hợp'));
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final customer = snapshot.data![index];
                  return Card(
                    child: ListTile(
                      leading: const TemplateIconBadge(
                        icon: Icons.person_outline,
                      ),
                      title: Text(customer.name),
                      subtitle: Text(
                        customer.phone.isEmpty
                            ? '${customer.orderCount} đơn'
                            : '${customer.phone} · ${customer.orderCount} đơn',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => CustomerDetailScreen(
                            repository: widget.repository,
                            customer: customer,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}

class CustomerDetailScreen extends StatelessWidget {
  const CustomerDetailScreen({
    super.key,
    required this.repository,
    required this.customer,
  });

  final OrderRepository repository;
  final CustomerSummary customer;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(customer.name)),
    body: FutureBuilder<List<FlowerOrder>>(
      future: repository.all(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Không thể tải đơn hàng'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final matching = snapshot.data!
            .where(
              (order) =>
                  order.customerName == customer.name &&
                  order.phone == customer.phone,
            )
            .toList();
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const TemplateSectionHeading(
              eyebrow: 'THÔNG TIN',
              title: 'Khách hàng',
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const TemplateIconBadge(icon: Icons.person_outline),
                title: Text(customer.name),
                subtitle: Text(
                  customer.phone.isEmpty
                      ? 'Chưa có số điện thoại'
                      : customer.phone,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${matching.length} đơn đã đặt',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (matching.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Chưa có đơn hàng'),
              ),
            for (final order in matching)
              Card(
                child: ListTile(
                  title: Text(order.productName),
                  subtitle: Text(
                    '${dayLabel(order.deliveryAt)} · ${order.status.label}',
                  ),
                  trailing: Text(money(order.total)),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.order,
    required this.repository,
    required this.onChanged,
  });
  final FlowerOrder order;
  final OrderRepository repository;
  final Future<void> Function() onChanged;
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late FlowerOrder order = widget.order;
  bool saving = false;
  int _statusMenuRevision = 0;

  Future<void> _editOrder() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateOrderScreen(
          repository: widget.repository,
          initialOrder: order,
        ),
      ),
    );
    if (changed != true || !mounted) {
      return;
    }
    final updated = await widget.repository.getById(order.id!);
    if (!mounted) {
      return;
    }
    if (updated != null) {
      setState(() => order = updated);
    }
    await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Đơn #${order.id}'),
      actions: [
        IconButton(
          tooltip: 'Sửa đơn',
          onPressed: saving ? null : _editOrder,
          icon: const Icon(Icons.edit_outlined),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        TemplateSectionHeading(
          eyebrow: 'ĐƠN HÀNG',
          title: 'Chi tiết đơn #${order.id}',
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CatalogProductImage(path: _orderThumbnail(order), size: 88),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.productName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: FlowerTemplateTheme.headingFont,
                              fontSize: 19,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            order.status.label,
                            style: const TextStyle(
                              color: _rose,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                _line('Khách hàng', order.customerName),
                _line(
                  'Số điện thoại',
                  order.phone.isEmpty ? 'Chưa có' : order.phone,
                ),
                _line(
                  'Giao lúc',
                  '${DateFormat('HH:mm', 'vi').format(order.deliveryAt)} · ${dayLabel(order.deliveryAt)}',
                ),
                _line('Địa chỉ', order.address),
                if (order.note.isNotEmpty) _line('Ghi chú', order.note),
                const Divider(height: 28),
                const Text(
                  'Sản phẩm',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                for (final item in order.effectiveItems)
                  _line('${item.quantity} × ${item.name}', money(item.total)),
                if (order.components.isNotEmpty) ...[
                  const Divider(height: 28),
                  const Text(
                    'Định lượng hoa',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  for (final component in order.components)
                    _line(
                      component.isMain ? 'Hoa chính' : 'Hoa phụ',
                      '${component.name} · ${component.quantity} ${component.unit}',
                    ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _line('Giá hoa', money(order.price)),
                _line('Phí giao', money(order.shippingFee)),
                const Divider(),
                _line('Tổng', money(order.total)),
                _line('Đã thu', money(order.paid)),
                if (order.status == OrderStatus.cancelled)
                  _line('Cần hoàn', money(order.paid))
                else
                  _line('Còn lại', money(order.remaining)),
              ],
            ),
          ),
        ),
        OrderMediaSection(orderId: order.id!, repository: widget.repository),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            if (order.remaining > 0 && order.status != OrderStatus.cancelled)
              FilledButton.icon(
                onPressed: saving ? null : () => _recordPayment(refund: false),
                icon: const Icon(Icons.add),
                label: const Text('Thu thêm'),
              ),
            if (order.paid > 0)
              OutlinedButton.icon(
                onPressed: saving ? null : () => _recordPayment(refund: true),
                icon: const Icon(Icons.undo),
                label: const Text('Hoàn tiền'),
              ),
          ],
        ),
        FutureBuilder<List<PaymentEntry>>(
          future: widget.repository.paymentsForOrder(order.id!),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox.shrink();
            }
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lịch sử thanh toán',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    for (final payment in snapshot.data!)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          payment.amount > 0
                              ? '+${money(payment.amount)}'
                              : money(payment.amount),
                        ),
                        subtitle: Text(
                          '${payment.note} · ${DateFormat('HH:mm dd/MM/yyyy', 'vi').format(payment.occurredAt)}',
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<OrderStatus>(
          key: ValueKey('${order.status.index}-$_statusMenuRevision'),
          initialValue: order.status,
          decoration: const InputDecoration(labelText: 'Trạng thái'),
          items: [order.status, ...order.status.allowedNext]
              .map(
                (status) =>
                    DropdownMenuItem(value: status, child: Text(status.label)),
              )
              .toList(),
          onChanged: saving
              ? null
              : (status) async {
                  if (status == null || status == order.status) {
                    return;
                  }
                  if (status == OrderStatus.cancelled) {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Hủy đơn hàng?'),
                        content: Text(
                          order.paid > 0
                              ? 'Đơn hủy sẽ không tính vào doanh thu dự kiến. Đã thu ${money(order.paid)}; hãy hoàn tiền nếu cần.'
                              : 'Đơn hủy sẽ không tính vào doanh thu dự kiến.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('Giữ đơn'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('Hủy đơn'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true || !mounted) {
                      if (mounted) {
                        setState(() => _statusMenuRevision++);
                      }
                      return;
                    }
                  }
                  setState(() => saving = true);
                  try {
                    await widget.repository.updateStatus(order, status);
                    setState(() => order = order.copyWith(status: status));
                    await widget.onChanged();
                  } catch (_) {
                    if (mounted) {
                      setState(() => _statusMenuRevision++);
                    }
                    if (context.mounted) {
                      AppToast.show(context, 'Không thể cập nhật trạng thái');
                    }
                  } finally {
                    if (mounted) {
                      setState(() => saving = false);
                    }
                  }
                },
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<StatusEntry>>(
          future: widget.repository.statusHistory(order.id!),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox.shrink();
            }
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lịch sử trạng thái',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    for (final entry in snapshot.data!)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.history, color: _sage),
                        title: Text(entry.status.label),
                        subtitle: Text(
                          DateFormat(
                            'HH:mm dd/MM/yyyy',
                            'vi',
                          ).format(entry.changedAt),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<OrderChangeEntry>>(
          future: widget.repository.orderChanges(order.id!),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox.shrink();
            }
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lịch sử chỉnh sửa',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    for (final change in snapshot.data!)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.edit_note, color: _sage),
                        title: Text(change.details),
                        subtitle: Text(
                          DateFormat(
                            'HH:mm dd/MM/yyyy',
                            'vi',
                          ).format(change.changedAt),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    ),
  );

  Future<void> _recordPayment({required bool refund}) async {
    final result = await showDialog<_PaymentResult>(
      context: context,
      builder: (_) => _PaymentInputDialog(
        refund: refund,
        max: refund ? order.paid : order.remaining,
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() => saving = true);
    try {
      await widget.repository.addPayment(
        order.id!,
        result.amount,
        note: result.note,
      );
      setState(() => order = order.copyWith(paid: order.paid + result.amount));
      await widget.onChanged();
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Không thể lưu thanh toán');
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 105,
          child: Text(label, style: const TextStyle(color: _sage)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _PaymentResult {
  const _PaymentResult(this.amount, this.note);
  final int amount;
  final String note;
}

class _PaymentInputDialog extends StatefulWidget {
  const _PaymentInputDialog({required this.refund, required this.max});
  final bool refund;
  final int max;

  @override
  State<_PaymentInputDialog> createState() => _PaymentInputDialogState();
}

class _PaymentInputDialogState extends State<_PaymentInputDialog> {
  final amount = TextEditingController();
  final note = TextEditingController();

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.refund ? 'Hoàn tiền' : 'Thu thêm'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: amount,
          keyboardType: TextInputType.number,
          inputFormatters: [
            MoneyInputFormatter(Localizations.localeOf(context).toString()),
          ],
          autofocus: true,
          decoration: InputDecoration(
            label: const RequiredLabel('Số tiền (đ)'),
            helperText: 'Tối đa ${money(widget.max)}',
          ),
        ),
        TextField(
          controller: note,
          decoration: const InputDecoration(
            labelText: 'Ghi chú (không bắt buộc)',
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          final value = parseCurrencyInput(amount.text);
          if (value == null || value <= 0 || value > widget.max) {
            AppToast.show(context, 'Số tiền không hợp lệ');
            return;
          }
          Navigator.pop(
            context,
            _PaymentResult(widget.refund ? -value : value, note.text.trim()),
          );
        },
        child: const Text('Lưu'),
      ),
    ],
  );
}

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({
    super.key,
    required this.repository,
    this.initialOrder,
    this.deliveryDay,
  });
  final OrderRepository repository;
  final FlowerOrder? initialOrder;
  final DateTime? deliveryDay;
  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final product = TextEditingController();
  final price = TextEditingController();
  final shipping = TextEditingController(text: '0');
  final paid = TextEditingController(text: '0');
  final address = TextEditingController();
  final note = TextEditingController();
  List<FlowerComponent> components = [];
  List<OrderItem> selectedItems = [];
  DateTime delivery = DateTime.now().add(const Duration(days: 1));
  int step = 0;
  bool saving = false;
  bool _saved = false;
  bool _dirty = false;
  bool _hasDraft = false;
  Timer? _draftTimer;
  Timer? _clockTimer;
  bool _deliveryWasValid = true;
  Future<void> _draftWrites = Future<void>.value();

  DateTime _deliveryOnDay(DateTime day, DateTime preferredTime) {
    final candidate = DateTime(
      day.year,
      day.month,
      day.day,
      preferredTime.hour,
      preferredTime.minute,
    );
    final now = DateTime.now();
    if (candidate.isAfter(now)) {
      return candidate;
    }
    return DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(const Duration(minutes: 1));
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialOrder;
    if (initial == null) {
      if (widget.deliveryDay != null) {
        delivery = _deliveryOnDay(widget.deliveryDay!, delivery);
      }
      _restoreDraft();
    } else {
      name.text = initial.customerName;
      phone.text = initial.phone;
      selectedItems = List.of(initial.effectiveItems);
      shipping.text = formatCurrencyInput(
        initial.shippingFee,
        Intl.getCurrentLocale(),
      );
      paid.text = formatCurrencyInput(initial.paid, Intl.getCurrentLocale());
      address.text = initial.address;
      note.text = initial.note;
      components = List.of(initial.components);
      delivery = initial.deliveryAt;
    }
    _deliveryWasValid = deliveryIssue() == null;
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      final valid = deliveryIssue() == null;
      if (valid != _deliveryWasValid) {
        setState(() => _deliveryWasValid = valid);
        if (!valid && step == 3) {
          AppToast.show(context, 'Giờ giao đã qua. Hãy chọn giờ giao mới.');
        }
      }
    });
  }

  Future<void> _restoreDraft() async {
    try {
      final draft = await widget.repository.loadDraft();
      if (draft == null || !mounted || _dirty) {
        return;
      }
      setState(() {
        _hasDraft = true;
        name.text = draft['name'] as String? ?? '';
        phone.text = draft['phone'] as String? ?? '';
        product.text = draft['product'] as String? ?? '';
        price.text = _formattedDraftMoney(draft['price'] as String? ?? '');
        shipping.text = _formattedDraftMoney(
          draft['shipping'] as String? ?? '0',
        );
        paid.text = _formattedDraftMoney(draft['paid'] as String? ?? '0');
        address.text = draft['address'] as String? ?? '';
        note.text = draft['note'] as String? ?? '';
        components = (draft['components'] as List<dynamic>? ?? [])
            .map(
              (item) => FlowerComponent.fromJson(item as Map<String, dynamic>),
            )
            .toList();
        selectedItems = (draft['items'] as List<dynamic>? ?? [])
            .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
            .toList();
        if (selectedItems.isEmpty &&
            (draft['step'] as int? ?? 0) > 1 &&
            product.text.trim().isNotEmpty &&
            (parseMoney(price.text) ?? 0) > 0) {
          selectedItems = [
            OrderItem(
              name: product.text.trim(),
              unitPrice: parseMoney(price.text)!,
              components: components,
            ),
          ];
          product.clear();
          price.clear();
        }
        delivery =
            DateTime.tryParse(draft['delivery'] as String? ?? '') ?? delivery;
        if (widget.deliveryDay != null) {
          delivery = _deliveryOnDay(widget.deliveryDay!, delivery);
        }
        step = (draft['step'] as int? ?? 0).clamp(0, 3);
        _deliveryWasValid = deliveryIssue() == null;
      });
    } catch (_) {
      // The form remains usable if a draft cannot be read.
    }
  }

  Map<String, dynamic> _draftPayload() => {
    'name': name.text,
    'phone': phone.text,
    'product': product.text,
    'price': price.text,
    'shipping': shipping.text,
    'paid': paid.text,
    'address': address.text,
    'note': note.text,
    'components': components.map((item) => item.toJson()).toList(),
    'items': selectedItems.map((item) => item.toJson()).toList(),
    'delivery': delivery.toIso8601String(),
    'step': step,
  };

  void _saveDraft() {
    if (widget.initialOrder != null || !_dirty || _saved) {
      return;
    }
    final snapshot = _draftPayload();
    _draftWrites = _draftWrites.then((_) async {
      try {
        await widget.repository.saveDraft(snapshot);
      } catch (_) {
        // A failed draft write must not block later saves or order creation.
      }
    });
  }

  void _scheduleDraftSave() {
    if (widget.initialOrder != null) {
      return;
    }
    _dirty = true;
    _hasDraft = true;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 350), _saveDraft);
  }

  Future<void> _discardDraft() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa bản nháp?'),
        content: const Text('Thông tin đơn đang nhập sẽ bị xóa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    _draftTimer?.cancel();
    await _draftWrites;
    await widget.repository.clearDraft();
    if (!mounted) {
      return;
    }
    setState(() {
      for (final controller in [name, phone, product, price, address, note]) {
        controller.clear();
      }
      shipping.text = '0';
      paid.text = '0';
      components = [];
      selectedItems = [];
      delivery = widget.deliveryDay == null
          ? DateTime.now().add(const Duration(days: 1))
          : _deliveryOnDay(widget.deliveryDay!, DateTime.now());
      _deliveryWasValid = true;
      step = 0;
      _dirty = false;
      _hasDraft = false;
    });
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _clockTimer?.cancel();
    _saveDraft();
    for (final c in [
      name,
      phone,
      product,
      price,
      shipping,
      paid,
      address,
      note,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int? parseMoney(String value) => parseCurrencyInput(value);

  String _formattedDraftMoney(String value) {
    final amount = parseCurrencyInput(value);
    return amount == null
        ? ''
        : formatCurrencyInput(amount, Intl.getCurrentLocale());
  }

  int get itemsPrice => orderItemsTotal(selectedItems);

  void addManualProduct() {
    final title = product.text.trim();
    final amount = parseMoney(price.text) ?? 0;
    if (title.isEmpty || amount <= 0) {
      AppToast.show(context, 'Nhập tên và giá sản phẩm hợp lệ');
      return;
    }
    setState(() {
      selectedItems.add(
        OrderItem(
          name: title,
          unitPrice: amount,
          components: List.of(components),
        ),
      );
      product.clear();
      price.clear();
      components = [];
    });
    _scheduleDraftSave();
  }

  void changeItemQuantity(int index, int quantity) {
    setState(() {
      if (quantity <= 0) {
        selectedItems.removeAt(index);
      } else {
        selectedItems[index] = selectedItems[index].withQuantity(quantity);
      }
    });
    _scheduleDraftSave();
  }

  String? deliveryIssue() {
    if (widget.initialOrder != null &&
        delivery == widget.initialOrder!.deliveryAt) {
      return null;
    }
    return deliveryTimeIssue(delivery);
  }

  String? validateStep() => switch (step) {
    0 when name.text.trim().isEmpty => 'Vui lòng nhập tên khách hàng',
    1 when selectedItems.isEmpty && product.text.trim().isEmpty =>
      'Vui lòng thêm sản phẩm',
    1
        when product.text.trim().isNotEmpty &&
            (parseMoney(price.text) ?? 0) <= 0 =>
      'Giá sản phẩm phải lớn hơn 0',
    1 when product.text.trim().isEmpty && price.text.isNotEmpty =>
      'Vui lòng nhập tên sản phẩm',
    2 when address.text.trim().isEmpty => 'Vui lòng nhập địa chỉ giao',
    2 when deliveryIssue() != null => deliveryIssue(),
    3 when parseMoney(shipping.text) == null || parseMoney(paid.text) == null =>
      'Vui lòng nhập số tiền hợp lệ',
    3
        when (parseMoney(paid.text) ?? 0) >
            itemsPrice + (parseMoney(shipping.text) ?? 0) =>
      'Tiền đã thu không vượt quá tổng',
    _ => null,
  };

  Future<void> next() async {
    final issue = validateStep();
    if (issue != null) {
      AppToast.show(context, issue);
      return;
    }
    if (step < 3) {
      if (step == 1 && product.text.trim().isNotEmpty) {
        addManualProduct();
      }
      setState(() => step++);
      _scheduleDraftSave();
      return;
    }
    if (selectedItems.isEmpty) {
      AppToast.show(context, 'Vui lòng thêm sản phẩm');
      setState(() => step = 1);
      return;
    }
    final timeIssue = deliveryIssue();
    if (timeIssue != null) {
      AppToast.show(context, timeIssue);
      return;
    }
    final order = FlowerOrder(
      id: widget.initialOrder?.id,
      customerName: name.text,
      phone: phone.text,
      productName: orderItemsLabel(selectedItems),
      price: itemsPrice,
      shippingFee: parseMoney(shipping.text)!,
      paid: widget.initialOrder?.paid ?? parseMoney(paid.text)!,
      deliveryAt: delivery,
      address: address.text,
      note: note.text,
      components: orderItemsComponents(selectedItems),
      items: List.of(selectedItems),
    );
    setState(() => saving = true);
    _draftTimer?.cancel();
    try {
      await _draftWrites;
      if (widget.initialOrder == null) {
        await widget.repository.add(order);
      } else {
        await widget.repository.updateOrder(order);
      }
      _saved = true;
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (exception) {
      if (mounted) {
        setState(() => saving = false);
        AppToast.show(
          context,
          exception is ArgumentError &&
                  exception.message ==
                      'Thời gian giao phải sau thời điểm hiện tại'
              ? exception.message as String
              : 'Không thể lưu đơn. Vui lòng thử lại',
        );
      }
    }
  }

  Future<void> chooseProduct() async {
    try {
      final products = await widget.repository.listProducts();
      if (!mounted) {
        return;
      }
      if (products.isEmpty) {
        AppToast.show(context, 'Catalog chưa có mẫu hoa');
        return;
      }
      final selected = await showModalBottomSheet<CatalogProduct>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.72,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: TemplateSectionHeading(
                    eyebrow: 'BỘ SƯU TẬP',
                    title: 'Chọn mẫu hoa',
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      for (final item in products)
                        Card(
                          child: ListTile(
                            leading: CatalogProductImage(
                              path: item.imagePath,
                              size: 64,
                            ),
                            title: Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(money(item.price)),
                            trailing: const Icon(
                              Icons.add_circle_outline,
                              color: _rose,
                            ),
                            onTap: () => Navigator.pop(sheetContext, item),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (selected == null || !mounted) {
        return;
      }
      setState(() {
        final index = selectedItems.indexWhere(
          (item) => item.catalogProductId == selected.id && selected.id != null,
        );
        if (index >= 0) {
          selectedItems[index] = selectedItems[index].withQuantity(
            selectedItems[index].quantity + 1,
          );
        } else {
          selectedItems.add(
            OrderItem(
              catalogProductId: selected.id,
              name: selected.name,
              unitPrice: selected.price,
              components: List.of(selected.components),
            ),
          );
        }
      });
      _scheduleDraftSave();
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Không thể tải catalog');
      }
    }
  }

  Future<void> pickDeliveryDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final currentDay = DateUtils.dateOnly(delivery);
    final date = await showDatePicker(
      context: context,
      initialDate: currentDay.isBefore(today) ? today : currentDay,
      firstDate: today,
      lastDate: DateTime(2100, 12, 31),
      helpText: 'CHỌN NGÀY GIAO',
      cancelText: 'HỦY',
      confirmText: 'TIẾP THEO',
    );
    if (date == null || !mounted) {
      return;
    }
    setState(() {
      delivery = _deliveryOnDay(date, delivery);
      _deliveryWasValid = true;
    });
    _scheduleDraftSave();
    await pickDeliveryTime();
  }

  Future<void> pickDeliveryTime() async {
    final now = DateTime.now();
    if (DateUtils.dateOnly(delivery).isBefore(DateUtils.dateOnly(now))) {
      await pickDeliveryDate();
      return;
    }
    final minimum = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(const Duration(minutes: 1));
    var candidate = _deliveryOnDay(delivery, delivery);
    final chosen = await showModalBottomSheet<DateTime>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: 300,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Chọn giờ · ${dayLabel(delivery)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext, candidate),
                      child: const Text('Xong'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  minimumDate: DateUtils.isSameDay(delivery, now)
                      ? minimum
                      : null,
                  initialDateTime: candidate,
                  use24hFormat: true,
                  onDateTimeChanged: (value) => candidate = value,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null || !mounted) {
      return;
    }
    final picked = DateTime(
      delivery.year,
      delivery.month,
      delivery.day,
      chosen.hour,
      chosen.minute,
    );
    final issue = deliveryTimeIssue(picked);
    if (issue != null) {
      AppToast.show(context, issue);
      return;
    }
    setState(() {
      delivery = picked;
      _deliveryWasValid = true;
    });
    _scheduleDraftSave();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.initialOrder == null ? 'Tạo đơn hoa' : 'Sửa đơn hoa'),
      actions: [
        if (widget.initialOrder == null && _hasDraft)
          IconButton(
            tooltip: 'Xóa bản nháp',
            onPressed: _discardDraft,
            icon: const Icon(Icons.delete_outline),
          ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bước ${step + 1}/4',
                  style: const TextStyle(
                    color: _rose,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: (step + 1) / 4,
                  minHeight: 5,
                  backgroundColor: FlowerTemplateTheme.line,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 18),
                Text(
                  ['Khách hàng', 'Sản phẩm', 'Giao hàng', 'Thanh toán'][step],
                  style: const TextStyle(
                    fontFamily: FlowerTemplateTheme.headingFont,
                    fontSize: 25,
                    height: 1.3,
                    color: _ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (step == 0) ...[
                  _field(
                    name,
                    'Tên khách hàng',
                    textInputAction: TextInputAction.next,
                  ),
                  _field(
                    phone,
                    'Số điện thoại (không bắt buộc)',
                    keyboard: TextInputType.phone,
                    required: false,
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      name.text = 'Khách vãng lai';
                      phone.clear();
                      _scheduleDraftSave();
                    }),
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Khách vãng lai'),
                  ),
                  if (name.text.trim().length >= 2 ||
                      phone.text.trim().length >= 2)
                    FutureBuilder<List<CustomerSummary>>(
                      future: widget.repository.customers(
                        query: phone.text.trim().length >= 2
                            ? phone.text
                            : name.text,
                      ),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Card(
                          child: Column(
                            children: [
                              const ListTile(
                                title: Text('Khách đã mua'),
                                dense: true,
                              ),
                              for (final customer in snapshot.data!.take(5))
                                ListTile(
                                  title: Text(customer.name),
                                  subtitle: Text(
                                    customer.phone.isEmpty
                                        ? '${customer.orderCount} đơn'
                                        : '${customer.phone} · ${customer.orderCount} đơn',
                                  ),
                                  onTap: () => setState(() {
                                    name.text = customer.name;
                                    phone.text = customer.phone;
                                    _scheduleDraftSave();
                                  }),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
                if (step == 1) ...[
                  OutlinedButton.icon(
                    onPressed: chooseProduct,
                    icon: const Icon(Icons.local_florist_outlined),
                    label: const Text('Thêm từ mẫu hoa'),
                  ),
                  const SizedBox(height: 12),
                  for (var index = 0; index < selectedItems.length; index++)
                    Card(
                      child: ListTile(
                        title: Text(selectedItems[index].name),
                        subtitle: Text(
                          '${money(selectedItems[index].unitPrice)} × ${selectedItems[index].quantity} = ${money(selectedItems[index].total)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip:
                                  'Giảm số lượng ${selectedItems[index].name}',
                              onPressed: () => changeItemQuantity(
                                index,
                                selectedItems[index].quantity - 1,
                              ),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Text('${selectedItems[index].quantity}'),
                            IconButton(
                              tooltip:
                                  'Tăng số lượng ${selectedItems[index].name}',
                              onPressed: () => changeItemQuantity(
                                index,
                                selectedItems[index].quantity + 1,
                              ),
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (selectedItems.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Tiền sản phẩm: ${money(itemsPrice)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  _field(
                    product,
                    'Tên sản phẩm thêm thủ công',
                    onChanged: (_) => components = [],
                    required: selectedItems.isEmpty,
                  ),
                  _field(
                    price,
                    'Giá sản phẩm thêm thủ công (đ)',
                    keyboard: TextInputType.number,
                    required: selectedItems.isEmpty,
                  ),
                  OutlinedButton.icon(
                    onPressed: addManualProduct,
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm sản phẩm'),
                  ),
                  Text(
                    orderItemsComponents(selectedItems).isEmpty
                        ? 'Chưa có định lượng hoa cho đơn này'
                        : '${orderItemsComponents(selectedItems).length} loại hoa đã được lưu vào đơn',
                  ),
                ],
                if (step == 2) ...[
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.calendar_month, color: _rose),
                      title: const RequiredLabel('Ngày giao'),
                      subtitle: Text(dayLabel(delivery)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: pickDeliveryDate,
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.schedule, color: _rose),
                      title: const RequiredLabel('Giờ giao'),
                      subtitle: Text(
                        DateFormat('HH:mm', 'vi').format(delivery),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: pickDeliveryTime,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _field(address, 'Địa chỉ giao'),
                  _field(
                    note,
                    'Ghi chú (không bắt buộc)',
                    maxLines: 3,
                    required: false,
                  ),
                ],
                if (step == 3) ...[
                  if (deliveryIssue() != null)
                    TextButton.icon(
                      onPressed: () => setState(() => step = 2),
                      icon: const Icon(Icons.schedule),
                      label: const Text('Chọn lại giờ giao'),
                    ),
                  _field(
                    shipping,
                    'Phí giao (đ)',
                    keyboard: TextInputType.number,
                  ),
                  _field(
                    paid,
                    'Đã thu / tiền cọc (đ)',
                    keyboard: TextInputType.number,
                    enabled: widget.initialOrder == null,
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tổng: ${money(itemsPrice + (parseMoney(shipping.text) ?? 0))}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Còn lại: ${money((itemsPrice + (parseMoney(shipping.text) ?? 0) - (parseMoney(paid.text) ?? 0)).clamp(0, 999999999999))}',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: FlowerTemplateTheme.line)),
            ),
            child: Row(
              children: [
                if (step > 0)
                  TextButton(
                    onPressed: saving
                        ? null
                        : () {
                            setState(() => step--);
                            _scheduleDraftSave();
                          },
                    child: const Text('Quay lại'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: saving || (step == 3 && deliveryIssue() != null)
                      ? null
                      : next,
                  child: Text(
                    saving
                        ? 'Đang lưu...'
                        : step == 3
                        ? widget.initialOrder == null
                              ? 'Lưu đơn'
                              : 'Cập nhật đơn'
                        : 'Tiếp tục',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboard,
    TextInputAction? textInputAction,
    int maxLines = 1,
    bool enabled = true,
    bool required = true,
    void Function(String)? onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboard,
      inputFormatters: keyboard == TextInputType.number
          ? [MoneyInputFormatter(Localizations.localeOf(context).toString())]
          : null,
      textInputAction: textInputAction,
      maxLines: maxLines,
      onChanged: (value) {
        onChanged?.call(value);
        setState(() {});
        _scheduleDraftSave();
      },
      decoration: InputDecoration(
        label: required ? RequiredLabel(label) : Text(label),
      ),
    ),
  );
}
