import 'package:easy_localization/easy_localization.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../constants/app.export.dart';
import '../customer_home_module/customer_home_controller.dart';
import '../vendor_detail_module/vendor_detail_controller.dart';
import '../vendor_detail_module/vendor_detail_view.dart';

/// The Feed tab (decided 2026-10-31): for the area the customer picked on
/// Home, paid promotions first, then vendors' portfolio photos and videos —
/// the server does the ordering. Likes, comments, Call / WhatsApp and the
/// vendor's profile from each post.
///
/// The location is Home's (CustomerHomeController), so the Feed always
/// follows the area in the header; Home asks it to reload on every change.
class CustomerFeedController extends GetxController {
  List<FeedItemModel> items = [];
  bool isLoading = false;
  bool isLoadingMore = false;
  int currentPage = 1;
  int lastPage = 1;

  /// No area chosen yet, or the chosen one matched no zone.
  bool hasNoLocation = false;

  /// The chip: for_you | offers | nearby | following.
  String filter = 'for_you';

  static const List<String> filters = ['for_you', 'offers', 'nearby', 'following'];

  bool get hasMore => currentPage < lastPage;

  // ── Comments sheet ──────────────────────────────────────────────────────
  FeedItemModel? commentsFor;
  List<FeedCommentModel> comments = [];
  bool isLoadingComments = false;
  bool isPostingComment = false;
  int commentsPage = 1;
  int commentsLastPage = 1;
  final TextEditingController commentController = TextEditingController();

  bool get hasMoreComments => commentsPage < commentsLastPage;

  @override
  void onInit() {
    super.onInit();
    fetchAPI();
  }

  @override
  void onClose() {
    commentController.dispose();
    super.onClose();
  }

  CustomerHomeController? get _home =>
      Get.isRegistered<CustomerHomeController>() ? Get.find<CustomerHomeController>() : null;

  Future<void> fetchAPI({bool loadMore = false}) async {
    final home = _home;
    final zoneId = home?.zone?.id;
    final latitude = home?.latitude;
    final longitude = home?.longitude;
    final pincode = home?.pincode;

    if (zoneId == null && (latitude == null || longitude == null) && (pincode ?? '').isEmpty) {
      hasNoLocation = true;
      items = [];
      update();
      return;
    }

    if (loadMore) {
      isLoadingMore = true;
    } else {
      isLoading = true;
    }
    update();

    try {
      // The point goes along with the zone: the zone decides the area,
      // the point orders "Nearby".
      final response = await DataSource.instance.feedAPI(
        zoneId: zoneId,
        latitude: latitude,
        longitude: longitude,
        pincode: zoneId == null && latitude == null ? pincode : null,
        page: loadMore ? currentPage + 1 : 1,
        filter: filter,
      );

      if (response == null || !response.isSuccess || response.data == null) {
        Utils.showToast(response?.message ?? tr(StringRes.somethingWentWrong), isError: true);
        return;
      }

      final data = response.data as Map<String, dynamic>;
      hasNoLocation = data['zone'] == null;

      final page = ((data['items'] as List<dynamic>?) ?? [])
          .map((e) => FeedItemModel.fromJson(e as Map<String, dynamic>))
          .toList();

      items = loadMore ? [...items, ...page] : page;

      final meta = response.meta;
      currentPage = meta?['current_page'] as int? ?? 1;
      lastPage = meta?['last_page'] as int? ?? 1;
    } catch (e) {
      if (kDebugMode) {
        print('Fetch feed error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    } finally {
      isLoading = false;
      isLoadingMore = false;
      update();
    }
  }

  void setFilter(String value) {
    if (value == filter) {
      return;
    }

    filter = value;
    items = [];
    update();
    fetchAPI();
  }

  Future<void> shareItem(FeedItemModel item) async {
    final text = [
      item.vendorName ?? '',
      if ((item.caption ?? '').isNotEmpty) item.caption!,
      if ((item.serviceName ?? '').isNotEmpty) item.serviceName!,
      if ((item.vendorPhone ?? '').isNotEmpty) item.vendorPhone!,
    ].join('\n');

    try {
      await Share.share(text);
    } catch (e) {
      if (kDebugMode) {
        print('Share feed post error $e');
      }
    }
  }

  /// Optimistic: the heart flips at once and settles on the server's count.
  Future<void> toggleLikeAPI(FeedItemModel item) async {
    final wasLiked = item.liked;
    item.liked = !wasLiked;
    item.likesCount += wasLiked ? -1 : 1;
    update();

    try {
      final response = await DataSource.instance.toggleFeedLikeAPI(type: item.type, id: item.id);

      if (response == null || !response.isSuccess || response.data == null) {
        _undoLike(item, wasLiked);
        Utils.showToast(response?.message ?? tr(StringRes.somethingWentWrong), isError: true);
        return;
      }

      final data = response.data as Map<String, dynamic>;
      item.liked = data['liked'] == true;
      item.likesCount = data['likes_count'] as int? ?? item.likesCount;
    } catch (e) {
      _undoLike(item, wasLiked);
      if (kDebugMode) {
        print('Toggle feed like error $e');
      }
    } finally {
      update();
    }
  }

  void _undoLike(FeedItemModel item, bool wasLiked) {
    item.liked = wasLiked;
    item.likesCount += wasLiked ? 1 : -1;
  }

  // ── Comments ────────────────────────────────────────────────────────────

  /// The comment being answered; null writes a new top-level comment.
  FeedCommentModel? replyTo;

  Future<void> openComments(FeedItemModel item) async {
    commentsFor = item;
    comments = [];
    replyTo = null;
    commentController.clear();
    await fetchCommentsAPI();
  }

  /// "Reply": answers this comment's thread, starting with "@Name ".
  void startReply(FeedCommentModel comment) {
    replyTo = comment;
    commentController.text = '@${comment.authorName} ';
    commentController.selection = TextSelection.collapsed(offset: commentController.text.length);
    update();
  }

  void cancelReply() {
    replyTo = null;
    commentController.clear();
    update();
  }

  void toggleReplies(FeedCommentModel comment) {
    comment.showReplies = !comment.showReplies;
    update();
  }

  /// The quick-reaction row adds the emoji where the cursor is.
  void insertEmoji(String emoji) {
    final text = commentController.text;
    final selection = commentController.selection;
    final at = selection.isValid ? selection.start : text.length;

    commentController.text = text.replaceRange(at, selection.isValid ? selection.end : text.length, emoji);
    commentController.selection = TextSelection.collapsed(offset: at + emoji.length);
    update();
  }

  Future<void> toggleCommentLikeAPI(FeedCommentModel comment) async {
    final wasLiked = comment.liked;
    comment.liked = !wasLiked;
    comment.likesCount += wasLiked ? -1 : 1;
    update();

    final response = await DataSource.instance.likeFeedCommentAPI(commentId: comment.id);

    if (response == null || !response.isSuccess || response.data == null) {
      comment.liked = wasLiked;
      comment.likesCount += wasLiked ? 1 : -1;
    } else {
      final data = response.data as Map<String, dynamic>;
      comment.liked = data['liked'] == true;
      comment.likesCount = data['likes_count'] as int? ?? comment.likesCount;
    }

    update();
  }

  Future<void> fetchCommentsAPI({bool loadMore = false}) async {
    final item = commentsFor;

    if (item == null) {
      return;
    }

    isLoadingComments = true;
    update();

    try {
      final response = await DataSource.instance.feedCommentsAPI(
        type: item.type,
        id: item.id,
        page: loadMore ? commentsPage + 1 : 1,
      );

      if (response == null || !response.isSuccess || response.data == null) {
        Utils.showToast(response?.message ?? tr(StringRes.postUnavailable), isError: true);
        return;
      }

      final page = (response.data as List<dynamic>)
          .map((e) => FeedCommentModel.fromJson(e as Map<String, dynamic>))
          .toList();

      comments = loadMore ? [...comments, ...page] : page;
      commentsPage = response.meta?['current_page'] as int? ?? 1;
      commentsLastPage = response.meta?['last_page'] as int? ?? 1;
    } catch (e) {
      if (kDebugMode) {
        print('Fetch feed comments error $e');
      }
    } finally {
      isLoadingComments = false;
      update();
    }
  }

  Future<void> postCommentAPI() async {
    final item = commentsFor;
    final body = commentController.text.trim();

    if (item == null || body.isEmpty || isPostingComment) {
      return;
    }

    isPostingComment = true;
    update();

    try {
      final parent = replyTo;
      final response = await DataSource.instance.addFeedCommentAPI(
        type: item.type,
        id: item.id,
        body: body,
        parentId: parent?.id,
      );

      if (response == null || !response.isSuccess || response.data == null) {
        Utils.showToast(response?.fieldError('body') ?? response?.message ?? tr(StringRes.somethingWentWrong), isError: true);
        return;
      }

      final created = FeedCommentModel.fromJson(response.data as Map<String, dynamic>);

      if (created.parentId == null) {
        comments = [created, ...comments];
      } else {
        // Under its thread, at the end — replies read oldest first.
        final thread = comments.where((c) => c.id == created.parentId).firstOrNull;
        thread?.replies.add(created);
        thread?.showReplies = true;
      }

      item.commentsCount += 1;
      replyTo = null;
      commentController.clear();
    } catch (e) {
      if (kDebugMode) {
        print('Post feed comment error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    } finally {
      isPostingComment = false;
      update();
    }
  }

  Future<void> deleteCommentAPI(FeedCommentModel comment) async {
    final response = await DataSource.instance.deleteFeedCommentAPI(commentId: comment.id);

    if (response == null || !response.isSuccess) {
      Utils.showToast(response?.message ?? tr(StringRes.somethingWentWrong), isError: true);
      return;
    }

    if (!comments.remove(comment)) {
      for (final thread in comments) {
        thread.replies.remove(comment);
      }
    }
    final item = commentsFor;
    if (item != null && item.commentsCount > 0) {
      item.commentsCount -= 1;
    }
    Utils.showToast(tr(StringRes.commentDeleted));
    update();
  }

  Future<void> reportCommentAPI(FeedCommentModel comment) async {
    final response = await DataSource.instance.reportFeedCommentAPI(commentId: comment.id);

    if (response == null || !response.isSuccess) {
      Utils.showToast(response?.message ?? tr(StringRes.somethingWentWrong), isError: true);
      return;
    }

    Utils.showToast(tr(StringRes.commentReported));
  }

  // ── Contact and profile ─────────────────────────────────────────────────

  /// Records the contact first (it is the vendor's lead, and for a paid
  /// promotion its "calls from this ad"), then opens the dialer — the same
  /// order as the vendor's own page.
  Future<void> callAPI(FeedItemModel item) async {
    final phone = item.vendorPhone;

    if (phone == null || phone.isEmpty || !await _recordLead(item, 'call')) {
      return;
    }

    await launchUrl(Uri(scheme: 'tel', path: phone));
  }

  Future<void> whatsappAPI(FeedItemModel item) async {
    final phone = item.vendorPhone;

    if (phone == null || phone.isEmpty || !await _recordLead(item, 'whatsapp')) {
      return;
    }

    await launchUrl(
      Uri.parse('https://wa.me/${VendorDetailController.whatsappNumber(phone)}'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<bool> _recordLead(FeedItemModel item, String channel) async {
    final vendorId = item.vendorId;

    if (vendorId == null) {
      return false;
    }

    final response = await DataSource.instance.createLeadAPI(
      vendorId: vendorId,
      zoneId: _home?.zone?.id,
      channel: channel,
      promotionId: item.isPromotion ? item.id : null,
    );

    if (response == null || !response.isSuccess) {
      Utils.showToast(tr(StringRes.leadFailedTryAgain), isError: true);
      return false;
    }

    return true;
  }

  void openVendor(FeedItemModel item) {
    final vendorId = item.vendorId;

    if (vendorId == null) {
      return;
    }

    // No subcategory: a Feed post is not tied to one service; the vendor's
    // page falls back to their first one for a contact.
    Get.to(() => VendorDetailView(
          vendorId: vendorId,
          subcategoryId: null,
          zoneId: _home?.zone?.id,
          latitude: _home?.latitude,
          longitude: _home?.longitude,
        ));
  }


  void openMedia(FeedItemModel item) {
    final url = item.mediaUrl;

    if (url == null) {
      return;
    }

    showPortfolioViewer([
      PortfolioViewerItem(type: item.mediaType, url: url, caption: item.caption ?? item.serviceName),
    ]);
  }
}
