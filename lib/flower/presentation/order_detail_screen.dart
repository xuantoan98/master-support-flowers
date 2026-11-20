part of 'flower_app.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.order,
    required this.repository,
    required this.onChanged,
  });
  final FlowerOrder order;
  final OrderRepository repository;
  final Future<void> Function() onChanged;
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late FlowerOrder order = widget.order;
  bool saving = false;
  bool skipApproval = false;

  /// Newest first; used to undo to the step the order actually came from.
  List<StatusEntry> history = const [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final value = await widget.repository.statusHistory(order.id!);
      if (mounted) {
        setState(() => history = value);
      }
    } catch (_) {
      // Undo falls back to the previous step of the chain.
    }
  }

  /// The earlier step this order went through before reaching its current
  /// status, so undoing a skipped step does not land on a step never taken.
  OrderStatus? get _undoStatus {
    final chain = statusChain(order.fulfillment);
    final current = chain.indexOf(order.status);
    if (current > 0) {
      for (final entry in history.skip(1)) {
        final index = chain.indexOf(entry.status);
        if (index >= 0 && index < current) {
          return entry.status;
        }
      }
    }
    return previousStatusFor(order, skipApproval: skipApproval);
  }

  Future<void> _loadSettings() async {
    try {
      final value = await widget.repository.skipApproval();
      if (mounted) {
        setState(() => skipApproval = value);
      }
    } catch (_) {
      // Keep the full flow when settings cannot be read.
    }
  }

  Future<void> _editOrder() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateOrderScreen(
          repository: widget.repository,
          initialOrder: order,
        ),
      ),
    );
    if (changed != true || !mounted) {
      return;
    }
    final updated = await widget.repository.getById(order.id!);
    if (!mounted) {
      return;
    }
    if (updated != null) {
      setState(() => order = updated);
    }
    await widget.onChanged();
  }

  Future<void> changeStatus(OrderStatus status) async {
    if (saving || status == order.status) {
      return;
    }
    if (status == OrderStatus.cancelled) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Hủy đơn hàng?'),
          content: Text(
            order.paid > 0
                ? 'Đơn hủy sẽ không tính vào doanh thu dự kiến. Đã thu ${money(order.paid)}; hãy hoàn tiền nếu cần.'
                : 'Đơn hủy sẽ không tính vào doanh thu dự kiến.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Giữ đơn'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Hủy đơn'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        return;
      }
    }
    setState(() => saving = true);
    try {
      await widget.repository.updateStatus(order, status);
      HapticFeedback.mediumImpact();
      setState(() => order = order.copyWith(status: status));
      await _loadHistory();
      await widget.onChanged();
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Không thể cập nhật trạng thái');
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Widget _statusCard() {
    final palette = context.palette;
    final cancelled = order.status == OrderStatus.cancelled;
    final chain = visibleStatusChain(order, skipApproval: skipApproval);
    final next = cancelled
        ? null
        : nextStatusFor(order, skipApproval: skipApproval);
    final previous = cancelled ? null : _undoStatus;
    // Offered when the next step is "Chờ duyệt" but the customer does not
    // need to approve this one.
    final afterApproval = next == OrderStatus.awaitingApproval
        ? nextStatusFor(order.copyWith(status: OrderStatus.awaitingApproval))
        : null;
    final canCancel = canChangeStatus(
      order.fulfillment,
      order.status,
      OrderStatus.cancelled,
    );
    String label(OrderStatus status) =>
        order.copyWith(status: status).statusLabel;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'TRẠNG THÁI',
                  style: TextStyle(
                    color: palette.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                OrderStatusChip(order: order),
              ],
            ),
            const SizedBox(height: 14),
            Opacity(
              opacity: cancelled ? 0.45 : 1,
              child: chain.length < 2
                  ? Row(
                      children: [
                        Icon(Icons.storefront_outlined, color: palette.muted),
                        const SizedBox(width: 8),
                        Text(
                          'Đã bán và giao tại quầy',
                          style: TextStyle(color: palette.muted),
                        ),
                      ],
                    )
                  : StepProgressBar(
                      current: cancelled ? -1 : chain.indexOf(order.status),
                      allDone: order.status == OrderStatus.delivered,
                      semanticsPrefix: 'Tiến trình đơn',
                      steps: [
                        for (final status in chain)
                          StepItem(
                            icon: _statusIcon(status),
                            label: label(status),
                            color: _statusColor(status),
                          ),
                      ],
                    ),
            ),
            if (cancelled) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.cancel_outlined, size: 18, color: palette.muted),
                  const SizedBox(width: 6),
                  Text('Đơn đã hủy', style: TextStyle(color: palette.muted)),
                ],
              ),
            ],
            if (next != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: saving ? null : () => changeStatus(next),
                  style: FilledButton.styleFrom(
                    backgroundColor: _statusColorOf(context, next),
                    foregroundColor: palette.isDark
                        ? palette.canvas
                        : Colors.white,
                    minimumSize: const Size(0, 50),
                  ),
                  icon: Icon(_statusIcon(next), size: 20),
                  label: Text('Chuyển sang: ${label(next)}'),
                ),
              ),
            ],
            if (afterApproval != null)
              Center(
                child: TextButton.icon(
                  onPressed: saving ? null : () => changeStatus(afterApproval),
                  icon: const Icon(Icons.fast_forward_rounded, size: 18),
                  label: Text('Bỏ qua chờ duyệt → ${label(afterApproval)}'),
                ),
              ),
            if (order.status == OrderStatus.making ||
                order.status == OrderStatus.awaitingApproval)
              Center(
                child: TextButton.icon(
                  onPressed: saving ? null : _sendPhotosForApproval,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Gửi ảnh cho khách duyệt'),
                ),
              ),
            if (previous != null)
              Center(
                child: TextButton.icon(
                  onPressed: saving ? null : () => changeStatus(previous),
                  style: TextButton.styleFrom(foregroundColor: palette.muted),
                  icon: const Icon(Icons.undo_rounded, size: 18),
                  label: Text('Quay lại: ${label(previous)}'),
                ),
              ),
            if (canCancel)
              Center(
                child: TextButton(
                  onPressed: saving
                      ? null
                      : () => changeStatus(OrderStatus.cancelled),
                  style: TextButton.styleFrom(
                    foregroundColor: palette.adapt(calendarOverdueColor),
                  ),
                  child: const Text('Hủy đơn'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Đơn #${order.id}'),
      actions: [
        IconButton(
          tooltip: 'Hóa đơn',
          onPressed: saving
              ? null
              : () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => InvoiceScreen(
                      order: order,
                      repository: widget.repository,
                    ),
                  ),
                ),
          icon: const Icon(Icons.receipt_long_outlined),
        ),
        IconButton(
          tooltip: 'Sửa đơn',
          onPressed: saving ? null : _editOrder,
          icon: const Icon(Icons.edit_outlined),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        TemplateSectionHeading(
          eyebrow: 'ĐƠN HÀNG',
          title: 'Chi tiết đơn #${order.id}',
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CatalogProductImage(path: orderThumbnail(order), size: 88),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.productName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: FlowerTemplateTheme.headingFont,
                              fontSize: 19,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          OrderStatusChip(order: order),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                _line(
                  'Người đặt',
                  order.customerName,
                  trailing: ContactButtons(
                    name: order.customerName,
                    phone: order.phone,
                  ),
                ),
                _line(
                  'Số điện thoại',
                  order.phone.isEmpty ? 'Chưa có' : order.phone,
                ),
                if (order.isGift) ...[
                  _line(
                    'Người nhận',
                    [
                      order.recipientName,
                      if (order.anonymousSender) '(ẩn tên người tặng)',
                    ].join(' '),
                    trailing: ContactButtons(
                      name: order.recipientName,
                      phone: order.recipientPhone,
                    ),
                  ),
                  if (order.recipientPhone.isNotEmpty)
                    _line('SĐT nhận', order.recipientPhone),
                ],
                _line('Hình thức', order.fulfillment.label),
                _line(
                  switch (order.fulfillment) {
                    FulfillmentType.delivery => 'Giao lúc',
                    FulfillmentType.pickup => 'Khách lấy lúc',
                    FulfillmentType.counter => 'Bán lúc',
                  },
                  '${DateFormat('HH:mm', 'vi').format(order.deliveryAt)} · ${dayLabel(order.deliveryAt)}',
                ),
                if (order.needsAddress)
                  _line(
                    'Địa chỉ',
                    order.address,
                    trailing: MapButton(address: order.address),
                  ),
                if (order.cardMessage.isNotEmpty)
                  _line('Lời thiệp', '“${order.cardMessage}”'),
                if (order.note.isNotEmpty) _line('Ghi chú', order.note),
                const Divider(height: 28),
                const Text(
                  'Sản phẩm',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                for (final item in order.effectiveItems)
                  _line('${item.quantity} × ${item.name}', money(item.total)),
                if (order.components.isNotEmpty) ...[
                  const Divider(height: 28),
                  const Text(
                    'Định lượng hoa',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  for (final component in order.components)
                    _line(
                      component.isMain ? 'Hoa chính' : 'Hoa phụ',
                      '${component.name} · ${component.quantity} ${component.unit}',
                    ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _statusCard(),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _line('Giá hoa', money(order.price)),
                if (order.needsAddress || order.shippingFee > 0)
                  _line('Phí giao', money(order.shippingFee)),
                if (order.surcharge > 0)
                  _line('Phụ thu', money(order.surcharge)),
                if (order.discount > 0)
                  _line('Giảm giá', '-${money(order.discount)}'),
                const Divider(),
                _line('Tổng', money(order.total)),
                _line('Đã thu', money(order.paid)),
                if (order.status == OrderStatus.cancelled)
                  _line('Cần hoàn', money(order.paid))
                else
                  _line('Còn lại', money(order.remaining)),
              ],
            ),
          ),
        ),
        OrderMediaSection(orderId: order.id!, repository: widget.repository),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: saving
              ? null
              : () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => InvoiceScreen(
                      order: order,
                      repository: widget.repository,
                    ),
                  ),
                ),
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('Xem và chia sẻ hóa đơn'),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            if (order.remaining > 0 && order.status != OrderStatus.cancelled)
              FilledButton.icon(
                onPressed: saving ? null : () => _recordPayment(refund: false),
                icon: const Icon(Icons.add),
                label: const Text('Thu thêm'),
              ),
            if (order.remaining > 0 && order.status != OrderStatus.cancelled)
              OutlinedButton.icon(
                onPressed: saving
                    ? null
                    : () => showPaymentQrSheet(
                        context,
                        repository: widget.repository,
                        orderId: order.id!,
                        amount: order.remaining,
                      ),
                icon: const Icon(Icons.qr_code_2),
                label: const Text('Mã QR'),
              ),
            if (order.paid > 0)
              OutlinedButton.icon(
                onPressed: saving ? null : () => _recordPayment(refund: true),
                icon: const Icon(Icons.undo),
                label: const Text('Hoàn tiền'),
              ),
          ],
        ),
        FutureBuilder<List<PaymentEntry>>(
          future: widget.repository.paymentsForOrder(order.id!),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox.shrink();
            }
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lịch sử thanh toán',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    for (final payment in snapshot.data!)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          payment.amount > 0
                              ? '+${money(payment.amount)}'
                              : money(payment.amount),
                        ),
                        subtitle: Text(
                          [
                            if (payment.method != null) payment.method!.label,
                            if (payment.note.isNotEmpty) payment.note,
                            DateFormat(
                              'HH:mm dd/MM/yyyy',
                              'vi',
                            ).format(payment.occurredAt),
                          ].join(' · '),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<StatusEntry>>(
          future: widget.repository.statusHistory(order.id!),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox.shrink();
            }
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lịch sử trạng thái',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    for (final entry in snapshot.data!)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.history,
                          color: context.palette.muted,
                        ),
                        title: Text(
                          order.copyWith(status: entry.status).statusLabel,
                        ),
                        subtitle: Text(
                          DateFormat(
                            'HH:mm dd/MM/yyyy',
                            'vi',
                          ).format(entry.changedAt),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<OrderChangeEntry>>(
          future: widget.repository.orderChanges(order.id!),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox.shrink();
            }
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lịch sử chỉnh sửa',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    for (final change in snapshot.data!)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.edit_note,
                          color: context.palette.muted,
                        ),
                        title: Text(change.details),
                        subtitle: Text(
                          DateFormat(
                            'HH:mm dd/MM/yyyy',
                            'vi',
                          ).format(change.changedAt),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    ),
  );

  /// Shares the order's photos (finished flowers first) so the shop can send
  /// them to the customer in Zalo, Messenger… for approval.
  Future<void> _sendPhotosForApproval() async {
    try {
      final media = await widget.repository.mediaForOrder(order.id!);
      final store = OrderMediaStore(widget.repository);
      final ordered = [
        ...media.where((m) => m.type == OrderMediaType.finished),
        ...media.where((m) => m.type != OrderMediaType.finished),
      ];
      final files = <XFile>[];
      for (final item in ordered.take(6)) {
        final file = await store.fileFor(item);
        if (file.existsSync()) {
          files.add(XFile(file.path));
        }
      }
      if (!mounted) {
        return;
      }
      if (files.isEmpty) {
        AppToast.show(context, 'Hãy chụp ảnh thành phẩm ở mục Ảnh đơn trước');
        return;
      }
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          files: files,
          text:
              'Tiệm gửi ảnh hoa đơn #${order.id} (${order.productName}). '
              'Anh/chị xem giúp tiệm đã ưng chưa ạ?',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
      if (order.status == OrderStatus.making && mounted) {
        await changeStatus(OrderStatus.awaitingApproval);
      }
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Không thể chia sẻ ảnh');
      }
    }
  }

  Future<void> _recordPayment({required bool refund}) async {
    final result = await showDialog<_PaymentResult>(
      context: context,
      builder: (_) => _PaymentInputDialog(
        refund: refund,
        max: refund ? order.paid : order.remaining,
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() => saving = true);
    try {
      await widget.repository.addPayment(
        order.id!,
        result.amount,
        note: result.note,
        method: result.method,
      );
      setState(() => order = order.copyWith(paid: order.paid + result.amount));
      await widget.onChanged();
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Không thể lưu thanh toán');
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  /// A label/value row; [trailing] (e.g. call and Zalo icons) sits at the
  /// right end, centred on the row.
  Widget _line(String label, String value, {Widget? trailing}) => Padding(
    padding: EdgeInsets.only(bottom: trailing == null ? 12 : 4),
    child: Row(
      crossAxisAlignment: trailing == null
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 105,
          child: Text(label, style: TextStyle(color: context.palette.muted)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class _PaymentResult {
  const _PaymentResult(this.amount, this.note, this.method);
  final int amount;
  final String note;
  final PaymentMethod method;
}

class _PaymentInputDialog extends StatefulWidget {
  const _PaymentInputDialog({required this.refund, required this.max});
  final bool refund;
  final int max;

  @override
  State<_PaymentInputDialog> createState() => _PaymentInputDialogState();
}

class _PaymentInputDialogState extends State<_PaymentInputDialog> {
  final amount = TextEditingController();
  final note = TextEditingController();
  PaymentMethod method = PaymentMethod.cash;

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.refund ? 'Hoàn tiền' : 'Thu thêm'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: amount,
          keyboardType: TextInputType.number,
          inputFormatters: [
            MoneyInputFormatter(Localizations.localeOf(context).toString()),
          ],
          autofocus: true,
          decoration: InputDecoration(
            label: const RequiredLabel('Số tiền (đ)'),
            helperText: 'Tối đa ${money(widget.max)}',
          ),
        ),
        if (!widget.refund)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => amount.text = formatCurrencyInput(
                widget.max,
                Localizations.localeOf(context).toString(),
              ),
              child: Text('Thu đủ ${money(widget.max)}'),
            ),
          ),
        const SizedBox(height: 8),
        PaymentMethodChips(
          value: method,
          methods: widget.refund
              ? const [PaymentMethod.cash, PaymentMethod.transfer]
              : PaymentMethod.values,
          onChanged: (value) => setState(() => method = value),
        ),
        TextField(
          controller: note,
          decoration: const InputDecoration(
            labelText: 'Ghi chú (không bắt buộc)',
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          final value = parseCurrencyInput(amount.text);
          if (value == null || value <= 0 || value > widget.max) {
            AppToast.show(context, 'Số tiền không hợp lệ');
            return;
          }
          Navigator.pop(
            context,
            _PaymentResult(
              widget.refund ? -value : value,
              note.text.trim(),
              method,
            ),
          );
        },
        child: const Text('Lưu'),
      ),
    ],
  );
}
