import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import 'customer_zone_location_controller.dart';

/// "Select your area" — see [CustomerZoneLocationController].
///
/// Header as on "Set your location", then a main zone field and — once the
/// chosen main zone has sub-zones — a sub-zone field, each opening a list.
/// Confirm sits in a footer and stays greyed until the pick is complete.
class CustomerZoneLocationView extends StatelessWidget {
  const CustomerZoneLocationView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CustomerZoneLocationController>(
      init: CustomerZoneLocationController(),
      dispose: (_) => Get.delete<CustomerZoneLocationController>(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: ServiceTokens.bg,
          body: Column(
            children: [
              header(),
              Expanded(child: body(controller)),
            ],
          ),
          bottomNavigationBar: controller.zones.isEmpty ? null : footer(controller),
        );
      },
    );
  }

  Widget header() {
    return CustomerHero(
      bottomPadding: 20.getSize,
      child: Row(
        children: [
          CustomerIconButton(icon: Icons.chevron_left, onTap: Get.back),
          Expanded(
            child: Column(
              children: [
                BaseTextDMSans(
                  text: tr(StringRes.selectYourArea),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                4.heightSpacer,
                BaseTextDMSans(
                  text: tr(StringRes.selectYourAreaDesc),
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.82),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          SizedBox(width: 42.getSize),
        ],
      ),
    );
  }

  Widget body(CustomerZoneLocationController controller) {
    if (controller.isLoading) {
      return Center(child: CupertinoActivityIndicator(color: ServiceTokens.accent));
    }

    if (controller.hasError) {
      return message(
        text: tr(StringRes.somethingWentWrong),
        action: BaseRaisedButton(
          onPressed: controller.fetchZonesAPI,
          buttonText: StringRes.retry,
          buttonColor: ServiceTokens.accent,
        ),
      );
    }

    if (controller.zones.isEmpty) {
      return message(text: tr(StringRes.noZonesAvailable));
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16.getSize, 20.getSize, 16.getSize, 24.getSize),
      children: [
        fieldLabel(tr(StringRes.mainZoneLabel)),
        8.heightSpacer,
        selectField(
          key: const ValueKey('mainZoneField'),
          icon: Icons.location_city_outlined,
          value: controller.mainZone?.name,
          placeholder: tr(StringRes.selectMainZone),
          onTap: () => openList(
            title: tr(StringRes.selectMainZone),
            options: controller.zones,
            selectedId: controller.mainZone?.id,
            onSelected: controller.selectMainZone,
          ),
        ),
        if (controller.needsSubZone) ...[
          20.heightSpacer,
          fieldLabel(tr(StringRes.subZoneLabel)),
          8.heightSpacer,
          selectField(
            key: const ValueKey('subZoneField'),
            icon: Icons.place_outlined,
            value: controller.subZone?.name,
            placeholder: tr(StringRes.selectSubZone),
            onTap: () => openList(
              title: tr(StringRes.selectSubZone),
              options: controller.mainZone!.children,
              selectedId: controller.subZone?.id,
              onSelected: controller.selectSubZone,
            ),
          ),
        ],
      ],
    );
  }

  Widget message({required String text, Widget? action}) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.getSize),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BaseTextDMSans(
              text: text,
              fontSize: 14,
              color: ServiceTokens.muted,
              textAlign: TextAlign.center,
              maxLines: 3,
            ),
            if (action != null) ...[
              16.heightSpacer,
              action,
            ],
          ],
        ),
      ),
    );
  }

  Widget fieldLabel(String text) {
    return BaseTextDMSans(
      text: text,
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: ServiceTokens.text,
      textAlign: TextAlign.start,
    );
  }

  /// A tappable field showing the pick, or a muted placeholder.
  Widget selectField({
    required Key key,
    required IconData icon,
    required String? value,
    required String placeholder,
    required VoidCallback onTap,
  }) {
    final hasValue = value != null && value.isNotEmpty;

    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.getSize),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.getSize, vertical: 15.getSize),
        decoration: BoxDecoration(
          color: ServiceTokens.card,
          borderRadius: BorderRadius.circular(14.getSize),
          border: Border.all(color: hasValue ? ServiceTokens.tileBorder : ServiceTokens.stroke),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20.getSize, color: ServiceTokens.accent),
            12.widthSpacer,
            Expanded(
              child: BaseTextDMSans(
                text: hasValue ? value : placeholder,
                fontSize: 14,
                fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                color: hasValue ? ServiceTokens.text : ServiceTokens.muted2,
                textAlign: TextAlign.start,
                maxLines: 1,
              ),
            ),
            Icon(Icons.keyboard_arrow_down, size: 22.getSize, color: ServiceTokens.muted2),
          ],
        ),
      ),
    );
  }

  /// The options as a bottom sheet list; closes on a tap.
  void openList({
    required String title,
    required List<ZoneModel> options,
    required int? selectedId,
    required ValueChanged<ZoneModel> onSelected,
  }) {
    Get.bottomSheet(
      Container(
        constraints: BoxConstraints(maxHeight: Get.height * 0.7),
        decoration: BoxDecoration(
          color: ServiceTokens.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26.getSize)),
          border: Border.all(color: ServiceTokens.stroke),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              12.heightSpacer,
              Center(
                child: Container(
                  height: 4.getSize,
                  width: 44.getSize,
                  decoration: BoxDecoration(
                    color: ServiceTokens.stroke2,
                    borderRadius: BorderRadius.circular(4.getSize),
                  ),
                ),
              ),
              16.heightSpacer,
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.getSize),
                child: BaseTextDMSans(
                  text: title,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: ServiceTokens.text,
                  textAlign: TextAlign.start,
                ),
              ),
              12.heightSpacer,
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.fromLTRB(20.getSize, 0, 20.getSize, 18.getSize),
                  itemCount: options.length,
                  separatorBuilder: (_, _) => 10.heightSpacer,
                  itemBuilder: (_, index) {
                    final zone = options[index];

                    return option(
                      zone: zone,
                      selected: zone.id == selectedId,
                      onTap: () {
                        Get.back();
                        onSelected(zone);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  Widget option({
    required ZoneModel zone,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final subZoneCount = zone.children.length;

    return InkWell(
      key: ValueKey('zone-${zone.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.getSize),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.getSize, vertical: 14.getSize),
        decoration: BoxDecoration(
          color: selected ? ServiceTokens.tileFill : ServiceTokens.card,
          borderRadius: BorderRadius.circular(14.getSize),
          border: Border.all(color: selected ? ServiceTokens.accent : ServiceTokens.stroke),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BaseTextDMSans(
                    text: zone.name ?? '',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ServiceTokens.text,
                    textAlign: TextAlign.start,
                  ),
                  if (subZoneCount > 0) ...[
                    2.heightSpacer,
                    BaseTextDMSans(
                      text: '$subZoneCount ${tr(StringRes.areasAvailable)}',
                      fontSize: 12,
                      color: ServiceTokens.muted,
                      textAlign: TextAlign.start,
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: ServiceTokens.accent, size: 22.getSize),
          ],
        ),
      ),
    );
  }

  Widget footer(CustomerZoneLocationController controller) {
    final enabled = controller.pickedZone != null;

    return Container(
      padding: EdgeInsets.fromLTRB(16.getSize, 14.getSize, 16.getSize, 12.getSize),
      decoration: BoxDecoration(
        color: ServiceTokens.card,
        border: Border(top: BorderSide(color: ServiceTokens.stroke)),
      ),
      child: SafeArea(
        top: false,
        child: BaseRaisedButton(
          key: const ValueKey('confirmZone'),
          onPressed: enabled ? controller.confirm : null,
          buttonText: StringRes.confirmLocation,
          buttonColor: enabled ? ServiceTokens.accent : ServiceTokens.card2,
          textColor: enabled ? Colors.white : ServiceTokens.muted2,
          borderColor: enabled ? null : ServiceTokens.stroke,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
