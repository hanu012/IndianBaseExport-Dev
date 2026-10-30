/// A zone (`GET /api/zones`) — a nested tree of parent zones with their
/// active leaf children.
///
/// `isLeaf` decides selectability (SPEC section 8): true for a leaf child
/// AND for a standalone top-level zone with no sub-zones. A parent with
/// children is `isLeaf == false` and is navigation/grouping only, never a
/// coverage unit itself.
class ZoneModel {
  int? id;
  String? name;
  String? pincode;
  bool isLeaf;
  List<ZoneModel> children;

  ZoneModel({
    this.id,
    this.name,
    this.pincode,
    this.isLeaf = true,
    List<ZoneModel>? children,
  }) : children = children ?? [];

  ZoneModel.fromJson(Map<String, dynamic> json)
      : id = json['id'] as int?,
        name = json['name'] as String?,
        pincode = json['pincode'] as String?,
        isLeaf = (json['is_leaf'] as bool?) ?? true,
        children = ((json['children'] as List<dynamic>?) ?? [])
            .map((e) => ZoneModel.fromJson(e as Map<String, dynamic>))
            .toList();
}

/// What the zone-mode location picker (CustomerZoneLocationView) returns:
/// the zone a customer can be in — a sub-zone, or a main zone that has
/// none — and the main zone it sits under, for the header's label.
class PickedZone {
  const PickedZone({required this.zone, this.parent});

  final ZoneModel zone;
  final ZoneModel? parent;

  int get id => zone.id!;

  /// "Satellite" — the home header's bold line.
  String get title => zone.name ?? '';

  /// "Satellite, Ahmedabad" — the fuller line under it.
  String get fullAddress =>
      parent == null ? title : '$title, ${parent!.name ?? ''}';
}
