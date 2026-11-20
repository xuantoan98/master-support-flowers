import 'package:flutter/cupertino.dart';
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

/// Google Maps search for a delivery address; opens the Maps app when it is
/// installed, otherwise the browser.
Uri mapUri(String address) => Uri.https('www.google.com', '/maps/search/', {
  'api': '1',
  'query': address.trim(),
});

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

/// Compact call and Zalo icons for one person, shown at the end of the row
/// with their name. Tooltips keep the full action for long-press and
/// screen readers.
class ContactButtons extends StatelessWidget {
  const ContactButtons({super.key, required this.name, required this.phone});

  final String name;
  final String phone;

  @override
  Widget build(BuildContext context) {
    if (dialablePhone(phone).length < 8) {
      return const SizedBox.shrink();
    }
    final color = Theme.of(context).colorScheme.primary;
    // Each platform's own icon set: SF-style on iPhone, Material on Android.
    final platform = Theme.of(context).platform;
    final apple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    // Thin round outline so the icons read as buttons, not decoration.
    final style = IconButton.styleFrom(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: const CircleBorder(),
      side: BorderSide(color: color.withValues(alpha: 0.6)),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Gọi $name',
          iconSize: 16,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          color: color,
          onPressed: () =>
              _open(context, callUri(phone), 'Không mở được ứng dụng gọi điện'),
          style: style,
          icon: Icon(apple ? CupertinoIcons.phone : Icons.call_outlined),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Nhắn Zalo cho $name',
          iconSize: 16,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          color: color,
          onPressed: () => _open(context, zaloUri(phone), 'Không mở được Zalo'),
          style: style,
          icon: Icon(
            apple ? CupertinoIcons.chat_bubble : Icons.chat_bubble_outline,
          ),
        ),
      ],
    );
  }
}

/// Round map button for a delivery address, matching [ContactButtons].
class MapButton extends StatelessWidget {
  const MapButton({super.key, required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    if (address.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final color = Theme.of(context).colorScheme.primary;
    final platform = Theme.of(context).platform;
    final apple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    return IconButton(
      tooltip: 'Mở bản đồ',
      iconSize: 16,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      color: color,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const CircleBorder(),
        side: BorderSide(color: color.withValues(alpha: 0.6)),
      ),
      onPressed: () => _open(context, mapUri(address), 'Không mở được bản đồ'),
      icon: Icon(apple ? CupertinoIcons.map : Icons.map_outlined),
    );
  }
}
