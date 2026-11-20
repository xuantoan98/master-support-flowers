part of 'flower_app.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key, required this.repository});

  final OrderRepository repository;

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Khách hàng')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 14),
          child: Column(
            children: [
              const TemplateSectionHeading(
                eyebrow: 'DANH BẠ',
                title: 'Khách hàng',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Tìm tên hoặc số điện thoại',
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<CustomerSummary>>(
            future: widget.repository.customers(query: search.text),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Không thể tải khách hàng'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.isEmpty) {
                return const Center(child: Text('Chưa có khách hàng phù hợp'));
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final customer = snapshot.data![index];
                  return Card(
                    child: ListTile(
                      leading: const TemplateIconBadge(
                        icon: Icons.person_outline,
                      ),
                      title: Text(customer.name),
                      subtitle: Text(
                        customer.phone.isEmpty
                            ? '${customer.orderCount} đơn'
                            : '${customer.phone} · ${customer.orderCount} đơn',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => CustomerDetailScreen(
                            repository: widget.repository,
                            customer: customer,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}

class CustomerDetailScreen extends StatelessWidget {
  const CustomerDetailScreen({
    super.key,
    required this.repository,
    required this.customer,
  });

  final OrderRepository repository;
  final CustomerSummary customer;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(customer.name)),
    body: FutureBuilder<List<FlowerOrder>>(
      future: repository.all(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Không thể tải đơn hàng'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final matching = snapshot.data!
            .where(
              (order) =>
                  order.customerName == customer.name &&
                  order.phone == customer.phone,
            )
            .toList();
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const TemplateSectionHeading(
              eyebrow: 'THÔNG TIN',
              title: 'Khách hàng',
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const TemplateIconBadge(icon: Icons.person_outline),
                title: Text(customer.name),
                subtitle: Text(
                  customer.phone.isEmpty
                      ? 'Chưa có số điện thoại'
                      : customer.phone,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${matching.length} đơn đã đặt',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (matching.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Chưa có đơn hàng'),
              ),
            for (final order in matching)
              Card(
                child: ListTile(
                  title: Text(order.productName),
                  subtitle: Text(
                    '${dayLabel(order.deliveryAt)} · ${order.statusLabel}',
                  ),
                  trailing: Text(money(order.total)),
                ),
              ),
          ],
        );
      },
    ),
  );
}
