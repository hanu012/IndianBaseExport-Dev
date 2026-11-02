import 'package:easy_localization/easy_localization.dart';
import 'package:uuid/uuid.dart';

import '../../../constants/app.export.dart';
import '../vendor_feed_comments_module/vendor_feed_comments_view.dart';
import '../vendor_promotions_module/vendor_promotions_controller.dart';

/// One promotion: its numbers, newest comments (with "Needs reply"), the
/// post and what was paid — and the actions: pause / resume (the clock stops
/// while paused), edit post, end early (no refund), extend (the same package
/// bought again, its days added once paid).
class VendorPromotionDetailController extends GetxController {
  VendorPromotionDetailController(this.promotionId);

  final int promotionId;

  PromotionModel? promotion;
  bool isLoading = false;

  // ── Replying to a comment ──
  final TextEditingController replyController = TextEditingController();
  bool isReplying = false;

  /// Kept for one extend attempt: a retried tap can never pay twice.
  String _extendKey = const Uuid().v4();

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

  Future<void> fetchAPI() async {
    isLoading = true;
    update();

    try {
      final response = await DataSource.instance.promotionDetailAPI(promotionId: promotionId);

      if (response == null || !response.isSuccess || response.data == null) {
        Utils.showToast(response?.message ?? tr(StringRes.somethingWentWrong), isError: true);
        return;
      }

      promotion = PromotionModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      if (kDebugMode) {
        print('Fetch promotion detail error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    } finally {
      isLoading = false;
      update();
    }
  }

  Future<void> togglePauseAPI() async {
    final current = promotion;

    if (current == null) {
      return;
    }

    await _action(
      () => current.isPaused
          ? DataSource.instance.resumePromotionAPI(promotionId: promotionId)
          : DataSource.instance.pausePromotionAPI(promotionId: promotionId),
      current.isPaused ? StringRes.promotionResumed : StringRes.promotionPaused,
    );
  }

  Future<void> endAPI() async {
    final confirmed = await Utils.confirmFn(
      title: tr(StringRes.endPromotionConfirmTitle),
      message: tr(StringRes.endPromotionConfirmDesc),
      confirmLabel: tr(StringRes.endPromotionAction),
      destructive: true,
    );

    if (confirmed) {
      await _action(() => DataSource.instance.endPromotionAPI(promotionId: promotionId), StringRes.promotionEnded);
    }
  }

  Future<void> extendAPI() async {
    final current = promotion;

    if (current == null) {
      return;
    }

    final confirmed = await Utils.confirmFn(
      title: tr(StringRes.extendPromotionConfirmTitle),
      message: tr(StringRes.extendPromotionConfirmDesc, args: [
        current.packageName ?? '',
        Utils.rupeesWhole(current.pricePaise),
        '${current.durationDays}',
      ]),
      confirmLabel: tr(StringRes.extendPromotionAction),
    );

    if (!confirmed) {
      return;
    }

    Utils.showCircularProgressLottie(true);

    try {
      final response = await DataSource.instance.extendPromotionAPI(promotionId: promotionId, idempotencyKey: _extendKey);
      Utils.showCircularProgressLottie(false);

      if (response == null || !response.isSuccess || response.data == null) {
        Utils.showToast(response?.message ?? tr(StringRes.somethingWentWrong), isError: true);
        return;
      }

      _extendKey = const Uuid().v4();
      final extended = PromotionModel.fromJson(response.data as Map<String, dynamic>);
      Utils.showToast(tr(extended.pendingExtensionDays != null
          ? StringRes.promotionExtensionAwaitingPayment
          : StringRes.promotionExtended));
      await _refreshAll();
    } catch (e) {
      Utils.showCircularProgressLottie(false);
      if (kDebugMode) {
        print('Extend promotion error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    }
  }

  Future<void> editPost() async {
    final current = promotion;

    if (current == null || !Get.isRegistered<VendorPromotionsController>()) {
      return;
    }

    if (await Get.find<VendorPromotionsController>().openEdit(current)) {
      await _refreshAll();
    }
  }

  Future<void> seeAllComments() async {
    await Get.to(() => const VendorFeedCommentsView());
    await fetchAPI();
  }

  Future<void> replyAPI(FeedCommentModel comment) async {
    final body = replyController.text.trim();

    if (body.isEmpty || isReplying) {
      return;
    }

    isReplying = true;
    update();

    try {
      final response = await DataSource.instance.vendorReplyFeedCommentAPI(commentId: comment.id, body: body);

      if (response == null || !response.isSuccess) {
        Utils.showToast(response?.fieldError('body') ?? response?.message ?? tr(StringRes.somethingWentWrong), isError: true);
        return;
      }

      replyController.clear();
      Get.back();
      Utils.showToast(tr(StringRes.replyPosted));
      await fetchAPI();
    } catch (e) {
      if (kDebugMode) {
        print('Reply to promotion comment error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    } finally {
      isReplying = false;
      update();
    }
  }

  Future<void> _action(Future<CommonResponse?> Function() call, String successKey) async {
    Utils.showCircularProgressLottie(true);

    try {
      final response = await call();
      Utils.showCircularProgressLottie(false);

      if (response == null || !response.isSuccess) {
        Utils.showToast(response?.message ?? tr(StringRes.somethingWentWrong), isError: true);
        return;
      }

      Utils.showToast(tr(successKey));
      await _refreshAll();
    } catch (e) {
      Utils.showCircularProgressLottie(false);
      if (kDebugMode) {
        print('Promotion action error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    }
  }

  /// This screen, and the list underneath so its card matches on the way back.
  Future<void> _refreshAll() async {
    await fetchAPI();

    if (Get.isRegistered<VendorPromotionsController>()) {
      Get.find<VendorPromotionsController>().fetchAPI();
    }
  }
}
