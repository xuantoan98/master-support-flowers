import 'dart:async';

import 'package:flower_orders/flower/data/address_suggester.dart';
import 'package:flower_orders/flower/presentation/address_field.dart';
import 'package:flower_orders/flower/presentation/flower_template_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSuggester implements AddressSuggester {
  final queries = <String>[];
  final pending = <String, Completer<List<AddressSuggestion>>>{};
  bool fail = false;

  @override
  Future<List<AddressSuggestion>> suggest(String input) {
    queries.add(input);
    if (fail) {
      return Future.error(Exception('offline'));
    }
    return (pending[input] = Completer()).future;
  }
}

const _vincom = AddressSuggestion(
  description: 'Vincom Center Bà Triệu, 191 Bà Triệu, Hai Bà Trưng, Hà Nội',
  mainText: 'Vincom Center Bà Triệu',
  secondaryText: '191 Bà Triệu, Hai Bà Trưng, Hà Nội',
);

Future<TextEditingController> _pump(
  WidgetTester tester,
  AddressSuggester? suggester,
) async {
  final controller = TextEditingController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: FlowerTemplateTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: AddressField(
            controller: controller,
            suggester: suggester,
            onChanged: () {},
          ),
        ),
      ),
    ),
  );
  return controller;
}

void main() {
  test('Goong predictions keep the service address name', () {
    final result = parseGoongPredictions({
      'status': 'OK',
      'predictions': [
        {
          'description': _vincom.description,
          'structured_formatting': {
            'main_text': _vincom.mainText,
            'secondary_text': _vincom.secondaryText,
          },
        },
        {'description': '  '},
        {'description': 'Hồ Gươm, Hoàn Kiếm, Hà Nội'},
      ],
    });
    expect(result, hasLength(2));
    expect(result.first.description, _vincom.description);
    expect(result.first.mainText, 'Vincom Center Bà Triệu');
    expect(result.last.mainText, 'Hồ Gươm, Hoàn Kiếm, Hà Nội');
    expect(parseGoongPredictions({'status': 'ZERO_RESULTS'}), isEmpty);
    expect(parseGoongPredictions('bad'), isEmpty);
  });

  testWidgets('picking a suggestion fills the map address name', (
    tester,
  ) async {
    final suggester = FakeSuggester();
    final controller = await _pump(tester, suggester);

    await tester.enterText(find.byType(TextField), 'Vi');
    await tester.pump(const Duration(milliseconds: 400));
    expect(suggester.queries, isEmpty, reason: 'needs at least 3 characters');

    await tester.enterText(find.byType(TextField), 'Vincom Ba');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'Vincom Ba Trieu');
    await tester.pump(const Duration(milliseconds: 400));
    expect(suggester.queries, ['Vincom Ba Trieu'], reason: 'debounced');

    suggester.pending['Vincom Ba Trieu']!.complete([_vincom]);
    await tester.pumpAndSettle();
    expect(find.text('Gợi ý bởi Goong'), findsOneWidget);

    await tester.tap(find.text('Vincom Center Bà Triệu'));
    await tester.pumpAndSettle();
    expect(controller.text, _vincom.description);
    expect(find.text('Địa chỉ theo bản đồ'), findsOneWidget);
    expect(find.text('Mở bản đồ'), findsOneWidget);
    expect(find.text('Gợi ý bởi Goong'), findsNothing);

    await tester.enterText(
      find.byType(TextField),
      '${_vincom.description}, tầng 6',
    );
    await tester.pump();
    expect(find.text('Địa chỉ theo bản đồ'), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('a slow older answer never replaces a newer one', (tester) async {
    final suggester = FakeSuggester();
    await _pump(tester, suggester);
    await tester.enterText(find.byType(TextField), 'Ho Guom');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'Vincom');
    await tester.pump(const Duration(milliseconds: 400));
    suggester.pending['Vincom']!.complete([_vincom]);
    await tester.pumpAndSettle();
    suggester.pending['Ho Guom']!.complete([
      const AddressSuggestion(
        description: 'Hồ Gươm',
        mainText: 'Hồ Gươm',
        secondaryText: '',
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Vincom Center Bà Triệu'), findsOneWidget);
    expect(find.text('Hồ Gươm'), findsNothing);
  });

  testWidgets('offline keeps manual input and explains it', (tester) async {
    final suggester = FakeSuggester()..fail = true;
    final controller = await _pump(tester, suggester);
    await tester.enterText(find.byType(TextField), '12 Hoa Mai');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(
      find.text('Không tải được gợi ý. Bạn vẫn có thể nhập tay.'),
      findsOneWidget,
    );
    expect(controller.text, '12 Hoa Mai');
  });

  testWidgets('without an API key the field is plain input', (tester) async {
    final controller = await _pump(tester, null);
    await tester.enterText(find.byType(TextField), '12 Hoa Mai');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Gõ địa chỉ để xem gợi ý từ bản đồ'), findsNothing);
    expect(controller.text, '12 Hoa Mai');
  });
}
