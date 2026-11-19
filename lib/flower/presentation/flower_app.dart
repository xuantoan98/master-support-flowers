import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

import '../data/address_suggester.dart';
import '../data/contact_picker.dart';
import '../data/live_activity_service.dart';
import '../data/order_reminder_service.dart';
import '../data/order_repository.dart';
import '../domain/business_stats.dart';
import '../domain/calendar_overview.dart';
import '../domain/catalog_product.dart';
import '../domain/flower_order.dart';
import '../domain/order_item.dart';
import '../domain/order_summary.dart';
import 'address_field.dart';
import 'app_toast.dart';
import 'calendar_widgets.dart';
import 'catalog_product_image.dart';
import 'catalog_screen.dart';
import 'flower_dock.dart';
import 'flower_template_theme.dart';
import 'flower_template_widgets.dart';
import 'invoice_screen.dart';
import 'money_input_formatter.dart';
import 'order_media_section.dart';
import 'order_success.dart';
import 'shop_profile_screen.dart';
import 'shopping_list_screen.dart';
import 'step_progress.dart';

String money(int value) =>
    '${NumberFormat.decimalPattern(Intl.getCurrentLocale()).format(value)} đ';
String dayLabel(DateTime value) => DateFormat('dd/MM/yyyy', 'vi').format(value);

Color _statusColor(OrderStatus status) => switch (status) {
  OrderStatus.newOrder => FlowerTemplateTheme.navy,
  OrderStatus.making => const Color(0xFFC0765B),
  OrderStatus.awaitingApproval => const Color(0xFF6975A2),
  OrderStatus.delivering => const Color(0xFF3E6C98),
  OrderStatus.delivered => FlowerTemplateTheme.deepSage,
  OrderStatus.cancelled => FlowerTemplateTheme.muted,
};

IconData _statusIcon(OrderStatus status) => switch (status) {
  OrderStatus.newOrder => Icons.auto_awesome_rounded,
  OrderStatus.making => Icons.content_cut_rounded,
  OrderStatus.awaitingApproval => Icons.thumb_up_alt_rounded,
  OrderStatus.delivering => Icons.pedal_bike_rounded,
  OrderStatus.delivered => Icons.verified_rounded,
  OrderStatus.cancelled => Icons.cancel_rounded,
};

Color _statusColorOf(BuildContext context, OrderStatus status) =>
    context.palette.adapt(_statusColor(status));

ThemeMode _themeModeFrom(String value) => switch (value) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

class FlowerApp extends StatefulWidget {
  const FlowerApp({
    super.key,
    required this.repository,
    this.locale = const Locale('vi'),
  });
  final OrderRepository repository;
  final Locale locale;

  @override
  State<FlowerApp> createState() => _FlowerAppState();
}

class _FlowerAppState extends State<FlowerApp> {
  final themeMode = ValueNotifier(ThemeMode.system);

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final value = await widget.repository.themePreference();
      themeMode.value = _themeModeFrom(value);
    } catch (_) {
      // Keep following the system setting when preferences cannot be read.
    }
  }

  @override
  void dispose() {
    themeMode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    Intl.defaultLocale = locale.languageCode;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeMode,
      builder: (context, mode, _) => MaterialApp(
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
        darkTheme: FlowerTemplateTheme.dark(),
        themeMode: mode,
        home: FlowerHome(repository: widget.repository, themeMode: themeMode),
      ),
    );
  }
}

class FlowerHome extends StatefulWidget {
  const FlowerHome({super.key, required this.repository, this.themeMode});
  final OrderRepository repository;

  /// Shared with [FlowerApp]; null hides the appearance setting.
  final ValueNotifier<ThemeMode>? themeMode;

  @override
  State<FlowerHome> createState() => _FlowerHomeState();
}

class _FlowerHomeState extends State<FlowerHome> with WidgetsBindingObserver {
  final liveActivity = LiveActivityService();
  bool liveActivityEnabled = false;
  bool updatingLiveActivity = false;
  final reminders = OrderReminderService();
  bool remindersEnabled = false;
  bool updatingReminders = false;
  int tab = 0;
  final orderSearch = TextEditingController();
  OrderStatus? orderStatusFilter;
  DateTime? orderDayFilter;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime selected = DateTime.now();
  bool get selectedDayIsPast =>
      DateUtils.dateOnly(selected).isBefore(DateUtils.dateOnly(DateTime.now()));
  List<FlowerOrder> orders = [];
  List<OrderPayment> statsPayments = [];
  StatsWindow statsWindow = StatsWindow.at(StatsPeriod.month, DateTime.now());
  bool statsLoading = false;
  String? statsError;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !updatingReminders) {
      refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  void shiftCalendar(int offset) {
    HapticFeedback.selectionClick();
    final next = DateTime(month.year, month.month + offset);
    final now = DateTime.now();
    setState(() {
      month = next;
      selected = next.year == now.year && next.month == now.month
          ? DateUtils.dateOnly(now)
          : next;
    });
  }

  void selectDay(DateTime day) {
    HapticFeedback.selectionClick();
    setState(() {
      selected = day;
      month = DateTime(day.year, day.month);
    });
  }

  Future<void> refresh() async {
    try {
      final result = await widget.repository.all();
      final enabled = await widget.repository.remindersEnabled();
      final liveEnabled =
          Platform.isIOS && await widget.repository.liveActivityEnabled();
      if (mounted) {
        setState(() {
          orders = result;
          remindersEnabled = enabled;
          liveActivityEnabled = liveEnabled;
          loading = false;
          error = null;
        });
      }
      if (enabled) {
        try {
          await reminders.sync(result, enabled: true);
        } catch (_) {
          if (mounted) {
            AppToast.show(context, 'Không thể cập nhật nhắc việc');
          }
        }
      }
      if (Platform.isIOS) {
        try {
          await liveActivity.sync(result, enabled: liveEnabled);
        } catch (_) {
          if (mounted && liveEnabled) {
            AppToast.show(context, 'Không thể cập nhật Live Activity');
          }
        }
      }
      if (tab == 2) {
        await loadStatsPayments();
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

  Future<void> loadStatsPayments() async {
    if (!mounted) {
      return;
    }
    setState(() {
      statsLoading = true;
      statsError = null;
    });
    try {
      final payments = await widget.repository.allPayments();
      if (mounted) {
        setState(() {
          statsPayments = payments;
          statsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          statsLoading = false;
          statsError = 'Không thể tải giao dịch để tính thống kê';
        });
      }
    }
  }

  void changeTab(int value) {
    setState(() => tab = value);
    if (value == 2) {
      loadStatsPayments();
    }
  }

  void selectStatsPeriod(StatsPeriod period) {
    final now = DateTime.now();
    final anchor = statsWindow.contains(now)
        ? now
        : DateTime.fromMillisecondsSinceEpoch(
            (statsWindow.start.millisecondsSinceEpoch +
                    statsWindow.end.millisecondsSinceEpoch) ~/
                2,
          );
    setState(() => statsWindow = StatsWindow.at(period, anchor));
  }

  Future<void> toggleReminders(bool enabled) async {
    if (updatingReminders) {
      return;
    }
    setState(() => updatingReminders = true);
    try {
      if (enabled && !await reminders.requestPermission()) {
        if (mounted) {
          AppToast.show(context, 'Hãy cho phép thông báo và nhắc đúng giờ');
        }
        return;
      }
      await reminders.sync(orders, enabled: enabled);
      await widget.repository.setRemindersEnabled(enabled);
      if (mounted) {
        setState(() => remindersEnabled = enabled);
      }
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Không thể thay đổi nhắc việc');
      }
    } finally {
      if (mounted) {
        setState(() => updatingReminders = false);
      }
    }
  }

  Future<void> changeThemeMode(
    ValueNotifier<ThemeMode> notifier,
    ThemeMode mode,
  ) async {
    final previous = notifier.value;
    notifier.value = mode;
    try {
      await widget.repository.setThemePreference(mode.name);
    } catch (_) {
      notifier.value = previous;
      if (mounted) {
        AppToast.show(context, 'Không thể lưu giao diện');
      }
    }
  }

  Future<void> toggleLiveActivity(bool enabled) async {
    if (updatingLiveActivity) {
      return;
    }
    setState(() => updatingLiveActivity = true);
    try {
      if (enabled && !await liveActivity.isAvailable()) {
        if (mounted) {
          AppToast.show(
            context,
            'Live Activity cần iPhone hỗ trợ và quyền trong Cài đặt',
          );
        }
        return;
      }
      await liveActivity.sync(orders, enabled: enabled);
      await widget.repository.setLiveActivityEnabled(enabled);
      if (mounted) {
        setState(() => liveActivityEnabled = enabled);
      }
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Không thể thay đổi Live Activity');
      }
    } finally {
      if (mounted) {
        setState(() => updatingLiveActivity = false);
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
      HapticFeedback.mediumImpact();
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
    extendBody: true,
    appBar: tab == 0
        ? null
        : AppBar(
            title: Text(['Lịch giao', 'Đơn hàng', 'Thống kê', 'Cá nhân'][tab]),
          ),
    body: loading
        ? (tab == 0
              ? const SafeArea(child: CalendarSkeleton())
              : const Center(child: CircularProgressIndicator()))
        : error != null
        ? SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error!),
                  TextButton(onPressed: refresh, child: const Text('Thử lại')),
                ],
              ),
            ),
          )
        : switch (tab) {
            0 => _calendarView(),
            1 => _ordersView(),
            2 => _statsView(),
            _ => _profileView(),
          },
    bottomNavigationBar: FlowerDock(
      selectedIndex: tab,
      onSelected: changeTab,
      onCreate: tab == 0 && selectedDayIsPast ? null : createOrder,
      items: const [
        FlowerDockItem(
          icon: Icons.calendar_month_outlined,
          selectedIcon: Icons.calendar_month,
          label: 'Lịch',
        ),
        FlowerDockItem(
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
          label: 'Đơn hàng',
        ),
        FlowerDockItem(
          icon: Icons.bar_chart_outlined,
          selectedIcon: Icons.bar_chart,
          label: 'Thống kê',
        ),
        FlowerDockItem(
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          label: 'Cá nhân',
        ),
      ],
    ),
  );

  Widget _calendarView() {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final day = DateUtils.dateOnly(selected);
    final active = orders
        .where((o) => o.status != OrderStatus.cancelled)
        .toList();
    final byDay = groupByDeliveryDay(active);
    final selectedOrders = byDay[day] ?? const <FlowerOrder>[];
    final summary = summarizeOrders(active, deliveryMonth: month);
    final previous = summarizeOrders(
      active,
      deliveryMonth: DateTime(month.year, month.month - 1),
    );
    final todayOrders = byDay[today] ?? const <FlowerOrder>[];
    final openToday = todayOrders.where(isUnfinished).length;
    final attention = ordersNeedingAttention(active, now);
    final overdueCount = attention.where((o) => isOverdue(o, now)).length;
    final occasion = currentOccasion(now);
    final dayEyebrow = DateUtils.isSameDay(day, today)
        ? 'HÔM NAY'
        : DateFormat('EEEE', 'vi').format(day).toUpperCase();
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          toolbarHeight: 76,
          centerTitle: false,
          titleSpacing: 20,
          backgroundColor: context.palette.canvas,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0.5,
          shadowColor: context.palette.line,
          title: Text(
            'Tiệm Hoa',
            style: TextStyle(
              fontFamily: FlowerTemplateTheme.headingFont,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: context.palette.ink,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Đơn cần chú ý',
              onPressed: () => _showAttention(attention, now),
              icon: Badge(
                isLabelVisible: attention.isNotEmpty,
                backgroundColor: context.palette.adapt(calendarOverdueColor),
                label: Text('${attention.length}'),
                child: const Icon(Icons.notifications_none),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
          sliver: SliverList.list(
            children: [
              Text(
                '${greetingFor(now)} ${occasion == null ? '🌷' : occasionStyle(occasion.occasion).emoji}',
                style: TextStyle(
                  color: occasion == null
                      ? context.palette.accent
                      : context.palette.adapt(
                          occasionStyle(occasion.occasion).color,
                        ),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (openToday == 0)
                    'Hôm nay chưa có đơn cần giao'
                  else
                    'Hôm nay có $openToday đơn cần giao',
                  if (overdueCount > 0) '$overdueCount đơn quá hạn',
                ].join(' · '),
                style: TextStyle(
                  fontSize: 13,
                  color: overdueCount > 0
                      ? context.palette.adapt(calendarOverdueColor)
                      : context.palette.muted,
                ),
              ),
              if (occasion != null) ...[
                const SizedBox(height: 12),
                OccasionBanner(window: occasion),
              ],
              const SizedBox(height: 14),
              DeliveryCalendar(
                month: month,
                selected: day,
                today: today,
                ordersByDay: byDay,
                onSelect: selectDay,
                onShift: shiftCalendar,
                onOpenOrder: showOrder,
              ),
              const SizedBox(height: 22),
              TemplateSectionHeading(
                eyebrow: dayEyebrow,
                title: 'Lịch giao ${dayLabel(day)}',
                trailing: selectedOrders.isEmpty
                    ? null
                    : Text(
                        '${selectedOrders.length} đơn',
                        style: TextStyle(color: context.palette.muted),
                      ),
              ),
              const SizedBox(height: 12),
              if (selectedOrders.isEmpty)
                _dayEmpty(past: day.isBefore(today))
              else
                ...selectedOrders.map(_swipeableOrderCard),
              const SizedBox(height: 14),
              TemplateSectionHeading(
                eyebrow: 'TỔNG QUAN',
                title: monthTitle(month),
              ),
              const SizedBox(height: 12),
              OverviewBento(
                month: month,
                summary: summary,
                previousSummary: previous,
                todayCount: todayOrders.length,
                todayOpen: openToday,
                money: money,
                weekly: weeklyRevenue(active, month),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dayEmpty({required bool past}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.palette.line),
    ),
    child: Column(
      children: [
        const TemplateIconBadge(icon: Icons.local_florist_outlined, size: 40),
        const SizedBox(height: 10),
        Text(
          past
              ? 'Ngày này không có đơn giao'
              : 'Chưa có đơn giao trong ngày này',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.palette.muted),
        ),
        if (!past) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: createOrder,
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Tạo đơn cho ngày này'),
          ),
        ],
      ],
    ),
  );

  Future<void> _showAttention(
    List<FlowerOrder> attention,
    DateTime now,
  ) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Đơn cần chú ý',
                style: TextStyle(
                  fontFamily: FlowerTemplateTheme.headingFont,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (attention.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Text('Không có đơn nào cần chú ý 🌷'),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final order in attention)
                      ListTile(
                        leading: Icon(
                          isOverdue(order, now)
                              ? Icons.warning_amber_rounded
                              : Icons.schedule,
                          color: isOverdue(order, now)
                              ? context.palette.adapt(calendarOverdueColor)
                              : _statusColorOf(context, order.status),
                        ),
                        title: Text(
                          '${order.customerName} · ${order.productName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${isOverdue(order, now) ? 'Quá hạn' : 'Hôm nay'} · '
                          '${DateFormat('HH:mm dd/MM', 'vi').format(order.deliveryAt)} · '
                          '${order.status.label}',
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          showOrder(order);
                        },
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Future<void> advanceStatus(FlowerOrder order, OrderStatus next) async {
    try {
      await widget.repository.updateStatus(order, next);
      HapticFeedback.mediumImpact();
      if (mounted) {
        AppToast.show(context, 'Đơn #${order.id}: ${next.label}');
      }
      await refresh();
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Không thể cập nhật trạng thái');
      }
    }
  }

  Widget _swipeableOrderCard(FlowerOrder order) {
    final card = _orderCard(order);
    final next = nextForwardStatus(order.status);
    if (next == null || order.id == null) {
      return card;
    }
    final color = _statusColorOf(context, next);
    return Dismissible(
      key: ValueKey('swipe-${order.id}-${order.status.index}'),
      direction: DismissDirection.startToEnd,
      dismissThresholds: const {DismissDirection.startToEnd: 0.4},
      confirmDismiss: (_) async {
        await advanceStatus(order, next);
        return false;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_forward, color: color),
            const SizedBox(width: 8),
            Text(
              'Chuyển sang "${next.label}"',
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      child: card,
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
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      children: [
        TemplateSectionHeading(
          eyebrow: 'QUẢN LÝ',
          title: 'Đơn hàng của bạn',
          trailing: Text(
            '${visible.length} đơn',
            style: TextStyle(color: context.palette.muted),
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
          ...visible.map(_swipeableOrderCard),
      ],
    );
  }

  Widget _statsView() {
    final report = calculateBusinessStats(orders, statsPayments, statsWindow);
    final biggestBucket = report.buckets.fold<int>(
      0,
      (value, bucket) => bucket.revenue > value ? bucket.revenue : value,
    );
    const weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      children: [
        const TemplateSectionHeading(
          eyebrow: 'HIỆU QUẢ KINH DOANH',
          title: 'Thống kê cửa hàng',
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          children: [
            for (final period in StatsPeriod.values)
              ChoiceChip(
                label: Text(switch (period) {
                  StatsPeriod.week => 'Tuần',
                  StatsPeriod.month => 'Tháng',
                  StatsPeriod.quarter => 'Quý',
                  StatsPeriod.year => 'Năm',
                }),
                selected: statsWindow.period == period,
                onSelected: (_) => selectStatsPeriod(period),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              tooltip: 'Kỳ trước',
              onPressed: () =>
                  setState(() => statsWindow = statsWindow.shift(-1)),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                _statsWindowLabel(statsWindow),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Kỳ sau',
              onPressed: () =>
                  setState(() => statsWindow = statsWindow.shift(1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        if (statsLoading) const LinearProgressIndicator(),
        if (statsError != null)
          TextButton(
            onPressed: loadStatsPayments,
            child: Text('$statsError · Thử lại'),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _metric(
                'Doanh thu đã giao',
                money(report.deliveredRevenue),
                Icons.check_circle_outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metric(
                'Giá trị đơn trong kỳ',
                money(report.bookedRevenue),
                Icons.spa_outlined,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: _metric(
                'Tiền thu ròng',
                money(report.netCash),
                Icons.payments_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metric(
                'Còn phải thu',
                money(report.outstanding),
                Icons.local_shipping_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${report.orderCount} đơn · ${report.deliveredCount} đã giao · ${report.pendingCount} chưa giao',
          style: TextStyle(color: context.palette.muted),
        ),
        const SizedBox(height: 4),
        Text(
          'Đã thu ${money(report.receipts)} · Hoàn ${money(report.refunds)}',
          style: TextStyle(color: context.palette.muted),
        ),
        if (report.orderCount == 0 &&
            report.receipts == 0 &&
            report.refunds == 0)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('Chưa có đơn hoặc giao dịch trong kỳ này.'),
          ),
        const SizedBox(height: 20),
        const TemplateSectionHeading(title: 'Doanh thu đã giao'),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (final bucket in report.buckets)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        SizedBox(width: 56, child: Text(bucket.label)),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: biggestBucket == 0
                                ? 0
                                : bucket.revenue / biggestBucket,
                            minHeight: 9,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 84,
                          child: Text(
                            money(bucket.revenue),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const TemplateSectionHeading(title: 'Khách và sản phẩm'),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('Khách quay lại'),
                subtitle: const Text(
                  'Từ 2 đơn chưa hủy cùng tên và số điện thoại',
                ),
                trailing: Text('${report.repeatCustomers}'),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Ngày và buổi đông đơn'),
                subtitle: Text(
                  report.busiestWeekday == null
                      ? 'Chưa có đơn trong kỳ'
                      : '${weekdays[report.busiestWeekday! - 1]} · ${report.busiestDaypart}',
                ),
              ),
              const ListTile(
                leading: Icon(Icons.local_florist_outlined),
                title: Text('Mẫu hoa bán chạy'),
                subtitle: Text('Theo số lượng trong đơn đã giao'),
              ),
              if (report.topProducts.isEmpty)
                const ListTile(title: Text('Chưa có sản phẩm đã giao trong kỳ'))
              else
                for (final (index, product) in report.topProducts.indexed)
                  ListTile(
                    leading: Text('${index + 1}.'),
                    title: Text(product.name),
                    trailing: Text('${product.quantity}'),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Doanh thu theo ngày giao của đơn đã giao. Tiền thu và hoàn theo ngày giao dịch; giá trị đơn và công nợ theo ngày giao, không tính đơn hủy.',
          style: TextStyle(color: context.palette.muted),
        ),
      ],
    );
  }

  String _statsWindowLabel(StatsWindow window) => switch (window.period) {
    StatsPeriod.week =>
      '${dayLabel(window.start)} – ${dayLabel(window.end.subtract(const Duration(days: 1)))}',
    StatsPeriod.month => 'Tháng ${window.start.month}/${window.start.year}',
    StatsPeriod.quarter =>
      'Quý ${((window.start.month - 1) ~/ 3) + 1}/${window.start.year}',
    StatsPeriod.year => 'Năm ${window.start.year}',
  };

  Widget _profileView() => ListView(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
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
          leading: const Icon(Icons.storefront_outlined),
          title: const Text('Hồ sơ shop & tài khoản'),
          subtitle: const Text('Thông tin hóa đơn và ảnh QR ngân hàng'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => ShopProfileScreen(repository: widget.repository),
            ),
          ),
        ),
      ),
      if (widget.themeMode case final notifier?)
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.palette_outlined),
                    SizedBox(width: 16),
                    Text('Giao diện'),
                  ],
                ),
                const SizedBox(height: 12),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: notifier,
                  builder: (context, mode, _) => SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('Theo máy'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_outlined),
                          label: Text('Sáng'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_outlined),
                          label: Text('Tối'),
                        ),
                      ],
                      selected: {mode},
                      onSelectionChanged: (value) =>
                          changeThemeMode(notifier, value.single),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      Card(
        child: SwitchListTile(
          secondary: const Icon(Icons.notifications_active_outlined),
          title: const Text('Nhắc việc'),
          subtitle: const Text('Trước giờ giao, quá giờ giao và công nợ'),
          value: remindersEnabled,
          onChanged: updatingReminders ? null : toggleReminders,
        ),
      ),
      if (Platform.isIOS)
        Card(
          child: SwitchListTile(
            secondary: const Icon(Icons.delivery_dining_outlined),
            title: const Text('Live Activity'),
            subtitle: const Text('iOS 16.2+ · Đơn đang giao trên màn khóa'),
            value: liveActivityEnabled,
            onChanged: updatingLiveActivity ? null : toggleLiveActivity,
          ),
        ),
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
          subtitle: Text('Sao lưu và đồng bộ nhiều máy sẽ được bổ sung sau.'),
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
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.palette.ink,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            maxLines: 2,
            style: TextStyle(color: context.palette.muted, fontSize: 12),
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
            CatalogProductImage(path: orderThumbnail(order), size: 80),
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
                    style: TextStyle(
                      color: context.palette.muted,
                      fontSize: 11,
                    ),
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
                          color: _statusColorOf(
                            context,
                            order.status,
                          ).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          order.status.label,
                          style: TextStyle(
                            color: _statusColorOf(context, order.status),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        money(order.total),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.palette.ink,
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

  static const _statusFlow = [
    OrderStatus.newOrder,
    OrderStatus.making,
    OrderStatus.awaitingApproval,
    OrderStatus.delivering,
    OrderStatus.delivered,
  ];

  Future<void> changeStatus(OrderStatus status) async {
    if (saving || status == order.status) {
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
              onPressed: () => Navigator.pop(dialogContext, false),
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
        return;
      }
    }
    setState(() => saving = true);
    try {
      await widget.repository.updateStatus(order, status);
      HapticFeedback.mediumImpact();
      setState(() => order = order.copyWith(status: status));
      await widget.onChanged();
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Không thể cập nhật trạng thái');
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Widget _statusCard() {
    final palette = context.palette;
    final cancelled = order.status == OrderStatus.cancelled;
    final next = nextForwardStatus(order.status);
    final canCancel = order.status.allowedNext.contains(OrderStatus.cancelled);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'TRẠNG THÁI',
                  style: TextStyle(
                    color: palette.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                Text(
                  order.status.label,
                  style: TextStyle(
                    color: _statusColorOf(context, order.status),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Opacity(
              opacity: cancelled ? 0.45 : 1,
              child: StepProgressBar(
                current: cancelled ? -1 : _statusFlow.indexOf(order.status),
                allDone: order.status == OrderStatus.delivered,
                semanticsPrefix: 'Tiến trình đơn',
                steps: [
                  for (final status in _statusFlow)
                    StepItem(
                      icon: _statusIcon(status),
                      label: status.label,
                      color: _statusColor(status),
                    ),
                ],
              ),
            ),
            if (cancelled) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.cancel_outlined, size: 18, color: palette.muted),
                  const SizedBox(width: 6),
                  Text('Đơn đã hủy', style: TextStyle(color: palette.muted)),
                ],
              ),
            ],
            if (next != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: saving ? null : () => changeStatus(next),
                  style: FilledButton.styleFrom(
                    backgroundColor: _statusColorOf(context, next),
                    foregroundColor: palette.isDark
                        ? palette.canvas
                        : Colors.white,
                    minimumSize: const Size(0, 50),
                  ),
                  icon: Icon(_statusIcon(next), size: 20),
                  label: Text('Chuyển sang: ${next.label}'),
                ),
              ),
            ],
            if (canCancel)
              Center(
                child: TextButton(
                  onPressed: saving
                      ? null
                      : () => changeStatus(OrderStatus.cancelled),
                  style: TextButton.styleFrom(
                    foregroundColor: palette.adapt(calendarOverdueColor),
                  ),
                  child: const Text('Hủy đơn'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Đơn #${order.id}'),
      actions: [
        IconButton(
          tooltip: 'Hóa đơn',
          onPressed: saving
              ? null
              : () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => InvoiceScreen(
                      order: order,
                      repository: widget.repository,
                    ),
                  ),
                ),
          icon: const Icon(Icons.receipt_long_outlined),
        ),
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
                    CatalogProductImage(path: orderThumbnail(order), size: 88),
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
                            style: TextStyle(
                              color: context.palette.primary,
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
        _statusCard(),
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
        OutlinedButton.icon(
          onPressed: saving
              ? null
              : () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => InvoiceScreen(
                      order: order,
                      repository: widget.repository,
                    ),
                  ),
                ),
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('Xem và chia sẻ hóa đơn'),
        ),
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
                        leading: Icon(
                          Icons.history,
                          color: context.palette.muted,
                        ),
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
                        leading: Icon(
                          Icons.edit_note,
                          color: context.palette.muted,
                        ),
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
          child: Text(label, style: TextStyle(color: context.palette.muted)),
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
    this.addressSuggester,
    this.contactPicker = pickSystemContact,
  });
  final OrderRepository repository;
  final FlowerOrder? initialOrder;
  final DateTime? deliveryDay;

  /// Map suggestions for the delivery address; defaults to Goong when the
  /// build has a `GOONG_API_KEY`, otherwise the field is manual only.
  final AddressSuggester? addressSuggester;

  /// Fills the customer step from the phone's address book.
  final ContactPicker contactPicker;
  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  late final AddressSuggester? _addressSuggester =
      widget.addressSuggester ?? GoongAddressSuggester.fromEnvironment();
  final name = TextEditingController();
  final phone = TextEditingController();
  final product = TextEditingController();
  final price = TextEditingController();
  final productFocus = FocusNode();
  final priceFocus = FocusNode();

  /// Quantity for the manual product being typed, shown before it is added.
  int manualQuantity = 1;
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
        manualQuantity = ((draft['manualQuantity'] as int?) ?? 1).clamp(1, 999);
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
    'manualQuantity': manualQuantity,
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
    productFocus.dispose();
    priceFocus.dispose();
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

  void addManualProduct({bool focusNext = false}) {
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
        ).withQuantity(manualQuantity),
      );
      product.clear();
      price.clear();
      components = [];
      manualQuantity = 1;
    });
    _scheduleDraftSave();
    if (focusNext) {
      _focusTextField(productFocus);
    }
  }

  /// Moves focus to a text field and makes sure the keyboard switches back
  /// from a numeric layout: some Android keyboards keep the previous input
  /// type when focus jumps between fields, so close the input connection
  /// first and reopen it on the next frame.
  void _focusTextField(FocusNode node) {
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && node.canRequestFocus) {
        node.requestFocus();
      }
    });
  }

  Future<void> pickFromContacts() async {
    final PickedContact? contact;
    try {
      contact = await widget.contactPicker();
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Không mở được danh bạ');
      }
      return;
    }
    if (contact == null || !mounted) {
      return;
    }
    if (contact.name.isEmpty && contact.phone.isEmpty) {
      AppToast.show(context, 'Liên hệ này chưa có tên hoặc số điện thoại');
      return;
    }
    setState(() {
      if (contact!.name.isNotEmpty) {
        name.text = contact.name;
      }
      phone.text = contact.phone;
    });
    _scheduleDraftSave();
    AppToast.show(context, 'Đã điền thông tin từ danh bạ', isError: false);
  }

  void changeManualQuantity(int quantity) {
    setState(() => manualQuantity = quantity.clamp(1, 999));
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

  static const _reviewStep = 4;

  bool get reviewing => step == _reviewStep;

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
    if (step == 3) {
      // Nothing is saved until the shop confirms the summary.
      setState(() => step = _reviewStep);
      _scheduleDraftSave();
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
      if (mounted && widget.initialOrder == null) {
        await showOrderSuccess(context);
      }
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
                            trailing: Icon(
                              Icons.add_circle_outline,
                              color: context.palette.primary,
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
      title: Column(
        children: [
          Text(
            widget.initialOrder == null ? 'Tạo đơn hoa' : 'Sửa đơn hoa',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.palette.muted,
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              [
                'Khách hàng',
                'Sản phẩm',
                'Giao hàng',
                'Thanh toán',
                'Xác nhận đơn',
              ][step],
              key: ValueKey(step),
            ),
          ),
        ],
      ),
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
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 10),
            child: StepProgressBar(
              current: step,
              allDone: reviewing,
              semanticsPrefix: reviewing ? 'Xem lại đơn' : 'Bước ${step + 1}/4',
              onStepTap: saving
                  ? null
                  : (index) {
                      setState(() => step = index);
                      _scheduleDraftSave();
                    },
              steps: const [
                StepItem(icon: Icons.person_rounded, label: 'Khách hàng'),
                StepItem(icon: Icons.local_florist_rounded, label: 'Sản phẩm'),
                StepItem(
                  icon: Icons.event_available_rounded,
                  label: 'Giao hàng',
                ),
                StepItem(icon: Icons.payments_rounded, label: 'Thanh toán'),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      24,
                      24,
                      24,
                      24 + FloatingFormBar.reservedHeight,
                    ),
                    children: [
                      if (step == 0) ...[
                        OutlinedButton.icon(
                          onPressed: saving ? null : pickFromContacts,
                          icon: const Icon(Icons.contacts_rounded),
                          label: const Text('Chọn từ danh bạ'),
                        ),
                        const SizedBox(height: 14),
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
                                    for (final customer in snapshot.data!.take(
                                      5,
                                    ))
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
                        for (
                          var index = 0;
                          index < selectedItems.length;
                          index++
                        )
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
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
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
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        _field(
                          product,
                          'Tên sản phẩm thêm thủ công',
                          onChanged: (_) => components = [],
                          required: selectedItems.isEmpty,
                          focusNode: productFocus,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => priceFocus.requestFocus(),
                          onTap: () {
                            // Coming from the numeric price field: reopen the
                            // keyboard so it switches back to letters.
                            if (!productFocus.hasFocus && priceFocus.hasFocus) {
                              _focusTextField(productFocus);
                            }
                          },
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _field(
                                price,
                                'Giá thủ công (đ)',
                                keyboard: TextInputType.number,
                                required: selectedItems.isEmpty,
                                focusNode: priceFocus,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) {
                                  if (product.text.trim().isNotEmpty) {
                                    addManualProduct(focusNext: true);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            _ManualQuantityStepper(
                              quantity: manualQuantity,
                              onChanged: changeManualQuantity,
                            ),
                          ],
                        ),
                        if (product.text.trim().isNotEmpty &&
                            (parseMoney(price.text) ?? 0) > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              'Thành tiền: $manualQuantity × ${money(parseMoney(price.text)!)} = ${money(manualQuantity * parseMoney(price.text)!)}',
                              style: TextStyle(color: context.palette.muted),
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: () => addManualProduct(focusNext: true),
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
                            leading: Icon(
                              Icons.calendar_month,
                              color: context.palette.primary,
                            ),
                            title: const RequiredLabel('Ngày giao'),
                            subtitle: Text(dayLabel(delivery)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: pickDeliveryDate,
                          ),
                        ),
                        Card(
                          child: ListTile(
                            leading: Icon(
                              Icons.schedule,
                              color: context.palette.primary,
                            ),
                            title: const RequiredLabel('Giờ giao'),
                            subtitle: Text(
                              DateFormat('HH:mm', 'vi').format(delivery),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: pickDeliveryTime,
                          ),
                        ),
                        const SizedBox(height: 14),
                        AddressField(
                          controller: address,
                          suggester: _addressSuggester,
                          onChanged: () {
                            setState(() {});
                            _scheduleDraftSave();
                          },
                        ),
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
                      if (reviewing) ..._reviewContent(),
                    ],
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: FloatingFormBar(
                    showBack: step > 0,
                    onBack: saving
                        ? null
                        : () {
                            setState(() => step--);
                            _scheduleDraftSave();
                          },
                    onPrimary: saving || (step >= 3 && deliveryIssue() != null)
                        ? null
                        : next,
                    primaryLabel: saving
                        ? 'Đang lưu...'
                        : reviewing
                        ? widget.initialOrder == null
                              ? 'Xác nhận tạo đơn'
                              : 'Xác nhận cập nhật'
                        : 'Tiếp tục',
                    primaryIcon: saving
                        ? null
                        : reviewing
                        ? Icons.check_circle_rounded
                        : Icons.arrow_forward_rounded,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  List<Widget> _reviewContent() {
    final palette = context.palette;
    final shippingFee = parseMoney(shipping.text) ?? 0;
    final paidAmount = widget.initialOrder?.paid ?? parseMoney(paid.text) ?? 0;
    final total = itemsPrice + shippingFee;
    final remaining = (total - paidAmount).clamp(0, total);
    final when = DateFormat(
      "EEEE, dd/MM/yyyy 'lúc' HH:mm",
      'vi',
    ).format(delivery);
    TextStyle muted([double size = 13]) =>
        TextStyle(fontSize: size, color: palette.muted);
    return [
      Text(
        'Kiểm tra lại thông tin. Đơn chỉ được lưu khi bạn bấm xác nhận.',
        style: muted(),
      ),
      const SizedBox(height: 12),
      _reviewCard('KHÁCH HÀNG', 0, [
        Text(
          name.text.trim(),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: palette.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          phone.text.trim().isEmpty
              ? 'Chưa có số điện thoại'
              : phone.text.trim(),
          style: muted(14),
        ),
      ]),
      _reviewCard('SẢN PHẨM', 1, [
        for (final item in selectedItems)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${item.quantity} × ${item.name}',
                    style: TextStyle(color: palette.ink),
                  ),
                ),
                Text(
                  money(item.total),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: palette.ink,
                  ),
                ),
              ],
            ),
          ),
      ]),
      _reviewCard('GIAO HÀNG', 2, [
        _reviewRow(Icons.schedule_rounded, when),
        const SizedBox(height: 8),
        _reviewRow(Icons.place_outlined, address.text.trim()),
        if (note.text.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          _reviewRow(Icons.sticky_note_2_outlined, note.text.trim()),
        ],
      ]),
      _reviewCard('THANH TOÁN', 3, [
        _reviewLine('Tiền hoa', money(itemsPrice)),
        _reviewLine('Phí giao', money(shippingFee)),
        _reviewLine('Tổng', money(total)),
        _reviewLine(
          widget.initialOrder == null ? 'Tiền cọc' : 'Đã thu',
          money(paidAmount),
        ),
        Divider(color: palette.line),
        Row(
          children: [
            Text(
              'CÒN LẠI',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: palette.ink,
              ),
            ),
            const Spacer(),
            Text(
              money(remaining),
              style: TextStyle(
                fontFamily: FlowerTemplateTheme.headingFont,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: palette.adapt(const Color(0xFFB8692F)),
              ),
            ),
          ],
        ),
      ]),
    ];
  }

  Widget _reviewCard(String title, int editStep, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 8, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: context.palette.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: saving
                    ? null
                    : () {
                        setState(() => step = editStep);
                        _scheduleDraftSave();
                      },
                child: Text(
                  'Sửa',
                  semanticsLabel: 'Sửa ${title.toLowerCase()}',
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _reviewLine(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Text(label, style: TextStyle(color: context.palette.muted)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: context.palette.ink,
          ),
        ),
      ],
    ),
  );

  Widget _reviewRow(IconData icon, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: context.palette.primary),
      const SizedBox(width: 8),
      Expanded(
        child: Text(text, style: TextStyle(color: context.palette.ink)),
      ),
    ],
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
    FocusNode? focusNode,
    ValueChanged<String>? onSubmitted,
    GestureTapCallback? onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: controller,
      focusNode: focusNode,
      onSubmitted: onSubmitted,
      onTap: onTap,
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

/// "− 2 +" control for the quantity of a product that is still being typed.
class _ManualQuantityStepper extends StatelessWidget {
  const _ManualQuantityStepper({
    required this.quantity,
    required this.onChanged,
  });

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: palette.field,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Giảm số lượng thủ công',
            onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          Semantics(
            container: true,
            label: 'Số lượng $quantity',
            excludeSemantics: true,
            child: SizedBox(
              width: 28,
              child: Text(
                '$quantity',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: palette.ink,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Tăng số lượng thủ công',
            onPressed: quantity < 999 ? () => onChanged(quantity + 1) : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}
