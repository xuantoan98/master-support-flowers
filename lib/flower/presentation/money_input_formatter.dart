import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

int? parseCurrencyInput(String value) =>
    int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), ''));

String formatCurrencyInput(int value, String locale) =>
    NumberFormat.decimalPattern(locale).format(value);

class MoneyInputFormatter extends TextInputFormatter {
  MoneyInputFormatter(this.locale);

  final String locale;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return TextEditingValue.empty;
    }
    if (digits.length > 15) {
      return oldValue;
    }
    final value = int.tryParse(digits);
    if (value == null) {
      return oldValue;
    }
    final formatted = formatCurrencyInput(value, locale);
    final beforeCursor = newValue.text
        .substring(
          0,
          newValue.selection.baseOffset.clamp(0, newValue.text.length),
        )
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length;
    var offset = 0;
    var seen = 0;
    while (offset < formatted.length && seen < beforeCursor) {
      if (RegExp(r'[0-9]').hasMatch(formatted[offset])) {
        seen++;
      }
      offset++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
