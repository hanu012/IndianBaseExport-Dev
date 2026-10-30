import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import 'vendor_document_upload_controller.dart';

/// Upload form for one KYC document; see [VendorDocumentUploadController].
///
/// A pushed screen rather than a bottom sheet: it carries up to two photo
/// previews, a text field and a date, which is more than a sheet holds
/// comfortably with the keyboard up. Laid out like the ehhs provider app's
/// document screen — plain header, the form, Submit pinned at the bottom.
class VendorDocumentUploadView extends StatelessWidget {
  final int? vendorId;
  final VendorDocumentModel document;

  const VendorDocumentUploadView({
    super.key,
    this.vendorId,
    required this.document,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<VendorDocumentUploadController>(
      init: VendorDocumentUploadController(vendorId: vendorId, document: document),
      dispose: (_) => Get.delete<VendorDocumentUploadController>(),
      builder: (controller) {
        final type = controller.type;

        return Scaffold(
          backgroundColor: ColorRes.backgroundColor,
          resizeToAvoidBottomInset: true,
          body: Column(
            children: [
              KycHeader(title: tr(StringRes.uploadDocumentTitle, args: [type.name ?? ''])),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16.getSize, 20.getSize, 16.getSize, 24.getSize),
                  children: [
                    VendorDocumentUploadForm(controller: controller, showSubmit: false),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: VendorDocumentUploadForm.submitBar(
            child: VendorDocumentUploadForm.submitButton(controller),
          ),
        );
      },
    );
  }
}

/// The upload form's body — review note, photo pickers, number, expiry and
/// tip — driven by one [VendorDocumentUploadController]. Shared by the
/// pushed [VendorDocumentUploadView] (which shows its own submit button)
/// and each document step of the KYC stepper (which does not: the
/// stepper's bottom "Save & continue" calls
/// [VendorDocumentUploadController.uploadAPI] instead).
class VendorDocumentUploadForm extends StatelessWidget {
  final VendorDocumentUploadController controller;

  /// False inside the stepper, whose own bottom button submits.
  final bool showSubmit;

  const VendorDocumentUploadForm({
    super.key,
    required this.controller,
    this.showSubmit = true,
  });

  @override
  Widget build(BuildContext context) {
    final type = controller.type;

    return Form(
      key: controller.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // What this document needs, as the provider app opens with.
          if ((type.description ?? '').isNotEmpty) ...[
            KycBanner(message: type.description!),
            16.heightSpacer,
          ],

          // Re-upload: the admin's reason stays in view while fixing it.
          if (controller.document.status == VendorDocumentModel.statusReupload &&
              (controller.document.reviewNote ?? '').isNotEmpty) ...[
            KycBanner(
              title: tr(StringRes.documentReviewNote),
              message: controller.document.reviewNote!,
              color: ColorRes.errorColor,
              icon: Icons.error_outline,
            ),
            16.heightSpacer,
          ],

          // Front and back side by side, as the provider app takes them.
          KycFieldLabel(text: tr(StringRes.documentPhoto)),
          10.heightSpacer,
          Container(
            padding: EdgeInsets.all(12.getSize),
            decoration: BoxDecoration(
              color: ColorRes.surfaceColor,
              borderRadius: BorderRadius.circular(14.getSize),
              border: Border.all(color: ColorRes.borderColor),
            ),
            child: Row(
              children: [
                sideBox(
                  key: const ValueKey('documentFront'),
                  label: tr(type.hasBack ? StringRes.documentFrontSide : StringRes.documentPhoto),
                  preview: controller.frontFile,
                  onTap: () => pickFor(controller, back: false),
                ),
                if (type.hasBack) ...[
                  12.widthSpacer,
                  sideBox(
                    key: const ValueKey('documentBack'),
                    label: tr(StringRes.documentBackSide),
                    preview: controller.backFile,
                    onTap: () => pickFor(controller, back: true),
                  ),
                ],
              ],
            ),
          ),
          errorText(controller.serverErrors['front']),
          errorText(controller.serverErrors['back']),

          if (type.hasNumber) ...[
            20.heightSpacer,
            KycFieldLabel(text: type.numberLabel ?? tr(StringRes.documentNumber)),
            10.heightSpacer,
            BaseTextField(
              key: const ValueKey('documentNumber'),
              controller: controller.numberController,
              hintText: type.numberHint ?? tr(StringRes.enterDocumentNumber),
              isShowBorder: true,
              validateMode: controller.autoValidateMode,
              validator: controller.validateNumber,
              onChanged: controller.onNumberChanged,
              textInputAction: TextInputAction.done,
              textInputType: type.maskNumber ? TextInputType.number : TextInputType.text,
              textCapitalization: type.maskNumber
                  ? TextCapitalization.none
                  : TextCapitalization.characters,
              maxLength: type.maskNumber ? 4 : null,
              inputFormatters: type.maskNumber
                  ? [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ]
                  : null,
            ),
            errorText(controller.serverErrors['number']),
          ],

          if (type.hasExpiry) ...[
            20.heightSpacer,
            KycFieldLabel(text: tr(StringRes.documentExpiryDate)),
            10.heightSpacer,
            expiryTile(context, controller),
            errorText(controller.serverErrors['expiry_date']),
          ],

          20.heightSpacer,
          KycBanner(
            message: tr(StringRes.documentPhotoTip),
            color: ColorRes.successColor,
            icon: Icons.tips_and_updates_outlined,
          ),

          if (showSubmit) ...[
            24.heightSpacer,
            submitButton(controller),
          ],
        ],
      ),
    );
  }

  /// Submit — disabled (greyed) until every piece the type needs is present.
  static Widget submitButton(VendorDocumentUploadController controller) {
    return BaseRaisedButton(
      key: const ValueKey('submitDocument'),
      onPressed: controller.canSubmit ? controller.submitAPI : null,
      buttonText: StringRes.submitDocument,
      buttonColor: controller.canSubmit
          ? ColorRes.primaryColor
          : ColorRes.surfaceElevatedColor,
      textColor: controller.canSubmit ? ColorRes.whiteColor : ColorRes.grayColor,
      borderColor: controller.canSubmit ? null : ColorRes.borderColor,
      fontWeight: FontWeight.w500,
    );
  }

  /// The white footer the primary action sits in, pinned under the form —
  /// shared with the KYC stepper's bottom bar.
  static Widget submitBar({required Widget child}) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.getSize, 14.getSize, 16.getSize, 12.getSize),
      decoration: BoxDecoration(
        color: ColorRes.surfaceColor,
        border: Border(top: BorderSide(color: ColorRes.borderColor)),
      ),
      child: SafeArea(top: false, child: child),
    );
  }

  /// Camera or gallery, as on the profile photo sheet.
  Future<void> pickFor(
    VendorDocumentUploadController controller, {
    required bool back,
  }) async {
    final source = await Get.bottomSheet<ImageSource>(
      sourceSheet(),
      isScrollControlled: true,
    );

    if (source != null) {
      await controller.pickImage(source: source, back: back);
    }
  }

  Widget sourceSheet() {
    return Container(
      padding: EdgeInsets.fromLTRB(16.getSize, 12.getSize, 16.getSize, 16.getSize),
      decoration: BoxDecoration(
        color: ColorRes.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22.getSize)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                height: 4.getSize,
                width: 46.getSize,
                decoration: BoxDecoration(
                  color: ColorRes.borderColor,
                  borderRadius: BorderRadius.circular(3.getSize),
                ),
              ),
            ),
            16.heightSpacer,
            BaseTextDMSans(
              text: tr(StringRes.addDocumentPhoto),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: ColorRes.secondaryColor,
              textAlign: TextAlign.start,
            ),
            8.heightSpacer,
            sourceOption(Icons.photo_camera_outlined, StringRes.takePhoto, ImageSource.camera),
            sourceOption(
              Icons.photo_library_outlined,
              StringRes.chooseFromGallery,
              ImageSource.gallery,
            ),
          ],
        ),
      ),
    );
  }

  Widget sourceOption(IconData icon, String labelKey, ImageSource source) {
    return InkWell(
      onTap: () => Get.back(result: source),
      borderRadius: BorderRadius.circular(12.getSize),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14.getSize, horizontal: 4.getSize),
        child: Row(
          children: [
            Icon(icon, size: 22.getSize, color: ColorRes.primaryColor),
            14.widthSpacer,
            BaseTextDMSans(
              text: tr(labelKey),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: ColorRes.secondaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget errorText(String? message) {
    if (message == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(top: 6.getSize, left: 4.getSize),
      child: BaseTextDMSans(
        text: message,
        fontSize: 11,
        color: ColorRes.errorColor,
        textAlign: TextAlign.start,
        maxLines: 3,
      ),
    );
  }

  /// One side of the document, as the provider app lays them out: a tinted
  /// box with an upload icon and its label, or the picked photo with a tick.
  Widget sideBox({
    required Key key,
    required String label,
    required File? preview,
    required VoidCallback onTap,
  }) {
    final picked = preview != null;

    return Expanded(
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.getSize),
        child: Stack(
          children: [
            Container(
              height: 110.getSize,
              width: double.infinity,
              decoration: BoxDecoration(
                color: picked
                    ? ColorRes.surfaceColor
                    : ColorRes.primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12.getSize),
                border: Border.all(
                  color: picked
                      ? ColorRes.primaryColor
                      : ColorRes.primaryColor.withValues(alpha: 0.25),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: picked
                  ? Image.file(
                      preview,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => Icon(
                        Icons.image_outlined,
                        size: 24.getSize,
                        color: ColorRes.primaryColor,
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_upload_outlined,
                          size: 28.getSize,
                          color: ColorRes.primaryColor,
                        ),
                        8.heightSpacer,
                        BaseTextDMSans(
                          text: label,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ColorRes.secondaryColor,
                          maxLines: 1,
                        ),
                        2.heightSpacer,
                        BaseTextDMSans(
                          text: StringRes.tapToUpload,
                          fontSize: 10,
                          color: ColorRes.grayColor,
                          maxLines: 1,
                        ).tr(),
                      ],
                    ),
            ),
            if (picked) ...[
              // Tick: this side is done; the label says which side it is.
              Positioned(
                top: 6.getSize,
                right: 6.getSize,
                child: Container(
                  decoration: BoxDecoration(
                    color: ColorRes.surfaceColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle,
                    size: 22.getSize,
                    color: ColorRes.successColor,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 5.getSize),
                  color: ColorRes.secondaryColor.withValues(alpha: 0.65),
                  child: BaseTextDMSans(
                    text: StringRes.replaceImage,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: ColorRes.whiteColor,
                    maxLines: 1,
                  ).tr(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget expiryTile(BuildContext context, VendorDocumentUploadController controller) {
    final text = controller.expiryDateText;

    return InkWell(
      key: const ValueKey('documentExpiry'),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: controller.expiryDate ?? controller.firstExpiryDate,
          firstDate: controller.firstExpiryDate,
          lastDate: controller.lastExpiryDate,
        );
        controller.setExpiryDate(picked);
      },
      borderRadius: BorderRadius.circular(12.getSize),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.getSize, vertical: 14.getSize),
        decoration: BoxDecoration(
          color: ColorRes.surfaceElevatedColor,
          borderRadius: BorderRadius.circular(12.getSize),
          border: Border.all(
            color: text == null ? ColorRes.borderColor : ColorRes.primaryColor,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.event_outlined, size: 20.getSize, color: ColorRes.primaryColor),
            12.widthSpacer,
            Expanded(
              child: BaseTextDMSans(
                text: text ?? tr(StringRes.selectExpiryDate),
                fontSize: 14,
                fontWeight: text == null ? FontWeight.w400 : FontWeight.w600,
                color: text == null ? ColorRes.grayColor : ColorRes.secondaryColor,
                textAlign: TextAlign.start,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
