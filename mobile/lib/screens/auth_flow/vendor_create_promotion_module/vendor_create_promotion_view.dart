import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import '../vendor_promotions_module/vendor_promotions_controller.dart';
import '../vendor_promotions_module/vendor_promotions_view.dart';

/// Buying a paid promotion: 1 Package, 2 Photo or video (optional),
/// 3 Caption (up to 300), 4 Areas (the vendor's own, searchable), then
/// "Pay ₹X & launch". Each step's number fills in once it is done.
///
/// Also "Edit post" for a running promotion — then only the photo/video and
/// caption steps show, and the bar saves instead of paying.
///
/// No controller of its own: binds to the list's VendorPromotionsController
/// (mounted underneath), so the new promotion is in the list on the way
/// back — the same pattern as the portfolio gallery screens.
class VendorCreatePromotionView extends StatelessWidget {
  const VendorCreatePromotionView({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<VendorPromotionsController>(
      // Find, not init: the list screen owns this controller's lifetime.
      init: Get.find<VendorPromotionsController>(),
      builder: (controller) {
        final editing = controller.isEditing;

        return Scaffold(
          backgroundColor: ServiceTokens.bg,
          body: SafeArea(
            child: !editing && controller.isLoadingOptions && controller.packages.isEmpty
                ? const Center(child: CupertinoActivityIndicator(color: ServiceTokens.accentBright))
                : ListView(
                    padding: EdgeInsets.fromLTRB(16.getSize, 8.getSize, 16.getSize, 24.getSize),
                    children: [
                      header(editing),
                      16.heightSpacer,
                      if (!editing) ...[
                        packagesStep(controller),
                        12.heightSpacer,
                      ],
                      mediaStep(controller, number: editing ? 1 : 2),
                      12.heightSpacer,
                      captionStep(controller, number: editing ? 2 : 3),
                      if (!editing) ...[
                        12.heightSpacer,
                        areasStep(controller),
                      ],
                    ],
                  ),
          ),
          bottomNavigationBar: payBar(controller),
        );
      },
    );
  }

  Widget header(bool editing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PromotionBackButton(onTap: Get.back),
        14.heightSpacer,
        BaseTextDMSans(
          text: tr(editing ? StringRes.editPostTitle : StringRes.newPromotionAction),
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: ServiceTokens.text,
          textAlign: TextAlign.start,
        ),
        4.heightSpacer,
        BaseTextDMSans(
          text: tr(editing ? StringRes.editPostDesc : StringRes.promoteBusinessDesc),
          fontSize: 12,
          color: ServiceTokens.muted,
          textAlign: TextAlign.start,
          maxLines: 3,
        ),
      ],
    );
  }

  /// A numbered card; the number fills teal once the step is [done].
  Widget step({required int number, required String title, required bool done, Widget? trailing, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.getSize),
      decoration: BoxDecoration(
        color: ServiceTokens.card,
        borderRadius: BorderRadius.circular(20.getSize),
        border: Border.all(color: ServiceTokens.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 26.getSize,
                width: 26.getSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: done ? ServiceTokens.accent : ServiceTokens.tileFill,
                  shape: BoxShape.circle,
                ),
                child: done
                    ? Icon(Icons.check, size: 14.getSize, color: Colors.white)
                    : BaseTextDMSans(text: '$number', fontSize: 11, fontWeight: FontWeight.w600, color: ServiceTokens.accent),
              ),
              10.widthSpacer,
              Expanded(
                child: BaseTextDMSans(
                  text: title,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ServiceTokens.text,
                  textAlign: TextAlign.start,
                ),
              ),
              ?trailing,
            ],
          ),
          12.heightSpacer,
          child,
        ],
      ),
    );
  }

  Widget smallMuted(String text) =>
      BaseTextDMSans(text: text, fontSize: 11, fontWeight: FontWeight.w500, color: ServiceTokens.muted);

  // ── 1. Package ──────────────────────────────────────────────────────────

  Widget packagesStep(VendorPromotionsController controller) {
    return step(
      number: 1,
      title: tr(StringRes.stepPackage),
      done: controller.selectedPackage != null,
      child: controller.packages.isEmpty
          ? BaseTextDMSans(text: tr(StringRes.somethingWentWrong), fontSize: 12, color: ServiceTokens.muted)
          : Column(
              children: [
                for (final package in controller.packages) ...[
                  packageTile(controller, package),
                  8.heightSpacer,
                ],
              ],
            ),
    );
  }

  Widget packageTile(VendorPromotionsController controller, PromotionPackageModel package) {
    final selected = controller.selectedPackage?.id == package.id;

    return InkWell(
      onTap: () => controller.selectPackage(package),
      borderRadius: BorderRadius.circular(16.getSize),
      child: Container(
        padding: EdgeInsets.all(14.getSize),
        decoration: BoxDecoration(
          color: selected ? ServiceTokens.tileFill : ServiceTokens.card,
          borderRadius: BorderRadius.circular(16.getSize),
          border: Border.all(color: selected ? ServiceTokens.accent : ServiceTokens.stroke, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? ServiceTokens.accent : ServiceTokens.muted2,
              size: 20.getSize,
            ),
            12.widthSpacer,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BaseTextDMSans(
                    text: package.name,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ServiceTokens.text,
                    textAlign: TextAlign.start,
                  ),
                  if (package.isPopular) ...[
                    4.heightSpacer,
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 7.getSize, vertical: 2.getSize),
                      decoration: BoxDecoration(
                        color: ServiceTokens.accent,
                        borderRadius: BorderRadius.circular(20.getSize),
                      ),
                      child: BaseTextDMSans(
                        text: tr(StringRes.mostPopularTag),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                  3.heightSpacer,
                  BaseTextDMSans(
                    text: [
                      tr(StringRes.packageDaysLabel, args: ['${package.durationDays}']),
                      if (!package.allowsVideo) tr(StringRes.photoOnlyLabel),
                    ].join(' · '),
                    fontSize: 11,
                    color: ServiceTokens.muted,
                    textAlign: TextAlign.start,
                  ),
                ],
              ),
            ),
            BaseTextDMSans(
              text: Utils.rupeesWhole(package.pricePaise),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: ServiceTokens.accent,
            ),
          ],
        ),
      ),
    );
  }

  // ── 2. Photo or video ───────────────────────────────────────────────────

  Widget mediaStep(VendorPromotionsController controller, {required int number}) {
    final path = controller.mediaPath;
    final existing = controller.removeMedia ? null : controller.existingMediaUrl;
    final isVideo = path != null ? controller.mediaType == 'video' : controller.existingMediaType == 'video';

    Widget? preview;

    if (path != null || existing != null) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(14.getSize),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: isVideo
              ? Container(
                  color: ServiceTokens.text,
                  alignment: Alignment.center,
                  child: Icon(Icons.play_circle_fill, size: 48.getSize, color: Colors.white),
                )
              : path != null
                  // On the web the picked file is a blob: URL, not a path.
                  ? (kIsWeb ? Image.network(path, fit: BoxFit.cover) : Image.file(File(path), fit: BoxFit.cover))
                  : Image.network(existing!, fit: BoxFit.cover),
        ),
      );
    }

    return step(
      number: number,
      title: tr(StringRes.stepMedia),
      done: controller.hasAnyMedia,
      trailing: smallMuted(tr(StringRes.optionalLabel)),
      child: preview != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                preview,
                10.heightSpacer,
                Row(
                  children: [
                    Expanded(
                      child: VendorSecondaryButton(
                        label: tr(StringRes.changeMediaAction),
                        icon: Icons.photo_outlined,
                        onTap: controller.pickPhoto,
                      ),
                    ),
                    8.widthSpacer,
                    Expanded(
                      child: VendorSecondaryButton(
                        label: tr(StringRes.removeMediaAction),
                        icon: Icons.delete_outline,
                        onTap: controller.clearMedia,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Container(
              padding: EdgeInsets.fromLTRB(14.getSize, 18.getSize, 14.getSize, 14.getSize),
              decoration: BoxDecoration(
                color: ServiceTokens.card2,
                borderRadius: BorderRadius.circular(16.getSize),
                border: Border.all(color: ServiceTokens.stroke2),
              ),
              child: Column(
                children: [
                  Icon(Icons.image_outlined, size: 28.getSize, color: ServiceTokens.accent),
                  6.heightSpacer,
                  BaseTextDMSans(
                    text: tr(StringRes.mediaDropHint),
                    fontSize: 11,
                    color: ServiceTokens.muted,
                    maxLines: 2,
                  ),
                  12.heightSpacer,
                  Row(
                    children: [
                      Expanded(
                        child: VendorSecondaryButton(
                          label: tr(StringRes.addPhotoAction),
                          icon: Icons.photo_outlined,
                          onTap: controller.pickPhoto,
                        ),
                      ),
                      if (controller.allowsVideo) ...[
                        8.widthSpacer,
                        Expanded(
                          child: VendorSecondaryButton(
                            label: tr(StringRes.addVideoAction),
                            icon: Icons.videocam_outlined,
                            onTap: controller.pickVideo,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  // ── 3. Caption ──────────────────────────────────────────────────────────

  Widget captionStep(VendorPromotionsController controller, {required int number}) {
    return step(
      number: number,
      title: tr(StringRes.stepCaption),
      done: controller.captionDone,
      trailing: smallMuted('${controller.captionController.text.characters.length}/${VendorPromotionsController.captionMax}'),
      child: BaseTextField(
        controller: controller.captionController,
        hintText: tr(StringRes.promotionCaptionHint),
        isShowBorder: true,
        fillColor: ServiceTokens.card2,
        borderColor: ServiceTokens.stroke,
        maxLines: 5,
        minLines: 3,
        maxLength: VendorPromotionsController.captionMax,
        onChanged: (_) => controller.update(),
      ),
    );
  }

  // ── 4. Areas ────────────────────────────────────────────────────────────

  Widget areasStep(VendorPromotionsController controller) {
    final selected = controller.selectedZones;

    return step(
      number: 4,
      title: tr(StringRes.stepAreas),
      done: selected.isNotEmpty,
      trailing: controller.zones.isEmpty
          ? null
          : smallMuted(tr(StringRes.areasSelectedCount, args: ['${selected.length}'])),
      child: controller.zones.isEmpty
          ? BaseTextDMSans(
              text: tr(StringRes.noPromotionAreas),
              fontSize: 12,
              color: ServiceTokens.muted,
              textAlign: TextAlign.start,
              maxLines: 3,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (selected.isNotEmpty) ...[
                  Wrap(
                    spacing: 6.getSize,
                    runSpacing: 6.getSize,
                    children: [for (final zone in selected) selectedChip(controller, zone)],
                  ),
                  10.heightSpacer,
                ],
                dropdownTrigger(controller),
                if (controller.areasOpen) ...[
                  8.heightSpacer,
                  dropdownPanel(controller),
                ],
              ],
            ),
    );
  }

  Widget selectedChip(VendorPromotionsController controller, PromotionZoneModel zone) {
    return Container(
      padding: EdgeInsets.fromLTRB(10.getSize, 5.getSize, 4.getSize, 5.getSize),
      decoration: BoxDecoration(
        color: ServiceTokens.tileFill,
        borderRadius: BorderRadius.circular(20.getSize),
        border: Border.all(color: ServiceTokens.tileBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BaseTextDMSans(text: zone.name, fontSize: 11, fontWeight: FontWeight.w500, color: ServiceTokens.accent),
          2.widthSpacer,
          InkWell(
            onTap: () => controller.toggleZone(zone),
            customBorder: const CircleBorder(),
            child: Padding(
              padding: EdgeInsets.all(2.getSize),
              child: Icon(Icons.close, size: 14.getSize, color: ServiceTokens.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget dropdownTrigger(VendorPromotionsController controller) {
    return InkWell(
      onTap: controller.toggleAreas,
      borderRadius: BorderRadius.circular(14.getSize),
      child: Container(
        height: 48.getSize,
        padding: EdgeInsets.symmetric(horizontal: 12.getSize),
        decoration: BoxDecoration(
          color: ServiceTokens.card2,
          borderRadius: BorderRadius.circular(14.getSize),
          border: Border.all(color: controller.areasOpen ? ServiceTokens.accent : ServiceTokens.stroke),
        ),
        child: Row(
          children: [
            Icon(Icons.location_on_outlined, size: 18.getSize, color: ServiceTokens.muted),
            8.widthSpacer,
            Expanded(
              child: BaseTextDMSans(
                text: tr(StringRes.selectAreasHint),
                fontSize: 12,
                color: ServiceTokens.muted,
                textAlign: TextAlign.start,
              ),
            ),
            Icon(
              controller.areasOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 20.getSize,
              color: ServiceTokens.muted,
            ),
          ],
        ),
      ),
    );
  }

  Widget dropdownPanel(VendorPromotionsController controller) {
    final zones = controller.filteredZones;

    return Container(
      decoration: BoxDecoration(
        color: ServiceTokens.card,
        borderRadius: BorderRadius.circular(14.getSize),
        border: Border.all(color: ServiceTokens.stroke),
        boxShadow: [BoxShadow(color: ServiceTokens.text.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(8.getSize),
            child: BaseTextField(
              controller: controller.areaSearchController,
              hintText: tr(StringRes.searchAreasHint),
              isShowBorder: true,
              fillColor: ServiceTokens.card2,
              borderColor: ServiceTokens.stroke,
              prefixIcon: Icon(Icons.search, size: 18.getSize, color: ServiceTokens.muted),
              onChanged: (_) => controller.update(),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 240.getSize),
            child: zones.isEmpty
                ? Padding(
                    padding: EdgeInsets.all(16.getSize),
                    child: BaseTextDMSans(text: tr(StringRes.noAreasMatch), fontSize: 12, color: ServiceTokens.muted),
                  )
                : ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      for (final zone in zones)
                        InkWell(
                          onTap: () => controller.toggleZone(zone),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12.getSize, vertical: 10.getSize),
                            child: Row(
                              children: [
                                Icon(
                                  controller.selectedZoneIds.contains(zone.id) ? Icons.check_box : Icons.check_box_outline_blank,
                                  size: 20.getSize,
                                  color: controller.selectedZoneIds.contains(zone.id) ? ServiceTokens.accent : ServiceTokens.muted2,
                                ),
                                10.widthSpacer,
                                Expanded(
                                  child: BaseTextDMSans(
                                    text: zone.name,
                                    fontSize: 12,
                                    color: ServiceTokens.text,
                                    textAlign: TextAlign.start,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(12.getSize, 8.getSize, 8.getSize, 8.getSize),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: ServiceTokens.stroke))),
            child: Row(
              children: [
                Expanded(
                  child: smallMuted(tr(StringRes.areasSelectedCount, args: ['${controller.selectedZoneIds.length}'])),
                ),
                TextButton(
                  onPressed: controller.toggleAreas,
                  child: BaseTextDMSans(
                    text: tr(StringRes.areasDoneAction),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ServiceTokens.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Pay / save bar ──────────────────────────────────────────────────────

  Widget payBar(VendorPromotionsController controller) {
    final editing = controller.isEditing;
    final price = controller.selectedPackage?.pricePaise ?? 0;

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(16.getSize, 12.getSize, 16.getSize, 12.getSize),
        decoration: BoxDecoration(
          color: ServiceTokens.card,
          border: Border(top: BorderSide(color: ServiceTokens.stroke)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!editing) ...[
              Row(
                children: [
                  BaseTextDMSans(text: tr(StringRes.totalLabel), fontSize: 12, color: ServiceTokens.muted),
                  const Spacer(),
                  BaseTextDMSans(
                    text: Utils.rupeesWhole(price),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: ServiceTokens.text,
                  ),
                ],
              ),
              10.heightSpacer,
            ],
            if (controller.isSubmitting && controller.uploadProgress > 0 && controller.uploadProgress < 1) ...[
              VendorProgressBar(ratio: controller.uploadProgress),
              10.heightSpacer,
            ],
            VendorPrimaryButton(
              label: editing
                  ? tr(StringRes.saveChanges)
                  : tr(StringRes.payAmountAndLaunch, args: [Utils.rupeesWhole(price)]),
              icon: editing ? Icons.check : Icons.rocket_launch_outlined,
              enabled: controller.canSubmit,
              onTap: controller.submitAPI,
            ),
            if (!editing && !controller.canSubmit && !controller.isSubmitting) ...[
              8.heightSpacer,
              BaseTextDMSans(text: tr(StringRes.promotionPayHint), fontSize: 11, color: ServiceTokens.muted),
            ],
          ],
        ),
      ),
    );
  }
}
