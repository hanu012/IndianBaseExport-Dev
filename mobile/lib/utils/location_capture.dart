import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../constants/string_res.dart';
import 'utils.dart';

/// Shared GPS capture flow (SPEC section 2.2, task 3.2) — service check,
/// permission check/request, then a high-accuracy fix.
///
/// Extracted from `add_vendor_controller.dart`'s original inline
/// `captureLocation()` (task 3.2, salesman's Add Vendor GPS capture) so
/// the customer home screen (task 4.6) reuses the exact same flow instead
/// of a second copy — both call sites now call [detect] and branch on
/// whether it returns a position.
class LocationCapture {
  /// A fix the phone already holds is reused when it is at most this old and
  /// this accurate. Waiting for a fresh high-accuracy fix took 5–30s indoors
  /// with nothing on screen, so "Use current location" looked dead; every
  /// customer flow lands on a draggable map pin anyway.
  static const Duration _recentFixAge = Duration(minutes: 2);
  static const double _recentFixAccuracyMeters = 100;

  /// How long to wait for a fresh fix before settling for the last known one.
  static const Duration _freshFixTimeout = Duration(seconds: 15);

  /// [maxAge] — pass [Duration.zero] where only a fresh fix will do (the
  /// salesman pinning a shop). [showProgress] — false where the screen
  /// already shows its own spinner for the capture.
  static Future<Position?> detect({
    Duration maxAge = _recentFixAge,
    bool showProgress = true,
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        Utils.showToast(tr(StringRes.locationServiceDisabled), isError: true);
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        Utils.showToast(tr(StringRes.locationPermissionDenied), isError: true);
        return null;
      }

      final lastKnown = await _lastKnown();

      if (lastKnown != null && maxAge > Duration.zero && _isRecent(lastKnown, maxAge)) {
        return lastKnown;
      }

      // After the permission prompt, so the spinner never sits over it. Only
      // with a navigator mounted — the dialog needs one to open on.
      final progress = showProgress && Utils.key.currentState != null;

      if (progress) Utils.showCircularProgressLottie(true);

      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: _freshFixTimeout,
          ),
        );
      } on TimeoutException {
        // No fresh fix in time — an older one beats an error, and the
        // caller's map pin can still be moved. Nothing at all is a failure.
        if (lastKnown != null) {
          return lastKnown;
        }

        rethrow;
      } finally {
        if (progress) Utils.showCircularProgressLottie(false);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Location capture error $e');
      }
      Utils.showToast(tr(StringRes.locationCaptureFailed), isError: true);
      return null;
    }
  }

  /// The phone's cached fix, or null. Never fatal: some devices have none or
  /// refuse the call, and a fresh fix is still worth waiting for then.
  static Future<Position?> _lastKnown() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  static bool _isRecent(Position position, Duration maxAge) {
    return DateTime.now().difference(position.timestamp) <= maxAge &&
        position.accuracy <= _recentFixAccuracyMeters;
  }
}
