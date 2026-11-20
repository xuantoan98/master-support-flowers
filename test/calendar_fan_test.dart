import 'package:flower_orders/flower/domain/flower_order.dart';
import 'package:flower_orders/flower/presentation/calendar_widgets.dart';
import 'package:flower_orders/flower/presentation/flower_template_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FlowerOrder _order(int id, String name, DateTime at) => FlowerOrder(
  id: id,
  customerName: name,
  phone: '',
  productName: 'Bó hồng',
  price: 100000,
  shippingFee: 0,
  paid: 0,
  deliveryAt: at,
  address: '',
);

void main() {
  testWidgets('every card in a fanned day opens its own order', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final day = DateTime(2030, 6, 12);
    final orders = [
      _order(1, 'An', day.add(const Duration(hours: 9))),
      _order(2, 'Bình', day.add(const Duration(hours: 10))),
      _order(3, 'Chi', day.add(const Duration(hours: 11))),
    ];
    for (final target in orders) {
      FlowerOrder? opened;
      await tester.pumpWidget(
        MaterialApp(
          theme: FlowerTemplateTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: DeliveryCalendar(
                month: DateTime(2030, 6),
                selected: day,
                today: DateTime(2030, 6, 2),
                ordersByDay: {day: orders},
                onSelect: (_) {},
                onShift: (_) {},
                onOpenOrder: (order) => opened = order,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel(RegExp(r'^12/6, 3 đơn')));
      await tester.pumpAndSettle();
      final card = find.bySemanticsLabel(
        RegExp('^Mở đơn ${target.customerName},'),
      );
      // Tap near the outer edge, where a too-narrow hit area would miss.
      final rect = tester.getRect(card);
      final point = target.id == 1
          ? rect.centerLeft + const Offset(14, 0)
          : target.id == 3
          ? rect.centerRight - const Offset(14, 0)
          : rect.center;
      await tester.tapAt(point);
      await tester.pumpAndSettle();
      expect(opened?.id, target.id);
    }
  });

  testWidgets('a past day with orders stays disabled-looking but opens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final past = DateTime(2030, 6, 5);
    final done = FlowerOrder(
      id: 7,
      customerName: 'Dung',
      phone: '',
      productName: 'Bó hồng',
      price: 100000,
      shippingFee: 0,
      paid: 100000,
      deliveryAt: past.add(const Duration(hours: 9)),
      address: '',
      status: OrderStatus.delivered,
    );
    FlowerOrder? opened;
    await tester.pumpWidget(
      MaterialApp(
        theme: FlowerTemplateTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: DeliveryCalendar(
              // The past day is the selected one.
              month: DateTime(2030, 6),
              selected: past,
              today: DateTime(2030, 6, 20),
              ordersByDay: {
                past: [done],
              },
              onSelect: (_) {},
              onShift: (_) {},
              onOpenOrder: (order) => opened = order,
            ),
          ),
        ),
      ),
    );
    final cell = find.bySemanticsLabel(RegExp(r'^5/6, 1 đơn'));
    final opacity = tester
        .widget<Opacity>(
          find.descendant(of: cell, matching: find.byType(Opacity)).first,
        )
        .opacity;
    expect(opacity, 0.5, reason: 'past days keep the disabled look');
    final shape =
        tester
                .widget<Material>(
                  find
                      .descendant(of: cell, matching: find.byType(Material))
                      .first,
                )
                .shape!
            as RoundedRectangleBorder;
    expect(shape.side, BorderSide.none, reason: 'no selection ring');

    await tester.tap(cell);
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp('^Mở đơn Dung,')));
    await tester.pumpAndSettle();
    expect(opened?.id, 7);
  });
}
