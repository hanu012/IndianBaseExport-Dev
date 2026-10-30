import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:service_marketplace/utils/location_capture.dart';

/// Same fake-platform pattern add_vendor_controller_test.dart already
/// established — geolocator's static methods delegate to whatever is set
/// as [GeolocatorPlatform.instance], so no device/platform channel is
/// needed to control the outcome.
class _FakeGeolocator extends GeolocatorPlatform {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.always;
  LocationPermission requestResult = LocationPermission.always;
  bool throwsOnPosition = false;
  bool timesOutOnPosition = false;
  Position? lastKnown;
  int currentPositionCalls = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) async => lastKnown;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => requestResult;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    currentPositionCalls++;

    if (throwsOnPosition) {
      throw Exception('gps hardware error');
    }

    if (timesOutOnPosition) {
      throw TimeoutException('no fix');
    }

    return _position(23.03, 72.55, DateTime(2026, 1, 1), 5);
  }
}

Position _position(double lat, double lng, DateTime at, double accuracy) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: at,
      accuracy: accuracy,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  testWidgets('returns a position when the service is enabled and permission is granted', (
    tester,
  ) async {
    GeolocatorPlatform.instance = _FakeGeolocator();

    final position = await LocationCapture.detect();

    expect(position?.latitude, 23.03);
    expect(position?.longitude, 72.55);
  });

  testWidgets('returns null when the location service is disabled', (tester) async {
    GeolocatorPlatform.instance = _FakeGeolocator()..serviceEnabled = false;

    expect(await LocationCapture.detect(), isNull);
  });

  testWidgets('requests permission when initially denied, then proceeds if granted', (
    tester,
  ) async {
    GeolocatorPlatform.instance = _FakeGeolocator()
      ..permission = LocationPermission.denied
      ..requestResult = LocationPermission.whileInUse;

    final position = await LocationCapture.detect();

    expect(position, isNotNull);
  });

  testWidgets('returns null when permission is denied even after requesting', (tester) async {
    GeolocatorPlatform.instance = _FakeGeolocator()
      ..permission = LocationPermission.denied
      ..requestResult = LocationPermission.denied;

    expect(await LocationCapture.detect(), isNull);
  });

  testWidgets('returns null when permission is permanently denied', (tester) async {
    GeolocatorPlatform.instance = _FakeGeolocator()..permission = LocationPermission.deniedForever;

    expect(await LocationCapture.detect(), isNull);
  });

  testWidgets('returns null and does not crash when getCurrentPosition throws', (tester) async {
    GeolocatorPlatform.instance = _FakeGeolocator()..throwsOnPosition = true;

    expect(await LocationCapture.detect(), isNull);
  });

  testWidgets('reuses a recent, accurate cached fix without waiting for GPS', (tester) async {
    final fake = _FakeGeolocator()
      ..lastKnown = _position(22.99, 72.60, DateTime.now().subtract(const Duration(seconds: 30)), 20);
    GeolocatorPlatform.instance = fake;

    final position = await LocationCapture.detect();

    expect(position?.latitude, 22.99);
    expect(fake.currentPositionCalls, 0);
  });

  testWidgets('waits for a fresh fix when the cached one is stale', (tester) async {
    final fake = _FakeGeolocator()
      ..lastKnown = _position(22.99, 72.60, DateTime.now().subtract(const Duration(minutes: 10)), 20);
    GeolocatorPlatform.instance = fake;

    expect((await LocationCapture.detect())?.latitude, 23.03);
    expect(fake.currentPositionCalls, 1);
  });

  testWidgets('maxAge zero always takes a fresh fix (salesman pinning a shop)', (tester) async {
    final fake = _FakeGeolocator()..lastKnown = _position(22.99, 72.60, DateTime.now(), 5);
    GeolocatorPlatform.instance = fake;

    expect((await LocationCapture.detect(maxAge: Duration.zero))?.latitude, 23.03);
    expect(fake.currentPositionCalls, 1);
  });

  testWidgets('falls back to the cached fix when a fresh one times out', (tester) async {
    GeolocatorPlatform.instance = _FakeGeolocator()
      ..timesOutOnPosition = true
      ..lastKnown = _position(22.99, 72.60, DateTime.now().subtract(const Duration(hours: 1)), 500);

    expect((await LocationCapture.detect())?.latitude, 22.99);
  });

  testWidgets('returns null when a fresh fix times out and nothing is cached', (tester) async {
    GeolocatorPlatform.instance = _FakeGeolocator()..timesOutOnPosition = true;

    expect(await LocationCapture.detect(), isNull);
  });
}
