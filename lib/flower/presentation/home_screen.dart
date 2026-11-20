part of 'flower_app.dart';

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

  /// Tab 0 shows today's to-do list; the calendar is one tap away.
  bool calendarMode = false;
  bool skipApproval = false;

  /// Hidden until the setting is read, and in fakes without settings.
  bool swipeHintSeen = true;

  /// One-time nudge to back up once the shop has real data on the phone.
  bool backupReminderDue = false;
  static const _backupReminderMinOrders = 10;
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
      var skip = skipApproval;
      try {
        skip = await widget.repository.skipApproval();
      } catch (_) {
        // A missing setting must not block the order list.
      }
      var hintSeen = swipeHintSeen;
      try {
        hintSeen = await widget.repository.swipeHintSeen();
      } catch (_) {
        hintSeen = true;
      }
      var backupDue = false;
      if (result.length >= _backupReminderMinOrders) {
        try {
          backupDue =
              await widget.repository.lastBackupAt() == null &&
              !await widget.repository.backupReminderDismissed();
        } catch (_) {
          // A missing setting just hides the reminder.
        }
      }
      if (mounted) {
        setState(() {
          skipApproval = skip;
          swipeHintSeen = hintSeen;
          backupReminderDue = backupDue;
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
          deliveryDay: tab == 0 && calendarMode && !selectedDayIsPast
              ? selected
              : null,
        ),
      ),
    );
    if (saved ?? false) {
      HapticFeedback.mediumImpact();
      await refresh();
    }
  }

  Future<void> quickSale() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QuickSaleScreen(repository: widget.repository),
      ),
    );
    if (saved ?? false) {
      await refresh();
    }
  }

  /// The "+" button: a counter sale or an order prepared for later.
  Future<void> showCreateMenu() async {
    final choice = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const TemplateIconBadge(icon: Icons.storefront),
                title: const Text('Bán nhanh tại quầy'),
                subtitle: const Text('Khách mua và nhận hoa ngay'),
                onTap: () => Navigator.pop(sheetContext, 0),
              ),
              ListTile(
                leading: const TemplateIconBadge(icon: Icons.event_note),
                title: const Text('Tạo đơn đặt trước'),
                subtitle: const Text('Giao tận nơi hoặc khách hẹn tới lấy'),
                onTap: () => Navigator.pop(sheetContext, 1),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    if (choice == 0) {
      await quickSale();
    } else if (choice == 1) {
      await createOrder();
    }
  }

  Future<void> toggleSkipApproval(bool value) async {
    setState(() => skipApproval = value);
    try {
      await widget.repository.setSkipApproval(value);
    } catch (_) {
      if (mounted) {
        setState(() => skipApproval = !value);
        AppToast.show(context, 'Không thể lưu cài đặt');
      }
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
            title: Text(['Hôm nay', 'Đơn hàng', 'Thống kê', 'Cửa hàng'][tab]),
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
            0 => calendarMode ? _calendarView() : _todayView(),
            1 => _ordersView(),
            2 => _statsView(),
            _ => _profileView(),
          },
    bottomNavigationBar: FlowerDock(
      selectedIndex: tab,
      onSelected: changeTab,
      // Creating orders stays locked while the calendar has a past day
      // selected, as before; the today list always allows it.
      onCreate: tab == 0 && calendarMode && selectedDayIsPast
          ? null
          : showCreateMenu,
      items: const [
        FlowerDockItem(
          icon: Icons.wb_sunny_outlined,
          selectedIcon: Icons.wb_sunny,
          label: 'Hôm nay',
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
          icon: Icons.storefront_outlined,
          selectedIcon: Icons.storefront,
          label: 'Cửa hàng',
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
            'Lịch giao',
            style: TextStyle(
              fontFamily: FlowerTemplateTheme.headingFont,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: context.palette.ink,
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () => setState(() => calendarMode = false),
              icon: const Icon(Icons.wb_sunny_outlined),
              label: const Text('Hôm nay'),
            ),
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

  /// The first screen: what the shop has to do today, money still owed and
  /// flowers to buy for tomorrow. The month calendar is one tap away.
  Widget _todayView() {
    final palette = context.palette;
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final tomorrow = today.add(const Duration(days: 1));
    final active = orders
        .where((o) => o.status != OrderStatus.cancelled)
        .toList();
    final todo = ordersNeedingAttention(active, now);
    final overdueCount = todo.where((o) => isOverdue(o, now)).length;
    final owed = active.where((o) => o.remaining > 0).toList()
      ..sort((a, b) => a.deliveryAt.compareTo(b.deliveryAt));
    final owedTotal = owed.fold<int>(0, (sum, o) => sum + o.remaining);
    final doneToday = active
        .where(
          (o) =>
              o.status == OrderStatus.delivered &&
              DateUtils.isSameDay(o.deliveryAt, today),
        )
        .toList();
    final shopping = buildShoppingList(
      active,
      tomorrow,
      tomorrow.add(const Duration(days: 1)),
    );
    final tomorrowCount = active
        .where(
          (o) => isUnfinished(o) && DateUtils.isSameDay(o.deliveryAt, tomorrow),
        )
        .length;
    final occasion = currentOccasion(now);
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          toolbarHeight: 76,
          centerTitle: false,
          titleSpacing: 20,
          backgroundColor: palette.canvas,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0.5,
          shadowColor: palette.line,
          title: Text(
            'Sổ Hoa',
            style: TextStyle(
              fontFamily: FlowerTemplateTheme.headingFont,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: palette.ink,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Lịch giao theo tháng',
              onPressed: () => setState(() => calendarMode = true),
              icon: const Icon(Icons.calendar_month_outlined),
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
                      ? palette.accent
                      : palette.adapt(occasionStyle(occasion.occasion).color),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (todo.isEmpty)
                    'Không còn đơn cần làm hôm nay'
                  else
                    '${todo.length} đơn cần làm',
                  if (overdueCount > 0) '$overdueCount đơn quá hạn',
                  if (doneToday.isNotEmpty) '${doneToday.length} đơn đã xong',
                ].join(' · '),
                style: TextStyle(
                  fontSize: 14,
                  color: overdueCount > 0
                      ? palette.adapt(calendarOverdueColor)
                      : palette.muted,
                ),
              ),
              if (occasion != null) ...[
                const SizedBox(height: 12),
                OccasionBanner(window: occasion),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: quickSale,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 52),
                      ),
                      icon: const Icon(Icons.storefront),
                      label: const Text('Bán nhanh'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: createOrder,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 52),
                      ),
                      icon: const Icon(Icons.event_note),
                      label: const Text('Đặt trước'),
                    ),
                  ),
                ],
              ),
              if (backupReminderDue) ...[
                const SizedBox(height: 16),
                _backupReminder(),
              ],
              const SizedBox(height: 22),
              TemplateSectionHeading(
                eyebrow: 'CẦN LÀM',
                title: 'Đơn hôm nay',
                trailing: todo.isEmpty
                    ? null
                    : Text(
                        '${todo.length} đơn',
                        style: TextStyle(color: palette.muted),
                      ),
              ),
              const SizedBox(height: 12),
              if (todo.isEmpty)
                _empty('Hôm nay không còn đơn cần làm 🌷')
              else ...[
                ..._swipeHint(todo),
                ...todo.map(_swipeableOrderCard),
              ],
              const SizedBox(height: 18),
              TemplateSectionHeading(
                eyebrow: 'CÔNG NỢ',
                title: 'Chưa thu đủ',
                trailing: owed.isEmpty
                    ? null
                    : Text(
                        money(owedTotal),
                        style: TextStyle(
                          color: palette.adapt(const Color(0xFFB8692F)),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              if (owed.isEmpty)
                Text(
                  'Tất cả đơn đã thu đủ tiền.',
                  style: TextStyle(color: palette.muted),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (final order in owed.take(5))
                        ListTile(
                          title: Text(
                            order.customerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  '#${order.id} · ${DateFormat('HH:mm dd/MM', 'vi').format(order.deliveryAt)}',
                                ),
                                OrderStatusChip(order: order),
                              ],
                            ),
                          ),
                          trailing: Text(
                            money(order.remaining),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: palette.adapt(const Color(0xFFB8692F)),
                            ),
                          ),
                          onTap: () => showOrder(order),
                        ),
                      if (owed.length > 5)
                        TextButton(
                          onPressed: () => changeTab(1),
                          child: Text('Xem tất cả ${owed.length} đơn'),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              TemplateSectionHeading(
                eyebrow: 'NGÀY MAI',
                title: 'Cần mua cho ngày mai',
                trailing: Text(
                  '$tomorrowCount đơn',
                  style: TextStyle(color: palette.muted),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (shopping.items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            tomorrowCount == 0
                                ? 'Ngày mai chưa có đơn.'
                                : 'Các đơn ngày mai chưa có định lượng hoa.',
                            style: TextStyle(color: palette.muted),
                          ),
                        )
                      else
                        for (final item in shopping.items.take(6))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Expanded(child: Text(item.name)),
                                Text(
                                  '${item.quantity} ${item.unit}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      if (shopping.ordersWithoutRecipe > 0 &&
                          shopping.items.isNotEmpty)
                        Text(
                          '${shopping.ordersWithoutRecipe} đơn chưa có định lượng',
                          style: TextStyle(color: palette.muted, fontSize: 13),
                        ),
                      const SizedBox(height: 8),
                      // A full-width button so it reads as an action, not text.
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 46),
                          ),
                          icon: const Icon(Icons.shopping_basket_outlined),
                          onPressed: () async {
                            await Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => ShoppingListScreen(
                                  repository: widget.repository,
                                  initialPeriod: 1,
                                ),
                              ),
                            );
                            await refresh();
                          },
                          label: Text(
                            shopping.items.length > 6
                                ? 'Xem đủ ${shopping.items.length} loại hoa'
                                : 'Mở danh sách mua',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '${isOverdue(order, now) ? 'Quá hạn' : 'Hôm nay'} · '
                                '${DateFormat('HH:mm dd/MM', 'vi').format(order.deliveryAt)}',
                              ),
                              OrderStatusChip(order: order),
                            ],
                          ),
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
      if (!swipeHintSeen) {
        _markSwipeHintSeen();
      }
      if (mounted) {
        AppToast.show(
          context,
          'Đơn #${order.id}: ${order.copyWith(status: next).statusLabel}',
          isError: false,
          actionLabel: 'Hoàn tác',
          onAction: () => _undoAdvance(order, next),
        );
      }
      await refresh();
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Không thể cập nhật trạng thái');
      }
    }
  }

  void _markSwipeHintSeen() {
    setState(() => swipeHintSeen = true);
    widget.repository.setSwipeHintSeen().catchError((Object _) {});
  }

  /// Data lives only on this phone, so nudge once to make a first backup.
  /// Gone after a backup or after "Để sau".
  Widget _backupReminder() {
    final palette = context.palette;
    return Card(
      color: palette.accent.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.cloud_upload_outlined, color: palette.accent),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sao lưu dữ liệu tiệm',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Đơn và khách chỉ nằm trên máy này. Sao lưu để '
                        'không mất khi hỏng hoặc đổi máy.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Wraps the buttons onto two lines with large system text.
            OverflowBar(
              alignment: MainAxisAlignment.end,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: 4,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() => backupReminderDue = false);
                    widget.repository.setBackupReminderDismissed().catchError(
                      (Object _) {},
                    );
                  },
                  child: const Text('Để sau'),
                ),
                FilledButton(
                  onPressed: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => BackupScreen(
                          repository: widget.repository,
                          onRestored: refresh,
                        ),
                      ),
                    );
                    await refresh();
                  },
                  child: const Text('Sao lưu ngay'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Shown above order lists until the shop swipes once or closes it.
  List<Widget> _swipeHint(Iterable<FlowerOrder> list) {
    if (swipeHintSeen ||
        !list.any(
          (o) =>
              o.id != null &&
              nextStatusFor(o, skipApproval: skipApproval) != null,
        )) {
      return const [];
    }
    final palette = context.palette;
    return [
      Card(
        color: palette.accent.withValues(alpha: 0.10),
        child: ListTile(
          leading: Icon(Icons.swipe_right_alt, color: palette.accent),
          title: const Text('Vuốt thẻ đơn sang phải để chuyển bước'),
          subtitle: const Text('Lỡ tay thì bấm “Hoàn tác” trên thông báo.'),
          trailing: IconButton(
            tooltip: 'Đã hiểu',
            onPressed: _markSwipeHintSeen,
            icon: const Icon(Icons.close),
          ),
        ),
      ),
      const SizedBox(height: 8),
    ];
  }

  /// Puts a swiped order back to the status it had before the swipe.
  Future<void> _undoAdvance(FlowerOrder order, OrderStatus next) async {
    try {
      await widget.repository.updateStatus(
        order.copyWith(status: next),
        order.status,
      );
      if (mounted) {
        AppToast.show(
          context,
          'Đơn #${order.id}: trở lại ${order.statusLabel}',
          isError: false,
        );
      }
      await refresh();
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Không thể hoàn tác');
      }
    }
  }

  Widget _swipeableOrderCard(FlowerOrder order) {
    final card = _orderCard(order);
    final next = nextStatusFor(order, skipApproval: skipApproval);
    if (next == null || order.id == null) {
      return card;
    }
    final nextLabel = order.copyWith(status: next).statusLabel;
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
              'Chuyển sang "$nextLabel"',
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
    // Header and filters are built eagerly; order cards are built lazily by
    // ListView.builder so only on-screen cards are created on each rebuild.
    final header = <Widget>[
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
              orderDayFilter == null ? 'Ngày giao' : dayLabel(orderDayFilter!),
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
        ..._swipeHint(visible),
    ];
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      itemCount: header.length + visible.length,
      itemBuilder: (context, index) => index < header.length
          ? header[index]
          : _swipeableOrderCard(visible[index - header.length]),
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
                            style: const TextStyle(fontSize: 12),
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

  Widget _storeTile(
    IconData icon,
    String title,
    String subtitle,
    Widget Function() page,
  ) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        await Navigator.of(
          context,
        ).push<void>(MaterialPageRoute(builder: (_) => page()));
        await refresh();
      },
    ),
  );

  Widget _storeSection(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
    child: Text(
      title,
      style: TextStyle(
        color: context.palette.accent,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    ),
  );

  // Smaller descriptions under each store/settings tile; titles unchanged.
  Widget _profileView() => ListTileTheme.merge(
    subtitleTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontSize: 11.5,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
    child: _profileList(),
  );

  Widget _profileList() => ListView(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
    children: [
      _storeSection('HẰNG NGÀY'),
      _storeTile(
        Icons.people_outline,
        'Khách hàng',
        'Khách cũ và lịch sử đơn',
        () => CustomerScreen(repository: widget.repository),
      ),
      _storeTile(
        Icons.local_florist_outlined,
        'Mẫu hoa',
        'Giá bán và thành phần hoa',
        () => CatalogScreen(repository: widget.repository),
      ),
      _storeTile(
        Icons.shopping_basket_outlined,
        'Danh sách mua hoa',
        'Tổng hợp hoa cần mua theo ngày giao',
        () => ShoppingListScreen(repository: widget.repository),
      ),
      _storeSection('CỬA HÀNG'),
      _storeTile(
        Icons.storefront_outlined,
        'Hồ sơ shop & tài khoản',
        'Thông tin hóa đơn, ngân hàng nhận tiền',
        () => ShopProfileScreen(repository: widget.repository),
      ),
      _storeTile(
        Icons.cloud_upload_outlined,
        'Sao lưu & khôi phục',
        'Giữ dữ liệu an toàn khi mất hoặc đổi máy',
        () => BackupScreen(repository: widget.repository, onRestored: refresh),
      ),
      _storeSection('CÀI ĐẶT'),
      Card(
        child: SwitchListTile(
          secondary: const Icon(Icons.fast_forward_outlined),
          title: const Text('Bỏ qua bước Chờ duyệt'),
          subtitle: const Text(
            'Làm xong là chuyển sang giao / chờ khách lấy, không cần khách duyệt ảnh',
          ),
          value: skipApproval,
          onChanged: toggleSkipApproval,
        ),
      ),
      Card(
        child: SwitchListTile(
          secondary: const Icon(Icons.notifications_active_outlined),
          title: const Text('Nhắc việc'),
          subtitle: const Text(
            'Trước/quá giờ giao, công nợ; 20h chuẩn bị đơn ngày mai, '
            '6h đi chợ hoa, 7 ngày trước dịp lễ',
          ),
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
      const Card(
        child: ListTile(
          leading: Icon(Icons.lock_outline),
          title: Text('Dữ liệu lưu trên thiết bị'),
          subtitle: Text(
            'Không cần tài khoản. Hãy sao lưu định kỳ để không mất dữ liệu.',
          ),
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
          // Money must never be cut off: shrink to fit with large system
          // text instead of ending in "…".
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.palette.ink,
              ),
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

  Widget _orderCard(FlowerOrder order) {
    final palette = context.palette;
    final owed = order.status != OrderStatus.cancelled && order.remaining > 0;
    final when = DateFormat('HH:mm dd/MM', 'vi').format(order.deliveryAt);
    final kindIcon = switch (order.fulfillment) {
      FulfillmentType.delivery => Icons.local_shipping_outlined,
      FulfillmentType.pickup => Icons.storefront_outlined,
      FulfillmentType.counter => Icons.point_of_sale_outlined,
    };
    return Card(
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
                    Row(
                      children: [
                        Icon(kindIcon, size: 15, color: palette.muted),
                        const SizedBox(width: 4),
                        Text(
                          when,
                          style: TextStyle(
                            color: palette.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (order.isGift) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.card_giftcard,
                            size: 15,
                            color: palette.accent,
                            semanticLabel: 'Đơn tặng',
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
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
                    Text(
                      order.isGift
                          ? '${order.customerName} → ${order.recipientName}'
                          : order.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: palette.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        OrderStatusChip(order: order),
                        const Spacer(),
                        Text(
                          owed
                              ? 'Còn ${money(order.remaining)}'
                              : money(order.total),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: owed
                                ? palette.adapt(const Color(0xFFB8692F))
                                : palette.ink,
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
}
