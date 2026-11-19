import 'package:flower_orders/flower/presentation/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('toast animates in, replaces the previous one, then leaves', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const Scaffold();
          },
        ),
      ),
    );

    AppToast.show(context, 'Lần một');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final opacity = tester.widget<FadeTransition>(
      find
          .ancestor(
            of: find.text('Lần một'),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(opacity.opacity.value, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();

    AppToast.show(context, 'Lần hai');
    await tester.pumpAndSettle();
    expect(find.text('Lần một'), findsNothing);
    expect(find.text('Lần hai'), findsOneWidget);

    await tester.pump(AppToast.visibleFor);
    await tester.pumpAndSettle();
    expect(find.text('Lần hai'), findsNothing);
  });
}
