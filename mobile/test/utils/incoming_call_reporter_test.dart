import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:service_marketplace/common_model/common_response.dart';
import 'package:service_marketplace/network/data_source.dart';
import 'package:service_marketplace/utils/incoming_call_reporter.dart';
import 'package:service_marketplace/utils/injector.dart';
import 'package:service_marketplace/utils/utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The vendor app's half of MainActivity's call_tracker channel, faked as
/// IncomingCallStore would answer.
class _FakeNative {
  List<Map<String, Object?>> queued = [];
  int? ackedUpTo;

  Future<Object?> handle(MethodCall call) async {
    switch (call.method) {
      case 'incomingCalls':
        return queued;
      case 'ackIncomingCalls':
        ackedUpTo = ((call.arguments as Map)['upTo'] as num).toInt();
        queued = queued.where((c) => (c['rang_at'] as int) > ackedUpTo!).toList();
        return null;
      case 'status':
        return {'phone': true, 'overlay': false};
      default:
        return null;
    }
  }
}

class _FakeDataSource extends DataSource {
  bool answers = true;
  List<Map<String, dynamic>>? sent;

  @override
  Future<CommonResponse?> reportIncomingCallsAPI({
    required String deviceTime,
    required List<Map<String, dynamic>> calls,
  }) async {
    sent = calls;
    return answers
        ? CommonResponse.fromJson({'success': true, 'data': {'matched': 1, 'enabled': true}, 'error': null})
        : null;
  }
}

const _channel = MethodChannel('service_marketplace/call_tracker');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeNative native;
  late _FakeDataSource api;

  setUp(() async {
    native = _FakeNative();
    api = _FakeDataSource();
    DataSource.instance = api;
    IncomingCallReporter.isSupported = () => true;
    Injector.callAnswerDetectionEnabled = true;
    Injector.accessToken = 'token';
    SharedPreferences.setMockInitialValues({});
    Injector.prefs = await SharedPreferences.getInstance();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, native.handle);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
    IncomingCallReporter.isSupported = () => false;
    Injector.accessToken = '';
  });

  group('IncomingCallReporter.flush', () {
    test('sends the queued calls and clears them once the server has them', () async {
      native.queued = [
        {'rang_at': 1000, 'answered': true, 'talk_seconds': 95},
        {'rang_at': 2000, 'answered': false, 'talk_seconds': null},
      ];

      await IncomingCallReporter.flush();

      expect(api.sent, hasLength(2));
      expect(api.sent!.first['answered'], isTrue);
      expect(api.sent!.first['talk_seconds'], 95);
      expect(api.sent!.first['rang_at'], DateTime.fromMillisecondsSinceEpoch(1000).toUtc().toIso8601String());
      expect(native.ackedUpTo, 2000);
      expect(native.queued, isEmpty);
    });

    test('keeps the calls on the phone when sending fails', () async {
      native.queued = [
        {'rang_at': 1000, 'answered': true, 'talk_seconds': 95},
      ];
      api.answers = false;

      await IncomingCallReporter.flush();

      expect(native.ackedUpTo, isNull);
      expect(native.queued, hasLength(1));
    });

    test('sends nothing while the admin switch is off', () async {
      Injector.callAnswerDetectionEnabled = false;
      native.queued = [
        {'rang_at': 1000, 'answered': true, 'talk_seconds': 95},
      ];

      await IncomingCallReporter.flush();

      expect(api.sent, isNull);
    });
  });

  group('Utils.callLabel', () {
    test('a confirmed answer shows the real talk time', () {
      expect(Utils.callLabel(outcome: 'answered', talkSeconds: 185, approxSeconds: 240), 'callAnswered · 3 minutesShort');
    });

    test('a confirmed miss says so, whatever the approximate length', () {
      expect(Utils.callLabel(outcome: 'not_answered', approxSeconds: 40), 'callNotAnswered');
    });

    test('unconfirmed falls back to the approximate length', () {
      expect(Utils.callLabel(approxSeconds: 240), '~4 minutesShort');
    });
  });
}
