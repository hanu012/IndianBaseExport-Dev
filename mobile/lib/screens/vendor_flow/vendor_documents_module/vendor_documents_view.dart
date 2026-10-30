import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import 'vendor_documents_controller.dart';

/// KYC documents list; see [VendorDocumentsController].
///
/// Laid out like the ehhs provider app's "My Document" screen: a plain
/// header, then one card per document — icon tile, name, status in its
/// colour and the status icon — with what is on file (number, expiry, the
/// photos), the admin's reason when a re-upload was asked for, and the
/// Upload action while it is allowed.
class VendorDocumentsView extends StatelessWidget {
  /// Null for the signed-in vendor's own documents.
  final int? vendorId;

  const VendorDocumentsView({super.key, this.vendorId});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<VendorDocumentsController>(
      init: VendorDocumentsController(vendorId: vendorId),
      dispose: (_) => Get.delete<VendorDocumentsController>(),
      builder: (controller) {
        return Scaffold(
          backgroundColor: ColorRes.backgroundColor,
          body: Column(
            children: [
              KycHeader(title: tr(StringRes.vendorDocumentsTitle)),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: controller.fetchDocumentsAPI,
                  color: ColorRes.primaryColor,
                  backgroundColor: ColorRes.surfaceColor,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16.getSize, 20.getSize, 16.getSize, 30.getSize),
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [content(controller)],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget content(VendorDocumentsController controller) {
    final data = controller.documents;

    if (data == null) {
      if (controller.hasError) {
        return errorState(controller);
      }

      return Padding(
        padding: EdgeInsets.only(top: 40.getSize),
        child: CupertinoActivityIndicator(color: ColorRes.primaryColor),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.showMissingBanner)
          KycBanner(
            key: const ValueKey('documentsBanner'),
            message: tr(
              StringRes.missingCompulsoryBanner,
              args: [controller.missingCompulsory.join(', ')],
            ),
            color: ColorRes.warningColor,
          )
        else if (data.complete)
          KycBanner(
            key: const ValueKey('documentsBanner'),
            message: tr(StringRes.documentsComplete),
            color: ColorRes.successColor,
            icon: Icons.verified_outlined,
          )
        else
          KycBanner(message: tr(StringRes.vendorDocumentsDesc)),
        20.heightSpacer,
        if (data.documents.isEmpty)
          BaseTextDMSans(
            text: StringRes.noDocumentTypes,
            fontSize: 14,
            color: ColorRes.grayColor,
            maxLines: 2,
          ).tr()
        else
          for (final document in data.documents) ...[
            documentCard(controller, document),
            14.heightSpacer,
          ],
      ],
    );
  }

  Widget errorState(VendorDocumentsController controller) {
    return Padding(
      padding: EdgeInsets.only(top: 24.getSize),
      child: Column(
        children: [
          BaseTextDMSans(
            text: StringRes.somethingWentWrong,
            fontSize: 14,
            color: ColorRes.grayColor,
          ).tr(),
          16.heightSpacer,
          BaseRaisedButton(
            onPressed: controller.fetchDocumentsAPI,
            buttonText: StringRes.retry,
            buttonColor: ColorRes.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget documentCard(
    VendorDocumentsController controller,
    VendorDocumentModel document,
  ) {
    final type = document.documentType;
    final showNote = document.status == VendorDocumentModel.statusReupload &&
        (document.reviewNote ?? '').isNotEmpty;
    final hasFront = (document.frontUrl ?? '').isNotEmpty;
    final hasBack = (document.backUrl ?? '').isNotEmpty;
    final hasDetails = (type.description ?? '').isNotEmpty ||
        (document.number ?? '').isNotEmpty ||
        (document.expiryDate ?? '').isNotEmpty ||
        hasFront ||
        hasBack;

    return Container(
      padding: EdgeInsets.all(14.getSize),
      decoration: BoxDecoration(
        color: ColorRes.surfaceColor,
        borderRadius: BorderRadius.circular(16.getSize),
        border: Border.all(color: ColorRes.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KycDocumentRow(document: document, flat: true),
          if (hasDetails) ...[
            14.heightSpacer,
            Divider(height: 1, color: ColorRes.borderColor),
            12.heightSpacer,
          ],
          if ((type.description ?? '').isNotEmpty)
            BaseTextDMSans(
              text: type.description!,
              fontSize: 12,
              color: ColorRes.grayColor,
              textAlign: TextAlign.start,
              maxLines: 3,
            ),
          if ((document.number ?? '').isNotEmpty) ...[
            8.heightSpacer,
            detailLine(
              type.numberLabel ?? tr(StringRes.documentNumber),
              document.number!,
            ),
          ],
          if ((document.expiryDate ?? '').isNotEmpty) ...[
            6.heightSpacer,
            detailLine(
              tr(StringRes.documentExpiresOn),
              VendorDocumentsController.formatDate(document.expiryDate!),
            ),
          ],
          // What was uploaded, so the uploader can check it — side by side,
          // as the provider app shows front and back.
          if (hasFront || hasBack) ...[
            12.heightSpacer,
            Row(
              children: [
                if (hasFront)
                  filePreview(controller, document.frontUrl!, StringRes.documentFrontSide),
                if (hasFront && hasBack) 12.widthSpacer,
                if (hasBack)
                  filePreview(controller, document.backUrl!, StringRes.documentBackSide),
                // A lone photo keeps half the width, not all of it.
                if (hasFront != hasBack) ...[
                  12.widthSpacer,
                  const Expanded(child: SizedBox()),
                ],
              ],
            ),
          ],
          if (showNote) ...[
            12.heightSpacer,
            KycBanner(
              title: tr(StringRes.documentReviewNote),
              message: document.reviewNote!,
              color: ColorRes.errorColor,
              icon: Icons.error_outline,
            ),
          ],
          if (document.canUpload) ...[
            14.heightSpacer,
            BaseRaisedButton(
              key: ValueKey('uploadDocument_${type.id}'),
              onPressed: () => controller.openUpload(document),
              buttonText: document.hasFile
                  ? StringRes.reuploadDocument
                  : StringRes.uploadDocument,
              buttonColor: ColorRes.primaryColor,
              textColor: ColorRes.whiteColor,
              fontWeight: FontWeight.w500,
              icon: Icon(
                Icons.upload_outlined,
                size: 18.getSize,
                color: ColorRes.whiteColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// One uploaded side, as the provider app shows them: a box with the
  /// photo (or a PDF tile) and its label; tap to open it full size.
  Widget filePreview(VendorDocumentsController controller, String url, String labelKey) {
    final isPdf = VendorDocumentsController.isPdf(url);

    return Expanded(
      child: InkWell(
        key: ValueKey('preview_$labelKey'),
        onTap: () => controller.openFile(url, photoViewer: photoViewer),
        borderRadius: BorderRadius.circular(10.getSize),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 90.getSize,
              decoration: BoxDecoration(
                color: ColorRes.backgroundColor,
                borderRadius: BorderRadius.circular(10.getSize),
                border: Border.all(color: ColorRes.borderColor),
              ),
              clipBehavior: Clip.antiAlias,
              child: isPdf
                  ? Icon(Icons.picture_as_pdf_outlined, color: ColorRes.errorColor, size: 30.getSize)
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.broken_image_outlined,
                        color: ColorRes.grayColor,
                        size: 24.getSize,
                      ),
                    ),
            ),
            6.heightSpacer,
            BaseTextDMSans(
              text: labelKey,
              fontSize: 12,
              color: ColorRes.grayColor,
            ).tr(),
          ],
        ),
      ),
    );
  }

  /// Full-screen photo with pinch-to-zoom. Dark backdrop on purpose: it is
  /// a viewer, and the photo is the only thing on it.
  Widget photoViewer(String url) {
    return Scaffold(
      backgroundColor: ColorRes.blackColor,
      appBar: AppBar(
        backgroundColor: ColorRes.blackColor,
        iconTheme: IconThemeData(color: ColorRes.whiteColor),
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => BaseTextDMSans(
              text: StringRes.somethingWentWrong,
              color: ColorRes.whiteColor,
            ).tr(),
          ),
        ),
      ),
    );
  }

  Widget detailLine(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: BaseTextDMSans(
            text: '$label: ',
            fontSize: 12,
            color: ColorRes.grayColor,
            textAlign: TextAlign.start,
            maxLines: 1,
          ),
        ),
        Flexible(
          child: BaseTextDMSans(
            text: value,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: ColorRes.secondaryColor,
            textAlign: TextAlign.start,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
