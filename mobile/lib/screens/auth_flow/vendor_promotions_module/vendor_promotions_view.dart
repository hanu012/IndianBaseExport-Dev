import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import 'vendor_promotions_controller.dart';

/// Profile → Promote your business: Live / Ended tabs with counts, each
/// promotion a card with its area, four numbers and how much of its time
/// has gone; tapping one opens its details. "New promotion" floats bottom
/// right.
class VendorPromotionsView extends StatelessWidget {
  const VendorPromotionsView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<VendorPromotionsController>(
      init: VendorPromotionsController(),
      dispose: (_) => Get.delete<VendorPromotionsController>(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: ServiceTokens.bg,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: controller.openCreate,
            backgroundColor: ServiceTokens.accent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.getSize)),
            icon: Icon(Icons.add, color: Colors.white, size: 20.getSize),
            label: BaseTextDMSans(
              text: tr(StringRes.newPromotionAction),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: controller.fetchAPI,
              color: ServiceTokens.accentBright,
              child: ListView(
                padding: EdgeInsets.fromLTRB(16.getSize, 8.getSize, 16.getSize, 96.getSize),
                children: [
                  header(),
                  16.heightSpacer,
                  tabs(controller),
                  14.heightSpacer,
                  ...list(controller),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PromotionBackButton(onTap: Get.back),
        14.heightSpacer,
        BaseTextDMSans(
          text: tr(StringRes.myPromotionsTitle),
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: ServiceTokens.text,
          textAlign: TextAlign.start,
        ),
        4.heightSpacer,
        BaseTextDMSans(
          text: tr(StringRes.promoteBusinessDesc),
          fontSize: 12,
          color: ServiceTokens.muted,
          textAlign: TextAlign.start,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget tabs(VendorPromotionsController controller) {
    return Container(
      padding: EdgeInsets.all(4.getSize),
      decoration: BoxDecoration(
        color: ServiceTokens.card2,
        borderRadius: BorderRadius.circular(14.getSize),
      ),
      child: Row(
        children: [
          tabButton(controller, VendorPromotionsController.tabLive, StringRes.promotionsTabLive, controller.liveCount),
          4.widthSpacer,
          tabButton(controller, VendorPromotionsController.tabEnded, StringRes.promotionsTabEnded, controller.endedCount),
        ],
      ),
    );
  }

  Widget tabButton(VendorPromotionsController controller, String value, String label, int count) {
    final selected = controller.tab == value;

    return Expanded(
      child: InkWell(
        onTap: () => controller.selectTab(value),
        borderRadius: BorderRadius.circular(10.getSize),
        child: Container(
          height: 38.getSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? ServiceTokens.card : Colors.transparent,
            borderRadius: BorderRadius.circular(10.getSize),
            boxShadow: selected
                ? [BoxShadow(color: ServiceTokens.text.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BaseTextDMSans(
                text: tr(label),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? ServiceTokens.text : ServiceTokens.muted,
              ),
              5.widthSpacer,
              BaseTextDMSans(text: '$count', fontSize: 12, color: ServiceTokens.muted),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> list(VendorPromotionsController controller) {
    if (controller.isLoading && controller.promotions.isEmpty) {
      return [
        40.heightSpacer,
        const Center(child: CupertinoActivityIndicator(color: ServiceTokens.accentBright)),
      ];
    }

    if (controller.promotions.isEmpty) {
      final live = controller.tab == VendorPromotionsController.tabLive;

      return [
        VendorPanel(
          child: Column(
            children: [
              Icon(Icons.campaign_outlined, size: 40.getSize, color: ServiceTokens.accent),
              10.heightSpacer,
              BaseTextDMSans(
                text: tr(live ? StringRes.noPromotionsTitle : StringRes.noEndedPromotions),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ServiceTokens.text,
              ),
              if (live) ...[
                6.heightSpacer,
                BaseTextDMSans(
                  text: tr(StringRes.noPromotionsDesc),
                  fontSize: 12,
                  color: ServiceTokens.muted,
                  maxLines: 4,
                ),
              ],
            ],
          ),
        ),
      ];
    }

    return [
      for (final promotion in controller.promotions) ...[
        promotionCard(controller, promotion),
        12.heightSpacer,
      ],
      if (controller.hasMore)
        Center(
          child: controller.isLoadingMore
              ? const CupertinoActivityIndicator(color: ServiceTokens.accentBright)
              : TextButton(
                  onPressed: () => controller.fetchAPI(loadMore: true),
                  child: BaseTextDMSans(text: StringRes.loadMore, fontSize: 12, color: ServiceTokens.accent).tr(),
                ),
        ),
    ];
  }

  Widget promotionCard(VendorPromotionsController controller, PromotionModel promotion) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => controller.openDetail(promotion),
        borderRadius: BorderRadius.circular(20.getSize),
        child: Container(
          padding: EdgeInsets.all(12.getSize),
          decoration: BoxDecoration(
            color: ServiceTokens.card,
            borderRadius: BorderRadius.circular(20.getSize),
            border: Border.all(color: ServiceTokens.stroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PromotionThumb(promotion: promotion, size: 72),
                  12.widthSpacer,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: BaseTextDMSans(
                                text: promotion.packageName ?? '',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: ServiceTokens.text,
                                textAlign: TextAlign.start,
                                maxLines: 2,
                              ),
                            ),
                            8.widthSpacer,
                            PromotionStatusPill(promotion: promotion),
                          ],
                        ),
                        4.heightSpacer,
                        BaseTextDMSans(
                          text: promotion.caption,
                          fontSize: 11,
                          color: ServiceTokens.muted,
                          textAlign: TextAlign.start,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        6.heightSpacer,
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 14.getSize, color: ServiceTokens.muted),
                            4.widthSpacer,
                            Expanded(
                              child: BaseTextDMSans(
                                text: promotion.areaNames,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: ServiceTokens.muted,
                                textAlign: TextAlign.start,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              12.heightSpacer,
              Container(height: 1, color: ServiceTokens.stroke),
              10.heightSpacer,
              Row(
                children: [
                  miniStat('${promotion.views}', StringRes.statViews),
                  miniStat('${promotion.likes}', StringRes.statLikes),
                  miniStat('${promotion.comments}', StringRes.statComments),
                  miniStat('${promotion.calls}', StringRes.statCalls),
                ],
              ),
              if (promotion.endsAt != null) ...[
                10.heightSpacer,
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14.getSize, color: ServiceTokens.muted),
                    10.widthSpacer,
                    Expanded(child: VendorProgressBar(ratio: promotion.timeRatio)),
                    10.widthSpacer,
                    BaseTextDMSans(
                      text: tr(StringRes.promotionEndsOn, args: [promotionDate(promotion.endsAt!, withYear: false)]),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: ServiceTokens.muted,
                    ),
                  ],
                ),
              ],
              if ((promotion.hiddenReason ?? '').isNotEmpty) ...[
                8.heightSpacer,
                BaseTextDMSans(
                  text: promotion.hiddenReason!,
                  fontSize: 11,
                  color: ColorRes.errorColor,
                  textAlign: TextAlign.start,
                  maxLines: 3,
                ),
              ],
              if (promotion.isPendingPayment) ...[
                8.heightSpacer,
                BaseTextDMSans(
                  text: tr(StringRes.promotionAwaitingPayment),
                  fontSize: 11,
                  color: ServiceTokens.muted,
                  textAlign: TextAlign.start,
                  maxLines: 3,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => controller.cancelPromotionAPI(promotion),
                    child: BaseTextDMSans(
                      text: tr(StringRes.cancelPromotionAction),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ColorRes.errorColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget miniStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          BaseTextDMSans(text: value, fontSize: 14, fontWeight: FontWeight.w600, color: ServiceTokens.text),
          2.heightSpacer,
          BaseTextDMSans(text: tr(label), fontSize: 10, color: ServiceTokens.muted),
        ],
      ),
    );
  }
}

// ── Shared by the promotion list, details and form ─────────────────────────

/// "1 Nov 2026", or "1 Nov" in tight spots.
String promotionDate(DateTime date, {bool withYear = true}) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  return withYear ? '${date.day} ${months[date.month - 1]} ${date.year}' : '${date.day} ${months[date.month - 1]}';
}

/// The round back button on the light header of the promotion screens.
class PromotionBackButton extends StatelessWidget {
  const PromotionBackButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ServiceTokens.card,
      shape: const CircleBorder(side: BorderSide(color: ServiceTokens.stroke)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 40.getSize,
          width: 40.getSize,
          child: Icon(Icons.chevron_left, size: 22.getSize, color: ServiceTokens.text),
        ),
      ),
    );
  }
}

/// The post's photo or video, or — for a text-only post — a teal tile with
/// the campaign mark.
class PromotionThumb extends StatelessWidget {
  const PromotionThumb({super.key, required this.promotion, this.size = 72});

  final PromotionModel promotion;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: size.getSize,
      width: size.getSize,
      child: promotion.hasMedia
          ? PortfolioMediaTile(
              type: promotion.mediaType,
              url: promotion.mediaUrl,
              radius: 14,
              onTap: () => showPortfolioViewer([
                PortfolioViewerItem(type: promotion.mediaType!, url: promotion.mediaUrl!, caption: promotion.caption),
              ]),
            )
          : Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14.getSize),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [ServiceTokens.heroTop, ServiceTokens.heroBottom],
                ),
              ),
              // White sits on the dark header gradient — the one surface
              // where it is still right (CLAUDE.md Theme).
              child: Icon(Icons.campaign_outlined, color: Colors.white, size: (size * 0.42).getSize),
            ),
    );
  }
}

/// Live (with its dot), Paused, Waiting for payment, Hidden, Ended…
class PromotionStatusPill extends StatelessWidget {
  const PromotionStatusPill({super.key, required this.promotion, this.onDark = false});

  final PromotionModel promotion;

  /// On the details hero: a white pill so it reads on the gradient.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (promotion.status) {
      'live' when promotion.isPaused => (tr(StringRes.promotionStatusPaused), ColorRes.warningColor),
      'live' => (tr(StringRes.promotionStatusLive), ServiceTokens.green),
      'pending_payment' => (tr(StringRes.promotionStatusPending), ColorRes.warningColor),
      'hidden' => (tr(StringRes.promotionStatusHidden), ColorRes.errorColor),
      'cancelled' => (tr(StringRes.promotionStatusCancelled), ServiceTokens.muted),
      _ => (tr(StringRes.promotionStatusEnded), ServiceTokens.muted),
    };
    final live = promotion.status == 'live' && !promotion.isPaused;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.getSize, vertical: 3.getSize),
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withValues(alpha: 0.95) : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20.getSize),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live) ...[
            Container(
              height: 6.getSize,
              width: 6.getSize,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.25), spreadRadius: 3)],
              ),
            ),
            6.widthSpacer,
          ],
          BaseTextDMSans(text: label, fontSize: 10, fontWeight: FontWeight.w600, color: color),
        ],
      ),
    );
  }
}
