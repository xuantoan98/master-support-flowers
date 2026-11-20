import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_toast.dart';

/// Digits only, as dialers and zalo.me links expect.
String dialablePhone(String phone) => phone.replaceAll(RegExp(r'[^0-9+]'), '');

Uri callUri(String phone) => Uri(scheme: 'tel', path: dialablePhone(phone));

/// Opens a chat in the Zalo app (or zalo.me in the browser). Vietnamese
/// numbers are accepted with a leading 0 or +84.
Uri zaloUri(String phone) {
  var digits = dialablePhone(phone).replaceAll('+', '');
  if (digits.startsWith('84') && digits.length > 10) {
    digits = '0${digits.substring(2)}';
  }
  return Uri.https('zalo.me', '/$digits');
}

Future<void> _open(BuildContext context, Uri uri, String failure) async {
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    AppToast.show(context, failure);
  }
}

/// "Gọi" and "Zalo" buttons for one person on an order.
class ContactButtons extends StatelessWidget {
  const ContactButtons({super.key, required this.name, required this.phone});

  final String name;
  final String phone;

  @override
  Widget build(BuildContext context) {
    if (dialablePhone(phone).length < 8) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () =>
              _open(context, callUri(phone), 'Không mở được ứng dụng gọi điện'),
          icon: const Icon(Icons.call_outlined, size: 18),
          label: Text('Gọi', semanticsLabel: 'Gọi $name'),
        ),
        OutlinedButton.icon(
          onPressed: () => _open(context, zaloUri(phone), 'Không mở được Zalo'),
          icon: const Icon(Icons.chat_bubble_outline, size: 18),
          label: Text('Zalo', semanticsLabel: 'Nhắn Zalo cho $name'),
        ),
      ],
    );
  }
}
