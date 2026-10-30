import 'package:flutter_test/flutter_test.dart';
import 'package:service_marketplace/common_model/common_response.dart';
import 'package:service_marketplace/network/data_source.dart';
import 'package:service_marketplace/screens/auth_flow/customer_zone_location_module/customer_zone_location_controller.dart';
import 'package:service_marketplace/utils/injector.dart';

/// GET /api/zones as the server sends it: Ahmedabad with two sub-zones,
/// and Gandhinagar with none (a main zone that is itself a leaf).
class _ZonesDataSource extends DataSource {
  bool fails = false;

  @override
  Future<CommonResponse?> zonesAPI() async {
    if (fails) {
      return null;
    }

    return CommonResponse.fromJson({
      'success': true,
      'data': [
        {
          'id': 1,
          'name': 'Ahmedabad',
          'is_leaf': false,
          'children': [
            {'id': 11, 'name': 'Satellite', 'is_leaf': true, 'children': []},
            {'id': 12, 'name': 'Gota', 'is_leaf': true, 'children': []},
          ],
        },
        {'id': 2, 'name': 'Gandhinagar', 'is_leaf': true, 'children': []},
      ],
      'error': null,
    });
  }
}

void main() {
  setUp(() {
    Injector.customerZoneId = null;
  });

  test('a main zone with sub-zones needs one picked before it can be confirmed', () async {
    DataSource.instance = _ZonesDataSource();
    final controller = CustomerZoneLocationController();
    await controller.fetchZonesAPI();

    controller.selectMainZone(controller.zones.first);

    expect(controller.needsSubZone, isTrue);
    expect(controller.pickedZone, isNull);

    controller.selectSubZone(controller.zones.first.children.last);

    expect(controller.pickedZone?.id, 12);
  });

  test('a main zone without sub-zones is itself the pick', () async {
    DataSource.instance = _ZonesDataSource();
    final controller = CustomerZoneLocationController();
    await controller.fetchZonesAPI();

    controller.selectMainZone(controller.zones.last);

    expect(controller.needsSubZone, isFalse);
    expect(controller.pickedZone?.id, 2);
  });

  test('changing the main zone clears the sub-zone', () async {
    DataSource.instance = _ZonesDataSource();
    final controller = CustomerZoneLocationController();
    await controller.fetchZonesAPI();

    controller.selectMainZone(controller.zones.first);
    controller.selectSubZone(controller.zones.first.children.first);
    controller.selectMainZone(controller.zones.last);

    expect(controller.subZone, isNull);
  });

  test('opens on the current pick', () async {
    DataSource.instance = _ZonesDataSource();
    Injector.customerZoneId = 11;
    final controller = CustomerZoneLocationController();
    await controller.fetchZonesAPI();

    expect(controller.mainZone?.id, 1);
    expect(controller.subZone?.id, 11);
  });

  test('a failed load shows the error state', () async {
    DataSource.instance = _ZonesDataSource()..fails = true;
    final controller = CustomerZoneLocationController();
    await controller.fetchZonesAPI();

    expect(controller.hasError, isTrue);
    expect(controller.zones, isEmpty);
  });
}
