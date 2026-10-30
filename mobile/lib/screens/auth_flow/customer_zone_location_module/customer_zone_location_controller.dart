import '../../../constants/app.export.dart';

/// "Select your area" — the customer location picker when the admin has
/// switched the map off (Settings → "Map location in customer app";
/// [Injector.mapLocationEnabled]).
///
/// Pick a main zone; when it has sub-zones, pick one of those too. Only a
/// zone a customer can be in — a sub-zone, or a main zone with none — can
/// be confirmed, the same rule the server matches vendors by (leaf zones
/// only), so a confirmed pick always finds the vendors subscribed to it.
///
/// Returns a [PickedZone] through `Get.back(result:)`; the caller saves it
/// and reports it to the server, as with the map picker's answer.
class CustomerZoneLocationController extends GetxController {
  /// Active main zones, each with its active sub-zones (`GET zones`).
  List<ZoneModel> zones = [];
  bool isLoading = false;
  bool hasError = false;

  ZoneModel? mainZone;
  ZoneModel? subZone;

  /// A main zone with sub-zones needs one of them picked.
  bool get needsSubZone => mainZone != null && mainZone!.children.isNotEmpty;

  /// The zone that would be saved, or null while the pick is incomplete.
  ZoneModel? get pickedZone => needsSubZone ? subZone : mainZone;

  @override
  void onInit() {
    super.onInit();
    fetchZonesAPI();
  }

  Future<void> fetchZonesAPI() async {
    isLoading = true;
    hasError = false;
    update();

    try {
      final response = await DataSource.instance.zonesAPI();

      if (response != null && response.isSuccess && response.data is List) {
        zones = (response.data as List)
            .map((e) => ZoneModel.fromJson(e as Map<String, dynamic>))
            .toList();
        _preselectCurrent();
      } else {
        hasError = true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Fetch zones error $e');
      }
      hasError = true;
    } finally {
      isLoading = false;
      update();
    }
  }

  /// Opens on the customer's current pick, so changing only the sub-zone
  /// is one tap. A zone that has since been switched off is simply absent.
  void _preselectCurrent() {
    final currentId = Injector.customerZoneId;

    if (currentId == null) {
      return;
    }

    for (final zone in zones) {
      if (zone.id == currentId && zone.children.isEmpty) {
        mainZone = zone;
        return;
      }

      for (final child in zone.children) {
        if (child.id == currentId) {
          mainZone = zone;
          subZone = child;
          return;
        }
      }
    }
  }

  void selectMainZone(ZoneModel zone) {
    if (zone.id != mainZone?.id) {
      mainZone = zone;
      // A sub-zone belongs to one main zone only.
      subZone = null;
    }
    update();
  }

  void selectSubZone(ZoneModel zone) {
    subZone = zone;
    update();
  }

  void confirm() {
    final zone = pickedZone;

    if (zone?.id == null) {
      return;
    }

    Get.back(
      result: PickedZone(zone: zone!, parent: needsSubZone ? mainZone : null),
    );
  }
}
