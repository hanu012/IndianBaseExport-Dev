import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import '../vendor_promotions_module/vendor_promotions_view.dart';
import 'vendor_promotion_detail_controller.dart';

/// A promotion's details: status hero with its time bar, Performance (views,
/// calls, likes, comments and how many viewers called), the newest comments
/// with "Needs reply", the post, what was paid, and Pause / Edit post / End
/// promotion — with "Extend promotion" pinned at the foot.
class VendorPromotionDetailView extends StatelessWidget {
  const VendorPromotionDetailView({super.key, required this.promotionId});

  final int promotionId;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<VendorPromotionDetailController>(
      init: VendorPromotionDetailController(promotionId),
      dispose: (_) => Get.delete<VendorPromotionDetailController>(),
      builder: (controller) {
        final promotion = controller.promotion;

        return Scaffold(
          backgroundColor: ServiceTokens.bg,
          body: SafeArea(
            child: promotion == null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      topBar(),
                      Expanded(
                        child: Center(
                          child: controller.isLoading
                              ? const CupertinoActivityIndicator(color: ServiceTokens.accentBright)
                              : TextButton(
                                  onPressed: controller.fetchAPI,
                                  child: BaseTextDMSans(text: tr(StringRes.somethingWentWrong), fontSize: 12, color: ServiceTokens.accent),
                                ),
                        ),
                      ),
                    ],
                  )
                : RefreshIndicator(
                    onRefresh: controller.fetchAPI,
                    color: ServiceTokens.accentBright,
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(16.getSize, 0, 16.getSize, 24.getSize),
                      children: [
                        topBar(),
                        hero(promotion),
                        12.heightSpacer,
                        performance(promotion),
                        12.heightSpacer,
                        comments(controller, promotion),
                        12.heightSpacer,
                        post(controller, promotion),
                        12.heightSpacer,
                        details(promotion),
                        12.heightSpacer,
                        ...actions(controller, promotion),
                      ],
                    ),
                  ),
          ),
          bottomNavigationBar: promotion == null || !canExtend(promotion) ? null : footer(controller, promotion),
        );
      },
    );
  }

  bool canExtend(PromotionModel promotion) =>
      (promotion.isRunning || promotion.status == 'ended') && promotion.pendingExtensionDays == null;

  Widget topBar() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.getSize),
      child: Row(
        children: [
          PromotionBackButton(onTap: Get.back),
          Expanded(
            child: BaseTextDMSans(
              text: tr(StringRes.promotionTitle),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: ServiceTokens.text,
            ),
          ),
          SizedBox(width: 40.getSize),
        ],
      ),
    );
  }

  Widget hero(PromotionModel promotion) {
    final subtitle = switch (promotion.status) {
      'live' when promotion.isPaused => tr(StringRes.promotionPausedDesc),
      'live' => tr(StringRes.promotionShowingDesc),
      'hidden' => promotion.hiddenReason ?? tr(StringRes.promotionHiddenDesc),
      'pending_payment' => tr(StringRes.promotionAwaitingPayment),
      _ => tr(StringRes.promotionEndedDesc),
    };

    // Everything here sits on the dark header gradient, where white text is
    // correct (CLAUDE.md Theme).
    return Container(
      padding: EdgeInsets.all(16.getSize),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.getSize),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ServiceTokens.heroTop, ServiceTokens.heroMid, ServiceTokens.heroBottom],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PromotionStatusPill(promotion: promotion, onDark: true),
          8.heightSpacer,
          BaseTextDMSans(
            text: promotion.packageName ?? '',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            textAlign: TextAlign.start,
            maxLines: 2,
          ),
          4.heightSpacer,
          BaseTextDMSans(
            text: subtitle,
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.85),
            textAlign: TextAlign.start,
            maxLines: 3,
          ),
          if (promotion.endsAt != null) ...[
            14.heightSpacer,
            VendorProgressBar(ratio: promotion.timeRatio, onHero: true),
            6.heightSpacer,
            Row(
              children: [
                if (promotion.startsAt != null)
                  BaseTextDMSans(
                    text: tr(StringRes.promotionStartedOn, args: [promotionDate(promotion.startsAt!, withYear: false)]),
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                const Spacer(),
                BaseTextDMSans(
                  text: tr(StringRes.promotionEndsOn, args: [promotionDate(promotion.endsAt!)]),
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ],
            ),
          ],
          if (promotion.pendingExtensionDays != null) ...[
            10.heightSpacer,
            BaseTextDMSans(
              text: tr(StringRes.promotionExtensionPending, args: ['${promotion.pendingExtensionDays}']),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              textAlign: TextAlign.start,
              maxLines: 2,
            ),
          ],
        ],
      ),
    );
  }

  Widget section({required String title, Widget? action, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.getSize),
      decoration: BoxDecoration(
        color: ServiceTokens.card,
        borderRadius: BorderRadius.circular(20.getSize),
        border: Border.all(color: ServiceTokens.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: BaseTextDMSans(
                  text: title,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ServiceTokens.text,
                  textAlign: TextAlign.start,
                ),
              ),
              ?action,
            ],
          ),
          10.heightSpacer,
          child,
        ],
      ),
    );
  }

  Widget linkButton(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.getSize),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.getSize, vertical: 2.getSize),
        child: BaseTextDMSans(text: label, fontSize: 12, fontWeight: FontWeight.w600, color: ServiceTokens.accent),
      ),
    );
  }

  Widget performance(PromotionModel promotion) {
    return section(
      title: tr(StringRes.performanceTitle),
      child: Column(
        children: [
          Row(
            children: [
              statTile(Icons.visibility_outlined, promotion.views, StringRes.statViews),
              8.widthSpacer,
              statTile(Icons.call_outlined, promotion.calls, StringRes.statCalls),
            ],
          ),
          8.heightSpacer,
          Row(
            children: [
              statTile(Icons.favorite_border, promotion.likes, StringRes.statLikes),
              8.widthSpacer,
              statTile(Icons.chat_bubble_outline, promotion.comments, StringRes.statComments),
            ],
          ),
          if (promotion.views > 0) ...[
            10.heightSpacer,
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 12.getSize, vertical: 10.getSize),
              decoration: BoxDecoration(
                color: ServiceTokens.tileFill,
                borderRadius: BorderRadius.circular(12.getSize),
              ),
              child: BaseTextDMSans(
                text: tr(StringRes.promotionCallRate, namedArgs: {
                  'calls': '${promotion.calls}',
                  'views': '${promotion.views}',
                }),
                fontSize: 12,
                color: ServiceTokens.text,
                textAlign: TextAlign.start,
                maxLines: 2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget statTile(IconData icon, int value, String label) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12.getSize),
        decoration: BoxDecoration(
          color: ServiceTokens.card2,
          borderRadius: BorderRadius.circular(14.getSize),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20.getSize, color: ServiceTokens.accent),
            6.heightSpacer,
            BaseTextDMSans(text: '$value', fontSize: 20, fontWeight: FontWeight.w600, color: ServiceTokens.text),
            BaseTextDMSans(text: tr(label), fontSize: 11, color: ServiceTokens.muted),
          ],
        ),
      ),
    );
  }

  Widget comments(VendorPromotionDetailController controller, PromotionModel promotion) {
    return section(
      title: tr(StringRes.commentsTitle),
      action: promotion.comments > 0 ? linkButton(tr(StringRes.seeAllAction), controller.seeAllComments) : null,
      child: promotion.recentComments.isEmpty
          ? BaseTextDMSans(
              text: tr(StringRes.noCommentsYet),
              fontSize: 12,
              color: ServiceTokens.muted,
              textAlign: TextAlign.start,
            )
          : Column(
              children: [
                for (final (index, comment) in promotion.recentComments.indexed) ...[
                  if (index > 0) Divider(height: 20.getSize, color: ServiceTokens.stroke),
                  commentRow(controller, comment),
                ],
              ],
            ),
    );
  }

  Widget commentRow(VendorPromotionDetailController controller, FeedCommentModel comment) {
    final initials = comment.authorName.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).take(2).map((part) => part[0].toUpperCase()).join();
    final lastReply = comment.replies.isEmpty ? null : comment.replies.last;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Initials underneath, the photo on top once it loads — an empty or
        // broken photo link leaves the initials showing, not a blank circle.
        CircleAvatar(
          radius: 16.getSize,
          backgroundColor: ServiceTokens.tileFill,
          child: Stack(
            alignment: Alignment.center,
            children: [
              BaseTextDMSans(text: initials, fontSize: 10, fontWeight: FontWeight.w600, color: ServiceTokens.accent),
              if ((comment.authorAvatarUrl ?? '').isNotEmpty)
                ClipOval(
                  child: Image.network(
                    comment.authorAvatarUrl!,
                    width: 32.getSize,
                    height: 32.getSize,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
            ],
          ),
        ),
        10.widthSpacer,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: BaseTextDMSans(
                      text: comment.authorName,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ServiceTokens.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  6.widthSpacer,
                  BaseTextDMSans(text: comment.timeAgo, fontSize: 10, color: ServiceTokens.muted),
                  if (comment.needsReply) ...[
                    6.widthSpacer,
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.getSize, vertical: 1.getSize),
                      decoration: BoxDecoration(
                        color: ColorRes.warningColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20.getSize),
                      ),
                      child: BaseTextDMSans(
                        text: tr(StringRes.needsReplyBadge),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: ColorRes.warningColor,
                      ),
                    ),
                  ],
                ],
              ),
              2.heightSpacer,
              BaseTextDMSans(
                text: comment.body,
                fontSize: 12,
                color: ServiceTokens.text,
                textAlign: TextAlign.start,
                maxLines: 4,
              ),
              if (lastReply != null && lastReply.isBusiness) ...[
                6.heightSpacer,
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(8.getSize),
                  decoration: BoxDecoration(
                    color: ServiceTokens.card2,
                    borderRadius: BorderRadius.circular(10.getSize),
                  ),
                  child: BaseTextDMSans(
                    text: '${tr(StringRes.businessBadge)}: ${lastReply.body}',
                    fontSize: 11,
                    color: ServiceTokens.muted,
                    textAlign: TextAlign.start,
                    maxLines: 3,
                  ),
                ),
              ],
              4.heightSpacer,
              linkButton(tr(StringRes.replyAction), () => replySheet(controller, comment)),
            ],
          ),
        ),
      ],
    );
  }

  void replySheet(VendorPromotionDetailController controller, FeedCommentModel comment) {
    controller.replyController.clear();

    Get.bottomSheet(
      GetBuilder<VendorPromotionDetailController>(
        builder: (sheetController) {
          return Container(
            padding: EdgeInsets.fromLTRB(16.getSize, 16.getSize, 16.getSize, 16.getSize),
            decoration: BoxDecoration(
              color: ServiceTokens.card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20.getSize)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BaseTextDMSans(
                    text: tr(StringRes.replyToCommentTitle, args: [comment.authorName]),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ServiceTokens.text,
                    textAlign: TextAlign.start,
                  ),
                  6.heightSpacer,
                  BaseTextDMSans(
                    text: comment.body,
                    fontSize: 12,
                    color: ServiceTokens.muted,
                    textAlign: TextAlign.start,
                    maxLines: 3,
                  ),
                  12.heightSpacer,
                  BaseTextField(
                    controller: sheetController.replyController,
                    hintText: tr(StringRes.replyAsBusinessHint, args: [tr(StringRes.businessBadge)]),
                    isShowBorder: true,
                    fillColor: ServiceTokens.card2,
                    borderColor: ServiceTokens.stroke,
                    maxLines: 3,
                    minLines: 1,
                    maxLength: 500,
                    onChanged: (_) => sheetController.update(),
                  ),
                  12.heightSpacer,
                  VendorPrimaryButton(
                    label: tr(StringRes.replyAction),
                    icon: Icons.send_outlined,
                    enabled: sheetController.replyController.text.trim().isNotEmpty && !sheetController.isReplying,
                    onTap: () => sheetController.replyAPI(comment),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
  }

  Widget post(VendorPromotionDetailController controller, PromotionModel promotion) {
    final editable = promotion.isRunning || promotion.isPendingPayment;

    return section(
      title: tr(StringRes.postSectionTitle),
      action: editable ? linkButton(tr(StringRes.editAction), controller.editPost) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PromotionThumb(promotion: promotion, size: 72),
          12.widthSpacer,
          Expanded(
            child: BaseTextDMSans(
              text: promotion.caption,
              fontSize: 12,
              color: ServiceTokens.text,
              textAlign: TextAlign.start,
              maxLines: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget details(PromotionModel promotion) {
    final rows = <(String, String)>[
      (tr(StringRes.promotionPlanLabel), promotion.packageName ?? '—'),
      (tr(StringRes.promotionAreaLabel), promotion.areaNames),
      if (promotion.endsAt != null) (tr(StringRes.promotionEndsLabel), promotionDate(promotion.endsAt!)),
      (tr(StringRes.amountPaidLabel), Utils.rupeesWhole(promotion.amountPaidPaise)),
    ];

    return section(
      title: tr(StringRes.detailsSectionTitle),
      child: Column(
        children: [
          for (final (index, (label, value)) in rows.indexed) ...[
            if (index > 0) Divider(height: 20.getSize, color: ServiceTokens.stroke),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BaseTextDMSans(text: label, fontSize: 12, color: ServiceTokens.muted),
                12.widthSpacer,
                Expanded(
                  child: BaseTextDMSans(
                    text: value,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ServiceTokens.text,
                    textAlign: TextAlign.end,
                    maxLines: 3,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> actions(VendorPromotionDetailController controller, PromotionModel promotion) {
    if (!promotion.isRunning) {
      return [];
    }

    return [
      Row(
        children: [
          // Pausing is the vendor's own switch — not offered while the admin
          // has the post hidden.
          if (promotion.status == 'live') ...[
            Expanded(
              child: VendorSecondaryButton(
                label: tr(promotion.isPaused ? StringRes.resumeAction : StringRes.pauseAction),
                icon: promotion.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                onTap: controller.togglePauseAPI,
              ),
            ),
            8.widthSpacer,
          ],
          Expanded(
            child: VendorSecondaryButton(
              label: tr(StringRes.editPostAction),
              icon: Icons.edit_outlined,
              onTap: controller.editPost,
            ),
          ),
        ],
      ),
      4.heightSpacer,
      Center(
        child: TextButton(
          onPressed: controller.endAPI,
          child: BaseTextDMSans(
            text: tr(StringRes.endPromotionAction),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: ColorRes.errorColor,
          ),
        ),
      ),
    ];
  }

  Widget footer(VendorPromotionDetailController controller, PromotionModel promotion) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(16.getSize, 12.getSize, 16.getSize, 12.getSize),
        decoration: BoxDecoration(
          color: ServiceTokens.card,
          border: Border(top: BorderSide(color: ServiceTokens.stroke)),
        ),
        child: VendorPrimaryButton(
          label: tr(StringRes.extendPromotionAction),
          icon: Icons.bolt,
          onTap: controller.extendAPI,
        ),
      ),
    );
  }
}
