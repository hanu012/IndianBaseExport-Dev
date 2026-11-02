import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import 'customer_feed_controller.dart';

/// The Feed tab of the customer home shell (decided 2026-10-31): paid
/// promotions for the customer's area first ("Sponsored"), then the work
/// photos and videos of vendors serving it. Chips narrow it (For you ·
/// Offers · Nearby · Following). Each post is a card: vendor, caption, media,
/// like / comment / share, and Call / WhatsApp.
///
/// Layout follows the Feed design; colours are the app's light theme
/// (CLAUDE.md), not the dark mock-up.
class CustomerFeedView extends StatelessWidget {
  const CustomerFeedView({super.key});

  static const Color _whatsappGreen = Color(0xFF12B76A);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CustomerFeedController>(
      init: CustomerFeedController(),
      dispose: (_) => Get.delete<CustomerFeedController>(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: ServiceTokens.bg,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                header(controller),
                chips(controller),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: controller.fetchAPI,
                    color: ServiceTokens.accentBright,
                    backgroundColor: ServiceTokens.card,
                    child: body(controller),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Header and chips ────────────────────────────────────────────────────

  Widget header(CustomerFeedController controller) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.getSize, 12.getSize, 16.getSize, 8.getSize),
      child: BaseTextDMSans(
        text: tr(StringRes.feedTitle),
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: ServiceTokens.text,
        textAlign: TextAlign.start,
      ),
    );
  }

  Widget chips(CustomerFeedController controller) {
    const labels = {
      'for_you': StringRes.feedChipForYou,
      'offers': StringRes.feedChipOffers,
      'nearby': StringRes.feedChipNearby,
      'following': StringRes.feedChipFollowing,
    };

    return SizedBox(
      height: 44.getSize,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.getSize, vertical: 4.getSize),
        children: [
          for (final filter in CustomerFeedController.filters) ...[
            GestureDetector(
              onTap: () => controller.setFilter(filter),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.getSize),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: controller.filter == filter ? ServiceTokens.accent : ServiceTokens.card,
                  borderRadius: BorderRadius.circular(20.getSize),
                  border: Border.all(color: controller.filter == filter ? ServiceTokens.accent : ServiceTokens.stroke),
                ),
                child: BaseTextDMSans(
                  text: tr(labels[filter]!),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: controller.filter == filter ? Colors.white : ServiceTokens.text,
                ),
              ),
            ),
            8.widthSpacer,
          ],
        ],
      ),
    );
  }

  // ── Body ────────────────────────────────────────────────────────────────

  Widget body(CustomerFeedController controller) {
    if (controller.isLoading && controller.items.isEmpty) {
      return Center(child: CupertinoActivityIndicator(color: ColorRes.primaryColor));
    }

    if (controller.items.isEmpty) {
      final message = controller.hasNoLocation
          ? StringRes.feedNoLocation
          : switch (controller.filter) {
              'offers' => StringRes.feedOffersEmpty,
              'following' => StringRes.feedFollowingEmpty,
              _ => StringRes.feedEmptyTitle,
            };

      // A ListView, so pull-to-refresh still works on an empty feed.
      return ListView(
        padding: EdgeInsets.all(32.getSize),
        children: [
          70.heightSpacer,
          Icon(Icons.dynamic_feed_outlined, size: 44.getSize, color: ServiceTokens.muted2),
          14.heightSpacer,
          BaseTextDMSans(
            text: tr(message),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: ServiceTokens.text,
            maxLines: 3,
          ),
          if (!controller.hasNoLocation && controller.filter == 'for_you') ...[
            6.heightSpacer,
            BaseTextDMSans(text: tr(StringRes.feedEmptyDesc), fontSize: 12, color: ServiceTokens.muted, maxLines: 3),
          ],
        ],
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16.getSize, 6.getSize, 16.getSize, 24.getSize),
      itemCount: controller.items.length + (controller.hasMore ? 1 : 0),
      separatorBuilder: (_, _) => 14.heightSpacer,
      itemBuilder: (_, index) {
        if (index == controller.items.length) {
          return loadMoreButton(controller);
        }

        return postCard(controller, controller.items[index]);
      },
    );
  }

  Widget loadMoreButton(CustomerFeedController controller) {
    return Center(
      child: controller.isLoadingMore
          ? CupertinoActivityIndicator(color: ColorRes.primaryColor)
          : TextButton(
              onPressed: () => controller.fetchAPI(loadMore: true),
              child: BaseTextDMSans(text: StringRes.loadMore, fontSize: 12, color: ColorRes.primaryColor).tr(),
            ),
    );
  }

  // ── Post card ───────────────────────────────────────────────────────────

  Widget postCard(CustomerFeedController controller, FeedItemModel item) {
    final hasMedia = (item.mediaUrl ?? '').isNotEmpty;
    final caption = item.caption ?? '';

    return Container(
      padding: EdgeInsets.all(12.getSize),
      decoration: BoxDecoration(
        color: ServiceTokens.card,
        borderRadius: BorderRadius.circular(18.getSize),
        border: Border.all(color: ServiceTokens.stroke),
        boxShadow: ServiceTokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          postHeader(controller, item),
          if (caption.isNotEmpty) ...[
            10.heightSpacer,
            // No media: the words are the post, so they read larger.
            BaseTextDMSans(
              text: caption,
              fontSize: hasMedia ? 12 : 15,
              fontWeight: hasMedia ? FontWeight.w400 : FontWeight.w600,
              color: ServiceTokens.text,
              textAlign: TextAlign.start,
              maxLines: 8,
            ),
          ],
          if (hasMedia) ...[
            10.heightSpacer,
            AspectRatio(
              aspectRatio: 4 / 3,
              child: PortfolioMediaTile(
                type: item.mediaType,
                url: item.mediaUrl,
                radius: 14,
                onTap: () => controller.openMedia(item),
                badge: item.isVideo
                    ? Align(
                        alignment: Alignment.bottomLeft,
                        child: Icon(Icons.play_circle_fill, color: Colors.white, size: 30.getSize),
                      )
                    : null,
              ),
            ),
          ],
          6.heightSpacer,
          actionsRow(controller, item),
          4.heightSpacer,
          contactRow(controller, item),
        ],
      ),
    );
  }

  Widget postHeader(CustomerFeedController controller, FeedItemModel item) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => controller.openVendor(item),
          child: ProfilePhoto(
            initials: profileInitials(item.vendorName),
            url: item.vendorPhotoUrl,
            size: 40,
            radius: 20.getSize,
          ),
        ),
        10.widthSpacer,
        Expanded(
          child: GestureDetector(
            onTap: () => controller.openVendor(item),
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: BaseTextDMSans(
                        text: item.vendorName ?? '',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ServiceTokens.text,
                        textAlign: TextAlign.start,
                        maxLines: 1,
                      ),
                    ),
                    if (item.vendorVerified) ...[
                      4.widthSpacer,
                      Icon(Icons.verified, size: 15.getSize, color: ServiceTokens.accentBright),
                    ],
                  ],
                ),
                2.heightSpacer,
                Row(
                  children: [
                    if ((item.serviceName ?? '').isNotEmpty)
                      Flexible(
                        child: BaseTextDMSans(
                          text: item.serviceName!,
                          fontSize: 10,
                          color: ServiceTokens.muted,
                          textAlign: TextAlign.start,
                          maxLines: 1,
                        ),
                      ),
                    if (item.isSponsored) ...[
                      6.widthSpacer,
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.getSize, vertical: 1.getSize),
                        decoration: BoxDecoration(
                          color: ColorRes.warningColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4.getSize),
                        ),
                        child: BaseTextDMSans(
                          text: tr(StringRes.sponsoredLabel),
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: ColorRes.warningColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_horiz, size: 20.getSize, color: ServiceTokens.muted),
          onSelected: (action) => action == 'profile' ? controller.openVendor(item) : controller.shareItem(item),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'profile',
              child: BaseTextDMSans(text: tr(StringRes.viewProfileAction), fontSize: 12, color: ServiceTokens.text),
            ),
            PopupMenuItem(
              value: 'share',
              child: BaseTextDMSans(text: tr(StringRes.shareAction), fontSize: 12, color: ServiceTokens.text),
            ),
          ],
        ),
      ],
    );
  }

  Widget actionsRow(CustomerFeedController controller, FeedItemModel item) {
    Widget action(IconData icon, Color color, String? count, VoidCallback onTap) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.getSize),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 6.getSize, vertical: 8.getSize),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 21.getSize, color: color),
              if (count != null) ...[
                5.widthSpacer,
                BaseTextDMSans(text: count, fontSize: 11, fontWeight: FontWeight.w600, color: ServiceTokens.text),
              ],
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        action(
          item.liked ? Icons.favorite : Icons.favorite_border,
          item.liked ? ColorRes.errorColor : ServiceTokens.text,
          '${item.likesCount}',
          () => controller.toggleLikeAPI(item),
        ),
        8.widthSpacer,
        action(Icons.chat_bubble_outline, ServiceTokens.text, '${item.commentsCount}', () => showComments(controller, item)),
        8.widthSpacer,
        action(Icons.send_outlined, ServiceTokens.text, null, () => controller.shareItem(item)),
      ],
    );
  }

  Widget contactRow(CustomerFeedController controller, FeedItemModel item) {
    return Row(
      children: [
        Expanded(
          child: Material(
            color: ServiceTokens.accent,
            borderRadius: BorderRadius.circular(12.getSize),
            child: InkWell(
              onTap: () => controller.callAPI(item),
              borderRadius: BorderRadius.circular(12.getSize),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 11.getSize),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.call_outlined, size: 16.getSize, color: Colors.white),
                    6.widthSpacer,
                    BaseTextDMSans(text: tr(StringRes.callButton), fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        ),
        10.widthSpacer,
        Expanded(
          child: Material(
            color: ServiceTokens.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.getSize),
              side: const BorderSide(color: ServiceTokens.stroke),
            ),
            child: InkWell(
              onTap: () => controller.whatsappAPI(item),
              borderRadius: BorderRadius.circular(12.getSize),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 11.getSize),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat, size: 16.getSize, color: _whatsappGreen),
                    6.widthSpacer,
                    BaseTextDMSans(
                      text: tr(StringRes.whatsappButton),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _whatsappGreen,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void showComments(CustomerFeedController controller, FeedItemModel item) {
    controller.openComments(item);
    Get.bottomSheet(
      _CommentsSheet(controller: controller),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }
}

/// The comments of one post: threads newest first, replies under each
/// (Reply, like, the vendor's own answers tagged "Business"), a row of quick
/// reactions and the box to write in.
class _CommentsSheet extends StatelessWidget {
  const _CommentsSheet({required this.controller});

  final CustomerFeedController controller;

  static const List<String> _quickReactions = ['❤️', '👏', '🔥', '🙏', '😍', '😂'];

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CustomerFeedController>(
      builder: (controller) {
        return Padding(
          // Rides above the keyboard.
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: ServiceTokens.card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22.getSize)),
            ),
            child: Column(
              children: [
                10.heightSpacer,
                Container(
                  height: 4.getSize,
                  width: 46.getSize,
                  decoration: BoxDecoration(color: ServiceTokens.stroke2, borderRadius: BorderRadius.circular(3.getSize)),
                ),
                12.heightSpacer,
                BaseTextDMSans(
                  text: tr(StringRes.commentsTitle),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ServiceTokens.text,
                ),
                10.heightSpacer,
                const Divider(height: 1, color: ServiceTokens.stroke),
                Expanded(child: list(controller)),
                const Divider(height: 1, color: ServiceTokens.stroke),
                reactionsRow(controller),
                if (controller.replyTo != null) replyingBanner(controller),
                inputRow(controller),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget list(CustomerFeedController controller) {
    if (controller.isLoadingComments && controller.comments.isEmpty) {
      return Center(child: CupertinoActivityIndicator(color: ColorRes.primaryColor));
    }

    if (controller.comments.isEmpty) {
      return Center(
        child: BaseTextDMSans(text: tr(StringRes.noCommentsYet), fontSize: 12, color: ServiceTokens.muted),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 8.getSize),
      itemCount: controller.comments.length + (controller.hasMoreComments ? 1 : 0),
      itemBuilder: (_, index) {
        if (index == controller.comments.length) {
          return TextButton(
            onPressed: () => controller.fetchCommentsAPI(loadMore: true),
            child: BaseTextDMSans(text: StringRes.loadMore, fontSize: 12, color: ColorRes.primaryColor).tr(),
          );
        }

        final comment = controller.comments[index];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            commentTile(controller, comment, reply: false),
            if (comment.replies.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(left: 58.getSize),
                child: GestureDetector(
                  onTap: () => controller.toggleReplies(comment),
                  child: Row(
                    children: [
                      Container(width: 22.getSize, height: 1, color: ServiceTokens.stroke2),
                      8.widthSpacer,
                      BaseTextDMSans(
                        text: comment.showReplies
                            ? tr(StringRes.hideRepliesAction)
                            : tr(StringRes.viewRepliesAction, args: ['${comment.replies.length}']),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: ServiceTokens.muted,
                      ),
                    ],
                  ),
                ),
              ),
            if (comment.showReplies)
              for (final reply in comment.replies)
                Padding(
                  padding: EdgeInsets.only(left: 42.getSize),
                  child: commentTile(controller, reply, reply: true),
                ),
          ],
        );
      },
    );
  }

  Widget commentTile(CustomerFeedController controller, FeedCommentModel comment, {required bool reply}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.getSize, 8.getSize, 8.getSize, 6.getSize),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfilePhoto(
            initials: profileInitials(comment.authorName),
            url: comment.authorAvatarUrl,
            size: reply ? 28 : 34,
            radius: (reply ? 14 : 17).getSize,
          ),
          10.widthSpacer,
          Expanded(
            child: GestureDetector(
              onLongPress: () => showActions(controller, comment),
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
                            border: Border.all(color: ServiceTokens.tileBorder),
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
                  3.heightSpacer,
                  BaseTextDMSans(
                    text: comment.body,
                    fontSize: 12,
                    color: ServiceTokens.text,
                    textAlign: TextAlign.start,
                    maxLines: 12,
                  ),
                  4.heightSpacer,
                  GestureDetector(
                    onTap: () => controller.startReply(comment),
                    child: BaseTextDMSans(
                      text: tr(StringRes.replyAction),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: ServiceTokens.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Like a comment: heart with its count underneath.
          GestureDetector(
            onTap: () => controller.toggleCommentLikeAPI(comment),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.getSize, vertical: 2.getSize),
              child: Column(
                children: [
                  Icon(
                    comment.liked ? Icons.favorite : Icons.favorite_border,
                    size: 15.getSize,
                    color: comment.liked ? ColorRes.errorColor : ServiceTokens.muted2,
                  ),
                  2.heightSpacer,
                  BaseTextDMSans(text: '${comment.likesCount}', fontSize: 9, color: ServiceTokens.muted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Long-press: delete your own, report someone else's.
  void showActions(CustomerFeedController controller, FeedCommentModel comment) {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.symmetric(vertical: 8.getSize),
        decoration: BoxDecoration(
          color: ServiceTokens.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18.getSize)),
        ),
        child: SafeArea(
          top: false,
          child: ListTile(
            leading: Icon(
              comment.isMine ? Icons.delete_outline : Icons.flag_outlined,
              color: comment.isMine ? ColorRes.errorColor : ServiceTokens.text,
            ),
            title: BaseTextDMSans(
              text: tr(comment.isMine ? StringRes.deleteAction : StringRes.reportCommentAction),
              fontSize: 13,
              color: comment.isMine ? ColorRes.errorColor : ServiceTokens.text,
              textAlign: TextAlign.start,
            ),
            onTap: () {
              Get.back();
              comment.isMine ? controller.deleteCommentAPI(comment) : controller.reportCommentAPI(comment);
            },
          ),
        ),
      ),
    );
  }

  Widget reactionsRow(CustomerFeedController controller) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.getSize, vertical: 6.getSize),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final emoji in _quickReactions)
            GestureDetector(
              onTap: () => controller.insertEmoji(emoji),
              child: Padding(
                padding: EdgeInsets.all(6.getSize),
                child: Text(emoji, style: TextStyle(fontSize: 22.getSize)),
              ),
            ),
        ],
      ),
    );
  }

  Widget replyingBanner(CustomerFeedController controller) {
    return Container(
      color: ServiceTokens.card2,
      padding: EdgeInsets.fromLTRB(16.getSize, 6.getSize, 8.getSize, 6.getSize),
      child: Row(
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
    );
  }

  Widget inputRow(CustomerFeedController controller) {
    final me = Injector.userData;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12.getSize, 6.getSize, 8.getSize, 10.getSize),
        child: Row(
          children: [
            ProfilePhoto(
              initials: profileInitials(me?.name),
              url: me?.avatarUrl,
              size: 34,
              radius: 17.getSize,
            ),
            10.widthSpacer,
            Expanded(
              child: Container(
                padding: EdgeInsets.only(left: 4.getSize, right: 4.getSize),
                decoration: BoxDecoration(
                  color: ServiceTokens.card2,
                  borderRadius: BorderRadius.circular(24.getSize),
                  border: Border.all(color: ServiceTokens.stroke),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller.commentController,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 500,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => controller.postCommentAPI(),
                        style: TextStyle(fontSize: 13.getFontSize, color: ServiceTokens.text, fontFamily: FontFamily.poppins),
                        decoration: InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12.getSize, vertical: 10.getSize),
                          hintText: tr(StringRes.addCommentForHint, args: [controller.commentsFor?.vendorName ?? '']),
                          hintStyle: TextStyle(
                            fontSize: 12.getFontSize,
                            color: ServiceTokens.muted2,
                            fontFamily: FontFamily.poppins,
                          ),
                        ),
                      ),
                    ),
                    controller.isPostingComment
                        ? Padding(
                            padding: EdgeInsets.all(10.getSize),
                            child: CupertinoActivityIndicator(color: ColorRes.primaryColor),
                          )
                        : TextButton(
                            onPressed: controller.postCommentAPI,
                            child: BaseTextDMSans(
                              text: tr(StringRes.postCommentAction),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: ServiceTokens.accent,
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
