import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/order_repository.dart';
import '../data/payment_qr_store.dart';
import '../domain/shop_profile.dart';
import '../domain/vn_banks.dart';
import 'app_toast.dart';

class ShopProfileScreen extends StatefulWidget {
  const ShopProfileScreen({super.key, required this.repository});

  final OrderRepository repository;

  @override
  State<ShopProfileScreen> createState() => _ShopProfileScreenState();
}

class _ShopProfileScreenState extends State<ShopProfileScreen> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final bankName = TextEditingController();
  final accountNumber = TextEditingController();
  final accountHolder = TextEditingController();
  ShopProfile? original;
  String bankBin = '';
  XFile? selectedQr;
  bool removeQr = false;
  bool loading = true;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final profile = await widget.repository.loadShopProfile();
      if (!mounted) {
        return;
      }
      original = profile;
      name.text = profile.name;
      phone.text = profile.phone;
      address.text = profile.address;
      bankName.text = profile.bankName;
      bankBin = profile.bankBin;
      accountNumber.text = profile.accountNumber;
      accountHolder.text = profile.accountHolder;
      if (mounted) {
        setState(() {
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

  @override
  void dispose() {
    for (final controller in [
      name,
      phone,
      address,
      bankName,
      accountNumber,
      accountHolder,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!formKey.currentState!.validate()) {
      return;
    }
    final draft = ShopProfile(
      name: name.text,
      phone: phone.text,
      address: address.text,
      bankBin: bankBin,
      bankName: bankName.text,
      accountNumber: accountNumber.text,
      accountHolder: accountHolder.text,
    );
    final issue = draft.validate();
    if (issue != null) {
      AppToast.show(context, issue);
      return;
    }
    setState(() => saving = true);
    final store = PaymentQrStore();
    String? newPath;
    try {
      if (selectedQr != null) {
        newPath = await store.save(selectedQr!);
      }
      final oldPath = original?.qrImagePath ?? '';
      final qrPath = removeQr ? '' : (newPath ?? oldPath);
      final profile = ShopProfile(
        name: draft.name,
        phone: draft.phone,
        address: draft.address,
        bankBin: draft.bankBin,
        bankName: draft.bankName,
        accountNumber: draft.accountNumber,
        accountHolder: draft.accountHolder,
        qrImagePath: qrPath,
      );
      await widget.repository.saveShopProfile(profile);
      if (oldPath != qrPath) {
        try {
          await store.delete(oldPath);
        } catch (_) {
          // The saved profile already points to the new image.
        }
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (newPath != null) {
        await store.delete(newPath);
      }
      if (mounted) {
        AppToast.show(
          context,
          error is ArgumentError
              ? '${error.message}'
              : 'Không thể lưu hồ sơ shop',
        );
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Future<void> pickBank() async {
    final chosen = await showModalBottomSheet<VnBank>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BankPickerSheet(selectedBin: bankBin),
    );
    if (chosen != null && mounted) {
      setState(() {
        bankBin = chosen.bin;
        bankName.text = chosen.shortName;
      });
    }
  }

  Future<void> pickQr() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked != null && mounted) {
        setState(() {
          selectedQr = picked;
          removeQr = false;
        });
      }
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Không thể chọn ảnh QR');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hồ sơ shop')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(
            child: TextButton(onPressed: load, child: Text('$error · Thử lại')),
          )
        : Form(
            key: formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Thông tin trên hóa đơn',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Tên shop *'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Vui lòng nhập tên shop'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Số điện thoại'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: address,
                  decoration: const InputDecoration(labelText: 'Địa chỉ shop'),
                  maxLines: 2,
                ),
                const SizedBox(height: 28),
                const Text(
                  'Tài khoản nhận tiền',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Khi có ngân hàng và số tài khoản, hóa đơn và nút "Mã QR" sẽ tạo mã VietQR có sẵn số tiền còn lại và mã đơn. Hãy quét thử bằng app ngân hàng một lần để kiểm tra.',
                ),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.account_balance_outlined),
                    title: Text(
                      bankByBin(bankBin)?.shortName ??
                          (bankName.text.isEmpty
                              ? 'Chọn ngân hàng'
                              : bankName.text),
                    ),
                    subtitle: Text(
                      bankByBin(bankBin)?.name ?? 'Cần chọn để tạo mã VietQR',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: saving ? null : pickBank,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: accountNumber,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Số tài khoản'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: accountHolder,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Tên chủ tài khoản',
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Ảnh QR ngân hàng (dự phòng)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Chỉ dùng khi chưa chọn ngân hàng: ảnh QR từ app ngân hàng sẽ in lên hóa đơn, khách tự nhập số tiền.',
                ),
                const SizedBox(height: 12),
                if (!removeQr &&
                    (selectedQr != null ||
                        (original?.qrImagePath.isNotEmpty ?? false))) ...[
                  Image.file(
                    File(selectedQr?.path ?? original!.qrImagePath),
                    height: 220,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const SizedBox(
                      height: 100,
                      child: Center(child: Text('Không đọc được ảnh QR')),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton.icon(
                  onPressed: saving ? null : pickQr,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(
                    selectedQr != null ||
                            (!removeQr &&
                                (original?.qrImagePath.isNotEmpty ?? false))
                        ? 'Thay ảnh QR'
                        : 'Chọn ảnh QR',
                  ),
                ),
                if (selectedQr != null ||
                    (!removeQr && (original?.qrImagePath.isNotEmpty ?? false)))
                  TextButton.icon(
                    onPressed: saving
                        ? null
                        : () => setState(() {
                            selectedQr = null;
                            removeQr = true;
                          }),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Xóa ảnh QR'),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: saving ? null : save,
                  child: Text(saving ? 'Đang lưu…' : 'Lưu hồ sơ'),
                ),
              ],
            ),
          ),
  );
}

/// Searchable bank list. Owns its search field so the field lives exactly as
/// long as the sheet, including its closing animation.
class _BankPickerSheet extends StatefulWidget {
  const _BankPickerSheet({required this.selectedBin});

  final String selectedBin;

  @override
  State<_BankPickerSheet> createState() => _BankPickerSheetState();
}

class _BankPickerSheetState extends State<_BankPickerSheet> {
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final term = search.text.trim().toLowerCase();
    final banks = vnBanks
        .where(
          (bank) => term.isEmpty || bank.label.toLowerCase().contains(term),
        )
        .toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: TextField(
                controller: search,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Tìm ngân hàng',
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final bank in banks)
                    ListTile(
                      title: Text(bank.shortName),
                      subtitle: Text(bank.name),
                      trailing: bank.bin == widget.selectedBin
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => Navigator.pop(context, bank),
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
