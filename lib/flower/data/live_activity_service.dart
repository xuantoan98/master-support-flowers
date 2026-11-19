import 'dart:io';

import 'package:flutter/services.dart';

import '../domain/flower_order.dart';
import '../domain/live_delivery.dart';

class LiveActivityService {
  LiveActivityService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('flower_orders/live_activity');

  final MethodChannel _channel;
  Future<void> _lastSync = Future<void>.value();

  Future<bool> isAvailable() async {
    if (!Platform.isIOS) {
      return false;
    }
    return await _channel.invokeMethod<bool>('isAvailable') ?? false;
  }

  Future<void> sync(Iterable<FlowerOrder> orders, {required bool enabled}) {
    if (!Platform.isIOS) {
      return Future<void>.value();
    }
    final deliveries = enabled ? planLiveDeliveries(orders) : <LiveDelivery>[];
    final next = _lastSync.catchError((Object _) {}).then((_) async {
      await _channel.invokeMethod<void>('sync', {
        'deliveries': deliveries.map((item) => item.toChannelMap()).toList(),
      });
    });
    _lastSync = next;
    return next;
  }
}
