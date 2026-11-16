import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'flower/data/order_repository.dart';
import 'flower/presentation/flower_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi');
  runApp(const FlowerBootstrap());
}

class FlowerBootstrap extends StatefulWidget {
  const FlowerBootstrap({super.key});

  @override
  State<FlowerBootstrap> createState() => _FlowerBootstrapState();
}

class _FlowerBootstrapState extends State<FlowerBootstrap> {
  late Future<OrderRepository> opening = _open();

  Future<OrderRepository> _open() async {
    final repository = OrderRepository();
    await repository.open();
    return repository;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<OrderRepository>(
    future: opening,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return FlowerApp(repository: snapshot.data!);
      }
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFFFF9F5),
          body: Center(
            child: snapshot.hasError
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 42),
                      const SizedBox(height: 12),
                      const Text('Không thể mở dữ liệu trên thiết bị'),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => setState(() => opening = _open()),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  )
                : const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_florist_outlined, size: 48),
                      SizedBox(height: 16),
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Đang mở dữ liệu...'),
                    ],
                  ),
          ),
        ),
      );
    },
  );
}
