import 'calendar_overview.dart';
import 'flower_order.dart';
import 'shopping_list.dart';

enum ReminderKind { beforeDelivery, overdueDelivery, outstandingPayment }

class OrderReminder {
  const OrderReminder({required this.id, required this.at, required this.kind});

  final int id;
  final DateTime at;
  final ReminderKind kind;

  String get title => switch (kind) {
    ReminderKind.beforeDelivery => 'Đơn #$id sắp giao',
    ReminderKind.overdueDelivery => 'Kiểm tra đơn #$id',
    ReminderKind.outstandingPayment => 'Kiểm tra công nợ đơn #$id',
  };

  String get body => switch (kind) {
    ReminderKind.beforeDelivery => 'Còn khoảng 1 giờ đến giờ giao.',
    ReminderKind.overdueDelivery =>
      'Đã qua giờ giao. Mở app để cập nhật trạng thái.',
    ReminderKind.outstandingPayment =>
      'Đơn còn tiền chưa thu. Mở app để kiểm tra.',
  };

  int get notificationId => 100000000 + id * 10 + kind.index;
}

List<OrderReminder> planOrderReminders(
  Iterable<FlowerOrder> orders, {
  required DateTime now,
}) {
  final reminders = <OrderReminder>[];
  for (final order in orders) {
    final id = order.id;
    if (id == null || order.status == OrderStatus.cancelled) {
      continue;
    }
    if (order.status != OrderStatus.delivered) {
      final before = order.deliveryAt.subtract(const Duration(hours: 1));
      final overdue = order.deliveryAt.add(const Duration(minutes: 15));
      if (before.isAfter(now)) {
        reminders.add(
          OrderReminder(id: id, at: before, kind: ReminderKind.beforeDelivery),
        );
      }
      if (overdue.isAfter(now)) {
        reminders.add(
          OrderReminder(
            id: id,
            at: overdue,
            kind: ReminderKind.overdueDelivery,
          ),
        );
      }
    }
    final paymentCheck = order.deliveryAt.add(const Duration(days: 1));
    if (order.remaining > 0 && paymentCheck.isAfter(now)) {
      reminders.add(
        OrderReminder(
          id: id,
          at: paymentCheck,
          kind: ReminderKind.outstandingPayment,
        ),
      );
    }
  }
  reminders.sort((a, b) => a.at.compareTo(b.at));
  // iOS keeps only the nearest 64 pending local notifications.
  return reminders.take(60).toList();
}

/// A shop-wide reminder that is not about one order.
class DailyReminder {
  const DailyReminder({
    required this.notificationId,
    required this.at,
    required this.title,
    required this.body,
  });

  final int notificationId;
  final DateTime at;
  final String title;
  final String body;
}

/// Hour of the evening "prepare tomorrow" and morning "flower market"
/// reminders, and of the holiday heads-up.
const eveningReminderHour = 20;
const marketReminderHour = 6;
const occasionReminderHour = 9;

/// Evening and morning reminders for the next [days] days, and a heads-up
/// 7 days before each big flower day. Days without work stay quiet.
List<DailyReminder> planDailyReminders(
  Iterable<FlowerOrder> orders, {
  required DateTime now,
  int days = 7,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final reminders = <DailyReminder>[];
  bool open(FlowerOrder o) =>
      o.status != OrderStatus.cancelled && o.status != OrderStatus.delivered;
  for (var offset = 0; offset < days; offset++) {
    final day = DateTime(today.year, today.month, today.day + offset);
    final next = DateTime(day.year, day.month, day.day + 1);
    final after = DateTime(day.year, day.month, day.day + 2);

    // 20:00: what has to be ready tomorrow.
    final evening = DateTime(day.year, day.month, day.day, eveningReminderHour);
    final tomorrow = orders
        .where(
          (o) =>
              open(o) &&
              !o.deliveryAt.isBefore(next) &&
              o.deliveryAt.isBefore(after),
        )
        .toList();
    if (evening.isAfter(now) && tomorrow.isNotEmpty) {
      final gifts = tomorrow.where((o) => o.cardMessage.trim().isNotEmpty);
      reminders.add(
        DailyReminder(
          notificationId: 150000000 + offset * 10,
          at: evening,
          title: 'Ngày mai có ${tomorrow.length} đơn',
          body: [
            'Chuẩn bị hoa, kiểm tra giờ giao và địa chỉ.',
            if (gifts.isNotEmpty) '${gifts.length} đơn có lời thiệp cần viết.',
          ].join(' '),
        ),
      );
    }

    // 06:00: the flower market list for the day.
    final morning = DateTime(day.year, day.month, day.day, marketReminderHour);
    final list = buildShoppingList(orders, day, next);
    if (morning.isAfter(now) && list.items.isNotEmpty) {
      final top = list.items
          .take(3)
          .map((i) => '${i.name} ${i.quantity} ${i.unit}')
          .join(', ');
      reminders.add(
        DailyReminder(
          notificationId: 150000000 + offset * 10 + 1,
          at: morning,
          title: 'Đi chợ hoa: ${list.items.length} loại cần mua',
          body: list.items.length > 3 ? '$top…' : top,
        ),
      );
    }
  }

  // 7 days ahead of each big day: stock up and take pre-orders.
  var index = 0;
  for (final (occasion, day) in upcomingOccasions(today, withinDays: 60)) {
    final at = DateTime(day.year, day.month, day.day - 7, occasionReminderHour);
    if (at.isAfter(now)) {
      reminders.add(
        DailyReminder(
          notificationId: 160000000 + index,
          at: at,
          title: 'Còn 7 ngày tới ${occasion.label}',
          body: 'Đặt hoa với mối hàng, chuẩn bị mẫu và nhận đơn đặt trước.',
        ),
      );
    }
    index++;
  }
  return reminders;
}
