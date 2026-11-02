import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import 'vendor_feed_comments_controller.dart';

/// Profile → Customer comments: each customer comment on one of the
/// vendor's Feed posts with the post's thumbnail, the replies under it, and
/// "Reply" to answer as the business.
class VendorFeedCommentsView extends StatelessWidget {
  const VendorFeedCommentsView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<VendorFeedCommentsController>(
      init: VendorFeedCommentsController(),
      dispose: (_) => Get.delete<VendorFeedCommentsController>(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: ServiceTokens.bg,
          body: RefreshIndicator(
            onRefresh: controller.fetchAPI,
            color: ServiceTokens.accentBright,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                hero(),
                Padding(
                  padding: EdgeInsets.fromLTRB(16.getSize, 16.getSize, 16.getSize, 24.getSize),
                  child: Column(children: list(controller)),
                ),
              ],
            ),
          ),
          bottomNavigationBar: controller.replyTo == null ? null : replyBar(controller),
        );
      },
    );
  }

  Widget hero() {
    return VendorHero(
      bottomPadding: 24.getSize,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VendorIconButton(icon: Icons.chevron_left, onTap: Get.back, tooltip: tr(StringRes.backToLogin)),
          14.heightSpacer,
          VendorHeroTitle(title: tr(StringRes.feedCommentsRow), subtitle: tr(StringRes.feedCommentsDesc)),
        ],
      ),
    );
  }

  List<Widget> list(VendorFeedCommentsController controller) {
    if (controller.isLoading && controller.comments.isEmpty) {
      return [40.heightSpacer, const CupertinoActivityIndicator(color: ServiceTokens.accentBright)];
    }

    if (controller.comments.isEmpty) {
      return [
        VendorPanel(
          child: Column(
            children: [
              Icon(Icons.chat_bubble_outline, size: 36.getSize, color: ServiceTokens.accent),
              10.heightSpacer,
              BaseTextDMSans(text: tr(StringRes.noFeedCommentsYet), fontSize: 12, color: ServiceTokens.muted, maxLines: 3),
            ],
          ),
        ),
      ];
    }

    return [
      for (final comment in controller.comments) ...[
        commentCard(controller, comment),
        12.heightSpacer,
      ],
      if (controller.hasMore)
        controller.isLoadingMore
            ? const CupertinoActivityIndicator(color: ServiceTokens.accentBright)
            : TextButton(
                onPressed: () => controller.fetchAPI(loadMore: true),
                child: BaseTextDMSans(text: StringRes.loadMore, fontSize: 12, color: ServiceTokens.accent).tr(),
              ),
    ];
  }

  Widget commentCard(VendorFeedCommentsController controller, FeedCommentModel comment) {
    final post = comment.post;

    return VendorPanel(
      padding: EdgeInsets.all(12.getSize),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post != null)
            Row(
              children: [
                SizedBox(
                  height: 40.getSize,
                  width: 40.getSize,
                  child: PortfolioMediaTile(type: post.mediaType, url: post.mediaUrl, radius: 8),
                ),
                10.widthSpacer,
                Expanded(
                  child: BaseTextDMSans(
                    text: post.caption ?? (post.type == 'promotion' ? tr(StringRes.sponsoredLabel) : ''),
                    fontSize: 10,
                    color: ServiceTokens.muted,
                    textAlign: TextAlign.start,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          10.heightSpacer,
          line(comment, reply: false),
          for (final reply in comment.replies)
            Padding(padding: EdgeInsets.only(left: 30.getSize, top: 8.getSize), child: line(reply, reply: true)),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => controller.startReply(comment),
              icon: Icon(Icons.reply, size: 16.getSize, color: ServiceTokens.accent),
              label: BaseTextDMSans(
                text: tr(StringRes.replyAction),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ServiceTokens.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget line(FeedCommentModel comment, {required bool reply}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfilePhoto(
          initials: profileInitials(comment.authorName),
          url: comment.authorAvatarUrl,
          size: reply ? 26 : 32,
          radius: (reply ? 13 : 16).getSize,
        ),
        8.widthSpacer,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: BaseTextDMSans(
                      text: comment.authorName,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: ServiceTokens.text,
                      textAlign: TextAlign.start,
                      maxLines: 1,
                    ),
                  ),
                  if (comment.isBusiness) ...[
                    6.widthSpacer,
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.getSize, vertical: 1.getSize),
                      decoration: BoxDecoration(
                        color: ServiceTokens.tileFill,
                        borderRadius: BorderRadius.circular(4.getSize),
                      ),
                      child: BaseTextDMSans(
                        text: tr(StringRes.businessBadge),
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        color: ServiceTokens.accent,
                      ),
                    ),
                  ],
                  6.widthSpacer,
                  BaseTextDMSans(text: comment.timeAgo, fontSize: 10, color: ServiceTokens.muted2),
                ],
              ),
              2.heightSpacer,
              BaseTextDMSans(
                text: comment.body,
                fontSize: 12,
                color: ServiceTokens.text,
                textAlign: TextAlign.start,
                maxLines: 10,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget replyBar(VendorFeedCommentsController controller) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(12.getSize, 8.getSize, 8.getSize, 8.getSize),
        decoration: const BoxDecoration(
          color: ServiceTokens.card,
          border: Border(top: BorderSide(color: ServiceTokens.stroke)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: BaseTextDMSans(
                    text: tr(StringRes.replyingToLabel, args: [controller.replyTo!.authorName]),
                    fontSize: 11,
                    color: ServiceTokens.muted,
                    textAlign: TextAlign.start,
                  ),
                ),
                GestureDetector(
                  onTap: controller.cancelReply,
                  child: Icon(Icons.close, size: 16.getSize, color: ServiceTokens.muted),
                ),
              ],
            ),
            6.heightSpacer,
            Row(
              children: [
                Expanded(
                  child: BaseTextField(
                    controller: controller.replyController,
                    hintText: tr(StringRes.replyAsBusinessHint, args: [tr(StringRes.businessBadge)]),
                    isShowBorder: true,
                    fillColor: ServiceTokens.card2,
                    borderColor: ServiceTokens.stroke,
                    maxLines: 3,
                    minLines: 1,
                    autofocus: true,
                    textInputAction: TextInputAction.send,
                    onFieldSubmitted: (_) => controller.replyAPI(),
                  ),
                ),
                controller.isPosting
                    ? Padding(
                        padding: EdgeInsets.all(12.getSize),
                        child: const CupertinoActivityIndicator(color: ServiceTokens.accentBright),
                      )
                    : TextButton(
                        onPressed: controller.replyAPI,
                        child: BaseTextDMSans(
                          text: tr(StringRes.postCommentAction),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ServiceTokens.accent,
                        ),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
