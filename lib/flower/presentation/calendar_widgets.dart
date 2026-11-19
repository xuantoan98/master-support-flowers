import 'package:flutter/material.dart';

import '../domain/calendar_overview.dart';
import '../domain/catalog_placeholders.dart';
import '../domain/flower_order.dart';
import '../domain/order_summary.dart';
import 'flower_template_theme.dart';

const calendarNotStartedColor = Color(0xFFE0A458);
const calendarInProgressColor = Color(0xFF4A7FB5);
const calendarDeliveredColor = FlowerTemplateTheme.deepSage;
const calendarOverdueColor = Color(0xFFC4554D);

Color calendarDotColor(CalendarDotKind kind) => switch (kind) {
  CalendarDotKind.notStarted => calendarNotStartedColor,
  CalendarDotKind.inProgress => calendarInProgressColor,
  CalendarDotKind.delivered => calendarDeliveredColor,
};

/// Badge text for a day's order count: never wider than "9+".
String orderCountLabel(int count) => count > 9 ? '9+' : '$count';

/// Picks a representative bouquet photo for an order.
String orderThumbnail(FlowerOrder order) {
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

/// Month grid; each day is a borderless tile showing up to three fanned
/// order cards.
class DeliveryCalendar extends StatelessWidget {
  const DeliveryCalendar({
    super.key,
    required this.month,
    required this.selected,
    required this.today,
    required this.ordersByDay,
    required this.onSelect,
    required this.onShift,
    required this.onOpenOrder,
  });

  /// First day of the displayed month.
  final DateTime month;
  final DateTime selected;
  final DateTime today;
  final Map<DateTime, List<FlowerOrder>> ordersByDay;
  final ValueChanged<DateTime> onSelect;

  /// -1 / +1: previous / next month.
  final ValueChanged<int> onShift;

  /// Opens one order from the enlarged card fan of a day.
  final ValueChanged<FlowerOrder> onOpenOrder;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Tháng trước',
                onPressed: () => onShift(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  monthTitle(month),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: context.palette.ink,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Tháng sau',
                onPressed: () => onShift(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Row(
            children: [
              for (final day in ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'])
                Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: TextStyle(
                        color: context.palette.muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity < -250) {
                onShift(1);
              } else if (velocity > 250) {
                onShift(-1);
              }
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween(begin: 0.98, end: 1.0).animate(animation),
                  child: child,
                ),
              ),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topCenter,
                children: [...previous, ?current],
              ),
              child: Column(
                key: ValueKey('${month.year}-${month.month}'),
                children: [
                  for (final week in _weeks())
                    Row(
                      children: [
                        for (final day in week)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(2.5),
                              child: day == null
                                  ? const AspectRatio(aspectRatio: 0.95)
                                  : _DayCell(
                                      date: day,
                                      today: today,
                                      selected: DateUtils.isSameDay(
                                        day,
                                        selected,
                                      ),
                                      orders: ordersByDay[day] ?? const [],
                                      onTap: () => onSelect(day),
                                      onOpenOrder: onOpenOrder,
                                    ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const _Legend(),
        ],
      ),
    ),
  );

  List<List<DateTime?>> _weeks() {
    final leading = DateTime(month.year, month.month).weekday - 1;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final cells = <DateTime?>[
      for (var i = 0; i < leading; i++) null,
      for (var d = 1; d <= days; d++) DateTime(month.year, month.month, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return [for (var i = 0; i < cells.length; i += 7) cells.sublist(i, i + 7)];
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.today,
    required this.selected,
    required this.orders,
    required this.onTap,
    required this.onOpenOrder,
  });

  final DateTime date;
  final DateTime today;
  final bool selected;
  final List<FlowerOrder> orders;
  final VoidCallback onTap;
  final ValueChanged<FlowerOrder> onOpenOrder;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isToday = DateUtils.isSameDay(date, today);
    final past = date.isBefore(dateOnly(today));
    final overdue = orders.any((order) => isOverdue(order, today));
    final visible = orders
        .where((order) => calendarDotKind(order.status) != null)
        .toList();
    final hasOrders = visible.isNotEmpty;
    final Color numberColor;
    if (overdue) {
      numberColor = palette.adapt(calendarOverdueColor);
    } else if (isToday) {
      numberColor = palette.primary;
    } else {
      numberColor = hasOrders ? palette.ink : palette.muted;
    }
    final label = [
      '${date.day}/${date.month}',
      if (isToday) 'hôm nay',
      if (hasOrders) '${visible.length} đơn',
      if (overdue) 'có đơn quá hạn',
    ].join(', ');
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: past && !overdue && !selected ? 0.5 : 1,
        child: AspectRatio(
          aspectRatio: 0.95,
          child: AnimatedScale(
            scale: selected ? 1.04 : 1,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            child: Material(
              color: hasOrders
                  ? palette.blush.withValues(alpha: palette.isDark ? 0.7 : 0.75)
                  : palette.line.withValues(alpha: palette.isDark ? 0.45 : 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: selected
                    ? BorderSide(color: palette.primary, width: 2)
                    : BorderSide.none,
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  onTap();
                  if (hasOrders) {
                    showOrderFan(
                      context,
                      date: date,
                      orders: visible,
                      onOpenOrder: onOpenOrder,
                    );
                  }
                },
                child: Stack(
                  children: [
                    if (hasOrders)
                      Positioned.fill(
                        bottom: 16,
                        child: _CardFan(orders: visible.take(3).toList()),
                      ),
                    if (visible.length > 1)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 15),
                          height: 15,
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: palette.adapt(const Color(0xFFD45D79)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: palette.card, width: 1.5),
                          ),
                          child: Text(
                            orderCountLabel(visible.length),
                            style: TextStyle(
                              color: palette.isDark
                                  ? palette.canvas
                                  : Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 5,
                      bottom: 3,
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.2,
                          color: numberColor,
                          fontWeight: hasOrders || isToday || overdue
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Up to three bouquet cards fanned like a hand of playing cards.
class _CardFan extends StatelessWidget {
  const _CardFan({required this.orders});

  final List<FlowerOrder> orders;

  static const _angles = {
    1: [0.0],
    2: [-0.16, 0.16],
    3: [-0.26, 0.0, 0.26],
  };

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final height = (constraints.maxHeight - 6).clamp(10.0, 30.0);
      final width = height * 0.8;
      final angles = _angles[orders.length]!;
      final spread = orders.length == 1 ? 0.0 : width * 0.32;
      return Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < orders.length; i++)
            Transform.translate(
              offset: Offset(
                orders.length == 1 ? 0 : spread * (i - (orders.length - 1) / 2),
                angles[i].abs() * 6 + 2,
              ),
              child: Transform.rotate(
                angle: angles[i],
                alignment: Alignment.bottomCenter,
                child: _MiniCard(
                  order: orders[i],
                  width: width,
                  height: height,
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.order,
    required this.width,
    required this.height,
  });

  final FlowerOrder order;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final kind = calendarDotKind(order.status)!;
    final palette = context.palette;
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: palette.adapt(calendarDotColor(kind)),
          width: 1.4,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Image.asset(
          orderThumbnail(order),
          fit: BoxFit.cover,
          cacheWidth: 96,
          errorBuilder: (_, _, _) => ColoredBox(color: palette.blush),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: 12,
    runSpacing: 4,
    children: [
      _LegendItem(
        color: context.palette.adapt(calendarNotStartedColor),
        label: 'Chưa làm',
      ),
      _LegendItem(
        color: context.palette.adapt(calendarInProgressColor),
        label: 'Đang xử lý',
      ),
      _LegendItem(
        color: context.palette.adapt(calendarDeliveredColor),
        label: 'Đã giao',
      ),
      _LegendItem(
        color: context.palette.adapt(calendarOverdueColor),
        label: 'Quá hạn',
        ring: true,
      ),
    ],
  );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    this.ring = false,
  });

  final Color color;
  final String label;
  final bool ring;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ring ? null : color,
          border: ring ? Border.all(color: color, width: 1.5) : null,
        ),
      ),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: context.palette.muted)),
    ],
  );
}

/// One large revenue card plus two small order-count cards.
class OverviewBento extends StatelessWidget {
  const OverviewBento({
    super.key,
    required this.month,
    required this.summary,
    required this.previousSummary,
    required this.todayCount,
    required this.todayOpen,
    required this.money,
    this.weekly = const [],
  });

  /// Revenue per week of [month], drawn as a sparkline.
  final List<int> weekly;
  final DateTime month;
  final OrderSummary summary;
  final OrderSummary previousSummary;
  final int todayCount;
  final int todayOpen;
  final String Function(int) money;

  @override
  Widget build(BuildContext context) {
    final previousMonth = DateTime(month.year, month.month - 1);
    final comparison = revenueComparison(
      summary.projectedRevenue,
      previousSummary.projectedRevenue,
      previousMonth,
    );
    final progress = summary.projectedRevenue <= 0
        ? 0.0
        : (summary.paid / summary.projectedRevenue).clamp(0.0, 1.0);
    final remaining = summary.remaining < 0 ? 0 : summary.remaining;
    final up = comparison?.startsWith('↑') ?? false;
    final down = comparison?.startsWith('↓') ?? false;
    return Column(
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.local_florist_outlined,
                      size: 16,
                      color: context.palette.accent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Doanh thu dự kiến T${month.month}',
                        style: TextStyle(
                          color: context.palette.muted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (comparison != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (up
                                      ? context.palette.adapt(
                                          calendarDeliveredColor,
                                        )
                                      : down
                                      ? context.palette.adapt(
                                          calendarOverdueColor,
                                        )
                                      : context.palette.muted)
                                  .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (up || down)
                              Icon(
                                up ? Icons.arrow_upward : Icons.arrow_downward,
                                size: 12,
                                color: up
                                    ? context.palette.adapt(
                                        calendarDeliveredColor,
                                      )
                                    : context.palette.adapt(
                                        calendarOverdueColor,
                                      ),
                              ),
                            const SizedBox(width: 2),
                            Text(
                              comparison.substring(2),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: up
                                    ? context.palette.adapt(
                                        calendarDeliveredColor,
                                      )
                                    : down
                                    ? context.palette.adapt(
                                        calendarOverdueColor,
                                      )
                                    : context.palette.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        money(summary.projectedRevenue),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: FlowerTemplateTheme.headingFont,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: context.palette.ink,
                        ),
                      ),
                    ),
                    if (weekly.where((value) => value > 0).length >= 2)
                      Semantics(
                        label:
                            'Doanh thu theo tuần: ${weekly.map(money).join(', ')}',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            CustomPaint(
                              size: const Size(96, 34),
                              painter: _SparklinePainter(
                                values: weekly,
                                color: context.palette.accent,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Theo tuần',
                              style: TextStyle(
                                fontSize: 10,
                                color: context.palette.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    color: context.palette.adapt(calendarDeliveredColor),
                    backgroundColor: context.palette.line,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Đã thu ${money(summary.paid)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.palette.adapt(calendarDeliveredColor),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      'Còn lại ${money(remaining)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.palette.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SmallStat(
                title: 'Đơn trong tháng',
                value: '${summary.orderCount}',
                caption: '${summary.pendingCount} chưa giao',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SmallStat(
                title: 'Đơn hôm nay',
                value: '$todayCount',
                caption: todayOpen == 0
                    ? 'Đã xong hết'
                    : '$todayOpen cần xử lý',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SmallStat extends StatelessWidget {
  const _SmallStat({
    required this.title,
    required this.value,
    required this.caption,
  });

  final String title;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: context.palette.muted, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: FlowerTemplateTheme.headingFont,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: context.palette.ink,
            ),
          ),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: context.palette.muted),
          ),
        ],
      ),
    ),
  );
}

/// Static placeholder shown while orders load.
class CalendarSkeleton extends StatelessWidget {
  const CalendarSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    Widget box(double height, {double? width, double radius = 16}) => Container(
      height: height,
      width: width,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.palette.line.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    return Semantics(
      label: 'Đang tải dữ liệu',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          box(28, width: 160, radius: 8),
          box(18, width: 220, radius: 8),
          const SizedBox(height: 8),
          box(150),
          box(22, width: 180, radius: 8),
          box(104),
          box(104),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<int> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) {
      return;
    }
    final top = values.reduce((a, b) => a > b ? a : b);
    final scale = top <= 0 ? 0.0 : (size.height - 6) / top;
    final step = size.width / (values.length - 1);
    final points = [
      for (var i = 0; i < values.length; i++)
        Offset(i * step, size.height - 3 - values[i] * scale),
    ];
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      line.lineTo(point.dx, point.dy);
    }
    final area = Path.from(line)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas
      ..drawPath(area, Paint()..color = color.withValues(alpha: 0.14))
      ..drawPath(
        line,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      )
      ..drawCircle(points.last, 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.color != color || !_sameValues(old.values, values);

  static bool _sameValues(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}

/// Accent colour, emoji and name for each peak occasion.
({Color color, String emoji, String name}) occasionStyle(
  FlowerOccasion occasion,
) => switch (occasion) {
  FlowerOccasion.tet => (
    color: const Color(0xFFC8453B),
    emoji: '🧧',
    name: 'Tết Nguyên Đán',
  ),
  FlowerOccasion.valentine => (
    color: const Color(0xFFD45D79),
    emoji: '💝',
    name: 'Valentine 14/2',
  ),
  FlowerOccasion.womensDay => (
    color: const Color(0xFFC2577F),
    emoji: '🌷',
    name: 'Quốc tế Phụ nữ 8/3',
  ),
  FlowerOccasion.vietnameseWomensDay => (
    color: const Color(0xFFB4466B),
    emoji: '🌹',
    name: 'Phụ nữ Việt Nam 20/10',
  ),
  FlowerOccasion.teachersDay => (
    color: const Color(0xFFB8692F),
    emoji: '💐',
    name: 'Nhà giáo Việt Nam 20/11',
  ),
};

/// Seasonal accent strip shown during the busy days before a holiday.
class OccasionBanner extends StatelessWidget {
  const OccasionBanner({super.key, required this.window});

  final OccasionWindow window;

  @override
  Widget build(BuildContext context) {
    final style = occasionStyle(window.occasion);
    final color = context.palette.adapt(style.color);
    final headline = switch (window.daysLeft) {
      > 0 => 'Còn ${window.daysLeft} ngày đến ${style.name}',
      0 => 'Hôm nay là ${style.name}',
      _ => 'Đang trong dịp ${style.name}',
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Text(style.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
                Text(
                  window.daysLeft > 0
                      ? 'Mùa cao điểm: chuẩn bị hoa và nhận đơn sớm'
                      : 'Ưu tiên giao đúng giờ cho khách',
                  style: TextStyle(fontSize: 12, color: context.palette.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Enlarges a day's order cards out of its calendar tile; tapping a card
/// opens that order.
Future<void> showOrderFan(
  BuildContext context, {
  required DateTime date,
  required List<FlowerOrder> orders,
  required ValueChanged<FlowerOrder> onOpenOrder,
}) {
  final box = context.findRenderObject()! as RenderBox;
  final origin = box.localToGlobal(Offset.zero) & box.size;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Đóng',
    barrierColor: Colors.black.withValues(alpha: 0.28),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (dialogContext, animation, _) => _OrderFanPopup(
      animation: animation,
      origin: origin,
      date: date,
      orders: orders,
      onOpen: (order) {
        Navigator.of(dialogContext).pop();
        onOpenOrder(order);
      },
    ),
  );
}

class _OrderFanPopup extends StatelessWidget {
  const _OrderFanPopup({
    required this.animation,
    required this.origin,
    required this.date,
    required this.orders,
    required this.onOpen,
  });

  final Animation<double> animation;
  final Rect origin;
  final DateTime date;
  final List<FlowerOrder> orders;
  final ValueChanged<FlowerOrder> onOpen;

  static const _cardWidth = 104.0;
  static const _cardHeight = 138.0;
  static const _angles = {
    1: [0.0],
    2: [-0.14, 0.14],
    3: [-0.22, 0.0, 0.22],
  };

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final shown = orders.take(3).toList();
    final angles = _angles[shown.length]!;
    final spread = shown.length == 1 ? 0.0 : _cardWidth * 0.78;
    const fanHeight = _cardHeight + 40;
    final fanWidth = _cardWidth + spread * (shown.length - 1) + 40;
    // Centre the fan just above the tapped day, kept on screen.
    final target = Offset(
      origin.center.dx.clamp(
        fanWidth / 2 + 16,
        screen.width - fanWidth / 2 - 16,
      ),
      (origin.top - fanHeight / 2 + 8).clamp(
        fanHeight / 2 + MediaQuery.paddingOf(context).top + 16,
        screen.height - fanHeight / 2 - 120,
      ),
    );
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, _) {
        final t = curved.value;
        final center = Offset.lerp(origin.center, target, t.clamp(0.0, 1.0))!;
        final scale = 0.3 + 0.7 * t;
        return Stack(
          children: [
            Positioned(
              left: center.dx - fanWidth / 2,
              top: center.dy - fanHeight / 2,
              width: fanWidth,
              height: fanHeight + 72,
              child: Opacity(
                opacity: animation.value.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: fanWidth,
                        height: fanHeight,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            for (var i = 0; i < shown.length; i++)
                              Transform.translate(
                                offset: Offset(
                                  spread * (i - (shown.length - 1) / 2) * t,
                                  angles[i].abs() * 40 * t,
                                ),
                                child: Transform.rotate(
                                  angle: angles[i] * t,
                                  alignment: Alignment.bottomCenter,
                                  child: _BigOrderCard(
                                    order: shown[i],
                                    onTap: () => onOpen(shown[i]),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Material(
                        color: context.palette.card,
                        shape: const StadiumBorder(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Text(
                            orders.length > shown.length
                                ? '${date.day}/${date.month} · ${orders.length} đơn · xem tất cả bên dưới'
                                : '${date.day}/${date.month} · Chạm card để mở đơn',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.palette.muted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BigOrderCard extends StatelessWidget {
  const _BigOrderCard({required this.order, required this.onTap});

  final FlowerOrder order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final kind = calendarDotKind(order.status)!;
    final color = palette.adapt(calendarDotColor(kind));
    final time =
        '${order.deliveryAt.hour.toString().padLeft(2, '0')}:'
        '${order.deliveryAt.minute.toString().padLeft(2, '0')}';
    return Semantics(
      button: true,
      label: 'Mở đơn ${order.customerName}, $time',
      excludeSemantics: true,
      child: Material(
        color: palette.card,
        elevation: 6,
        shadowColor: Colors.black38,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: color, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: _OrderFanPopup._cardWidth,
            height: _OrderFanPopup._cardHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(5, 5, 5, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Image.asset(
                        orderThumbnail(order),
                        width: double.infinity,
                        fit: BoxFit.cover,
                        cacheWidth: 240,
                        errorBuilder: (_, _, _) =>
                            ColoredBox(color: palette.blush),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 5, 8, 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: palette.ink,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '$time · ${order.status.label}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: palette.muted,
                              ),
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
      ),
    );
  }
}
