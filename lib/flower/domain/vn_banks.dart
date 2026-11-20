/// Vietnamese banks on the NAPAS 247 network, with the BIN that VietQR uses
/// to route a transfer. Most common banks first.
class VnBank {
  const VnBank(this.shortName, this.name, this.bin);

  final String shortName;
  final String name;
  final String bin;

  String get label => '$shortName · $name';
}

const vnBanks = <VnBank>[
  VnBank('Vietcombank', 'Ngoại thương Việt Nam', '970436'),
  VnBank('VietinBank', 'Công thương Việt Nam', '970415'),
  VnBank('BIDV', 'Đầu tư và Phát triển Việt Nam', '970418'),
  VnBank('Agribank', 'Nông nghiệp và Phát triển Nông thôn', '970405'),
  VnBank('Techcombank', 'Kỹ thương Việt Nam', '970407'),
  VnBank('MB', 'Quân đội', '970422'),
  VnBank('ACB', 'Á Châu', '970416'),
  VnBank('VPBank', 'Việt Nam Thịnh Vượng', '970432'),
  VnBank('TPBank', 'Tiên Phong', '970423'),
  VnBank('Sacombank', 'Sài Gòn Thương Tín', '970403'),
  VnBank('HDBank', 'Phát triển TP.HCM', '970437'),
  VnBank('VIB', 'Quốc tế', '970441'),
  VnBank('SHB', 'Sài Gòn – Hà Nội', '970443'),
  VnBank('OCB', 'Phương Đông', '970448'),
  VnBank('MSB', 'Hàng Hải', '970426'),
  VnBank('SeABank', 'Đông Nam Á', '970440'),
  VnBank('Eximbank', 'Xuất Nhập khẩu', '970431'),
  VnBank('LPBank', 'Lộc Phát Việt Nam', '970449'),
  VnBank('Nam A Bank', 'Nam Á', '970428'),
  VnBank('Bac A Bank', 'Bắc Á', '970409'),
  VnBank('ABBANK', 'An Bình', '970425'),
  VnBank('VietABank', 'Việt Á', '970427'),
  VnBank('BVBank', 'Bản Việt', '970454'),
  VnBank('PVcomBank', 'Đại chúng Việt Nam', '970412'),
  VnBank('Kienlongbank', 'Kiên Long', '970452'),
  VnBank('NCB', 'Quốc Dân', '970419'),
  VnBank('SCB', 'Sài Gòn', '970429'),
  VnBank('Saigonbank', 'Sài Gòn Công Thương', '970400'),
  VnBank('BaoViet Bank', 'Bảo Việt', '970438'),
  VnBank('PGBank', 'Thịnh vượng và Phát triển', '970430'),
  VnBank('Vietbank', 'Việt Nam Thương Tín', '970433'),
  VnBank('DongA Bank', 'Đông Á', '970406'),
  VnBank('GPBank', 'Dầu khí Toàn cầu', '970408'),
  VnBank('Shinhan Bank', 'Shinhan Việt Nam', '970424'),
  VnBank('Woori Bank', 'Woori Việt Nam', '970457'),
  VnBank('Public Bank', 'Public Bank Việt Nam', '970439'),
  VnBank('UOB', 'UOB Việt Nam', '970458'),
];

VnBank? bankByBin(String bin) {
  for (final bank in vnBanks) {
    if (bank.bin == bin.trim()) {
      return bank;
    }
  }
  return null;
}
