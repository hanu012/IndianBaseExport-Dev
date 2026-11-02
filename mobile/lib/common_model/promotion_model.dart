import 'feed_model.dart';

/// A paid-promotion package the vendor can buy.
class PromotionPackageModel {
  final int id;
  final String name;
  final String? description;
  final int durationDays;
  final int pricePaise;
  final bool allowsVideo;

  /// Admin-ticked "Most popular" tag.
  final bool isPopular;

  PromotionPackageModel({
    required this.id,
    required this.name,
    this.description,
    required this.durationDays,
    required this.pricePaise,
    required this.allowsVideo,
    this.isPopular = false,
  });

  factory PromotionPackageModel.fromJson(Map<String, dynamic> json) {
    return PromotionPackageModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      durationDays: json['duration_days'] as int? ?? 0,
      pricePaise: json['price_paise'] as int? ?? 0,
      allowsVideo: json['allows_video'] == true,
      isPopular: json['is_popular'] == true,
    );
  }
}

/// An area id and name — the vendor's own zones they can promote in.
class PromotionZoneModel {
  final int id;
  final String name;

  PromotionZoneModel({required this.id, required this.name});

  factory PromotionZoneModel.fromJson(Map<String, dynamic> json) =>
      PromotionZoneModel(id: json['id'] as int? ?? 0, name: json['name'] as String? ?? '');
}

/// One of the vendor's own promotions, with its numbers. The details-only
/// fields (amount paid, comments) are empty on the list.
class PromotionModel {
  final int id;
  final String? packageName;
  final bool allowsVideo;
  final String caption;

  /// image | video, or null for a text-only post.
  final String? mediaType;
  final String? mediaUrl;
  final int pricePaise;
  final int durationDays;

  /// live | pending_payment | ended | cancelled | hidden
  final String status;
  final bool isShowing;
  final bool isPaused;
  final String? hiddenReason;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? pausedAt;
  final List<PromotionZoneModel> zones;
  final int views;
  final int likes;
  final int comments;
  final int calls;

  // ── Details screen ──
  final int amountPaidPaise;
  final int unansweredComments;
  final List<FeedCommentModel> recentComments;

  /// While waiting for payment: when the SMS payment link stops working.
  final DateTime? paymentLinkExpiresAt;

  /// Days and price of an extension waiting for its payment link, if any.
  final int? pendingExtensionDays;

  PromotionModel({
    required this.id,
    this.packageName,
    this.allowsVideo = false,
    required this.caption,
    this.mediaType,
    this.mediaUrl,
    required this.pricePaise,
    required this.durationDays,
    required this.status,
    required this.isShowing,
    this.isPaused = false,
    this.hiddenReason,
    this.startsAt,
    this.endsAt,
    this.pausedAt,
    required this.zones,
    this.views = 0,
    this.likes = 0,
    this.comments = 0,
    this.calls = 0,
    this.amountPaidPaise = 0,
    this.unansweredComments = 0,
    List<FeedCommentModel>? recentComments,
    this.pendingExtensionDays,
    this.paymentLinkExpiresAt,
  }) : recentComments = recentComments ?? [];

  bool get isVideo => mediaType == 'video';

  bool get hasMedia => mediaUrl != null && mediaType != null;

  bool get isPendingPayment => status == 'pending_payment';

  /// Live or hidden — the clock is running (or paused) and it can be acted on.
  bool get isRunning => status == 'live' || status == 'hidden';

  bool get isOver => status == 'ended' || status == 'cancelled';

  String get areaNames => zones.map((zone) => zone.name).join(', ');

  /// How much of its time has passed, 0..1 — paused time does not count.
  double get timeRatio {
    final start = startsAt;
    final end = endsAt;

    if (isOver) return 1;
    if (start == null || end == null || !end.isAfter(start)) return 0;

    final now = isPaused && pausedAt != null ? pausedAt! : DateTime.now();

    return (now.difference(start).inSeconds / end.difference(start).inSeconds).clamp(0.0, 1.0);
  }

  factory PromotionModel.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>? ?? {};
    final extension = json['pending_extension'] as Map<String, dynamic>?;

    return PromotionModel(
      id: json['id'] as int? ?? 0,
      packageName: json['package_name'] as String?,
      allowsVideo: json['allows_video'] == true,
      caption: json['caption'] as String? ?? '',
      mediaType: json['media_type'] as String?,
      mediaUrl: json['media_url'] as String?,
      pricePaise: json['price_paise'] as int? ?? 0,
      durationDays: json['duration_days'] as int? ?? 0,
      status: json['status'] as String? ?? 'ended',
      isShowing: json['is_showing'] == true,
      isPaused: json['is_paused'] == true,
      hiddenReason: json['hidden_reason'] as String?,
      startsAt: DateTime.tryParse(json['starts_at'] as String? ?? '')?.toLocal(),
      endsAt: DateTime.tryParse(json['ends_at'] as String? ?? '')?.toLocal(),
      pausedAt: DateTime.tryParse(json['paused_at'] as String? ?? '')?.toLocal(),
      zones: ((json['zones'] as List<dynamic>?) ?? [])
          .map((e) => PromotionZoneModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      views: stats['views'] as int? ?? 0,
      likes: stats['likes'] as int? ?? 0,
      comments: stats['comments'] as int? ?? 0,
      calls: stats['calls'] as int? ?? 0,
      amountPaidPaise: json['amount_paid_paise'] as int? ?? 0,
      unansweredComments: json['unanswered_comments'] as int? ?? 0,
      recentComments: ((json['recent_comments'] as List<dynamic>?) ?? [])
          .map((e) => FeedCommentModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      pendingExtensionDays: extension?['days'] as int?,
      paymentLinkExpiresAt: DateTime.tryParse((json['payment'] as Map<String, dynamic>?)?['link_expires_at'] as String? ?? '')?.toLocal(),
    );
  }
}
