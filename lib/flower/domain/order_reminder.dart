import 'flower_order.dart';

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
