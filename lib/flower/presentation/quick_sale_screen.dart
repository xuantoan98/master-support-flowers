part of 'flower_app.dart';

/// One-page sale for a customer standing at the counter: pick flowers, take
/// the money, done. Saved as a finished counter order paid in full.
class QuickSaleScreen extends StatefulWidget {
  const QuickSaleScreen({super.key, required this.repository});

  final OrderRepository repository;

  @override
  State<QuickSaleScreen> createState() => _QuickSaleScreenState();
}

class _QuickSaleScreenState extends State<QuickSaleScreen> {
  late final Future<List<CatalogProduct>> products = widget.repository
      .listProducts();
  final items = <OrderItem>[];
  final customer = TextEditingController();
  final phone = TextEditingController();
  final manualName = TextEditingController();
  final manualPrice = TextEditingController();
  final discount = TextEditingController();
  PaymentMethod method = PaymentMethod.cash;
  bool saving = false;
  ProductCategory? category;

  /// When the sale happened, for a sale entered later the same day.
  /// Null means now.
  TimeOfDay? soldAt;

  /// Same bottom-sheet wheel as the create-order time picker, capped at now.
  Future<void> pickSoldAt() async {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    var candidate = soldAt == null
        ? now
        : today.add(Duration(hours: soldAt!.hour, minutes: soldAt!.minute));
    final chosen = await showModalBottomSheet<DateTime>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: 300,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Đơn đã bán lúc · Hôm nay',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext, candidate),
                      child: const Text('Xong'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  maximumDate: now,
                  initialDateTime: candidate,
                  use24hFormat: true,
                  onDateTimeChanged: (value) => candidate = value,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null || !mounted) {
      return;
    }
    if (chosen.hour * 60 + chosen.minute > now.hour * 60 + now.minute) {
      AppToast.show(context, 'Giờ bán không được sau bây giờ');
      return;
    }
    setState(() => soldAt = TimeOfDay.fromDateTime(chosen));
  }

  @override
  void dispose() {
    for (final c in [customer, phone, manualName, manualPrice, discount]) {
      c.dispose();
    }
    super.dispose();
  }

  int get itemsTotal => orderItemsTotal(items);
  int get discountAmount =>
      (parseCurrencyInput(discount.text) ?? 0).clamp(0, itemsTotal);
  int get total => itemsTotal - discountAmount;

  int quantityOf(CatalogProduct product) => items
      .where((item) => item.catalogProductId == product.id)
      .fold(0, (sum, item) => sum + item.quantity);

  void addProduct(CatalogProduct product) {
    HapticFeedback.selectionClick();
    setState(() {
      final index = items.indexWhere(
        (item) => product.id != null && item.catalogProductId == product.id,
      );
      if (index >= 0) {
        items[index] = items[index].withQuantity(items[index].quantity + 1);
      } else {
        items.add(
          OrderItem(
            catalogProductId: product.id,
            name: product.displayName,
            unitPrice: product.price,
            components: List.of(product.components),
          ),
        );
      }
    });
  }

  void changeQuantity(int index, int quantity) {
    setState(() {
      if (quantity <= 0) {
        items.removeAt(index);
      } else {
        items[index] = items[index].withQuantity(quantity);
      }
    });
  }

  void addManual() {
    final name = manualName.text.trim();
    final price = parseCurrencyInput(manualPrice.text) ?? 0;
    if (name.isEmpty || price <= 0) {
      AppToast.show(context, 'Nhập tên và giá sản phẩm hợp lệ');
      return;
    }
    setState(() {
      items.add(OrderItem(name: name, unitPrice: price));
      manualName.clear();
      manualPrice.clear();
    });
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> finish() async {
    if (items.isEmpty) {
      AppToast.show(context, 'Chọn ít nhất một sản phẩm');
      return;
    }
    if (method == PaymentMethod.transfer && total > 0) {
      final received = await _confirmTransfer();
      if (received != true || !mounted) {
        return;
      }
    }
    final current = DateTime.now();
    final now = soldAt == null
        ? current
        : DateTime(
            current.year,
            current.month,
            current.day,
            soldAt!.hour,
            soldAt!.minute,
          );
    final order = FlowerOrder(
      customerName: customer.text.trim().isEmpty
          ? 'Khách lẻ'
          : customer.text.trim(),
      phone: phone.text.trim(),
      productName: orderItemsLabel(items),
      price: itemsTotal,
      shippingFee: 0,
      paid: total,
      deliveryAt: now,
      address: '',
      items: List.of(items),
      components: orderItemsComponents(items),
      status: OrderStatus.delivered,
      fulfillment: FulfillmentType.counter,
      discount: discountAmount,
    );
    setState(() => saving = true);
    try {
      final id = await widget.repository.add(
        order,
        paymentMethod: total > 0 ? method : null,
      );
      HapticFeedback.mediumImpact();
      if (mounted) {
        AppToast.show(
          context,
          'Đã bán xong đơn #$id · ${money(total)}',
          isError: false,
        );
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => saving = false);
        AppToast.show(context, 'Không thể lưu đơn bán. Vui lòng thử lại');
      }
    }
  }

  /// Shows the shop's VietQR for the total; the shop confirms once the
  /// money shows up in its banking app.
  Future<bool?> _confirmTransfer() async {
    final profile = await widget.repository.loadShopProfile();
    if (!mounted) {
      return false;
    }
    return showModalBottomSheet<bool>(
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
                'Khách quét mã để chuyển khoản',
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
                  amount: total,
                  note: 'Mua hoa ${DateFormat('HHmm').format(DateTime.now())}',
                )
              else
                Text(
                  'Chưa có tài khoản ngân hàng trong Hồ sơ shop. Đưa khách số tài khoản để chuyển ${money(total)}.',
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 50)),
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Đã nhận tiền'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('Bán nhanh tại quầy')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  const TemplateSectionHeading(
                    eyebrow: 'BƯỚC 1',
                    title: 'Chọn hoa',
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<CatalogProduct>>(
                    future: products,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Text('Không thể tải mẫu hoa');
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      // Sold-out products stay in the catalog, not here.
                      final available = snapshot.data!
                          .where((p) => !p.soldOut)
                          .toList();
                      final used = ProductCategory.values
                          .where((c) => available.any((p) => p.category == c))
                          .toList();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (used.length > 1) ...[
                            CategoryFilter(
                              categories: used,
                              value: category,
                              onChanged: (value) =>
                                  setState(() => category = value),
                            ),
                            const SizedBox(height: 10),
                          ],
                          GridView.count(
                            crossAxisCount: 3,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.72,
                            children: [
                              for (final product in available)
                                if (category == null ||
                                    product.category == category)
                                  _productTile(product),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: manualName,
                          decoration: const InputDecoration(
                            labelText: 'Sản phẩm khác',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: manualPrice,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            MoneyInputFormatter(
                              Localizations.localeOf(context).toString(),
                            ),
                          ],
                          onSubmitted: (_) => addManual(),
                          decoration: const InputDecoration(
                            labelText: 'Giá (đ)',
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Thêm sản phẩm khác',
                        onPressed: addManual,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  if (items.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    for (var index = 0; index < items.length; index++)
                      Card(
                        child: ListTile(
                          title: Text(items[index].name),
                          subtitle: Text(
                            '${money(items[index].unitPrice)} × ${items[index].quantity}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Bớt ${items[index].name}',
                                onPressed: () => changeQuantity(
                                  index,
                                  items[index].quantity - 1,
                                ),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text('${items[index].quantity}'),
                              IconButton(
                                tooltip: 'Thêm ${items[index].name}',
                                onPressed: () => changeQuantity(
                                  index,
                                  items[index].quantity + 1,
                                ),
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 20),
                  const TemplateSectionHeading(
                    eyebrow: 'BƯỚC 2',
                    title: 'Thu tiền',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: discount,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      MoneyInputFormatter(
                        Localizations.localeOf(context).toString(),
                      ),
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Giảm giá (đ, không bắt buộc)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  PaymentMethodChips(
                    value: method,
                    methods: const [PaymentMethod.cash, PaymentMethod.transfer],
                    onChanged: (value) => setState(() => method = value),
                  ),
                  const SizedBox(height: 4),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history_toggle_off),
                    title: const Text('Bán lúc'),
                    subtitle: Text(
                      soldAt == null
                          ? 'Bây giờ · chạm để ghi bù đơn đã bán trước đó hôm nay'
                          : 'Hôm nay ${soldAt!.hour.toString().padLeft(2, '0')}:${soldAt!.minute.toString().padLeft(2, '0')}',
                    ),
                    trailing: soldAt == null
                        ? const Icon(Icons.chevron_right)
                        : IconButton(
                            tooltip: 'Bán bây giờ',
                            onPressed: () => setState(() => soldAt = null),
                            icon: const Icon(Icons.close),
                          ),
                    onTap: pickSoldAt,
                  ),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Thông tin khách (không bắt buộc)'),
                    children: [
                      TextField(
                        controller: customer,
                        decoration: const InputDecoration(
                          labelText: 'Tên khách',
                          hintText: 'Khách lẻ',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Số điện thoại',
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: palette.card,
                border: Border(top: BorderSide(color: palette.line)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Tổng tiền',
                          style: TextStyle(color: palette.muted, fontSize: 13),
                        ),
                        Text(
                          money(total),
                          style: TextStyle(
                            fontFamily: FlowerTemplateTheme.headingFont,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: palette.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: saving || items.isEmpty ? null : finish,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                    ),
                    icon: Icon(
                      method == PaymentMethod.transfer
                          ? Icons.qr_code_2
                          : Icons.check_circle_rounded,
                    ),
                    label: Text(
                      saving
                          ? 'Đang lưu…'
                          : method == PaymentMethod.transfer
                          ? 'Hiện mã QR'
                          : 'Thu tiền & xong',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _productTile(CatalogProduct product) {
    final palette = context.palette;
    final count = quantityOf(product);
    return Semantics(
      button: true,
      label:
          '${product.name}, ${money(product.price)}'
          '${count > 0 ? ', đã chọn $count' : ''}',
      excludeSemantics: true,
      child: Material(
        color: palette.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: count > 0 ? palette.primary : palette.line,
            width: count > 0 ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => addProduct(product),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) => Center(
                        child: CatalogProductImage(
                          path: product.imagePath,
                          size: box.maxWidth < box.maxHeight
                              ? box.maxWidth
                              : box.maxHeight,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          money(product.price),
                          style: TextStyle(color: palette.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (count > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: CircleAvatar(
                    radius: 13,
                    backgroundColor: palette.primary,
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: palette.onPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
