part of 'flower_app.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({
    super.key,
    required this.repository,
    this.initialOrder,
    this.deliveryDay,
    this.addressSuggester,
    this.contactPicker = pickSystemContact,
  });
  final OrderRepository repository;
  final FlowerOrder? initialOrder;
  final DateTime? deliveryDay;

  /// Map suggestions for the delivery address; defaults to Goong when the
  /// build has a `GOONG_API_KEY`, otherwise the field is manual only.
  final AddressSuggester? addressSuggester;

  /// Fills the customer step from the phone's address book.
  final ContactPicker contactPicker;
  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  late final AddressSuggester? _addressSuggester =
      widget.addressSuggester ?? GoongAddressSuggester.fromEnvironment();
  final name = TextEditingController();
  final phone = TextEditingController();
  final product = TextEditingController();
  final price = TextEditingController();
  final productFocus = FocusNode();
  final priceFocus = FocusNode();

  /// Quantity for the manual product being typed, shown before it is added.
  int manualQuantity = 1;
  final shipping = TextEditingController(text: '0');
  final paid = TextEditingController(text: '0');
  final address = TextEditingController();
  final note = TextEditingController();
  final recipientName = TextEditingController();
  final recipientPhone = TextEditingController();
  final cardMessage = TextEditingController();
  final discount = TextEditingController();
  final surcharge = TextEditingController();
  FulfillmentType fulfillment = FulfillmentType.delivery;
  bool isGift = false;
  bool anonymousSender = false;

  /// The discount field holds a percentage of goods + surcharge, not đồng.
  bool discountPercent = false;
  PaymentMethod depositMethod = PaymentMethod.cash;
  List<FlowerComponent> components = [];
  List<OrderItem> selectedItems = [];
  DateTime delivery = roundUpToHalfHour(
    DateTime.now().add(const Duration(days: 1)),
  );
  int step = 0;

  /// The shop's past orders, for defaults and "order again".
  List<FlowerOrder> _history = const [];
  bool saving = false;
  bool _saved = false;
  bool _dirty = false;
  bool _hasDraft = false;
  Timer? _draftTimer;
  Timer? _clockTimer;
  bool _deliveryWasValid = true;
  Future<void> _draftWrites = Future<void>.value();

  DateTime _deliveryOnDay(DateTime day, DateTime preferredTime) {
    final candidate = DateTime(
      day.year,
      day.month,
      day.day,
      preferredTime.hour,
      preferredTime.minute,
    );
    final now = DateTime.now();
    if (candidate.isAfter(now)) {
      return candidate;
    }
    return DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(const Duration(minutes: 1));
  }

  @override
  void initState() {
    super.initState();
    final initial = widget.initialOrder;
    if (initial == null) {
      if (widget.deliveryDay != null) {
        delivery = _deliveryOnDay(widget.deliveryDay!, delivery);
      }
      _restoreDraft().then((_) => _loadHistory());
    } else {
      name.text = initial.customerName;
      phone.text = initial.phone;
      selectedItems = List.of(initial.effectiveItems);
      shipping.text = formatCurrencyInput(
        initial.shippingFee,
        Intl.getCurrentLocale(),
      );
      paid.text = formatCurrencyInput(initial.paid, Intl.getCurrentLocale());
      address.text = initial.address;
      note.text = initial.note;
      components = List.of(initial.components);
      delivery = initial.deliveryAt;
      fulfillment = initial.fulfillment;
      isGift = initial.isGift;
      recipientName.text = initial.recipientName;
      recipientPhone.text = initial.recipientPhone;
      cardMessage.text = initial.cardMessage;
      anonymousSender = initial.anonymousSender;
      discount.text = initial.discount == 0
          ? ''
          : formatCurrencyInput(initial.discount, Intl.getCurrentLocale());
      surcharge.text = initial.surcharge == 0
          ? ''
          : formatCurrencyInput(initial.surcharge, Intl.getCurrentLocale());
    }
    _deliveryWasValid = deliveryIssue() == null;
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      final valid = deliveryIssue() == null;
      if (valid != _deliveryWasValid) {
        setState(() => _deliveryWasValid = valid);
        if (!valid && step == 3) {
          AppToast.show(context, 'Giờ giao đã qua. Hãy chọn giờ giao mới.');
        }
      }
    });
  }

  Future<void> _loadHistory() async {
    final List<FlowerOrder> orders;
    try {
      orders = await widget.repository.all();
    } catch (_) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _history = orders;
      // Start a fresh order with the fee the shop usually charges.
      if (!_hasDraft && !_dirty && (parseMoney(shipping.text) ?? 0) == 0) {
        final fee = usualShippingFee(orders);
        if (fee > 0) {
          shipping.text = formatCurrencyInput(fee, Intl.getCurrentLocale());
        }
      }
    });
  }

  /// The selected customer's previous order, offered as "order again".
  FlowerOrder? get _previousOrder => widget.initialOrder == null
      ? lastOrderOf(_history, name.text, phone.text)
      : null;

  void _orderAgain(FlowerOrder previous) {
    setState(() {
      selectedItems = List.of(previous.effectiveItems);
      fulfillment = previous.fulfillment == FulfillmentType.counter
          ? FulfillmentType.pickup
          : previous.fulfillment;
      address.text = previous.address;
      isGift = previous.isGift;
      recipientName.text = previous.recipientName;
      recipientPhone.text = previous.recipientPhone;
      anonymousSender = previous.anonymousSender;
      if (fulfillment == FulfillmentType.delivery) {
        shipping.text = formatCurrencyInput(
          previous.shippingFee,
          Intl.getCurrentLocale(),
        );
      }
    });
    _scheduleDraftSave();
    AppToast.show(
      context,
      'Đã điền như đơn ${DateFormat('dd/MM', 'vi').format(previous.deliveryAt)}. '
      'Hãy chọn ngày giờ giao.',
      isError: false,
    );
  }

  Future<void> _restoreDraft() async {
    try {
      final draft = await widget.repository.loadDraft();
      if (draft == null || !mounted || _dirty) {
        return;
      }
      setState(() {
        _hasDraft = true;
        name.text = draft['name'] as String? ?? '';
        phone.text = draft['phone'] as String? ?? '';
        product.text = draft['product'] as String? ?? '';
        manualQuantity = ((draft['manualQuantity'] as int?) ?? 1).clamp(1, 999);
        price.text = _formattedDraftMoney(draft['price'] as String? ?? '');
        shipping.text = _formattedDraftMoney(
          draft['shipping'] as String? ?? '0',
        );
        paid.text = _formattedDraftMoney(draft['paid'] as String? ?? '0');
        address.text = draft['address'] as String? ?? '';
        note.text = draft['note'] as String? ?? '';
        fulfillment = FulfillmentTypeLabel.parse(draft['fulfillment']);
        isGift = draft['isGift'] as bool? ?? false;
        recipientName.text = draft['recipientName'] as String? ?? '';
        recipientPhone.text = draft['recipientPhone'] as String? ?? '';
        cardMessage.text = draft['cardMessage'] as String? ?? '';
        anonymousSender = draft['anonymousSender'] as bool? ?? false;
        discountPercent = draft['discountPercent'] as bool? ?? false;
        discount.text = discountPercent
            ? draft['discount'] as String? ?? ''
            : _formattedDraftMoney(draft['discount'] as String? ?? '');
        surcharge.text = _formattedDraftMoney(
          draft['surcharge'] as String? ?? '',
        );
        depositMethod =
            PaymentMethodLabel.parse(draft['depositMethod']) ??
            PaymentMethod.cash;
        components = (draft['components'] as List<dynamic>? ?? [])
            .map(
              (item) => FlowerComponent.fromJson(item as Map<String, dynamic>),
            )
            .toList();
        selectedItems = (draft['items'] as List<dynamic>? ?? [])
            .map((item) => OrderItem.fromJson(item as Map<String, dynamic>))
            .toList();
        if (selectedItems.isEmpty &&
            (draft['step'] as int? ?? 0) > 1 &&
            product.text.trim().isNotEmpty &&
            (parseMoney(price.text) ?? 0) > 0) {
          selectedItems = [
            OrderItem(
              name: product.text.trim(),
              unitPrice: parseMoney(price.text)!,
              components: components,
            ),
          ];
          product.clear();
          price.clear();
        }
        delivery =
            DateTime.tryParse(draft['delivery'] as String? ?? '') ?? delivery;
        if (widget.deliveryDay != null) {
          delivery = _deliveryOnDay(widget.deliveryDay!, delivery);
        }
        step = (draft['step'] as int? ?? 0).clamp(0, 3);
        _deliveryWasValid = deliveryIssue() == null;
      });
    } catch (_) {
      // The form remains usable if a draft cannot be read.
    }
  }

  Map<String, dynamic> _draftPayload() => {
    'name': name.text,
    'phone': phone.text,
    'product': product.text,
    'manualQuantity': manualQuantity,
    'price': price.text,
    'shipping': shipping.text,
    'paid': paid.text,
    'address': address.text,
    'note': note.text,
    'fulfillment': fulfillment.key,
    'isGift': isGift,
    'recipientName': recipientName.text,
    'recipientPhone': recipientPhone.text,
    'cardMessage': cardMessage.text,
    'anonymousSender': anonymousSender,
    'discountPercent': discountPercent,
    'discount': discount.text,
    'surcharge': surcharge.text,
    'depositMethod': depositMethod.name,
    'components': components.map((item) => item.toJson()).toList(),
    'items': selectedItems.map((item) => item.toJson()).toList(),
    'delivery': delivery.toIso8601String(),
    'step': step,
  };

  void _saveDraft() {
    if (widget.initialOrder != null || !_dirty || _saved) {
      return;
    }
    final snapshot = _draftPayload();
    _draftWrites = _draftWrites.then((_) async {
      try {
        await widget.repository.saveDraft(snapshot);
      } catch (_) {
        // A failed draft write must not block later saves or order creation.
      }
    });
  }

  void _scheduleDraftSave() {
    if (widget.initialOrder != null) {
      return;
    }
    _dirty = true;
    _hasDraft = true;
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 350), _saveDraft);
  }

  Future<void> _discardDraft() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa bản nháp?'),
        content: const Text('Thông tin đơn đang nhập sẽ bị xóa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    _draftTimer?.cancel();
    await _draftWrites;
    await widget.repository.clearDraft();
    if (!mounted) {
      return;
    }
    setState(() {
      for (final controller in [
        name,
        phone,
        product,
        price,
        address,
        note,
        recipientName,
        recipientPhone,
        cardMessage,
        discount,
        surcharge,
      ]) {
        controller.clear();
      }
      fulfillment = FulfillmentType.delivery;
      isGift = false;
      anonymousSender = false;
      discountPercent = false;
      depositMethod = PaymentMethod.cash;
      final fee = usualShippingFee(_history);
      shipping.text = fee > 0
          ? formatCurrencyInput(fee, Intl.getCurrentLocale())
          : '0';
      paid.text = '0';
      components = [];
      selectedItems = [];
      delivery = widget.deliveryDay == null
          ? roundUpToHalfHour(DateTime.now().add(const Duration(days: 1)))
          : _deliveryOnDay(widget.deliveryDay!, DateTime.now());
      _deliveryWasValid = true;
      step = 0;
      _dirty = false;
      _hasDraft = false;
    });
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _clockTimer?.cancel();
    _saveDraft();
    productFocus.dispose();
    priceFocus.dispose();
    for (final c in [
      name,
      phone,
      product,
      price,
      shipping,
      paid,
      address,
      note,
      recipientName,
      recipientPhone,
      cardMessage,
      discount,
      surcharge,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int? parseMoney(String value) => parseCurrencyInput(value);

  String _formattedDraftMoney(String value) {
    final amount = parseCurrencyInput(value);
    return amount == null
        ? ''
        : formatCurrencyInput(amount, Intl.getCurrentLocale());
  }

  int get itemsPrice => orderItemsTotal(selectedItems);

  bool get delivers => fulfillment == FulfillmentType.delivery;

  int get shippingAmount => delivers ? (parseMoney(shipping.text) ?? 0) : 0;

  int get surchargeAmount => parseMoney(surcharge.text) ?? 0;

  /// The discount in đồng, whether it was typed as đồng or as a percentage.
  int get discountAmount {
    final value = parseMoney(discount.text) ?? 0;
    if (!discountPercent) {
      return value;
    }
    return (itemsPrice + surchargeAmount) * value.clamp(0, 100) ~/ 100;
  }

  int get orderTotal =>
      itemsPrice + shippingAmount + surchargeAmount - discountAmount;

  void addManualProduct({bool focusNext = false}) {
    final title = product.text.trim();
    final amount = parseMoney(price.text) ?? 0;
    if (title.isEmpty || amount <= 0) {
      AppToast.show(context, 'Nhập tên và giá sản phẩm hợp lệ');
      return;
    }
    setState(() {
      selectedItems.add(
        OrderItem(
          name: title,
          unitPrice: amount,
          components: List.of(components),
        ).withQuantity(manualQuantity),
      );
      product.clear();
      price.clear();
      components = [];
      manualQuantity = 1;
    });
    _scheduleDraftSave();
    if (focusNext) {
      _focusTextField(productFocus);
    }
  }

  /// Moves focus to a text field and makes sure the keyboard switches back
  /// from a numeric layout: some Android keyboards keep the previous input
  /// type when focus jumps between fields, so close the input connection
  /// first and reopen it on the next frame.
  void _focusTextField(FocusNode node) {
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && node.canRequestFocus) {
        node.requestFocus();
      }
    });
  }

  Future<void> pickFromContacts() async {
    final PickedContact? contact;
    try {
      contact = await widget.contactPicker();
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Không mở được danh bạ');
      }
      return;
    }
    if (contact == null || !mounted) {
      return;
    }
    if (contact.name.isEmpty && contact.phone.isEmpty) {
      AppToast.show(context, 'Liên hệ này chưa có tên hoặc số điện thoại');
      return;
    }
    setState(() {
      if (contact!.name.isNotEmpty) {
        name.text = contact.name;
      }
      phone.text = contact.phone;
    });
    _scheduleDraftSave();
    AppToast.show(context, 'Đã điền thông tin từ danh bạ', isError: false);
  }

  Future<void> pickRecipientFromContacts() async {
    final PickedContact? contact;
    try {
      contact = await widget.contactPicker();
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Không mở được danh bạ');
      }
      return;
    }
    if (contact == null || !mounted) {
      return;
    }
    setState(() {
      if (contact!.name.isNotEmpty) {
        recipientName.text = contact.name;
      }
      recipientPhone.text = contact.phone;
    });
    _scheduleDraftSave();
  }

  void changeManualQuantity(int quantity) {
    setState(() => manualQuantity = quantity.clamp(1, 999));
    _scheduleDraftSave();
  }

  void changeItemQuantity(int index, int quantity) {
    setState(() {
      if (quantity <= 0) {
        selectedItems.removeAt(index);
      } else {
        selectedItems[index] = selectedItems[index].withQuantity(quantity);
      }
    });
    _scheduleDraftSave();
  }

  String? deliveryIssue() {
    if (widget.initialOrder != null &&
        delivery == widget.initialOrder!.deliveryAt) {
      return null;
    }
    return deliveryTimeIssue(delivery);
  }

  static const _reviewStep = 4;

  bool get reviewing => step == _reviewStep;

  String? validateStep([int? at]) => switch (at ?? step) {
    0 when name.text.trim().isEmpty => 'Vui lòng nhập tên khách hàng',
    1 when selectedItems.isEmpty && product.text.trim().isEmpty =>
      'Vui lòng thêm sản phẩm',
    1
        when product.text.trim().isNotEmpty &&
            (parseMoney(price.text) ?? 0) <= 0 =>
      'Giá sản phẩm phải lớn hơn 0',
    1 when product.text.trim().isEmpty && price.text.isNotEmpty =>
      'Vui lòng nhập tên sản phẩm',
    0 when isGift && recipientName.text.trim().isEmpty =>
      'Vui lòng nhập tên người nhận',
    2 when delivers && address.text.trim().isEmpty =>
      'Vui lòng nhập địa chỉ giao',
    2 when deliveryIssue() != null => deliveryIssue(),
    3
        when (delivers && parseMoney(shipping.text) == null) ||
            parseMoney(paid.text) == null =>
      'Vui lòng nhập số tiền hợp lệ',
    3 when discountPercent && (parseMoney(discount.text) ?? 0) > 100 =>
      'Giảm giá theo % không vượt quá 100%',
    3 when discountAmount > itemsPrice + surchargeAmount =>
      'Giảm giá không vượt quá tiền hàng',
    3 when (parseMoney(paid.text) ?? 0) > orderTotal =>
      'Tiền đã thu không vượt quá tổng',
    _ => null,
  };

  /// True when every step from here to payment is already valid, so the
  /// shop can jump to the summary without paging through defaults.
  bool get canReviewEarly {
    if (widget.initialOrder != null || step == 0 || step >= 3) {
      return false;
    }
    final hasItems = selectedItems.isNotEmpty || product.text.trim().isNotEmpty;
    if (!hasItems) {
      return false;
    }
    for (var s = 0; s <= 3; s++) {
      if (validateStep(s) != null) {
        return false;
      }
    }
    return deliveryIssue() == null;
  }

  void reviewNow() {
    if (product.text.trim().isNotEmpty) {
      addManualProduct();
    }
    setState(() => step = _reviewStep);
    _scheduleDraftSave();
  }

  Future<void> next() async {
    final issue = validateStep();
    if (issue != null) {
      AppToast.show(context, issue);
      return;
    }
    if (step < 3) {
      if (step == 1 && product.text.trim().isNotEmpty) {
        addManualProduct();
      }
      setState(() => step++);
      _scheduleDraftSave();
      return;
    }
    if (selectedItems.isEmpty) {
      AppToast.show(context, 'Vui lòng thêm sản phẩm');
      setState(() => step = 1);
      return;
    }
    final timeIssue = deliveryIssue();
    if (timeIssue != null) {
      AppToast.show(context, timeIssue);
      return;
    }
    if (step == 3) {
      // Nothing is saved until the shop confirms the summary.
      setState(() => step = _reviewStep);
      _scheduleDraftSave();
      return;
    }
    final order = FlowerOrder(
      id: widget.initialOrder?.id,
      customerName: name.text,
      phone: phone.text,
      productName: orderItemsLabel(selectedItems),
      price: itemsPrice,
      shippingFee: shippingAmount,
      paid: widget.initialOrder?.paid ?? parseMoney(paid.text)!,
      deliveryAt: delivery,
      address: delivers ? address.text : '',
      note: note.text,
      components: orderItemsComponents(selectedItems),
      items: List.of(selectedItems),
      status: widget.initialOrder?.status ?? OrderStatus.newOrder,
      fulfillment: fulfillment,
      recipientName: isGift ? recipientName.text : '',
      recipientPhone: isGift ? recipientPhone.text : '',
      cardMessage: cardMessage.text,
      anonymousSender: isGift && anonymousSender,
      discount: discountAmount,
      surcharge: surchargeAmount,
    );
    setState(() => saving = true);
    _draftTimer?.cancel();
    try {
      await _draftWrites;
      if (widget.initialOrder == null) {
        await widget.repository.add(
          order,
          paymentMethod: order.paid > 0 ? depositMethod : null,
        );
      } else {
        await widget.repository.updateOrder(order);
      }
      _saved = true;
      if (mounted && widget.initialOrder == null) {
        await showOrderSuccess(context);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (exception) {
      if (mounted) {
        setState(() => saving = false);
        AppToast.show(
          context,
          exception is ArgumentError &&
                  exception.message ==
                      'Thời gian giao phải sau thời điểm hiện tại'
              ? exception.message as String
              : 'Không thể lưu đơn. Vui lòng thử lại',
        );
      }
    }
  }

  Future<void> chooseProduct() async {
    try {
      final all = await widget.repository.listProducts();
      if (!mounted) {
        return;
      }
      final products = all.where((p) => !p.soldOut).toList();
      if (products.isEmpty) {
        AppToast.show(
          context,
          all.isEmpty
              ? 'Catalog chưa có mẫu hoa'
              : 'Các mẫu hoa đều đang tạm hết',
        );
        return;
      }
      final selected = await showModalBottomSheet<CatalogProduct>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => _ProductPickerSheet(products: products),
      );
      if (selected == null || !mounted) {
        return;
      }
      setState(() {
        final index = selectedItems.indexWhere(
          (item) => item.catalogProductId == selected.id && selected.id != null,
        );
        if (index >= 0) {
          selectedItems[index] = selectedItems[index].withQuantity(
            selectedItems[index].quantity + 1,
          );
        } else {
          selectedItems.add(
            OrderItem(
              catalogProductId: selected.id,
              name: selected.displayName,
              unitPrice: selected.price,
              components: List.of(selected.components),
            ),
          );
        }
      });
      _scheduleDraftSave();
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Không thể tải catalog');
      }
    }
  }

  Future<void> pickDeliveryDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final currentDay = DateUtils.dateOnly(delivery);
    final date = await showDatePicker(
      context: context,
      initialDate: currentDay.isBefore(today) ? today : currentDay,
      firstDate: today,
      lastDate: DateTime(2100, 12, 31),
      helpText: 'CHỌN NGÀY GIAO',
      cancelText: 'HỦY',
      confirmText: 'TIẾP THEO',
    );
    if (date == null || !mounted) {
      return;
    }
    setState(() {
      delivery = _deliveryOnDay(date, delivery);
      _deliveryWasValid = true;
    });
    _scheduleDraftSave();
    await pickDeliveryTime();
  }

  Future<void> pickDeliveryTime() async {
    final now = DateTime.now();
    if (DateUtils.dateOnly(delivery).isBefore(DateUtils.dateOnly(now))) {
      await pickDeliveryDate();
      return;
    }
    final minimum = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(const Duration(minutes: 1));
    var candidate = _deliveryOnDay(delivery, delivery);
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
                    Expanded(
                      child: Text(
                        'Chọn giờ · ${dayLabel(delivery)}',
                        style: const TextStyle(
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
                  minimumDate: DateUtils.isSameDay(delivery, now)
                      ? minimum
                      : null,
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
    final picked = DateTime(
      delivery.year,
      delivery.month,
      delivery.day,
      chosen.hour,
      chosen.minute,
    );
    final issue = deliveryTimeIssue(picked);
    if (issue != null) {
      AppToast.show(context, issue);
      return;
    }
    setState(() {
      delivery = picked;
      _deliveryWasValid = true;
    });
    _scheduleDraftSave();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Column(
        children: [
          Text(
            widget.initialOrder == null ? 'Tạo đơn hoa' : 'Sửa đơn hoa',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.palette.muted,
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              [
                'Khách hàng',
                'Sản phẩm',
                'Nhận hàng',
                'Thanh toán',
                'Xác nhận đơn',
              ][step],
              key: ValueKey(step),
            ),
          ),
        ],
      ),
      actions: [
        if (widget.initialOrder == null && _hasDraft)
          IconButton(
            tooltip: 'Xóa bản nháp',
            onPressed: _discardDraft,
            icon: const Icon(Icons.delete_outline),
          ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 8, 28, 10),
            child: StepProgressBar(
              current: step,
              allDone: reviewing,
              semanticsPrefix: reviewing ? 'Xem lại đơn' : 'Bước ${step + 1}/4',
              onStepTap: saving
                  ? null
                  : (index) {
                      setState(() => step = index);
                      _scheduleDraftSave();
                    },
              steps: const [
                StepItem(icon: Icons.person_rounded, label: 'Khách hàng'),
                StepItem(icon: Icons.local_florist_rounded, label: 'Sản phẩm'),
                StepItem(
                  icon: Icons.event_available_rounded,
                  label: 'Nhận hàng',
                ),
                StepItem(icon: Icons.payments_rounded, label: 'Thanh toán'),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      24,
                      24,
                      24,
                      24 + FloatingFormBar.reservedHeight,
                    ),
                    children: [
                      if (step == 0) ...[
                        OutlinedButton.icon(
                          onPressed: saving ? null : pickFromContacts,
                          icon: const Icon(Icons.contacts_rounded),
                          label: const Text('Chọn từ danh bạ'),
                        ),
                        const SizedBox(height: 14),
                        _field(
                          name,
                          'Tên khách hàng',
                          textInputAction: TextInputAction.next,
                        ),
                        _field(
                          phone,
                          'Số điện thoại (không bắt buộc)',
                          keyboard: TextInputType.phone,
                          required: false,
                        ),
                        TextButton.icon(
                          onPressed: () => setState(() {
                            name.text = 'Khách vãng lai';
                            phone.clear();
                            _scheduleDraftSave();
                          }),
                          icon: const Icon(Icons.person_outline),
                          label: const Text('Khách vãng lai'),
                        ),
                        if (name.text.trim().length >= 2 ||
                            phone.text.trim().length >= 2)
                          FutureBuilder<List<CustomerSummary>>(
                            future: widget.repository.customers(
                              query: phone.text.trim().length >= 2
                                  ? phone.text
                                  : name.text,
                            ),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Card(
                                child: Column(
                                  children: [
                                    const ListTile(
                                      title: Text('Khách đã mua'),
                                      dense: true,
                                    ),
                                    for (final customer in snapshot.data!.take(
                                      5,
                                    ))
                                      ListTile(
                                        title: Text(customer.name),
                                        subtitle: Text(
                                          customer.phone.isEmpty
                                              ? '${customer.orderCount} đơn'
                                              : '${customer.phone} · ${customer.orderCount} đơn',
                                        ),
                                        onTap: () => setState(() {
                                          name.text = customer.name;
                                          phone.text = customer.phone;
                                          _scheduleDraftSave();
                                        }),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                      if (step == 0 && _previousOrder != null)
                        _orderAgainCard(_previousOrder!),
                      if (step == 0) ..._giftFields(),
                      if (step == 1) ...[
                        OutlinedButton.icon(
                          onPressed: chooseProduct,
                          icon: const Icon(Icons.local_florist_outlined),
                          label: const Text('Thêm từ mẫu hoa'),
                        ),
                        const SizedBox(height: 12),
                        for (
                          var index = 0;
                          index < selectedItems.length;
                          index++
                        )
                          Card(
                            child: ListTile(
                              title: Text(selectedItems[index].name),
                              subtitle: Text(
                                '${money(selectedItems[index].unitPrice)} × ${selectedItems[index].quantity} = ${money(selectedItems[index].total)}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip:
                                        'Giảm số lượng ${selectedItems[index].name}',
                                    onPressed: () => changeItemQuantity(
                                      index,
                                      selectedItems[index].quantity - 1,
                                    ),
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                  ),
                                  Text('${selectedItems[index].quantity}'),
                                  IconButton(
                                    tooltip:
                                        'Tăng số lượng ${selectedItems[index].name}',
                                    onPressed: () => changeItemQuantity(
                                      index,
                                      selectedItems[index].quantity + 1,
                                    ),
                                    icon: const Icon(Icons.add_circle_outline),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (selectedItems.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              'Tiền sản phẩm: ${money(itemsPrice)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        _field(
                          product,
                          'Tên sản phẩm thêm thủ công',
                          onChanged: (_) => components = [],
                          required: selectedItems.isEmpty,
                          focusNode: productFocus,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => priceFocus.requestFocus(),
                          onTap: () {
                            // Coming from the numeric price field: reopen the
                            // keyboard so it switches back to letters.
                            if (!productFocus.hasFocus && priceFocus.hasFocus) {
                              _focusTextField(productFocus);
                            }
                          },
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _field(
                                price,
                                'Giá thủ công (đ)',
                                keyboard: TextInputType.number,
                                required: selectedItems.isEmpty,
                                focusNode: priceFocus,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) {
                                  if (product.text.trim().isNotEmpty) {
                                    addManualProduct(focusNext: true);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            _ManualQuantityStepper(
                              quantity: manualQuantity,
                              onChanged: changeManualQuantity,
                            ),
                          ],
                        ),
                        if (product.text.trim().isNotEmpty &&
                            (parseMoney(price.text) ?? 0) > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              'Thành tiền: $manualQuantity × ${money(parseMoney(price.text)!)} = ${money(manualQuantity * parseMoney(price.text)!)}',
                              style: TextStyle(color: context.palette.muted),
                            ),
                          ),
                        OutlinedButton.icon(
                          onPressed: () => addManualProduct(focusNext: true),
                          icon: const Icon(Icons.add),
                          label: const Text('Thêm sản phẩm'),
                        ),
                        Text(
                          orderItemsComponents(selectedItems).isEmpty
                              ? 'Chưa có định lượng hoa cho đơn này'
                              : '${orderItemsComponents(selectedItems).length} loại hoa đã được lưu vào đơn',
                        ),
                      ],
                      if (step == 2) ...[
                        if (fulfillment == FulfillmentType.counter)
                          const Card(
                            child: ListTile(
                              leading: Icon(Icons.storefront_outlined),
                              title: Text('Bán tại quầy'),
                              subtitle: Text('Khách đã nhận hoa tại tiệm'),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<FulfillmentType>(
                                showSelectedIcon: false,
                                segments: const [
                                  ButtonSegment(
                                    value: FulfillmentType.delivery,
                                    icon: Icon(Icons.local_shipping_outlined),
                                    label: Text('Giao tận nơi'),
                                  ),
                                  ButtonSegment(
                                    value: FulfillmentType.pickup,
                                    icon: Icon(Icons.storefront_outlined),
                                    label: Text('Khách tới lấy'),
                                  ),
                                ],
                                selected: {fulfillment},
                                onSelectionChanged: (value) {
                                  setState(() => fulfillment = value.single);
                                  _scheduleDraftSave();
                                },
                              ),
                            ),
                          ),
                        if (fulfillment != FulfillmentType.counter) ...[
                          Card(
                            child: ListTile(
                              leading: Icon(
                                Icons.calendar_month,
                                color: context.palette.primary,
                              ),
                              title: RequiredLabel(
                                delivers ? 'Ngày giao' : 'Ngày khách tới lấy',
                              ),
                              subtitle: Text(dayLabel(delivery)),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: pickDeliveryDate,
                            ),
                          ),
                          Card(
                            child: ListTile(
                              leading: Icon(
                                Icons.schedule,
                                color: context.palette.primary,
                              ),
                              title: RequiredLabel(
                                delivers ? 'Giờ giao' : 'Giờ khách tới lấy',
                              ),
                              subtitle: Text(
                                DateFormat('HH:mm', 'vi').format(delivery),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: pickDeliveryTime,
                            ),
                          ),
                          _deliverySlots(),
                        ],
                        const SizedBox(height: 14),
                        if (delivers)
                          AddressField(
                            controller: address,
                            suggester: _addressSuggester,
                            onChanged: () {
                              setState(() {});
                              _scheduleDraftSave();
                            },
                          ),
                        _field(
                          cardMessage,
                          'Lời thiệp / banner (không bắt buộc)',
                          maxLines: 3,
                          required: false,
                        ),
                        _field(
                          note,
                          'Ghi chú nội bộ (không bắt buộc)',
                          maxLines: 3,
                          required: false,
                        ),
                      ],
                      if (step == 3) ...[
                        if (deliveryIssue() != null)
                          TextButton.icon(
                            onPressed: () => setState(() => step = 2),
                            icon: const Icon(Icons.schedule),
                            label: const Text('Chọn lại giờ giao'),
                          ),
                        if (delivers)
                          _field(
                            shipping,
                            'Phí giao (đ)',
                            keyboard: TextInputType.number,
                          ),
                        ..._adjustmentFields(),
                        _field(
                          paid,
                          'Đã thu / tiền cọc (đ)',
                          keyboard: TextInputType.number,
                          enabled: widget.initialOrder == null,
                        ),
                        if (widget.initialOrder == null && orderTotal > 0)
                          _quickDeposit(),
                        if (widget.initialOrder == null &&
                            (parseMoney(paid.text) ?? 0) > 0)
                          PaymentMethodChips(
                            value: depositMethod,
                            onChanged: (method) {
                              setState(() => depositMethod = method);
                              _scheduleDraftSave();
                            },
                          ),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tổng: ${money(orderTotal)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Còn lại: ${money((orderTotal - (parseMoney(paid.text) ?? 0)).clamp(0, 999999999999))}',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (canReviewEarly)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: OutlinedButton.icon(
                            onPressed: saving ? null : reviewNow,
                            icon: const Icon(Icons.fact_check_outlined),
                            label: const Text('Đủ thông tin · Xem lại đơn'),
                          ),
                        ),
                      if (reviewing) ..._reviewContent(),
                    ],
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: FloatingFormBar(
                    showBack: step > 0,
                    onBack: saving
                        ? null
                        : () {
                            setState(() => step--);
                            _scheduleDraftSave();
                          },
                    onPrimary: saving || (step >= 3 && deliveryIssue() != null)
                        ? null
                        : next,
                    primaryLabel: saving
                        ? 'Đang lưu...'
                        : reviewing
                        ? widget.initialOrder == null
                              ? 'Xác nhận tạo đơn'
                              : 'Xác nhận cập nhật'
                        : 'Tiếp tục',
                    primaryIcon: saving
                        ? null
                        : reviewing
                        ? Icons.check_circle_rounded
                        : Icons.arrow_forward_rounded,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  List<Widget> _reviewContent() {
    final palette = context.palette;
    final shippingFee = shippingAmount;
    final paidAmount = widget.initialOrder?.paid ?? parseMoney(paid.text) ?? 0;
    final total = orderTotal;
    final remaining = (total - paidAmount).clamp(0, total);
    final when = DateFormat(
      "EEEE, dd/MM/yyyy 'lúc' HH:mm",
      'vi',
    ).format(delivery);
    TextStyle muted([double size = 13]) =>
        TextStyle(fontSize: size, color: palette.muted);
    return [
      Text(
        'Kiểm tra lại thông tin. Đơn chỉ được lưu khi bạn bấm xác nhận.',
        style: muted(),
      ),
      const SizedBox(height: 12),
      _reviewCard('KHÁCH HÀNG', 0, [
        Text(
          name.text.trim(),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: palette.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          phone.text.trim().isEmpty
              ? 'Chưa có số điện thoại'
              : phone.text.trim(),
          style: muted(14),
        ),
        if (isGift) ...[
          const SizedBox(height: 10),
          Text('Người nhận', style: muted(12)),
          Text(
            [
              recipientName.text.trim(),
              recipientPhone.text.trim(),
            ].where((part) => part.isNotEmpty).join(' · '),
            style: TextStyle(fontWeight: FontWeight.w600, color: palette.ink),
          ),
          if (anonymousSender) Text('Ẩn tên người tặng', style: muted(12)),
        ],
      ]),
      _reviewCard('SẢN PHẨM', 1, [
        for (final item in selectedItems)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${item.quantity} × ${item.name}',
                    style: TextStyle(color: palette.ink),
                  ),
                ),
                Text(
                  money(item.total),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: palette.ink,
                  ),
                ),
              ],
            ),
          ),
      ]),
      _reviewCard('NHẬN HÀNG', 2, [
        _reviewRow(
          delivers ? Icons.local_shipping_outlined : Icons.storefront_outlined,
          fulfillment.label,
        ),
        const SizedBox(height: 8),
        _reviewRow(Icons.schedule_rounded, when),
        if (delivers) ...[
          const SizedBox(height: 8),
          _reviewRow(Icons.place_outlined, address.text.trim()),
        ],
        if (cardMessage.text.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          _reviewRow(Icons.mail_outline, '“${cardMessage.text.trim()}”'),
        ],
        if (note.text.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          _reviewRow(Icons.sticky_note_2_outlined, note.text.trim()),
        ],
      ]),
      _reviewCard('THANH TOÁN', 3, [
        _reviewLine('Tiền hoa', money(itemsPrice)),
        if (delivers) _reviewLine('Phí giao', money(shippingFee)),
        if (surchargeAmount > 0) _reviewLine('Phụ thu', money(surchargeAmount)),
        if (discountAmount > 0)
          _reviewLine('Giảm giá', '-${money(discountAmount)}'),
        _reviewLine('Tổng', money(total)),
        _reviewLine(
          widget.initialOrder == null
              ? (paidAmount > 0
                    ? 'Tiền cọc · ${depositMethod.label}'
                    : 'Tiền cọc')
              : 'Đã thu',
          money(paidAmount),
        ),
        Divider(color: palette.line),
        Row(
          children: [
            Text(
              'CÒN LẠI',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: palette.ink,
              ),
            ),
            const Spacer(),
            Text(
              money(remaining),
              style: TextStyle(
                fontFamily: FlowerTemplateTheme.headingFont,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: palette.adapt(const Color(0xFFB8692F)),
              ),
            ),
          ],
        ),
      ]),
    ];
  }

  List<Widget> _giftFields() => [
    const SizedBox(height: 4),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: const Icon(Icons.card_giftcard_outlined),
      title: const Text('Đơn tặng người khác'),
      subtitle: const Text('Người nhận khác người đặt'),
      value: isGift,
      onChanged: (value) {
        setState(() => isGift = value);
        _scheduleDraftSave();
      },
    ),
    if (isGift) ...[
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: saving ? null : pickRecipientFromContacts,
          icon: const Icon(Icons.contacts_rounded),
          label: const Text('Chọn người nhận từ danh bạ'),
        ),
      ),
      _field(
        recipientName,
        'Tên người nhận',
        textInputAction: TextInputAction.next,
      ),
      _field(
        recipientPhone,
        'SĐT người nhận (để shipper gọi)',
        keyboard: TextInputType.phone,
        required: false,
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Ẩn tên người tặng'),
        subtitle: const Text(
          'Không ghi tên người đặt trên thiệp và phiếu giao',
        ),
        value: anonymousSender,
        onChanged: (value) {
          setState(() => anonymousSender = value);
          _scheduleDraftSave();
        },
      ),
    ],
  ];

  List<Widget> _adjustmentFields() => [
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: TextField(
              controller: discount,
              keyboardType: TextInputType.number,
              inputFormatters: [
                MoneyInputFormatter(Localizations.localeOf(context).toString()),
              ],
              onChanged: (_) {
                setState(() {});
                _scheduleDraftSave();
              },
              decoration: InputDecoration(
                labelText: discountPercent ? 'Giảm giá (%)' : 'Giảm giá (đ)',
                helperText: discountPercent && discountAmount > 0
                    ? '= ${money(discountAmount)}'
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: false, label: Text('đ')),
              ButtonSegment(value: true, label: Text('%')),
            ],
            selected: {discountPercent},
            onSelectionChanged: (value) {
              setState(() {
                discountPercent = value.single;
                discount.clear();
              });
              _scheduleDraftSave();
            },
          ),
        ),
      ],
    ),
    _field(
      surcharge,
      'Phụ thu, ví dụ ngày lễ (đ)',
      keyboard: TextInputType.number,
      required: false,
    ),
  ];

  Widget _reviewCard(String title, int editStep, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 8, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: context.palette.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: saving
                    ? null
                    : () {
                        setState(() => step = editStep);
                        _scheduleDraftSave();
                      },
                child: Text(
                  'Sửa',
                  semanticsLabel: 'Sửa ${title.toLowerCase()}',
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _reviewLine(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Text(label, style: TextStyle(color: context.palette.muted)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: context.palette.ink,
          ),
        ),
      ],
    ),
  );

  Widget _reviewRow(IconData icon, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: context.palette.primary),
      const SizedBox(width: 8),
      Expanded(
        child: Text(text, style: TextStyle(color: context.palette.ink)),
      ),
    ],
  );

  Widget _orderAgainCard(FlowerOrder previous) => Card(
    child: ListTile(
      leading: Icon(Icons.replay_rounded, color: context.palette.primary),
      title: Text(
        'Lần trước · ${DateFormat('dd/MM', 'vi').format(previous.deliveryAt)}',
      ),
      subtitle: Text(
        '${previous.productName} · ${money(previous.total)}'
        '${previous.isGift ? ' · tặng ${previous.recipientName}' : ''}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: TextButton(
        onPressed: () => _orderAgain(previous),
        child: const Text('Đặt lại'),
      ),
    ),
  );

  /// Morning / noon / afternoon / evening in one tap; slots already past
  /// on the chosen day are disabled.
  Widget _deliverySlots() {
    DateTime at(int hour) =>
        DateTime(delivery.year, delivery.month, delivery.day, hour);
    final chosen = deliverySlots
        .where((slot) => delivery == at(slot.hour))
        .map((slot) => slot.hour)
        .toSet();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<int>(
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            padding: WidgetStatePropertyAll(EdgeInsets.zero),
          ),
          segments: [
            for (final slot in deliverySlots)
              ButtonSegment(
                value: slot.hour,
                enabled: deliveryTimeIssue(at(slot.hour)) == null,
                tooltip: '${slot.label} ${slot.hour}:00',
                label: Text('${slot.label} ${slot.hour}h', maxLines: 1),
              ),
          ],
          selected: chosen,
          onSelectionChanged: (selection) {
            if (selection.isEmpty) {
              return;
            }
            setState(() => delivery = at(selection.single));
            _scheduleDraftSave();
          },
        ),
      ),
    );
  }

  /// One tap for the usual amounts: nothing yet, half, or everything.
  Widget _quickDeposit() {
    final current = parseMoney(paid.text) ?? 0;
    final half = depositHalf(orderTotal);
    Widget chip(String label, int amount) => ChoiceChip(
      label: Text(label),
      selected: current == amount,
      onSelected: (_) {
        setState(() {
          paid.text = formatCurrencyInput(amount, Intl.getCurrentLocale());
        });
        _scheduleDraftSave();
      },
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          chip('Chưa thu', 0),
          if (half > 0 && half < orderTotal) chip('Cọc 50%', half),
          chip('Thu đủ', orderTotal),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboard,
    TextInputAction? textInputAction,
    int maxLines = 1,
    bool enabled = true,
    bool required = true,
    void Function(String)? onChanged,
    FocusNode? focusNode,
    ValueChanged<String>? onSubmitted,
    GestureTapCallback? onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: controller,
      focusNode: focusNode,
      onSubmitted: onSubmitted,
      onTap: onTap,
      enabled: enabled,
      keyboardType: keyboard,
      inputFormatters: keyboard == TextInputType.number
          ? [MoneyInputFormatter(Localizations.localeOf(context).toString())]
          : null,
      textInputAction: textInputAction,
      maxLines: maxLines,
      onChanged: (value) {
        onChanged?.call(value);
        setState(() {});
        _scheduleDraftSave();
      },
      decoration: InputDecoration(
        label: required ? RequiredLabel(label) : Text(label),
      ),
    ),
  );
}

/// "− 2 +" control for the quantity of a product that is still being typed.
class _ManualQuantityStepper extends StatelessWidget {
  const _ManualQuantityStepper({
    required this.quantity,
    required this.onChanged,
  });

  final int quantity;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: palette.field,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Giảm số lượng thủ công',
            onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          Semantics(
            container: true,
            label: 'Số lượng $quantity',
            excludeSemantics: true,
            child: SizedBox(
              width: 28,
              child: Text(
                '$quantity',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: palette.ink,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Tăng số lượng thủ công',
            onPressed: quantity < 999 ? () => onChanged(quantity + 1) : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

/// Catalog picker with search and category filter; sold-out products are
/// already left out by the caller.
class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet({required this.products});

  final List<CatalogProduct> products;

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final search = TextEditingController();
  ProductCategory? category;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final used = ProductCategory.values
        .where((c) => widget.products.any((p) => p.category == c))
        .toList();
    final shown = widget.products
        .where(
          (p) =>
              (category == null || p.category == category) &&
              p.matches(search.text),
        )
        .toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: TemplateSectionHeading(
                eyebrow: 'BỘ SƯU TẬP',
                title: 'Chọn mẫu hoa',
              ),
            ),
            if (widget.products.length > 6)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Tìm tên mẫu, loại hoa',
                  ),
                ),
              ),
            if (used.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: CategoryFilter(
                  categories: used,
                  value: category,
                  onChanged: (value) => setState(() => category = value),
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  if (shown.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Không có mẫu phù hợp'),
                    ),
                  for (final item in shown)
                    Card(
                      child: ListTile(
                        leading: CatalogProductImage(
                          path: item.imagePath,
                          size: 64,
                        ),
                        title: Text(
                          item.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(money(item.price)),
                        trailing: Icon(
                          Icons.add_circle_outline,
                          color: context.palette.primary,
                        ),
                        onTap: () => Navigator.pop(context, item),
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
}
