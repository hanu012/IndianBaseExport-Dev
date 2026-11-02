import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';

/// Profile → Customer comments: what customers wrote on this vendor's Feed
/// posts (promotions and portfolio), newest first, and replying as the
/// business — the reply shows in the customer app with a "Business" tag.
class VendorFeedCommentsController extends GetxController {
  List<FeedCommentModel> comments = [];
  bool isLoading = false;
  bool isLoadingMore = false;
  int currentPage = 1;
  int lastPage = 1;

  bool get hasMore => currentPage < lastPage;

  /// The comment being answered; the reply box shows while it is set.
  FeedCommentModel? replyTo;
  bool isPosting = false;
  final TextEditingController replyController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    fetchAPI();
  }

  @override
  void onClose() {
    replyController.dispose();
    super.onClose();
  }

  Future<void> fetchAPI({bool loadMore = false}) async {
    if (loadMore) {
      isLoadingMore = true;
    } else {
      isLoading = true;
    }
    update();

    try {
      final response = await DataSource.instance.vendorFeedCommentsAPI(page: loadMore ? currentPage + 1 : 1);

      if (response == null || !response.isSuccess || response.data == null) {
        Utils.showToast(response?.message ?? tr(StringRes.somethingWentWrong), isError: true);
        return;
      }

      final page = (response.data as List<dynamic>)
          .map((e) => FeedCommentModel.fromJson(e as Map<String, dynamic>))
          .toList();

      comments = loadMore ? [...comments, ...page] : page;
      currentPage = response.meta?['current_page'] as int? ?? 1;
      lastPage = response.meta?['last_page'] as int? ?? 1;
    } catch (e) {
      if (kDebugMode) {
        print('Fetch vendor feed comments error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    } finally {
      isLoading = false;
      isLoadingMore = false;
      update();
    }
  }

  void startReply(FeedCommentModel comment) {
    replyTo = comment;
    replyController.text = '@${comment.authorName} ';
    replyController.selection = TextSelection.collapsed(offset: replyController.text.length);
    update();
  }

  void cancelReply() {
    replyTo = null;
    replyController.clear();
    update();
  }

  Future<void> replyAPI() async {
    final target = replyTo;
    final body = replyController.text.trim();

    if (target == null || body.isEmpty || isPosting) {
      return;
    }

    isPosting = true;
    update();

    try {
      final response = await DataSource.instance.vendorReplyFeedCommentAPI(commentId: target.id, body: body);

      if (response == null || !response.isSuccess || response.data == null) {
        Utils.showToast(response?.fieldError('body') ?? response?.message ?? tr(StringRes.somethingWentWrong), isError: true);
        return;
      }

      final reply = FeedCommentModel.fromJson(response.data as Map<String, dynamic>);
      final thread = comments.where((c) => c.id == reply.parentId).firstOrNull;
      thread?.replies.add(reply);

      replyTo = null;
      replyController.clear();
      Utils.showToast(tr(StringRes.replyPosted));
    } catch (e) {
      if (kDebugMode) {
        print('Vendor reply error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    } finally {
      isPosting = false;
      update();
    }
  }
}
