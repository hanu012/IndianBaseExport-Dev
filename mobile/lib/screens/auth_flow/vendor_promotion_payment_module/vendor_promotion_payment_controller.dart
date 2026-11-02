import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';
import '../vendor_promotions_module/vendor_promotions_controller.dart';

/// "Waiting for payment" for a promotion — the same flow as a vendor's own
/// subscription (VendorPaymentPendingController): with Razorpay payment
/// links on, the link went out by SMS and the promotion goes live when the
/// webhook says it is paid. This screen only re-reads the promotion; the
/// app never takes the payment itself.
///
/// Opens over the promotions list (the form it replaced is gone), so every
/// way out is a plain Get.back() to that list, which is then refreshed.
class VendorPromotionPaymentController extends GetxController {
  VendorPromotionPaymentController({required this.promotion});

  PromotionModel promotion;

  bool isChecking = false;

  /// After paying: live → back to Promotions; withdrawn or the link expired
  /// → back too; otherwise still waiting.
  Future<void> checkAgainAPI() async {
    if (isChecking) {
      return;
    }

    isChecking = true;
    update();

    try {
      final response = await DataSource.instance.promotionDetailAPI(promotionId: promotion.id);

      if (response == null || !response.isSuccess || response.data == null) {
        Utils.showToast(response?.message ?? tr(StringRes.somethingWentWrong), isError: true);
        return;
      }

      promotion = PromotionModel.fromJson(response.data as Map<String, dynamic>);

      if (!promotion.isPendingPayment) {
        Utils.showToast(
          tr(promotion.isRunning ? StringRes.promotionLive : StringRes.promotionCancelled),
          isError: !promotion.isRunning,
        );
        _backToList();
        return;
      }

      Utils.showToast(tr(StringRes.stillAwaitingPayment));
    } catch (e) {
      if (kDebugMode) {
        print('Promotion payment status error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    } finally {
      isChecking = false;
      update();
    }
  }

  /// Withdraws it — the server cancels the payment link first, so it can
  /// never be paid afterwards.
  Future<void> cancelAPI() async {
    Utils.showCircularProgressLottie(true);

    try {
      final response = await DataSource.instance.cancelPromotionAPI(promotionId: promotion.id);
      Utils.showCircularProgressLottie(false);

      if (response == null || !response.isSuccess) {
        Utils.showToast(response?.message ?? tr(StringRes.somethingWentWrong), isError: true);
        return;
      }

      Utils.showToast(tr(StringRes.promotionCancelled));
      _backToList();
    } catch (e) {
      Utils.showCircularProgressLottie(false);
      if (kDebugMode) {
        print('Cancel promotion error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    }
  }

  /// The list is mounted underneath (CLAUDE.md: never offAll to it).
  void _backToList() {
    Get.back();

    if (Get.isRegistered<VendorPromotionsController>()) {
      Get.find<VendorPromotionsController>().fetchAPI();
    }
  }

  /// "14 Oct 2026, 18:30" in the device's time zone; empty when unknown.
  String get expiresLabel {
    final expires = promotion.paymentLinkExpiresAt;

    return expires == null ? '' : DateFormat('dd MMM yyyy, HH:mm').format(expires);
  }
}
