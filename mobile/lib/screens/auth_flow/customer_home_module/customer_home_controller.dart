import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart' show Constants;
import '../../../utils/location_capture.dart';
import '../../../utils/place_service.dart';
import '../customer_favorites_module/customer_favorites_controller.dart';
import '../customer_feed_module/customer_feed_controller.dart';
import '../customer_select_location_module/customer_select_location_view.dart';
import '../customer_set_location_module/customer_set_location_view.dart';
import '../customer_zone_location_module/customer_zone_location_view.dart';

/// Customer home (SPEC sections 4.2 and 4.3-4.4) — the location header,
/// the category grid, a rail of popular services, and the vendors
/// nearest the chosen location.
///
/// Location is resolved once here and threaded down into subcategory
/// browse and vendor search, which take it as explicit parameters
/// rather than re-deriving it server-side from the stored customer
/// record.
class CustomerHomeController extends GetxController {
  /// Which bottom-bar destination is showing. The three are kept in an
  /// IndexedStack by the view, so switching tabs does not rebuild or
  /// refetch the one being left.
  int tabIndex = 0;

  bool isDetecting = false;
  ResolvedZoneModel? zone;

  /// The point behind [zone]. Threaded into vendor search and vendor
  /// detail, both of which re-resolve the authoritative zone from it.
  double? latitude;
  double? longitude;
  String? pincode;

  /// What the header shows. Null until GPS or a chosen place resolves.
  String? locationLabel;

  /// SPEC section 4.2's fallback: entered when GPS is refused, or when
  /// the point matched no defined zone. The entry field now lives on
  /// the Select location screen rather than inline on home, but the
  /// resolution path is unchanged.
  final TextEditingController pincodeController = TextEditingController();

  /// True once GPS has failed or produced an unmatched point — the two
  /// triggers SPEC section 4.2 names.
  bool showPincodeFallback = false;

  List<CategoryModel> categories = [];
  bool isLoadingCategories = false;

  /// "Vendors near you" — the nearest handful for the first subcategory
  /// the customer's area actually offers.
  List<VendorSearchModel> nearbyVendors = [];
  bool isLoadingVendors = false;

  /// Up to six subcategories drawn from across the category tree, for
  /// the horizontal rail. Flattened here rather than in the view so the
  /// view stays a pure render of controller state.
  ///
  /// Subcategories the admin flagged "Popular" come first — the panel
  /// promises they surface first — then the rest in catalogue order.
  List<PopularService> get popularServices {
    final all = <PopularService>[
      for (final category in categories)
        for (final subcategory in category.subcategories)
          PopularService(subcategory, category),
    ];

    return [
      ...all.where((service) => service.subcategory.isPopular),
      ...all.where((service) => !service.subcategory.isPopular),
    ].take(6).toList();
  }

  @override
  void onInit() {
    super.onInit();

    // Independent of each other, so neither waits on the other.
    fetchCategoriesAPI();
    restoreOrDetectLocation();
  }

  /// Indexes of the destinations in the view's IndexedStack:
  /// Home 0, Feed 1, Favourites 2, Profile 3.
  static const int feedTab = 1;
  static const int favoritesTab = 2;

  void changeTab(int index) {
    tabIndex = index;
    update();

    // The IndexedStack keeps Favourites alive, so its onInit fetch ran
    // once at launch — a vendor favourited since (from search or a
    // vendor's page) would never appear. Reload on every visit.
    if (index == favoritesTab && Get.isRegistered<CustomerFavoritesController>()) {
      Get.find<CustomerFavoritesController>().fetchAPI();
    }

    // The Feed's first load can run before Home has resolved the area;
    // an empty Feed tries again when opened.
    if (index == feedTab && Get.isRegistered<CustomerFeedController>()) {
      final feed = Get.find<CustomerFeedController>();

      if (feed.items.isEmpty) {
        feed.fetchAPI();
      }
    }
  }

  /// Uses the location the customer last chose, if there is one.
  ///
  /// A stored choice wins over a fresh GPS fix on purpose: someone who
  /// deliberately set their location to where the work is happening
  /// should not be silently dragged back to where they are standing
  /// every time they open the app.
  Future<void> restoreOrDetectLocation() async {
    if (!Injector.mapLocationEnabled) {
      await restoreZone();
      return;
    }

    if (Injector.hasCustomerLocation) {
      latitude = Injector.customerLatitude;
      longitude = Injector.customerLongitude;
      locationLabel = _headerText(Injector.customerLocationLabel, Injector.customerLocationAddress);
      update();

      await _reportLocation(latitude: latitude, longitude: longitude);
      return;
    }

    await detectLocation();
  }

  /// A fresh GPS fix, named through the platform geocoder.
  ///
  /// Silent on refusal: the header falls back to a "Set your location"
  /// prompt, which is a better answer than an error the customer cannot
  /// act on from here.
  Future<void> detectLocation() async {
    isDetecting = true;
    update();

    final position = await LocationCapture.detect();

    if (position == null) {
      // GPS refused or unavailable — SPEC section 4.2's first fallback
      // trigger.
      isDetecting = false;
      showPincodeFallback = true;
      update();
      return;
    }

    final place = await PlaceService.instance.addressAt(
      position.latitude,
      position.longitude,
    );

    latitude = position.latitude;
    longitude = position.longitude;
    locationLabel = _headerText(place?.title, place?.fullAddress);

    if (place != null) {
      await Injector.setCustomerLocation(
        label: place.title,
        address: place.fullAddress,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    }

    await _reportLocation(latitude: latitude, longitude: longitude);
  }

  /// Zone mode (admin has the map location off): the zone the customer
  /// picked last, or — with none yet — the picker, since without a zone
  /// there are no vendors to show. No GPS in this mode.
  Future<void> restoreZone() async {
    final zoneId = Injector.customerZoneId;

    if (zoneId == null) {
      // After the first frame: a route cannot be pushed from onInit.
      WidgetsBinding.instance.addPostFrameCallback((_) => openLocationPicker());
      return;
    }

    locationLabel = _headerText(Injector.customerLocationLabel, Injector.customerLocationAddress);
    update();

    await _reportLocation(zoneId: zoneId);
  }

  /// Opens the location picker and adopts whatever comes back.
  Future<void> openLocationPicker() async {
    if (!Injector.mapLocationEnabled) {
      await _openZonePicker();
      return;
    }

    final result = await Get.to<PlaceSuggestion?>(
      // Constants.useNewLocationFlow: false restores the previous picker.
      () => Constants.useNewLocationFlow
          ? const CustomerSetLocationView()
          : const CustomerSelectLocationView(),
    );

    if (result == null || !result.hasPoint) {
      return;
    }

    latitude = result.latitude;
    longitude = result.longitude;
    locationLabel = _headerText(result.title, result.fullAddress);
    pincode = null;
    update();

    await Injector.setCustomerLocation(
      label: result.title,
      address: result.fullAddress,
      latitude: result.latitude!,
      longitude: result.longitude!,
    );

    await _reportLocation(latitude: latitude, longitude: longitude);
  }

  /// The header line under "Your location": the full address, not just the
  /// label — a saved address's label alone ("Home") said nothing about
  /// where. The address already starts with the label ("Home, B-12 …",
  /// "Satellite, Ahmedabad"), so nothing is lost; the label is the fallback
  /// when there is no address.
  static String? _headerText(String? label, String? address) {
    return (address != null && address.trim().isNotEmpty) ? address : label;
  }

  /// Zone mode's picker: main zone, then sub-zone.
  Future<void> _openZonePicker() async {
    final picked = await Get.to<PickedZone?>(() => const CustomerZoneLocationView());

    if (picked == null) {
      return;
    }

    locationLabel = _headerText(picked.title, picked.fullAddress);
    update();

    await Injector.setCustomerZone(
      zoneId: picked.id,
      label: picked.title,
      address: picked.fullAddress,
    );

    await _reportLocation(zoneId: picked.id);
  }

  /// SPEC section 4.2's fallback path: resolve by pincode instead of a
  /// point. The server does the lookup — the app never maps a pincode
  /// to a zone itself.
  Future<void> submitPincodeAPI() async {
    final entered = pincodeController.text.trim();

    if (entered.isEmpty) {
      Utils.showToast(tr(StringRes.invalidPincode), isError: true);
      return;
    }

    await _reportLocation(pincode: entered);

    if (zone != null) {
      // The zone's own name is the only label a pincode yields.
      locationLabel = zone?.name ?? entered;
      update();
    }
  }

  /// Tells the server where the customer is and keeps the zone it
  /// resolves, which is what vendor matching keys on.
  Future<void> _reportLocation({
    double? latitude,
    double? longitude,
    String? pincode,
    int? zoneId,
  }) async {
    isDetecting = true;
    update();

    try {
      final response = await DataSource.instance.updateCustomerLocationAPI(
        latitude: latitude,
        longitude: longitude,
        pincode: pincode,
        zoneId: zoneId,
      );

      if (response == null || !response.isSuccess || response.data == null) {
        showPincodeFallback = true;
        return;
      }

      final data = response.data as Map<String, dynamic>;
      final resolvedZone = data['zone'];

      zone = resolvedZone is Map<String, dynamic>
          ? ResolvedZoneModel.fromJson(resolvedZone)
          : null;

      // SPEC section 4.2's second fallback trigger: the point or
      // pincode matched no defined zone.
      showPincodeFallback = zone == null;

      // A picked zone the admin has switched off since: drop it, so the
      // header asks again instead of showing an area with no vendors.
      if (zoneId != null && zone == null) {
        locationLabel = null;
        await Injector.clearCustomerZone();
        Utils.showToast(tr(StringRes.zoneNotServed), isError: true);
      }

      // Kept whatever the zone outcome: vendor search re-resolves the
      // zone from the point itself, so an unmatched point is still
      // worth threading through.
      this.latitude = latitude;
      this.longitude = longitude;
      this.pincode = pincode;
    } catch (e) {
      if (kDebugMode) {
        print('Report location error $e');
      }
    } finally {
      isDetecting = false;
      update();
      // Who is nearby depends on where "here" is, so this follows every
      // location change rather than running once at startup.
      fetchNearbyVendorsAPI();

      // So does the Feed: its posts are for this area.
      if (Get.isRegistered<CustomerFeedController>()) {
        Get.find<CustomerFeedController>().fetchAPI();
      }
    }
  }

  Future<void> fetchCategoriesAPI() async {
    isLoadingCategories = true;
    update();

    try {
      final response = await DataSource.instance.categoriesAPI();

      if (response == null || !response.isSuccess || response.data == null) {
        Utils.showToast(
          response?.message ?? tr(StringRes.somethingWentWrong),
          isError: true,
        );
        return;
      }

      categories = (response.data as List<dynamic>)
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Fetch categories error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    } finally {
      isLoadingCategories = false;
      update();
      // Needs a subcategory id, which only exists once categories land.
      fetchNearbyVendorsAPI();
    }
  }

  /// The nearby rail: every vendor serving the customer's zone, whatever
  /// their services — vendor search with no subcategory. It used to search
  /// one "representative" subcategory, so a zone full of vendors showed
  /// none here unless one happened to offer that exact service.
  Future<void> fetchNearbyVendorsAPI() async {
    // A point (map mode) or a resolved zone (zone mode has no point).
    if (zone == null && (latitude == null || longitude == null)) {
      return;
    }

    isLoadingVendors = true;
    update();

    try {
      final response = await DataSource.instance.vendorSearchAPI(
        latitude: latitude,
        longitude: longitude,
        zoneId: zone?.id,
        perPage: 5,
      );

      if (response == null || !response.isSuccess || response.data == null) {
        nearbyVendors = [];
        return;
      }

      final data = response.data as Map<String, dynamic>;
      final vendors = (data['vendors'] as List<dynamic>?) ?? [];

      nearbyVendors = vendors
          .map((e) => VendorSearchModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Fetch nearby vendors error $e');
      }
      nearbyVendors = [];
    } finally {
      isLoadingVendors = false;
      update();
    }
  }

  /// Pull-to-refresh on the home tab.
  Future<void> refreshAll() async {
    await fetchCategoriesAPI();
    await fetchNearbyVendorsAPI();
  }

  @override
  void onClose() {
    pincodeController.dispose();
    super.onClose();
  }
}

/// A subcategory paired with the category it belongs to, for the rail's
/// two-line card.
class PopularService {
  const PopularService(this.subcategory, this.category);

  final SubcategoryModel subcategory;
  final CategoryModel category;
}
