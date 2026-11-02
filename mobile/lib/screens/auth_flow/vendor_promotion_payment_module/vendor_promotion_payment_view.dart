import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import 'vendor_promotion_payment_controller.dart';

/// "Waiting for payment" for a promotion — see
/// [VendorPromotionPaymentController]. Laid out like the subscription's
/// VendorPaymentPendingView.
class VendorPromotionPaymentView extends StatelessWidget {
  const VendorPromotionPaymentView({super.key, required this.promotion});

  final PromotionModel promotion;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<VendorPromotionPaymentController>(
      init: VendorPromotionPaymentController(promotion: promotion),
      dispose: (_) => Get.delete<VendorPromotionPaymentController>(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: ServiceTokens.bg,
          body: RefreshIndicator(
            color: ServiceTokens.accent,
            onRefresh: controller.checkAgainAPI,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                VendorHero(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      VendorIconButton(icon: Icons.chevron_left, onTap: Get.back, tooltip: tr(StringRes.backToLogin)),
                      14.heightSpacer,
                      VendorHeroTitle(
                        title: tr(StringRes.paymentPendingTitle),
                        subtitle: tr(StringRes.promotionAwaitingPayment),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(16.getSize),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      summaryCard(controller),
                      24.heightSpacer,
                      VendorPrimaryButton(
                        label: tr(StringRes.checkPaymentStatus),
                        icon: Icons.refresh,
                        enabled: !controller.isChecking,
                        onTap: controller.checkAgainAPI,
                      ),
                      12.heightSpacer,
                      VendorSecondaryButton(
                        label: tr(StringRes.cancelPromotionAction),
                        onTap: controller.cancelAPI,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget summaryCard(VendorPromotionPaymentController controller) {
    final promotion = controller.promotion;

    Widget row(String label, String value) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 6.getSize),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            BaseTextDMSans(text: label, fontSize: 12, color: ServiceTokens.muted),
            12.widthSpacer,
            Flexible(
              child: BaseTextDMSans(
                text: value,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ServiceTokens.text,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      );
    }

    return VendorPanel(
      child: Column(
        children: [
          row(tr(StringRes.planLabel), promotion.packageName ?? '-'),
          row(tr(StringRes.priceLabel), Utils.rupeesWhole(promotion.pricePaise)),
          row(tr(StringRes.promotionAreaLabel), promotion.areaNames),
          if (controller.expiresLabel.isNotEmpty)
            row(tr(StringRes.paymentLinkValidUntil), controller.expiresLabel),
        ],
      ),
    );
  }
}
