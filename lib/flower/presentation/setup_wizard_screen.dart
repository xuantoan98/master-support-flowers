import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/order_repository.dart';
import '../domain/catalog_product.dart';
import '../domain/shop_profile.dart';
import 'app_toast.dart';
import 'catalog_product_image.dart';
import 'flower_template_theme.dart';
import 'flower_template_widgets.dart';
import 'shop_profile_screen.dart';

/// First run: shop name, bank account for VietQR, and which suggested
/// flower designs to keep. Every step after the name can be skipped.
class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({
    super.key,
    required this.repository,
    required this.onDone,
  });

  final OrderRepository repository;
  final VoidCallback onDone;

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  int step = 0;
  bool saving = false;
  final name = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final accountNumber = TextEditingController();
  final accountHolder = TextEditingController();
  String bankBin = '';
  String bankName = '';
  List<CatalogProduct>? products;
  final kept = <int>{};

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final list = await widget.repository.listProducts();
      if (mounted) {
        setState(() {
          products = list;
          kept.addAll(list.map((p) => p.id).whereType<int>());
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => products = const []);
      }
    }
  }

  @override
  void dispose() {
    for (final c in [name, phone, address, accountNumber, accountHolder]) {
      c.dispose();
    }
    super.dispose();
  }

  ShopProfile get profile => ShopProfile(
    name: name.text.trim(),
    phone: phone.text.trim(),
    address: address.text.trim(),
    bankBin: bankBin,
    bankName: bankName,
    accountNumber: accountNumber.text.replaceAll(RegExp(r'\s'), ''),
    accountHolder: accountHolder.text.trim().toUpperCase(),
  );

  void next() {
    if (step == 0 && name.text.trim().isEmpty) {
      AppToast.show(context, 'Vui lòng nhập tên tiệm');
      return;
    }
    if (step == 1) {
      final issue = profile.validate();
      if (issue != null) {
        AppToast.show(context, issue);
        return;
      }
      if (accountNumber.text.trim().isNotEmpty && bankBin.isEmpty) {
        AppToast.show(context, 'Hãy chọn ngân hàng của tài khoản');
        return;
      }
    }
    if (step < 2) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => step++);
      return;
    }
    finish();
  }

  Future<void> finish() async {
    setState(() => saving = true);
    try {
      await widget.repository.saveShopProfile(profile);
      for (final product in products ?? const <CatalogProduct>[]) {
        if (product.id != null && !kept.contains(product.id)) {
          await widget.repository.archiveProduct(product.id!);
        }
      }
      await widget.repository.setSetupDone();
      widget.onDone();
    } catch (_) {
      if (mounted) {
        setState(() => saving = false);
        AppToast.show(context, 'Không thể lưu thiết lập');
      }
    }
  }

  Future<void> skipAll() async {
    try {
      await widget.repository.setSetupDone();
    } catch (_) {}
    widget.onDone();
  }

  Future<void> pickBank() async {
    final chosen = await showBankPicker(context, selectedBin: bankBin);
    if (chosen != null && mounted) {
      setState(() {
        bankBin = chosen.bin;
        bankName = chosen.shortName;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('Thiết lập tiệm · ${step + 1}/3'),
        actions: [
          if (step == 0)
            TextButton(onPressed: skipAll, child: const Text('Để sau')),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                24,
                12,
                24,
                24 + FloatingFormBar.reservedHeight,
              ),
              children: [
                LinearProgressIndicator(
                  value: (step + 1) / 3,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 20),
                ...switch (step) {
                  0 => _shopStep(),
                  1 => _bankStep(),
                  _ => _productsStep(palette),
                },
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: FloatingFormBar(
                showBack: step > 0,
                onBack: saving ? null : () => setState(() => step--),
                onPrimary: saving ? null : next,
                primaryLabel: saving
                    ? 'Đang lưu...'
                    : step == 2
                    ? 'Bắt đầu bán'
                    : step == 1 && accountNumber.text.trim().isEmpty
                    ? 'Bỏ qua'
                    : 'Tiếp tục',
                primaryIcon: step == 2
                    ? Icons.check_circle_rounded
                    : Icons.arrow_forward_rounded,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _shopStep() => [
    const TemplateSectionHeading(
      eyebrow: 'CHÀO MỪNG',
      title: 'Tiệm của bạn tên gì?',
    ),
    const SizedBox(height: 8),
    const Text('Tên, số điện thoại và địa chỉ in trên hóa đơn gửi khách.'),
    const SizedBox(height: 12),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline, size: 18, color: context.palette.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Dữ liệu chỉ lưu trên máy này, không cần tài khoản '
            'và không gửi lên máy chủ nào.',
            style: TextStyle(fontSize: 13, color: context.palette.muted),
          ),
        ),
      ],
    ),
    const SizedBox(height: 18),
    TextField(
      controller: name,
      autofocus: true,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        label: RequiredLabel('Tên tiệm'),
        hintText: 'Ví dụ: Tiệm Hoa Lan',
      ),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: phone,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: 'Số điện thoại (không bắt buộc)',
      ),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: address,
      decoration: const InputDecoration(
        labelText: 'Địa chỉ tiệm (không bắt buộc)',
      ),
    ),
  ];

  List<Widget> _bankStep() => [
    const TemplateSectionHeading(
      eyebrow: 'NHẬN CHUYỂN KHOẢN',
      title: 'Tài khoản ngân hàng',
    ),
    const SizedBox(height: 8),
    const Text(
      'App tạo mã VietQR có sẵn số tiền và mã đơn, khách quét là chuyển '
      'đúng. Có thể bỏ qua và thêm sau trong Cửa hàng › Hồ sơ shop.',
    ),
    const SizedBox(height: 18),
    Card(
      child: ListTile(
        leading: const Icon(Icons.account_balance_outlined),
        title: Text(bankName.isEmpty ? 'Chọn ngân hàng' : bankName),
        trailing: const Icon(Icons.chevron_right),
        onTap: pickBank,
      ),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: accountNumber,
      keyboardType: TextInputType.number,
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(labelText: 'Số tài khoản'),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: accountHolder,
      textCapitalization: TextCapitalization.characters,
      decoration: const InputDecoration(
        labelText: 'Tên chủ tài khoản',
        hintText: 'NGUYEN VAN A',
      ),
    ),
  ];

  List<Widget> _productsStep(FlowerPalette palette) {
    final list = products;
    return [
      const TemplateSectionHeading(eyebrow: 'MẪU HOA', title: 'Mẫu gợi ý'),
      const SizedBox(height: 8),
      const Text(
        'Giữ những mẫu tiệm hay bán để tạo đơn nhanh. Giá và ảnh sửa được '
        'sau trong Mẫu hoa.',
      ),
      const SizedBox(height: 12),
      if (list == null)
        const Center(child: CircularProgressIndicator())
      else if (list.isEmpty)
        const Text('Chưa có mẫu gợi ý. Bạn có thể thêm mẫu sau.')
      else ...[
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => setState(() {
              if (kept.length == list.length) {
                kept.clear();
              } else {
                kept.addAll(list.map((p) => p.id).whereType<int>());
              }
            }),
            child: Text(
              kept.length == list.length ? 'Bỏ chọn tất cả' : 'Chọn tất cả',
            ),
          ),
        ),
        for (final product in list)
          Card(
            child: CheckboxListTile(
              value: kept.contains(product.id),
              onChanged: (value) => setState(() {
                if (value ?? false) {
                  kept.add(product.id!);
                } else {
                  kept.remove(product.id);
                }
              }),
              secondary: CatalogProductImage(path: product.imagePath, size: 52),
              title: Text(product.displayName),
              subtitle: Text(
                '${NumberFormat.decimalPattern('vi').format(product.price)} đ',
                style: TextStyle(color: palette.muted),
              ),
            ),
          ),
      ],
    ];
  }
}
