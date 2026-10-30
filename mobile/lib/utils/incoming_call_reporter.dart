import 'dart:async';
import 'dart:io' show Platform;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../constants/flavor_config.dart';
import '../constants/pref_keys.dart';
import '../constants/string_res.dart';
import '../network/data_source.dart';
import '../widgets/base_services.dart';
import '../widgets/base_text.dart';
import 'injector.dart';

/// The vendor app's half of "was the customer's call answered?" (Android).
///
/// IncomingCallReceiver (vendor flavour only) notes when each incoming call
/// rang, whether it was answered and how long the talk lasted — times only,
/// never a number — even while the app is closed. This sends them to
/// `POST vendors/me/calls` at launch and on every return to the app, where
/// CallOutcomeMatcher pairs each with the customer's call lead and drops the
/// rest. A call stays on the phone until the server has it.
///
/// Admin switch: Settings → App → "Confirm answered calls (vendor app)"
/// ([Injector.callAnswerDetectionEnabled]).
class IncomingCallReporter {
  IncomingCallReporter._();

  static const MethodChannel _channel = MethodChannel('service_marketplace/call_tracker');

  /// Swappable seam for tests — there is no Android host under flutter test.
  @visibleForTesting
  static bool Function() isSupported =
      () => !kIsWeb && Platform.isAndroid && FlavorConfig.current.isVendor;

  static AppLifecycleListener? _lifecycle;
  static bool _flushing = false;

  static bool get _active => isSupported() && Injector.callAnswerDetectionEnabled;

  /// Once at startup in the vendor app.
  static void init() {
    if (!isSupported()) {
      return;
    }

    _lifecycle ??= AppLifecycleListener(onResume: () => unawaited(flush()));
    unawaited(flush());
  }

  /// Sends what the phone has seen. Quiet on any failure: the calls stay
  /// queued on the phone and go next time.
  static Future<void> flush() async {
    if (_flushing || !_active || !Injector.isLoggedIn) {
      return;
    }

    _flushing = true;

    try {
      final raw = await _channel.invokeListMethod<Map<dynamic, dynamic>>('incomingCalls') ?? const [];

      if (raw.isEmpty) {
        return;
      }

      final calls = [
        for (final call in raw)
          {
            'rang_at': DateTime.fromMillisecondsSinceEpoch((call['rang_at'] as num).toInt())
                .toUtc()
                .toIso8601String(),
            'answered': call['answered'] == true,
            'talk_seconds': (call['talk_seconds'] as num?)?.toInt(),
          },
      ];

      final response = await DataSource.instance.reportIncomingCallsAPI(
        deviceTime: DateTime.now().toUtc().toIso8601String(),
        calls: calls,
      );

      if (response?.isSuccess ?? false) {
        final newest = raw
            .map((call) => (call['rang_at'] as num).toInt())
            .reduce((a, b) => a > b ? a : b);
        await _channel.invokeMethod<void>('ackIncomingCalls', {'upTo': newest});
      }
    } catch (e) {
      if (kDebugMode) {
        print('Incoming calls report error $e');
      }
    } finally {
      _flushing = false;
    }
  }

  /// Once, from the vendor home: explains why, then asks Android for the
  /// phone permission. "Not now" is remembered — calls then just show their
  /// approximate length, as before.
  static Future<void> askOnce() async {
    if (!_active || (Injector.prefs?.getBool(PrefKeys.callConfirmAsked) ?? false)) {
      return;
    }

    try {
      final status = await _channel.invokeMapMethod<String, dynamic>('status') ?? const {};

      if (status['phone'] == true) {
        return;
      }

      await Injector.prefs?.setBool(PrefKeys.callConfirmAsked, true);

      if (await _explain()) {
        await _channel.invokeMethod<bool>('requestPhonePermission');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Phone permission error $e');
      }
    }
  }

  static Future<bool> _explain() async {
    final allow = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: ServiceTokens.card,
        title: BaseTextDMSans(
          text: StringRes.callConfirmTitle,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: ServiceTokens.text,
          textAlign: TextAlign.start,
        ).tr(),
        content: BaseTextDMSans(
          text: StringRes.callConfirmDesc,
          fontSize: 12,
          color: ServiceTokens.muted,
          textAlign: TextAlign.start,
          maxLines: 8,
        ).tr(),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: BaseTextDMSans(
              text: StringRes.callBubbleNotNow,
              fontSize: 12,
              color: ServiceTokens.muted,
            ).tr(),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: BaseTextDMSans(
              text: StringRes.callBubbleEnable,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ServiceTokens.accent,
            ).tr(),
          ),
        ],
      ),
    );

    return allow ?? false;
  }
}
