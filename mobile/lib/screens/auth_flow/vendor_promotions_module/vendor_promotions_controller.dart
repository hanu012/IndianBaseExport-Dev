import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../constants/app.export.dart';
import '../vendor_create_promotion_module/vendor_create_promotion_view.dart';
import '../vendor_promotion_detail_module/vendor_promotion_detail_view.dart';
import '../vendor_promotion_payment_module/vendor_promotion_payment_view.dart';

/// Paid promotions (decided 2026-10-31): the vendor's Live / Ended lists with
/// their numbers, buying a new one — package, optional photo or video,
/// caption, areas — and editing a running one's post.
///
/// TWO SCREENS, ONE CONTROLLER: the list (VendorPromotionsView) registers
/// it; the form (VendorCreatePromotionView) binds to the same one, so a
/// promotion bought or edited there is in the list on the way back. The
/// details screen has its own controller and calls back into this one.
///
/// Paid like a subscription: with online payment links off it goes live at
/// once; on, the vendor gets an SMS link and it goes live once paid. The app
/// never takes the payment itself.
class VendorPromotionsController extends GetxController {
  static const String tabLive = 'live';
  static const String tabEnded = 'ended';

  String tab = tabLive;
  int liveCount = 0;
  int endedCount = 0;

  List<PromotionModel> promotions = [];
  bool isLoading = false;
  bool isLoadingMore = false;
  int currentPage = 1;
  int lastPage = 1;

  bool get hasMore => currentPage < lastPage;

  // ── Form (buy or edit) ──────────────────────────────────────────────────
  List<PromotionPackageModel> packages = [];
  List<PromotionZoneModel> zones = [];
  bool isLoadingOptions = false;

  /// Set while the form edits this promotion's post instead of buying one.
  PromotionModel? editing;

  bool get isEditing => editing != null;

  PromotionPackageModel? selectedPackage;

  /// The picked file's path — on Flutter Web a blob: URL, which the preview
  /// shows with Image.network and the upload reads as bytes ([_pickedFile]).
  String? mediaPath;
  XFile? _pickedFile;
  String mediaType = 'image';

  /// Editing: the post's current photo/video, until replaced or removed.
  String? existingMediaUrl;
  String? existingMediaType;
  bool removeMedia = false;

  final Set<int> selectedZoneIds = {};
  final TextEditingController captionController = TextEditingController();
  final TextEditingController areaSearchController = TextEditingController();
  bool areasOpen = false;
  bool isSubmitting = false;
  double uploadProgress = 0;

  static const int captionMax = 300;

  /// Kept for one purchase attempt: a retried tap can never pay twice.
  String _idempotencyKey = const Uuid().v4();

  final ImagePicker _picker = ImagePicker();

  @override
  void onInit() {
    super.onInit();
    fetchAPI();
  }

  @override
  void onClose() {
    captionController.dispose();
    areaSearchController.dispose();
    super.onClose();
  }

  void selectTab(String value) {
    if (tab == value) {
      return;
    }

    tab = value;
    promotions = [];
    fetchAPI();
  }

  Future<void> fetchAPI({bool loadMore = false}) async {
    if (loadMore) {
      isLoadingMore = true;
    } else {
      isLoading = true;
    }
    update();

    try {
      final response = await DataSource.instance.myPromotionsAPI(tab: tab, page: loadMore ? currentPage + 1 : 1);

      if (response == null || !response.isSuccess || response.data == null) {
        Utils.showToast(response?.message ?? tr(StringRes.somethingWentWrong), isError: true);
        return;
      }

      final page = (response.data as List<dynamic>)
          .map((e) => PromotionModel.fromJson(e as Map<String, dynamic>))
          .toList();

      promotions = loadMore ? [...promotions, ...page] : page;
      currentPage = response.meta?['current_page'] as int? ?? 1;
      lastPage = response.meta?['last_page'] as int? ?? 1;

      final counts = response.meta?['counts'] as Map<String, dynamic>?;
      liveCount = counts?[tabLive] as int? ?? liveCount;
      endedCount = counts?[tabEnded] as int? ?? endedCount;
    } catch (e) {
      if (kDebugMode) {
        print('Fetch promotions error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    } finally {
      isLoading = false;
      isLoadingMore = false;
      update();
    }
  }

  /// A promotion still waiting for payment opens "Waiting for payment";
  /// any other its details.
  Future<void> openDetail(PromotionModel promotion) async {
    if (promotion.isPendingPayment) {
      await Get.to(() => VendorPromotionPaymentView(promotion: promotion));
    } else {
      await Get.to(() => VendorPromotionDetailView(promotionId: promotion.id));
    }

    await fetchAPI();
  }

  Future<void> cancelPromotionAPI(PromotionModel promotion) async {
    Utils.showCircularProgressLottie(true);

    try {
      final response = await DataSource.instance.cancelPromotionAPI(promotionId: promotion.id);
      Utils.showCircularProgressLottie(false);

      if (response == null || !response.isSuccess) {
        Utils.showToast(response?.message ?? tr(StringRes.somethingWentWrong), isError: true);
        return;
      }

      Utils.showToast(tr(StringRes.promotionCancelled));
      await fetchAPI();
    } catch (e) {
      Utils.showCircularProgressLottie(false);
      if (kDebugMode) {
        print('Cancel promotion error $e');
      }
    }
  }

  // ── The form ────────────────────────────────────────────────────────────

  void _resetForm() {
    selectedPackage = null;
    mediaPath = null;
    _pickedFile = null;
    mediaType = 'image';
    existingMediaUrl = null;
    existingMediaType = null;
    removeMedia = false;
    selectedZoneIds.clear();
    captionController.clear();
    areaSearchController.clear();
    areasOpen = false;
    uploadProgress = 0;
    _idempotencyKey = const Uuid().v4();
  }

  /// Opens the buy screen with a clean form and fresh options.
  void openCreate() {
    _resetForm();
    editing = null;
    fetchOptionsAPI();
    Get.to(() => const VendorCreatePromotionView());
  }

  /// "Edit post" from the details screen: caption and photo/video only.
  /// Completes when the form closes — true when the post was saved.
  Future<bool> openEdit(PromotionModel promotion) async {
    _resetForm();
    editing = promotion;
    captionController.text = promotion.caption;
    existingMediaUrl = promotion.hasMedia ? promotion.mediaUrl : null;
    existingMediaType = promotion.hasMedia ? promotion.mediaType : null;
    update();

    final saved = await Get.to<bool>(() => const VendorCreatePromotionView());
    editing = null;

    return saved == true;
  }

  Future<void> fetchOptionsAPI() async {
    isLoadingOptions = true;
    update();

    try {
      final response = await DataSource.instance.promotionOptionsAPI();

      if (response == null || !response.isSuccess || response.data == null) {
        Utils.showToast(response?.message ?? tr(StringRes.somethingWentWrong), isError: true);
        return;
      }

      final data = response.data as Map<String, dynamic>;
      packages = ((data['packages'] as List<dynamic>?) ?? [])
          .map((e) => PromotionPackageModel.fromJson(e as Map<String, dynamic>))
          .toList();
      zones = ((data['zones'] as List<dynamic>?) ?? [])
          .map((e) => PromotionZoneModel.fromJson(e as Map<String, dynamic>))
          .toList();
      selectedPackage ??= packages.isEmpty ? null : packages.first;
    } catch (e) {
      if (kDebugMode) {
        print('Fetch promotion options error $e');
      }
    } finally {
      isLoadingOptions = false;
      update();
    }
  }

  /// Video is allowed by the package being bought, or the one being edited.
  bool get allowsVideo => editing?.allowsVideo ?? selectedPackage?.allowsVideo ?? true;

  void selectPackage(PromotionPackageModel package) {
    selectedPackage = package;

    // A photo-only package cannot take the video already chosen.
    if (!package.allowsVideo && mediaType == 'video') {
      mediaPath = null;
      _pickedFile = null;
      mediaType = 'image';
    }

    _idempotencyKey = const Uuid().v4();
    update();
  }

  // ── Areas dropdown ──────────────────────────────────────────────────────

  void toggleAreas() {
    areasOpen = !areasOpen;

    if (!areasOpen) {
      areaSearchController.clear();
    }

    update();
  }

  List<PromotionZoneModel> get filteredZones {
    final term = areaSearchController.text.trim().toLowerCase();

    return term.isEmpty ? zones : zones.where((zone) => zone.name.toLowerCase().contains(term)).toList();
  }

  List<PromotionZoneModel> get selectedZones => zones.where((zone) => selectedZoneIds.contains(zone.id)).toList();

  /// Any of the vendor's own areas — packages have no area limit.
  void toggleZone(PromotionZoneModel zone) {
    if (!selectedZoneIds.remove(zone.id)) {
      selectedZoneIds.add(zone.id);
    }

    _idempotencyKey = const Uuid().v4();
    update();
  }

  // ── Photo / video ───────────────────────────────────────────────────────

  bool get hasAnyMedia => mediaPath != null || (existingMediaUrl != null && !removeMedia);

  Future<void> pickPhoto() async {
    XFile? picked;

    try {
      picked = await _picker.pickImage(source: ImageSource.gallery);
    } catch (e) {
      if (kDebugMode) {
        print('Pick promotion photo error $e');
      }
    }

    if (picked == null) {
      return;
    }

    _pickedFile = picked;
    // Compression has no web implementation; the browser upload goes as is.
    mediaPath = kIsWeb ? picked.path : await _compress(picked.path) ?? picked.path;
    mediaType = 'image';
    _idempotencyKey = const Uuid().v4();
    update();
  }

  Future<void> pickVideo() async {
    XFile? picked;

    try {
      picked = await _picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 60));
    } catch (e) {
      if (kDebugMode) {
        print('Pick promotion video error $e');
      }
    }

    if (picked == null) {
      return;
    }

    _pickedFile = picked;
    mediaPath = picked.path;
    mediaType = 'video';
    _idempotencyKey = const Uuid().v4();
    update();
  }

  /// Back to a text-only post.
  void clearMedia() {
    mediaPath = null;
    _pickedFile = null;
    mediaType = 'image';

    if (existingMediaUrl != null) {
      removeMedia = true;
    }

    _idempotencyKey = const Uuid().v4();
    update();
  }

  // ── Submit ──────────────────────────────────────────────────────────────

  bool get captionDone => captionController.text.trim().isNotEmpty;

  bool get canSubmit {
    if (isSubmitting || !captionDone) {
      return false;
    }

    return isEditing || (selectedPackage != null && selectedZoneIds.isNotEmpty);
  }

  Future<void> submitAPI() => isEditing ? _updatePostAPI() : _createPromotionAPI();

  Future<void> _createPromotionAPI() async {
    final package = selectedPackage;

    if (package == null || !captionDone || selectedZoneIds.isEmpty) {
      Utils.showToast(tr(StringRes.promotionIncomplete), isError: true);
      return;
    }

    isSubmitting = true;
    uploadProgress = 0;
    update();

    try {
      final picked = _pickedFile;
      final path = mediaPath;

      final response = await DataSource.instance.createPromotionAPI(
        packageId: package.id,
        mediaType: path == null ? null : mediaType,
        filePath: kIsWeb ? null : path,
        // Flutter Web has no file path to read — send the bytes instead.
        fileBytes: kIsWeb && picked != null && path != null ? await picked.readAsBytes() : null,
        fileName: picked?.name,
        caption: captionController.text.trim(),
        zoneIds: selectedZoneIds.toList(),
        idempotencyKey: _idempotencyKey,
        onSendProgress: _progress,
      );

      if (response == null || !response.isSuccess || response.data == null) {
        Utils.showToast(_errorOf(response), isError: true);
        return;
      }

      final promotion = PromotionModel.fromJson(response.data as Map<String, dynamic>);

      tab = tabLive;

      if (promotion.isPendingPayment) {
        // Razorpay on: paid like a subscription — the link went by SMS, and
        // "Waiting for payment" replaces this form until it is paid; from
        // there it returns to the list.
        Get.off(() => VendorPromotionPaymentView(promotion: promotion));
      } else {
        Utils.showToast(tr(StringRes.promotionLive));
        // Back to the list, which is mounted underneath (CLAUDE.md: never
        // offAll to a screen still in the stack).
        Get.back();
      }

      await fetchAPI();
    } catch (e) {
      if (kDebugMode) {
        print('Create promotion error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    } finally {
      isSubmitting = false;
      update();
    }
  }

  Future<void> _updatePostAPI() async {
    final promotion = editing;

    if (promotion == null || !captionDone) {
      return;
    }

    isSubmitting = true;
    uploadProgress = 0;
    update();

    try {
      final picked = _pickedFile;
      final path = mediaPath;

      final response = await DataSource.instance.updatePromotionPostAPI(
        promotionId: promotion.id,
        caption: captionController.text.trim(),
        mediaType: path == null ? null : mediaType,
        filePath: kIsWeb ? null : path,
        fileBytes: kIsWeb && picked != null && path != null ? await picked.readAsBytes() : null,
        fileName: picked?.name,
        removeMedia: removeMedia && path == null,
        onSendProgress: _progress,
      );

      if (response == null || !response.isSuccess) {
        Utils.showToast(_errorOf(response), isError: true);
        return;
      }

      Utils.showToast(tr(StringRes.postUpdated));
      // Back to the details screen underneath, which re-reads the post.
      Get.back(result: true);
    } catch (e) {
      if (kDebugMode) {
        print('Update promotion post error $e');
      }
      Utils.showToast(tr(StringRes.somethingWentWrong), isError: true);
    } finally {
      isSubmitting = false;
      update();
    }
  }

  void _progress(int sent, int total) {
    if (total > 0) {
      uploadProgress = sent / total;
      update();
    }
  }

  String _errorOf(CommonResponse? response) {
    return response?.fieldError('zone_ids') ??
        response?.fieldError('file') ??
        response?.fieldError('caption') ??
        response?.fieldError('promotion_package_id') ??
        response?.message ??
        tr(StringRes.somethingWentWrong);
  }

  Future<String?> _compress(String sourcePath) async {
    try {
      final result = await FlutterImageCompress.compressAndGetFile(
        sourcePath,
        '${sourcePath}_promo.jpg',
        quality: 82,
        minWidth: 1280,
        minHeight: 1280,
      );

      return result?.path;
    } catch (e) {
      if (kDebugMode) {
        print('Compress promotion photo error $e');
      }
      return null;
    }
  }
}
