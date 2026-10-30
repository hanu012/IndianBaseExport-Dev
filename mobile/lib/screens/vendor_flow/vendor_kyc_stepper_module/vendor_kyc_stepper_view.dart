import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import '../vendor_document_upload_module/vendor_document_upload_controller.dart';
import '../vendor_document_upload_module/vendor_document_upload_view.dart';
import 'vendor_kyc_stepper_controller.dart';

/// "Document verification" stepper; see [VendorKycStepperController].
///
/// Laid out like a registration wizard: a header with a back arrow and the
/// title, a row of segmented progress bars, a "Step X of N · document"
/// line, the steps in a PageView that only moves by the buttons, and the
/// primary action pinned at the bottom.
class VendorKycStepperView extends StatelessWidget {
  /// Null for the signed-in vendor's own documents.
  final int? vendorId;

  /// Salesman only: shows "Skip for now", which just leaves.
  final bool allowSkip;

  const VendorKycStepperView({super.key, this.vendorId, this.allowSkip = false});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<VendorKycStepperController>(
      init: VendorKycStepperController(vendorId: vendorId, allowSkip: allowSkip),
      dispose: (_) => Get.delete<VendorKycStepperController>(),
      builder: (controller) {
        final ready = controller.documents != null;

        return PopScope(
          // The system back follows the header arrow: a step back, not
          // straight off the screen.
          canPop: !ready || controller.currentIndex == 0,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              controller.previousStep();
            }
          },
          child: Scaffold(
            backgroundColor: ColorRes.backgroundColor,
            resizeToAvoidBottomInset: true,
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  header(controller),
                  if (ready) ...[
                    progressBars(controller),
                    10.heightSpacer,
                    stepLine(controller),
                  ],
                  Expanded(child: ready ? pages(controller) : placeholder(controller)),
                ],
              ),
            ),
            bottomNavigationBar: ready ? bottomBar(controller) : null,
          ),
        );
      },
    );
  }

  Widget header(VendorKycStepperController controller) {
    return KycHeader(
      title: tr(StringRes.kycStepperTitle),
      backKey: const ValueKey('kycBack'),
      onBack: controller.previousStep,
    );
  }

  Widget progressBars(VendorKycStepperController controller) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.getSize, 14.getSize, 16.getSize, 0),
      child: Row(
        children: List.generate(controller.totalSteps, (index) {
          final reached = index <= controller.currentIndex;

          return Expanded(
            child: Container(
              key: ValueKey('kycProgress_$index'),
              height: 4.getSize,
              margin: EdgeInsets.only(
                right: index == controller.totalSteps - 1 ? 0 : 8.getSize,
              ),
              decoration: BoxDecoration(
                color: reached ? ColorRes.primaryColor : ColorRes.borderColor,
                borderRadius: BorderRadius.circular(4.getSize),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget stepLine(VendorKycStepperController controller) {
    final step = tr(
      StringRes.kycStepOf,
      args: ['${controller.currentIndex + 1}', '${controller.totalSteps}'],
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.getSize),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text.rich(
          key: const ValueKey('kycStepLine'),
          TextSpan(
            text: step,
            style: TextStyle(
              fontSize: 13.getFontSize,
              fontWeight: FontWeight.w600,
              color: ColorRes.primaryColor,
            ),
            children: [
              TextSpan(
                text: ' · ${controller.currentStepTitle}',
                style: TextStyle(
                  fontSize: 13.getFontSize,
                  fontWeight: FontWeight.w500,
                  color: ColorRes.secondaryColor,
                ),
              ),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget placeholder(VendorKycStepperController controller) {
    if (controller.hasError) {
      return Padding(
        padding: EdgeInsets.all(24.getSize),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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

    return Center(child: CupertinoActivityIndicator(color: ColorRes.primaryColor));
  }

  Widget pages(VendorKycStepperController controller) {
    return PageView.builder(
      controller: controller.pageController,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: controller.totalSteps,
      itemBuilder: (context, index) {
        final padding = EdgeInsets.fromLTRB(16.getSize, 18.getSize, 16.getSize, 24.getSize);

        if (index >= controller.steps.length) {
          return SingleChildScrollView(padding: padding, child: reviewStep(controller));
        }

        final document = controller.steps[index];

        return SingleChildScrollView(
          padding: padding,
          child: GetBuilder<VendorDocumentUploadController>(
            tag: controller.stepTag(document),
            // Owned by the stepper controller, not by this page: the page
            // is torn down whenever its step scrolls away.
            autoRemove: false,
            builder: (upload) => documentStep(upload),
          ),
        );
      },
    );
  }

  Widget documentStep(VendorDocumentUploadController upload) {
    // The admin's reason for a re-upload and the type's description lead
    // the form.
    return VendorDocumentUploadForm(controller: upload, showSubmit: false);
  }

  Widget reviewStep(VendorKycStepperController controller) {
    final documents = controller.documents?.documents ?? const <VendorDocumentModel>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KycBanner(message: tr(StringRes.kycReviewStepDesc)),
        16.heightSpacer,
        if (documents.isEmpty)
          BaseTextDMSans(
            text: StringRes.noDocumentTypes,
            fontSize: 14,
            color: ColorRes.grayColor,
            maxLines: 2,
          ).tr()
        else
          for (final document in documents) ...[
            reviewRow(controller, document),
            12.heightSpacer,
          ],
        8.heightSpacer,
        KycBanner(
          message: tr(StringRes.kycReviewTeamNote),
          color: ColorRes.successColor,
          icon: Icons.verified_user_outlined,
        ),
      ],
    );
  }

  Widget reviewRow(VendorKycStepperController controller, VendorDocumentModel document) {
    final type = document.documentType;
    final canAdd = !type.isCompulsory && document.canUpload;

    return KycDocumentRow(
      key: ValueKey('kycReviewRow_${type.id}'),
      document: document,
      trailing: canAdd
          ? TextButton(
              key: ValueKey('kycOptionalUpload_${type.id}'),
              onPressed: () => controller.openUpload(document),
              style: TextButton.styleFrom(
                foregroundColor: ColorRes.primaryColor,
                backgroundColor: ColorRes.primaryColor.withValues(alpha: 0.08),
                padding: EdgeInsets.symmetric(horizontal: 12.getSize, vertical: 6.getSize),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.getSize)),
              ),
              child: BaseTextDMSans(
                text: document.hasFile ? StringRes.kycReplaceDocument : StringRes.kycAddDocument,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ColorRes.primaryColor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ).tr(),
            )
          : null,
    );
  }

  Widget bottomBar(VendorKycStepperController controller) {
    final document = controller.currentDocument;

    return VendorDocumentUploadForm.submitBar(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (document == null)
            primaryButton(
              key: const ValueKey('kycSubmit'),
              label: StringRes.kycSubmitForVerification,
              onPressed: controller.submitForVerification,
            )
          else
            // Follows the current step's form, so it greys out until that
            // document has everything its type needs.
            GetBuilder<VendorDocumentUploadController>(
              key: ValueKey(controller.stepTag(document)),
              tag: controller.stepTag(document),
              autoRemove: false,
              builder: (upload) => primaryButton(
                key: const ValueKey('kycSaveContinue'),
                label: StringRes.kycSaveContinue,
                onPressed: upload.canSubmit ? controller.saveAndContinueAPI : null,
              ),
            ),
          if (controller.allowSkip)
            TextButton(
              key: const ValueKey('kycSkip'),
              onPressed: controller.skip,
              style: TextButton.styleFrom(foregroundColor: ColorRes.grayColor),
              child: BaseTextDMSans(
                text: StringRes.kycSkipForNow,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ColorRes.grayColor,
              ).tr(),
            ),
        ],
      ),
    );
  }

  Widget primaryButton({
    required Key key,
    required String label,
    required VoidCallback? onPressed,
  }) {
    final enabled = onPressed != null;

    return BaseRaisedButton(
      key: key,
      onPressed: onPressed,
      buttonText: label,
      buttonColor: enabled ? ColorRes.primaryColor : ColorRes.surfaceElevatedColor,
      textColor: enabled ? ColorRes.whiteColor : ColorRes.grayColor,
      borderColor: enabled ? null : ColorRes.borderColor,
      fontWeight: FontWeight.w500,
    );
  }
}
