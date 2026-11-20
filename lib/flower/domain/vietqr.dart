/// Builds VietQR (NAPAS 247, EMVCo) payloads that banking apps scan to
/// pre-fill the account, the amount and the transfer note.
library;

/// Transfer note for an order: banks keep only plain ASCII reliably.
String vietQrOrderNote(int orderId) => 'DH$orderId';

/// Returns null when the bank BIN or account number is missing or invalid.
String? buildVietQrPayload({
  required String bankBin,
  required String accountNumber,
  int? amount,
  String note = '',
}) {
  final bin = bankBin.trim();
  final account = accountNumber.replaceAll(RegExp(r'\s'), '');
  if (!RegExp(r'^\d{6}$').hasMatch(bin) ||
      !RegExp(r'^[0-9A-Za-z]{1,19}$').hasMatch(account)) {
    return null;
  }
  final beneficiary = _field('00', bin) + _field('01', account);
  final merchant =
      _field('00', 'A000000727') +
      _field('01', beneficiary) +
      _field('02', 'QRIBFTTA');
  final cleanNote = vietQrSafeText(note);
  final hasAmount = amount != null && amount > 0;
  final body = StringBuffer()
    ..write(_field('00', '01'))
    // 12 = dynamic QR (one payment with an amount), 11 = static.
    ..write(_field('01', hasAmount ? '12' : '11'))
    ..write(_field('38', merchant))
    ..write(_field('53', '704'))
    ..write(hasAmount ? _field('54', '$amount') : '')
    ..write(_field('58', 'VN'))
    ..write(cleanNote.isEmpty ? '' : _field('62', _field('08', cleanNote)))
    ..write('6304');
  final text = body.toString();
  return '$text${crc16Ccitt(text).toRadixString(16).toUpperCase().padLeft(4, '0')}';
}

/// Strips Vietnamese marks and anything banks may reject; max 25 chars.
String vietQrSafeText(String value) {
  const from =
      'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ'
      'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
  const to =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd'
      'AAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    final index = from.indexOf(char);
    final plain = index >= 0 ? to[index] : char;
    if (RegExp(r'[A-Za-z0-9 ]').hasMatch(plain)) {
      buffer.write(plain);
    }
  }
  final text = buffer.toString().replaceAll(RegExp(r' +'), ' ').trim();
  return text.length > 25 ? text.substring(0, 25).trim() : text;
}

String _field(String id, String value) =>
    '$id${value.length.toString().padLeft(2, '0')}$value';

/// CRC-16/CCITT-FALSE as required by EMVCo QR.
int crc16Ccitt(String data) {
  var crc = 0xFFFF;
  for (final byte in data.codeUnits) {
    crc ^= byte << 8;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) : (crc << 1);
      crc &= 0xFFFF;
    }
  }
  return crc;
}
