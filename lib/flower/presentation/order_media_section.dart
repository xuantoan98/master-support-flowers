import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/order_media_store.dart';
import '../data/order_repository.dart';
import '../domain/order_media.dart';
import 'app_toast.dart';

class OrderMediaSection extends StatefulWidget {
  const OrderMediaSection({
    super.key,
    required this.orderId,
    required this.repository,
  });

  final int orderId;
  final OrderRepository repository;

  @override
  State<OrderMediaSection> createState() => _OrderMediaSectionState();
}

class _OrderMediaSectionState extends State<OrderMediaSection> {
  late final store = OrderMediaStore(widget.repository);
  late Future<List<OrderMedia>> media = widget.repository.mediaForOrder(
    widget.orderId,
  );
  bool saving = false;

  void refresh() => setState(() {
    media = widget.repository.mediaForOrder(widget.orderId);
  });

  Future<void> add() async {
    final type = await showModalBottomSheet<OrderMediaType>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Loại ảnh')),
            for (final type in OrderMediaType.values)
              ListTile(
                title: Text(type.label),
                onTap: () => Navigator.pop(sheetContext, type),
              ),
          ],
        ),
      ),
    );
    if (type == null || !mounted) {
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) {
      return;
    }
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2000,
      );
      if (picked == null || !mounted) {
        return;
      }
      setState(() => saving = true);
      await store.save(widget.orderId, type, picked);
      if (mounted) {
        refresh();
      }
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Không thể thêm ảnh. Vui lòng thử lại');
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Future<void> remove(OrderMedia item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa ảnh?'),
        content: Text('${item.type.label} sẽ bị xóa khỏi đơn.'),
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
    try {
      await store.delete(item);
      if (mounted) {
        refresh();
      }
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Không thể xóa ảnh');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Ảnh của đơn',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
              TextButton.icon(
                onPressed: saving ? null : add,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Thêm ảnh'),
              ),
            ],
          ),
          FutureBuilder<List<OrderMedia>>(
            future: media,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return TextButton(
                  onPressed: refresh,
                  child: const Text('Không thể tải ảnh · Thử lại'),
                );
              }
              if (!snapshot.hasData) {
                return const LinearProgressIndicator();
              }
              if (snapshot.data!.isEmpty) {
                return const Text('Chưa có ảnh cho đơn này');
              }
              return SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: snapshot.data!.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final item = snapshot.data![index];
                    return FutureBuilder<File>(
                      future: store.fileFor(item),
                      builder: (context, fileSnapshot) => SizedBox(
                        width: 120,
                        child: Column(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: fileSnapshot.hasData
                                    ? Image.file(
                                        fileSnapshot.data!,
                                        width: 120,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => const Center(
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                          ),
                                        ),
                                      )
                                    : const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.type.label,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Xóa ảnh',
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => remove(item),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}
