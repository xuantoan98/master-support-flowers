import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/address_suggester.dart';
import 'app_toast.dart';
import 'flower_template_theme.dart';

/// Delivery address input with map suggestions. Picking a suggestion fills
/// the field with the map service's own address name. Without a suggester
/// (no API key) or offline, it behaves as a plain text field.
class AddressField extends StatefulWidget {
  const AddressField({
    super.key,
    required this.controller,
    required this.suggester,
    required this.onChanged,
    this.debounce = const Duration(milliseconds: 350),
  });

  final TextEditingController controller;
  final AddressSuggester? suggester;
  final VoidCallback onChanged;
  final Duration debounce;

  @override
  State<AddressField> createState() => _AddressFieldState();
}

class _AddressFieldState extends State<AddressField> {
  Timer? _debounce;
  int _requestId = 0;
  List<AddressSuggestion> suggestions = const [];
  bool loading = false;
  bool failed = false;

  /// The current text came from a map suggestion and was not edited since.
  bool picked = false;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onTyped(String value) {
    widget.onChanged();
    _debounce?.cancel();
    final suggester = widget.suggester;
    setState(() {
      picked = false;
      failed = false;
      if (value.trim().length < 3) {
        suggestions = const [];
        loading = false;
      }
    });
    if (suggester == null || value.trim().length < 3) {
      _requestId++;
      return;
    }
    _debounce = Timer(widget.debounce, () => _search(suggester, value));
  }

  Future<void> _search(AddressSuggester suggester, String query) async {
    final id = ++_requestId;
    setState(() => loading = true);
    try {
      final result = await suggester.suggest(query);
      if (!mounted || id != _requestId) {
        return;
      }
      setState(() {
        suggestions = result.take(5).toList();
        loading = false;
      });
    } catch (_) {
      if (!mounted || id != _requestId) {
        return;
      }
      setState(() {
        suggestions = const [];
        loading = false;
        failed = true;
      });
    }
  }

  void _pick(AddressSuggestion suggestion) {
    _debounce?.cancel();
    _requestId++;
    widget.controller.value = TextEditingValue(
      text: suggestion.description,
      selection: TextSelection.collapsed(offset: suggestion.description.length),
    );
    setState(() {
      suggestions = const [];
      loading = false;
      picked = true;
    });
    widget.onChanged();
    FocusScope.of(context).unfocus();
  }

  Future<void> _openMap() async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': widget.controller.text.trim(),
    });
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      AppToast.show(context, 'Không mở được bản đồ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: widget.controller,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.done,
            onChanged: _onTyped,
            decoration: InputDecoration(
              label: const RequiredLabel('Địa chỉ giao'),
              prefixIcon: Icon(Icons.place_outlined, color: palette.primary),
              suffixIcon: loading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              helperText: widget.suggester == null
                  ? null
                  : 'Gõ địa chỉ để xem gợi ý từ bản đồ',
            ),
          ),
          if (suggestions.isNotEmpty)
            Card(
              margin: const EdgeInsets.only(top: 6),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final suggestion in suggestions)
                    InkWell(
                      onTap: () => _pick(suggestion),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.location_on_rounded,
                                size: 20,
                                color: palette.accent,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    suggestion.mainText,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: palette.ink,
                                    ),
                                  ),
                                  if (suggestion.secondaryText.isNotEmpty)
                                    Text(
                                      suggestion.secondaryText,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: palette.muted,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
                    child: Text(
                      'Gợi ý bởi Goong',
                      textAlign: TextAlign.end,
                      style: TextStyle(fontSize: 10, color: palette.muted),
                    ),
                  ),
                ],
              ),
            ),
          if (failed)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                'Không tải được gợi ý. Bạn vẫn có thể nhập tay.',
                style: TextStyle(fontSize: 12, color: palette.muted),
              ),
            ),
          if (picked)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: palette.accent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Địa chỉ theo bản đồ',
                      style: TextStyle(fontSize: 12, color: palette.accent),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _openMap,
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Mở bản đồ'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
