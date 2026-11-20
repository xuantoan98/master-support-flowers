import 'package:flutter/material.dart';

import '../domain/flower_order.dart';

/// Tiền mặt / Chuyển khoản / COD choice for a payment.
class PaymentMethodChips extends StatelessWidget {
  const PaymentMethodChips({
    super.key,
    required this.value,
    required this.onChanged,
    this.methods = PaymentMethod.values,
  });

  final PaymentMethod value;
  final ValueChanged<PaymentMethod> onChanged;
  final List<PaymentMethod> methods;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final method in methods)
          ChoiceChip(
            avatar: Icon(switch (method) {
              PaymentMethod.cash => Icons.payments_outlined,
              PaymentMethod.transfer => Icons.qr_code_2,
              PaymentMethod.cod => Icons.delivery_dining_outlined,
            }, size: 18),
            label: Text(method.label),
            selected: method == value,
            onSelected: (_) => onChanged(method),
          ),
      ],
    ),
  );
}
