import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../data/order_repository.dart';
import '../domain/shop_profile.dart';
import '../domain/vietqr.dart';
import '../domain/vn_banks.dart';
import 'flower_template_theme.dart';
import 'shop_profile_screen.dart';

String _money(int value) =>
    '${NumberFormat.decimalPattern(Intl.getCurrentLocale()).format(value)} đ';

/// A VietQR with the amount and transfer note filled in, plus the account
/// details printed under it so the customer can check before paying.
///
/// Always drawn black on white: banking apps scan it reliably that way in
/// both light and dark mode, and on the shared invoice image.
class VietQrCard extends StatelessWidget {
  const VietQrCard({
    super.key,
    required this.profile,
    required this.amount,
    required this.note,
    this.size = 220,
  });

  final ShopProfile profile;
  final int amount;
  final String note;
  final double size;

  @override
  Widget build(BuildContext context) {
    final payload = profile.vietQrPayload(amount: amount, note: note);
    if (payload == null) {
      return const SizedBox.shrink();
    }
    final bank = bankByBin(profile.bankBin);
    const ink = Color(0xFF1F2421);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4DDD5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: 'Mã VietQR chuyển khoản ${_money(amount)}',
            image: true,
            child: QrImageView(
              data: payload,
              size: size,
              backgroundColor: Colors.white,
              padding: EdgeInsets.zero,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: ink,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: ink,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _money(amount),
            style: const TextStyle(
              color: ink,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            [
              bank?.shortName ?? profile.bankName,
              profile.accountNumber,
              if (profile.accountHolder.isNotEmpty)
                profile.accountHolder.toUpperCase(),
            ].where((part) => part.trim().isNotEmpty).join(' · '),
            textAlign: TextAlign.center,
            style: const TextStyle(color: ink, fontSize: 13),
          ),
          Text(
            'Nội dung: ${vietQrSafeText(note)}',
            style: const TextStyle(color: Color(0xFF5B615D), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet with the order's payment QR; leads the shop to add bank
/// details when they are missing.
Future<void> showPaymentQrSheet(
  BuildContext context, {
  required OrderRepository repository,
  required int orderId,
  required int amount,
}) async {
  final profile = await repository.loadShopProfile();
  if (!context.mounted) {
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Quét mã để chuyển khoản',
              style: TextStyle(
                fontFamily: FlowerTemplateTheme.headingFont,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            if (profile.hasVietQr)
              VietQrCard(
                profile: profile,
                amount: amount,
                note: vietQrOrderNote(orderId),
              )
            else ...[
              const Text(
                'Chọn ngân hàng và nhập số tài khoản trong Hồ sơ shop để tạo mã QR có sẵn số tiền.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => ShopProfileScreen(repository: repository),
                    ),
                  );
                },
                icon: const Icon(Icons.account_balance_outlined),
                label: const Text('Mở Hồ sơ shop'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
