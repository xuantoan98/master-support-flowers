import 'vietqr.dart';

class ShopProfile {
  const ShopProfile({
    this.name = 'Tiệm Hoa',
    this.phone = '',
    this.address = '',
    this.bankBin = '',
    this.bankName = '',
    this.accountNumber = '',
    this.accountHolder = '',
    this.qrImagePath = '',
  });

  factory ShopProfile.fromMap(Map<String, Object?> row) => ShopProfile(
    name: row['name']?.toString() ?? 'Tiệm Hoa',
    phone: row['phone']?.toString() ?? '',
    address: row['address']?.toString() ?? '',
    bankBin: row['bank_bin']?.toString() ?? '',
    bankName: row['bank_name']?.toString() ?? '',
    accountNumber: row['account_number']?.toString() ?? '',
    accountHolder: row['account_holder']?.toString() ?? '',
    qrImagePath: row['qr_image_path']?.toString() ?? '',
  );

  final String name;
  final String phone;
  final String address;
  final String bankBin;
  final String bankName;
  final String accountNumber;
  final String accountHolder;
  final String qrImagePath;

  /// Enough bank details to print a VietQR with the amount filled in.
  bool get hasVietQr =>
      buildVietQrPayload(bankBin: bankBin, accountNumber: accountNumber) !=
      null;

  String? vietQrPayload({int? amount, String note = ''}) => buildVietQrPayload(
    bankBin: bankBin,
    accountNumber: accountNumber,
    amount: amount,
    note: note,
  );

  String? validate() {
    if (name.trim().isEmpty) {
      return 'Vui lòng nhập tên shop';
    }
    if (accountNumber.trim().isNotEmpty &&
        !RegExp(
          r'^[0-9A-Za-z]{1,19}$',
        ).hasMatch(accountNumber.replaceAll(RegExp(r'\s'), ''))) {
      return 'Số tài khoản chỉ gồm chữ số hoặc chữ cái, tối đa 19 ký tự';
    }
    return null;
  }

  Map<String, Object?> toMap() => {
    'name': name.trim(),
    'phone': phone.trim(),
    'address': address.trim(),
    'bank_bin': bankBin.trim(),
    'bank_name': bankName.trim(),
    'account_number': accountNumber.trim(),
    'account_holder': accountHolder.trim(),
    'qr_image_path': qrImagePath,
  };
}
