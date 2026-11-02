/// One post in the customer Feed (`GET /api/feed`): a paid promotion
/// ([isSponsored]) or a vendor's portfolio photo/video.
class FeedItemModel {
  /// 'promotion' | 'post' — how the post is addressed for likes and comments.
  final String type;
  final int id;
  final bool isSponsored;
  final int? vendorId;
  final String? vendorName;
  final String? vendorPhotoUrl;
  final String? vendorPhone;

  /// Approved by the admin with every required KYC document verified — the
  /// tick next to the name.
  final bool vendorVerified;

  /// The vendor's own words — promotions only.
  final String? caption;

  /// The service a portfolio post shows ("AC Repair") — posts only.
  final String? serviceName;
  final String mediaType;
  final String? mediaUrl;
  int likesCount;
  int commentsCount;
  bool liked;
  final DateTime? createdAt;

  FeedItemModel({
    required this.type,
    required this.id,
    required this.isSponsored,
    this.vendorId,
    this.vendorName,
    this.vendorPhotoUrl,
    this.vendorPhone,
    this.vendorVerified = false,
    this.caption,
    this.serviceName,
    this.mediaType = 'image',
    this.mediaUrl,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.liked = false,
    this.createdAt,
  });

  bool get isVideo => mediaType == 'video';

  bool get isPromotion => type == 'promotion';

  factory FeedItemModel.fromJson(Map<String, dynamic> json) {
    final vendor = json['vendor'] as Map<String, dynamic>? ?? {};

    return FeedItemModel(
      type: json['type'] as String? ?? 'post',
      id: json['id'] as int? ?? 0,
      isSponsored: json['sponsored'] == true,
      vendorId: vendor['id'] as int?,
      vendorName: vendor['business_name'] as String?,
      vendorPhotoUrl: vendor['shop_photo_url'] as String?,
      vendorPhone: vendor['phone'] as String?,
      vendorVerified: vendor['verified'] == true,
      caption: json['caption'] as String?,
      serviceName: json['service_name'] as String?,
      mediaType: json['media_type'] as String? ?? 'image',
      mediaUrl: json['media_url'] as String?,
      likesCount: json['likes_count'] as int? ?? 0,
      commentsCount: json['comments_count'] as int? ?? 0,
      liked: json['liked'] == true,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal(),
    );
  }
}

/// A comment on a Feed post — by a customer, or by the vendor who owns the
/// post replying as the business ([isBusiness]). Top-level comments carry
/// their [replies] (one level deep).
class FeedCommentModel {
  final int id;
  final int? parentId;
  final String body;
  final String authorName;
  final String? authorAvatarUrl;
  final bool isBusiness;
  final bool isMine;
  int likesCount;
  bool liked;
  final DateTime? createdAt;
  final List<FeedCommentModel> replies;

  /// On the vendor's own comments screen: the post it was left on.
  final FeedCommentPostModel? post;

  /// On a promotion's details screen: the business has not answered it yet.
  final bool needsReply;

  /// Replies are folded until "View replies" is tapped.
  bool showReplies;

  FeedCommentModel({
    required this.id,
    this.parentId,
    required this.body,
    required this.authorName,
    this.authorAvatarUrl,
    this.isBusiness = false,
    this.isMine = false,
    this.likesCount = 0,
    this.liked = false,
    this.createdAt,
    List<FeedCommentModel>? replies,
    this.post,
    this.needsReply = false,
    this.showReplies = true,
  }) : replies = replies ?? [];

  factory FeedCommentModel.fromJson(Map<String, dynamic> json) {
    return FeedCommentModel(
      id: json['id'] as int? ?? 0,
      parentId: json['parent_id'] as int?,
      body: json['body'] as String? ?? '',
      authorName: json['author_name'] as String? ?? '',
      authorAvatarUrl: json['author_avatar_url'] as String?,
      isBusiness: json['is_business'] == true,
      isMine: json['is_mine'] == true,
      likesCount: json['likes_count'] as int? ?? 0,
      liked: json['liked'] == true,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal(),
      replies: ((json['replies'] as List<dynamic>?) ?? [])
          .map((e) => FeedCommentModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      post: json['post'] is Map<String, dynamic>
          ? FeedCommentPostModel.fromJson(json['post'] as Map<String, dynamic>)
          : null,
      needsReply: json['needs_reply'] == true,
    );
  }

  /// "2h", "3d", "now" — the stamp beside the author's name.
  String get timeAgo {
    final at = createdAt;

    if (at == null) {
      return '';
    }

    final diff = DateTime.now().difference(at);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';

    return '${(diff.inDays / 7).floor()}w';
  }
}

/// The post a comment was left on — for the vendor's comments screen.
class FeedCommentPostModel {
  final String type;
  final int id;
  final String? caption;
  final String mediaType;
  final String? mediaUrl;

  FeedCommentPostModel({required this.type, required this.id, this.caption, this.mediaType = 'image', this.mediaUrl});

  factory FeedCommentPostModel.fromJson(Map<String, dynamic> json) => FeedCommentPostModel(
        type: json['type'] as String? ?? 'post',
        id: json['id'] as int? ?? 0,
        caption: json['caption'] as String?,
        mediaType: json['media_type'] as String? ?? 'image',
        mediaUrl: json['media_url'] as String?,
      );
}
