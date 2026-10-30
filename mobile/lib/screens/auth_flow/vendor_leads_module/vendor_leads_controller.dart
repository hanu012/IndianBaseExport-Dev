import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';

/// The vendor Leads tab (SPEC section 3 item 7, task 4.8) — every
/// customer who tapped Call or WhatsApp. (The "Request a review" action
/// was removed from the app on 2026-10-29.)
class VendorLeadsController extends GetxController {
  List<LeadModel> leads = [];

  bool isLoading = false;
  bool isLoadingMore = false;
  int currentPage = 1;
  int lastPage = 1;

  bool get hasMore => currentPage < lastPage;

  @override
  void onInit() {
    super.onInit();
    fetchAPI();
  }

  Future<void> fetchAPI({bool loadMore = false}) async {
    if (loadMore) {
      isLoadingMore = true;
    } else {
      isLoading = true;
      currentPage = 1;
    }
    update();

    try {
      final response = await DataSource.instance.vendorLeadsAPI(
        page: loadMore ? currentPage + 1 : 1,
      );

      if (response == null || !response.isSuccess || response.data == null) {
        Utils.showToast(
          response?.message ?? tr(StringRes.somethingWentWrong),
          isError: true,
        );
        return;
      }

      final fetched = (response.data as List<dynamic>)
          .map((e) => LeadModel.fromJson(e as Map<String, dynamic>))
          .toList();

      leads = loadMore ? [...leads, ...fetched] : fetched;

      final meta = response.meta;
      currentPage = meta?['current_page'] as int? ?? 1;
      lastPage = meta?['last_page'] as int? ?? 1;
    } catch (e) {
      if (kDebugMode) {
        print('Vendor leads error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    } finally {
      isLoading = false;
      isLoadingMore = false;
      update();
    }
  }
}
