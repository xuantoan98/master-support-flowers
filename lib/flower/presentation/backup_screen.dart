part of 'flower_app.dart';

/// Manual backup to a file the shop keeps elsewhere (Drive, Zalo, a
/// computer) and restore from such a file on this or a new phone.
class BackupScreen extends StatefulWidget {
  const BackupScreen({
    super.key,
    required this.repository,
    required this.onRestored,
    this.pickBackupFile = _pickBackupFile,
  });

  final OrderRepository repository;
  final Future<void> Function() onRestored;

  /// Returns the chosen file, or null when the shop cancels.
  final Future<File?> Function() pickBackupFile;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

Future<File?> _pickBackupFile() async {
  final result = await FilePicker.platform.pickFiles();
  final path = result?.files.single.path;
  return path == null ? null : File(path);
}

class _BackupScreenState extends State<BackupScreen> {
  late final service = BackupService(widget.repository);
  DateTime? lastBackup;
  bool working = false;

  @override
  void initState() {
    super.initState();
    _loadLastBackup();
  }

  Future<void> _loadLastBackup() async {
    try {
      final value = await widget.repository.lastBackupAt();
      if (mounted) {
        setState(() => lastBackup = value);
      }
    } catch (_) {
      // The screen still works without the date.
    }
  }

  Future<void> backup(BuildContext buttonContext) async {
    setState(() => working = true);
    try {
      final box = buttonContext.findRenderObject() as RenderBox?;
      final origin = box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size;
      final file = await service.createBackup();
      if (!mounted) {
        return;
      }
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/zip')],
          subject: 'Sao lưu Sổ Hoa',
          text: 'Bản sao lưu dữ liệu Sổ Hoa. Giữ file này ở nơi an toàn.',
          sharePositionOrigin: origin,
        ),
      );
      if (result.status != ShareResultStatus.dismissed) {
        final now = DateTime.now();
        await widget.repository.setLastBackupAt(now);
        if (mounted) {
          setState(() => lastBackup = now);
          AppToast.show(context, 'Đã tạo bản sao lưu', isError: false);
        }
      }
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Không thể tạo bản sao lưu');
      }
    } finally {
      if (mounted) {
        setState(() => working = false);
      }
    }
  }

  Future<void> restore() async {
    final File? file;
    try {
      file = await widget.pickBackupFile();
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Không mở được trình chọn file');
      }
      return;
    }
    if (file == null || !mounted) {
      return;
    }
    setState(() => working = true);
    try {
      final info = await service.inspect(file);
      if (!mounted) {
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Khôi phục bản sao lưu?'),
          content: Text(
            'Bản sao lưu lúc ${DateFormat('HH:mm dd/MM/yyyy', 'vi').format(info.createdAt)} '
            'có ${info.orderCount} đơn và ${info.fileCount} ảnh.\n\n'
            'Toàn bộ dữ liệu hiện tại trên máy sẽ được thay bằng bản sao lưu này.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Thôi'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Khôi phục'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        return;
      }
      await service.restore(file);
      await widget.onRestored();
      if (mounted) {
        AppToast.show(context, 'Đã khôi phục dữ liệu', isError: false);
        await _loadLastBackup();
      }
    } on BackupException catch (error) {
      if (mounted) {
        AppToast.show(context, error.message);
      }
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Không thể khôi phục dữ liệu');
      }
    } finally {
      if (mounted) {
        setState(() => working = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final stale =
        lastBackup == null ||
        DateTime.now().difference(lastBackup!) > const Duration(days: 7);
    return Scaffold(
      appBar: AppBar(title: const Text('Sao lưu & khôi phục')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(
            child: ListTile(
              leading: Icon(
                stale ? Icons.warning_amber_rounded : Icons.verified_outlined,
                color: stale
                    ? palette.adapt(calendarOverdueColor)
                    : palette.accent,
              ),
              title: Text(
                lastBackup == null
                    ? 'Chưa sao lưu lần nào'
                    : 'Sao lưu gần nhất: ${DateFormat('HH:mm dd/MM/yyyy', 'vi').format(lastBackup!)}',
              ),
              subtitle: const Text(
                'Đơn, khách, mẫu hoa và ảnh chỉ nằm trên máy này. Hãy sao lưu ít nhất mỗi tuần.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (buttonContext) => FilledButton.icon(
              onPressed: working ? null : () => backup(buttonContext),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Tạo bản sao lưu'),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'App tạo một file .zip. Lưu file vào Google Drive, gửi qua Zalo cho chính bạn hoặc chép sang máy tính.',
            style: TextStyle(color: palette.muted),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: working ? null : restore,
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
            icon: const Icon(Icons.settings_backup_restore),
            label: const Text('Khôi phục từ file sao lưu'),
          ),
          const SizedBox(height: 8),
          Text(
            'Dùng khi đổi máy hoặc cài lại app. Dữ liệu hiện tại sẽ được thay bằng dữ liệu trong file.',
            style: TextStyle(color: palette.muted),
          ),
          if (working) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}
