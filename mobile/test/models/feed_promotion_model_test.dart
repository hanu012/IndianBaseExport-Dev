import 'package:flutter_test/flutter_test.dart';
import 'package:service_marketplace/common_model/feed_model.dart';
import 'package:service_marketplace/common_model/promotion_model.dart';

/// The Feed and paid-promotion models parse what FeedController /
/// VendorPromotionController actually send.
void main() {
  test('a sponsored feed item parses vendor, media and counts', () {
    final item = FeedItemModel.fromJson({
      'type': 'promotion',
      'id': 7,
      'sponsored': true,
      'vendor': {'id': 3, 'business_name': 'Cool Air', 'shop_photo_url': null, 'phone': '9811111111'},
      'caption': '20% off',
      'service_name': null,
      'media_type': 'video',
      'media_url': 'http://x/v.mp4',
      'likes_count': 4,
      'comments_count': 2,
      'liked': true,
      'created_at': '2026-10-31T10:00:00+00:00',
    });

    expect(item.isPromotion, isTrue);
    expect(item.isSponsored, isTrue);
    expect(item.isVideo, isTrue);
    expect(item.vendorId, 3);
    expect(item.vendorPhone, '9811111111');
    expect(item.likesCount, 4);
    expect(item.liked, isTrue);
  });

  test('an organic post carries its service and no caption', () {
    final item = FeedItemModel.fromJson({
      'type': 'post',
      'id': 9,
      'sponsored': false,
      'vendor': {'id': 3, 'business_name': 'Cool Air'},
      'service_name': 'AC Repair',
      'media_type': 'image',
      'media_url': 'http://x/p.jpg',
    });

    expect(item.isPromotion, isFalse);
    expect(item.caption, isNull);
    expect(item.serviceName, 'AC Repair');
    expect(item.likesCount, 0);
  });

  test('a vendor promotion parses status, areas and numbers', () {
    final promotion = PromotionModel.fromJson({
      'id': 1,
      'package_name': '7-Day Premium Reach',
      'caption': 'Offer',
      'media_type': 'image',
      'price_paise': 99900,
      'duration_days': 7,
      'status': 'pending_payment',
      'is_showing': false,
      'zones': [
        {'id': 5, 'name': 'Satellite'},
      ],
      'stats': {'views': 120, 'likes': 8, 'comments': 3, 'calls': 2},
    });

    expect(promotion.isPendingPayment, isTrue);
    expect(promotion.zones.single.name, 'Satellite');
    expect(promotion.views, 120);
    expect(promotion.calls, 2);
  });

  test('a package parses its price, days and video rule', () {
    final package = PromotionPackageModel.fromJson({
      'id': 2,
      'name': 'Weekend Blitz',
      'duration_days': 2,
      'price_paise': 34900,
      'allows_video': false,
    });

    expect(package.durationDays, 2);
    expect(package.pricePaise, 34900);
    expect(package.allowsVideo, isFalse);
  });
}
