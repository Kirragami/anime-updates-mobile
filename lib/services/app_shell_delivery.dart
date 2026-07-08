import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Delivers foreground UI actions that require a [Navigator] context.
///
/// Actions stay queued until they report success or are cancelled. Retries are
/// coalesced to at most one flush per frame for performance.
class AppShellDeliveryCoordinator {
  AppShellDeliveryCoordinator({
    required this.navigatorKey,
    required this.isMounted,
    required this.lifecycleState,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final bool Function() isMounted;
  final AppLifecycleState Function() lifecycleState;

  final Map<String, _PendingDelivery> _pendingByKey = {};
  bool _flushScheduled = false;

  bool get isForegroundInteractive {
    final state = lifecycleState();
    return state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
  }

  void enqueue({
    required String key,
    required Future<bool> Function(BuildContext context) action,
  }) {
    _pendingByKey[key] = _PendingDelivery(action: action);
    scheduleFlush();
  }

  void cancel(String key) {
    _pendingByKey.remove(key);
  }

  void cancelWhere(bool Function(String key) predicate) {
    _pendingByKey.removeWhere((key, _) => predicate(key));
  }

  void cancelAll() {
    _pendingByKey.clear();
  }

  void scheduleFlush() {
    if (_flushScheduled || !isMounted() || _pendingByKey.isEmpty) {
      return;
    }

    _flushScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _flushScheduled = false;
      if (!isMounted()) return;
      unawaited(_flush());
    });
  }

  Future<void> _flush() async {
    if (!isMounted() || !isForegroundInteractive || _pendingByKey.isEmpty) {
      return;
    }

    final context = navigatorKey.currentContext;
    if (context == null) {
      scheduleFlush();
      return;
    }

    final batch = Map<String, _PendingDelivery>.from(_pendingByKey);
    for (final entry in batch.entries) {
      if (!isMounted() || !isForegroundInteractive) {
        scheduleFlush();
        return;
      }

      try {
        final completed = await entry.value.action(context);
        if (completed) {
          _pendingByKey.remove(entry.key);
        }
      } catch (_) {
        // Keep queued; a later flush will retry.
      }
    }

    if (_pendingByKey.isNotEmpty) {
      scheduleFlush();
    }
  }
}

class _PendingDelivery {
  const _PendingDelivery({required this.action});

  final Future<bool> Function(BuildContext context) action;
}
