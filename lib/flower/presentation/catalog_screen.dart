import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../data/catalog_image_store.dart';
import '../data/order_repository.dart';
import '../domain/catalog_product.dart';
import 'app_toast.dart';
import 'catalog_product_image.dart';
import 'flower_template_theme.dart';
import 'flower_template_widgets.dart';
import 'money_input_formatter.dart';

String _money(int value) =>
    '${NumberFormat.decimalPattern(Intl.getCurrentLocale()).format(value)} đ';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key, required this.repository});

  final OrderRepository repository;

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  late Future<List<CatalogProduct>> products = widget.repository.listProducts();
  final search = TextEditingController();
  ProductCategory? category;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> toggleSoldOut(CatalogProduct product) async {
    try {
      await widget.repository.setProductSoldOut(product.id!, !product.soldOut);
      if (mounted) {
        AppToast.show(
          context,
          product.soldOut
              ? '“${product.name}” bán lại được'
              : '“${product.name}” tạm hết, ẩn khi tạo đơn',
          isError: false,
        );
      }
      refresh();
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Không thể cập nhật mẫu hoa');
      }
    }
  }

  void refresh() => setState(() {
    products = widget.repository.listProducts();
  });

  Future<void> edit(CatalogProduct? product) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CatalogEditorScreen(
          repository: widget.repository,
          initial: product,
        ),
      ),
    );
    if (changed ?? false) {
      refresh();
    }
  }

  Future<void> archive(CatalogProduct product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ẩn mẫu hoa?'),
        content: Text(
          'Mẫu “${product.name}” sẽ biến mất khỏi catalog. Đơn cũ vẫn giữ thông tin đã lưu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ẩn mẫu'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await widget.repository.archiveProduct(product.id!);
    refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mẫu hoa')),
    body: FutureBuilder<List<CatalogProduct>>(
      future: products,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Không thể tải catalog'),
                TextButton(onPressed: refresh, child: const Text('Thử lại')),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.isEmpty) {
          return const Center(
            child: Text('Chưa có mẫu hoa. Thêm mẫu để tạo đơn nhanh hơn.'),
          );
        }
        final all = snapshot.data!;
        final shown = all
            .where(
              (p) =>
                  (category == null || p.category == category) &&
                  p.matches(search.text),
            )
            .toList();
        final used = ProductCategory.values
            .where((c) => all.any((p) => p.category == c))
            .toList();
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
          itemCount: shown.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TemplateSectionHeading(
                      eyebrow: 'BỘ SƯU TẬP',
                      title: 'Mẫu hoa',
                      trailing: Text(
                        '${all.length} mẫu',
                        style: TextStyle(color: context.palette.muted),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: search,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Tìm tên mẫu, loại hoa',
                      ),
                    ),
                    if (used.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      CategoryFilter(
                        categories: used,
                        value: category,
                        onChanged: (value) => setState(() => category = value),
                      ),
                    ],
                    if (shown.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Text('Không có mẫu phù hợp'),
                      ),
                  ],
                ),
              );
            }
            final product = shown[index - 1];
            return Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => edit(product),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Opacity(
                        opacity: product.soldOut ? 0.4 : 1,
                        child: CatalogProductImage(
                          path: product.imagePath,
                          size: 104,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.displayName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: FlowerTemplateTheme.headingFont,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              [
                                ?product.category?.label,
                                '${product.components.length} loại hoa',
                                if (product.soldOut) 'Tạm hết',
                              ].join(' · '),
                              style: TextStyle(
                                color: context.palette.muted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _money(product.price),
                              style: TextStyle(
                                color: context.palette.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Tùy chọn ${product.name}',
                        onSelected: (value) => value == 'sold_out'
                            ? toggleSoldOut(product)
                            : archive(product),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'sold_out',
                            child: ListTile(
                              leading: Icon(
                                product.soldOut
                                    ? Icons.shopping_cart_outlined
                                    : Icons.remove_shopping_cart_outlined,
                              ),
                              title: Text(
                                product.soldOut
                                    ? 'Có hoa lại, bán tiếp'
                                    : 'Tạm hết hoa',
                              ),
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'archive',
                            child: ListTile(
                              leading: Icon(Icons.archive_outlined),
                              title: Text('Ẩn mẫu khỏi catalog'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => edit(null),
      icon: const Icon(Icons.add),
      label: const Text('Thêm mẫu'),
    ),
  );
}

class CatalogEditorScreen extends StatefulWidget {
  const CatalogEditorScreen({
    super.key,
    required this.repository,
    this.initial,
  });

  final OrderRepository repository;
  final CatalogProduct? initial;

  @override
  State<CatalogEditorScreen> createState() => _CatalogEditorScreenState();
}

class _ComponentInput {
  _ComponentInput(FlowerComponent? initial)
    : name = TextEditingController(text: initial?.name ?? ''),
      quantity = TextEditingController(
        text: initial?.quantity.toString() ?? '1',
      ),
      unit = TextEditingController(text: initial?.unit ?? 'cành'),
      isMain = initial?.isMain ?? true;

  final TextEditingController name;
  final TextEditingController quantity;
  final TextEditingController unit;
  bool isMain;

  void dispose() {
    name.dispose();
    quantity.dispose();
    unit.dispose();
  }
}

class _CatalogEditorScreenState extends State<CatalogEditorScreen> {
  final name = TextEditingController();
  final price = TextEditingController();
  final inputs = <_ComponentInput>[];
  bool saving = false;
  late String imagePath = widget.initial?.imagePath ?? '';
  late ProductCategory? category = widget.initial?.category;
  late String size = widget.initial?.size ?? '';
  late bool soldOut = widget.initial?.soldOut ?? false;
  XFile? selectedImage;

  @override
  void initState() {
    super.initState();
    name.text = widget.initial?.name ?? '';
    price.text = widget.initial == null
        ? ''
        : formatCurrencyInput(widget.initial!.price, Intl.getCurrentLocale());
    inputs.addAll(widget.initial?.components.map(_ComponentInput.new) ?? []);
  }

  @override
  void dispose() {
    name.dispose();
    price.dispose();
    for (final input in inputs) {
      input.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (saving) {
      return;
    }
    final components = <FlowerComponent>[];
    for (final input in inputs) {
      components.add(
        FlowerComponent(
          name: input.name.text,
          quantity: int.tryParse(input.quantity.text) ?? 0,
          unit: input.unit.text,
          isMain: input.isMain,
        ),
      );
    }
    var item = CatalogProduct(
      id: widget.initial?.id,
      name: name.text,
      price: parseCurrencyInput(price.text) ?? 0,
      imagePath: imagePath,
      components: components,
      category: category,
      size: size,
      soldOut: soldOut,
    );
    final issue = item.validate();
    if (issue != null) {
      AppToast.show(context, issue);
      return;
    }
    setState(() => saving = true);
    try {
      if (selectedImage != null) {
        imagePath = await CatalogImageStore().save(selectedImage!);
        item = item.copyWith(imagePath: imagePath);
      }
      await widget.repository.saveProduct(item);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => saving = false);
        AppToast.show(context, 'Không thể lưu mẫu hoa');
      }
    }
  }

  Future<void> pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (picked != null && mounted) {
        setState(() => selectedImage = picked);
      }
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Không thể chọn ảnh');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.initial == null ? 'Thêm mẫu hoa' : 'Sửa mẫu hoa'),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 112),
      children: [
        TemplateSectionHeading(
          eyebrow: 'BỘ SƯU TẬP',
          title: widget.initial == null ? 'Thêm mẫu hoa' : 'Chỉnh sửa mẫu hoa',
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            if (selectedImage != null || imagePath.isNotEmpty)
              CatalogProductImage(
                path: selectedImage?.path ?? imagePath,
                size: 88,
              )
            else
              const SizedBox(
                width: 88,
                height: 88,
                child: Icon(Icons.local_florist_outlined),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: saving ? null : pickImage,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Chọn ảnh hoa'),
                  ),
                  if (selectedImage != null || imagePath.isNotEmpty)
                    TextButton(
                      onPressed: saving
                          ? null
                          : () => setState(() {
                              selectedImage = null;
                              imagePath = '';
                            }),
                      child: const Text('Dùng ảnh mặc định ngẫu nhiên'),
                    )
                  else
                    const Text('Để trống: app tự chọn ảnh hoa mặc định'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: name,
          decoration: const InputDecoration(
            label: RequiredLabel('Tên mẫu hoa'),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: price,
          keyboardType: TextInputType.number,
          inputFormatters: [
            MoneyInputFormatter(Localizations.localeOf(context).toString()),
          ],
          decoration: const InputDecoration(
            label: RequiredLabel('Giá bán (đ)'),
          ),
        ),
        const SizedBox(height: 16),
        Text('Loại', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final value in ProductCategory.values)
              ChoiceChip(
                label: Text(value.label),
                selected: category == value,
                onSelected: (selected) =>
                    setState(() => category = selected ? value : null),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Kích cỡ (không bắt buộc)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          segments: [
            for (final value in productSizes)
              ButtonSegment(value: value, label: Text('Cỡ $value')),
          ],
          selected: {if (size.isNotEmpty) size},
          onSelectionChanged: (selection) =>
              setState(() => size = selection.isEmpty ? '' : selection.single),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Tạm hết hoa'),
          subtitle: const Text(
            'Vẫn giữ trong catalog, ẩn khi tạo đơn và bán nhanh',
          ),
          value: soldOut,
          onChanged: (value) => setState(() => soldOut = value),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Thành phần hoa',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              onPressed: () =>
                  setState(() => inputs.add(_ComponentInput(null))),
              icon: const Icon(Icons.add),
              label: const Text('Thêm hoa'),
            ),
          ],
        ),
        if (inputs.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Chưa có định lượng. Danh sách mua hoa sẽ không tính mẫu này.',
            ),
          ),
        for (var i = 0; i < inputs.length; i++) _componentCard(i),
      ],
    ),
    floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    floatingActionButton: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: FloatingFormBar(
        onPrimary: saving ? null : save,
        primaryLabel: saving ? 'Đang lưu...' : 'Lưu mẫu',
        primaryIcon: saving ? null : Icons.check_circle_rounded,
      ),
    ),
  );

  Widget _componentCard(int index) {
    final input = inputs[index];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: input.name,
                    decoration: const InputDecoration(
                      label: RequiredLabel('Tên hoa'),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Xóa hoa',
                  onPressed: () => setState(() {
                    inputs.removeAt(index);
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => input.dispose(),
                    );
                  }),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: input.quantity,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      label: RequiredLabel('Số lượng'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: input.unit,
                    decoration: const InputDecoration(
                      label: RequiredLabel('Đơn vị'),
                    ),
                  ),
                ),
              ],
            ),
            DropdownButton<bool>(
              value: input.isMain,
              items: const [
                DropdownMenuItem(value: true, child: Text('Hoa chính')),
                DropdownMenuItem(value: false, child: Text('Hoa phụ')),
              ],
              onChanged: (value) =>
                  setState(() => input.isMain = value ?? true),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row of category chips; "Tất cả" clears the filter.
class CategoryFilter extends StatelessWidget {
  const CategoryFilter({
    super.key,
    required this.categories,
    required this.value,
    required this.onChanged,
  });

  final List<ProductCategory> categories;
  final ProductCategory? value;
  final ValueChanged<ProductCategory?> onChanged;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        ChoiceChip(
          label: const Text('Tất cả'),
          selected: value == null,
          onSelected: (_) => onChanged(null),
        ),
        for (final category in categories) ...[
          const SizedBox(width: 6),
          ChoiceChip(
            label: Text(category.short),
            selected: value == category,
            onSelected: (selected) => onChanged(selected ? category : null),
          ),
        ],
      ],
    ),
  );
}
