import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../data/address_suggester.dart';
import '../data/backup_service.dart';
import '../data/contact_picker.dart';
import '../data/live_activity_service.dart';
import '../data/order_media_store.dart';
import '../data/order_reminder_service.dart';
import '../data/order_repository.dart';
import '../domain/business_stats.dart';
import '../domain/calendar_overview.dart';
import '../domain/catalog_product.dart';
import '../domain/flower_order.dart';
import '../domain/order_defaults.dart';
import '../domain/order_item.dart';
import '../domain/order_media.dart';
import '../domain/order_status_flow.dart';
import '../domain/order_summary.dart';
import '../domain/shopping_list.dart';
import 'address_field.dart';
import 'app_toast.dart';
import 'calendar_widgets.dart';
import 'catalog_product_image.dart';
import 'catalog_screen.dart';
import 'contact_actions.dart';
import 'flower_dock.dart';
import 'flower_template_theme.dart';
import 'flower_template_widgets.dart';
import 'invoice_screen.dart';
import 'money_input_formatter.dart';
import 'order_media_section.dart';
import 'order_success.dart';
import 'payment_method_chips.dart';
import 'payment_qr.dart';
import 'setup_wizard_screen.dart';
import 'shop_profile_screen.dart';
import 'shopping_list_screen.dart';
import 'step_progress.dart';

part 'home_screen.dart';
part 'customer_screens.dart';
part 'order_detail_screen.dart';
part 'create_order_screen.dart';
part 'quick_sale_screen.dart';
part 'backup_screen.dart';

String money(int value) =>
    '${NumberFormat.decimalPattern(Intl.getCurrentLocale()).format(value)} đ';
String dayLabel(DateTime value) => DateFormat('dd/MM/yyyy', 'vi').format(value);

Color _statusColor(OrderStatus status) => switch (status) {
  OrderStatus.newOrder => FlowerTemplateTheme.navy,
  OrderStatus.making => const Color(0xFFC0765B),
  OrderStatus.awaitingApproval => const Color(0xFF6975A2),
  OrderStatus.delivering => const Color(0xFF3E6C98),
  OrderStatus.delivered => FlowerTemplateTheme.deepSage,
  OrderStatus.cancelled => FlowerTemplateTheme.muted,
};

IconData _statusIcon(OrderStatus status) => switch (status) {
  OrderStatus.newOrder => Icons.auto_awesome_rounded,
  OrderStatus.making => Icons.content_cut_rounded,
  OrderStatus.awaitingApproval => Icons.thumb_up_alt_rounded,
  OrderStatus.delivering => Icons.pedal_bike_rounded,
  OrderStatus.delivered => Icons.verified_rounded,
  OrderStatus.cancelled => Icons.cancel_rounded,
};

Color _statusColorOf(BuildContext context, OrderStatus status) =>
    context.palette.adapt(_statusColor(status));

/// The one way an order status is shown: a tinted pill in the status colour.
class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({super.key, required this.order});

  final FlowerOrder order;

  @override
  Widget build(BuildContext context) {
    final color = _statusColorOf(context, order.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        order.statusLabel,
        style: TextStyle(
          color: color,
          fontSize: 12,
          height: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

ThemeMode _themeModeFrom(String value) => switch (value) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

class FlowerApp extends StatefulWidget {
  const FlowerApp({
    super.key,
    required this.repository,
    this.locale = const Locale('vi'),
  });
  final OrderRepository repository;
  final Locale locale;

  @override
  State<FlowerApp> createState() => _FlowerAppState();
}

class _FlowerAppState extends State<FlowerApp> {
  final themeMode = ValueNotifier(ThemeMode.system);

  /// Null while checking; true shows the first-run setup.
  bool? needsSetup;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _checkSetup();
  }

  Future<void> _checkSetup() async {
    var value = false;
    try {
      value = await widget.repository.needsSetup();
    } catch (_) {
      // Without settings (or in tests) go straight to the app.
    }
    if (mounted) {
      setState(() => needsSetup = value);
    }
  }

  Future<void> _loadTheme() async {
    try {
      final value = await widget.repository.themePreference();
      themeMode.value = _themeModeFrom(value);
    } catch (_) {
      // Keep following the system setting when preferences cannot be read.
    }
  }

  @override
  void dispose() {
    themeMode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    Intl.defaultLocale = locale.languageCode;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'Sổ Hoa',
        debugShowCheckedModeBanner: false,
        locale: locale,
        supportedLocales: const [Locale('vi'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: FlowerTemplateTheme.light(),
        darkTheme: FlowerTemplateTheme.dark(),
        themeMode: mode,
        home: switch (needsSetup) {
          null => const Scaffold(),
          true => SetupWizardScreen(
            repository: widget.repository,
            onDone: () => setState(() => needsSetup = false),
          ),
          false => FlowerHome(
            repository: widget.repository,
            themeMode: themeMode,
          ),
        },
      ),
    );
  }
}
