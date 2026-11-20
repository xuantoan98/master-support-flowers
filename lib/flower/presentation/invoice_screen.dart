import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../data/order_media_store.dart';
import '../data/order_repository.dart';
import '../domain/flower_order.dart';
import '../domain/order_media.dart';
import '../domain/shop_profile.dart';
import '../domain/vietqr.dart';
import 'app_toast.dart';
import 'flower_template_theme.dart';
import 'payment_qr.dart';
import 'shop_profile_screen.dart';

class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({
    super.key,
    required this.order,
    required this.repository,
  });

  final FlowerOrder order;
  final OrderRepository repository;

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  final invoiceKey = GlobalKey();
  ShopProfile? shop;
  bool qrExists = false;

  /// A real photo of the flowers: the order's finished photo, else its
  /// sample photo, else the catalog photo the shop took (not a placeholder).
  File? productPhoto;
  bool loading = true;
  bool sharing = false;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = await widget.repository.loadShopProfile();
      final imageExists =
          result.qrImagePath.isNotEmpty &&
          File(result.qrImagePath).existsSync();
      final photo = await _findProductPhoto();
      if (photo != null && mounted) {
        try {
          // Decode before the invoice can be captured as an image.
          await precacheImage(
            FileImage(photo),
            context,
            // A broken file falls back to the errorBuilder below.
            onError: (_, _) {},
          );
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          productPhoto = photo;
          shop = result;
          qrExists = imageExists;
          loading = false;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Không thể tải hồ sơ shop';
        });
      }
    }
  }

  Future<File?> _findProductPhoto() async {
    final order = widget.order;
    try {
      if (order.id != null) {
        final media = await widget.repository.mediaForOrder(order.id!);
        final store = OrderMediaStore(widget.repository);
        for (final type in [OrderMediaType.finished, OrderMediaType.sample]) {
          for (final item in media.reversed.where((m) => m.type == type)) {
            final file = await store.fileFor(item);
            if (file.existsSync()) {
              return file;
            }
          }
        }
      }
    } catch (_) {
      // No photos: the invoice works without one.
    }
    try {
      final ids = order.effectiveItems
          .map((item) => item.catalogProductId)
          .whereType<int>()
          .toSet();
      if (ids.isEmpty) {
        return null;
      }
      for (final product in await widget.repository.listProducts()) {
        if (ids.contains(product.id) &&
            product.imagePath.isNotEmpty &&
            !product.imagePath.startsWith('assets/')) {
          final file = File(product.imagePath);
          if (file.existsSync()) {
            return file;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// A QR is printed while money is still owed: the generated VietQR when
  /// the shop has bank details, otherwise its uploaded QR image.
  bool get canShowQr =>
      widget.order.status != OrderStatus.cancelled &&
      widget.order.remaining > 0 &&
      (qrExists || (shop?.hasVietQr ?? false));

  Future<void> shareInvoice(BuildContext buttonContext) async {
    if (sharing) {
      return;
    }
    final box = buttonContext.findRenderObject() as RenderBox?;
    final shareOrigin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    setState(() => sharing = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          invoiceKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) {
        throw StateError('Không tạo được ảnh hóa đơn');
      }
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              data.buffer.asUint8List(),
              mimeType: 'image/png',
              name: 'hoa_don_${widget.order.id}.png',
            ),
          ],
          sharePositionOrigin: shareOrigin,
        ),
      );
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Không thể chia sẻ hóa đơn');
      }
    } finally {
      if (mounted) {
        setState(() => sharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Hóa đơn #${widget.order.id}')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(
            child: TextButton(onPressed: load, child: Text('$error · Thử lại')),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Xem trước ảnh gửi khách',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (widget.order.remaining > 0 &&
                    widget.order.status != OrderStatus.cancelled) ...[
                  if (!qrExists && !shop!.hasVietQr)
                    TextButton.icon(
                      onPressed: () async {
                        await Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ShopProfileScreen(
                              repository: widget.repository,
                            ),
                          ),
                        );
                        await load();
                      },
                      icon: const Icon(Icons.account_balance_outlined),
                      label: const Text('Thêm tài khoản ngân hàng để in mã QR'),
                    )
                  else if (!shop!.hasVietQr)
                    const Text(
                      'Ảnh QR do shop cung cấp. Nếu ảnh có số tiền cố định, hãy đối chiếu trước khi chia sẻ.',
                    ),
                  const SizedBox(height: 12),
                ],
                Center(
                  child: RepaintBoundary(
                    key: invoiceKey,
                    // The invoice is an image sent to customers: always light.
                    child: Theme(
                      data: FlowerTemplateTheme.light(),
                      child: DefaultTextStyle.merge(
                        style: const TextStyle(color: FlowerTemplateTheme.ink),
                        child: Container(
                          width: (MediaQuery.sizeOf(context).width - 32).clamp(
                            0,
                            380,
                          ),
                          color: Colors.white,
                          padding: const EdgeInsets.all(22),
                          child: _invoiceContent(shop!),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Builder(
                  builder: (buttonContext) => FilledButton.icon(
                    onPressed: sharing
                        ? null
                        : () => shareInvoice(buttonContext),
                    icon: const Icon(Icons.share_outlined),
                    label: Text(
                      sharing ? 'Đang tạo ảnh…' : 'Chia sẻ ảnh hóa đơn',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ảnh chia sẻ không chứa ghi chú nội bộ. Hãy kiểm tra ảnh QR và số tiền trước khi gửi.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
  );

  Widget _invoiceContent(ShopProfile profile) {
    final order = widget.order;
    return DefaultTextStyle(
      style: const TextStyle(
        fontFamily: FlowerTemplateTheme.bodyFont,
        color: Color(0xFF26334B),
        fontSize: 13,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            profile.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: FlowerTemplateTheme.headingFont,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (profile.phone.isNotEmpty)
            Text(profile.phone, textAlign: TextAlign.center),
          if (profile.address.isNotEmpty)
            Text(profile.address, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          Container(height: 2, color: FlowerTemplateTheme.navy),
          const SizedBox(height: 16),
          Text(
            'HÓA ĐƠN #${order.id}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 12),
          _row('Khách hàng', order.customerName),
          if (order.phone.isNotEmpty) _row('Điện thoại', order.phone),
          if (order.isGift) _row('Người nhận', order.recipientName),
          _row('Hình thức', order.fulfillment.label),
          _row(switch (order.fulfillment) {
            FulfillmentType.delivery => 'Giao lúc',
            FulfillmentType.pickup => 'Nhận lúc',
            FulfillmentType.counter => 'Ngày mua',
          }, DateFormat('HH:mm dd/MM/yyyy', 'vi').format(order.deliveryAt)),
          if (order.needsAddress) _row('Địa chỉ giao', order.address),
          const Divider(height: 28),
          if (productPhoto != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                productPhoto!,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 14),
          ],
          for (final item in order.effectiveItems)
            _row('${item.quantity} × ${item.name}', _money(item.total)),
          const Divider(height: 28),
          _row('Giá hoa', _money(order.price)),
          if (order.shippingFee > 0 || order.needsAddress)
            _row('Phí giao', _money(order.shippingFee)),
          if (order.surcharge > 0) _row('Phụ thu', _money(order.surcharge)),
          if (order.discount > 0)
            _row('Giảm giá', '-${_money(order.discount)}'),
          _row('Tổng cộng', _money(order.total), bold: true),
          _row('Đã thu', _money(order.paid)),
          if (order.status == OrderStatus.cancelled)
            _row(
              'Đơn đã hủy',
              order.paid > 0 ? 'Cần hoàn ${_money(order.paid)}' : '',
              bold: true,
            )
          else
            _row('Còn phải thu', _money(order.remaining), bold: true),
          if (canShowQr && profile.hasVietQr) ...[
            const SizedBox(height: 14),
            Center(
              child: VietQrCard(
                profile: profile,
                amount: order.remaining,
                note: vietQrOrderNote(order.id ?? 0),
                size: 200,
              ),
            ),
          ] else if (canShowQr && qrExists) ...[
            const SizedBox(height: 14),
            Center(
              child: Image.file(
                File(profile.qrImagePath),
                width: 220,
                height: 220,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Text('Không đọc được ảnh QR'),
              ),
            ),
            const Text(
              'Ảnh QR ngân hàng do shop cung cấp',
              textAlign: TextAlign.center,
            ),
            if (profile.bankName.isNotEmpty)
              Text(profile.bankName, textAlign: TextAlign.center),
            if (profile.accountNumber.isNotEmpty)
              Text(profile.accountNumber, textAlign: TextAlign.center),
            if (profile.accountHolder.isNotEmpty)
              Text(profile.accountHolder, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 18),
          const Text(
            'Cảm ơn quý khách!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: FlowerTemplateTheme.headingFont,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  String _money(int value) =>
      '${NumberFormat.decimalPattern('vi').format(value)} đ';
}
