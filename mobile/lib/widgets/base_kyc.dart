import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../common_model/vendor_document_model.dart';
import '../constants/color_res.dart';
import '../constants/constant.dart';
import '../constants/string_res.dart';
import 'base_text.dart';

/// The KYC document screens' shared pieces — the documents list, the
/// upload form, the "Document verification" stepper and the vendor's
/// "Documents submitted" status screen — laid out like the ehhs provider
/// app's document screens: a plain header with a centred title, document
/// cards with an icon tile, the status in its colour and a status icon,
/// and tinted info banners.
///
/// One place for a status's label, colour and icon, so a document reads
/// the same on every screen it appears on.
class KycStatus {
  KycStatus._();

  /// Translation key. Unknown values fall back to the neutral "Pending
  /// upload" rather than showing a raw API string.
  static String label(String status) {
    switch (status) {
      case VendorDocumentModel.statusUploaded:
        return StringRes.docStatusUploaded;
      case VendorDocumentModel.statusInVerification:
        return StringRes.docStatusInVerification;
      case VendorDocumentModel.statusVerified:
        return StringRes.docStatusVerified;
      case VendorDocumentModel.statusReupload:
        return StringRes.docStatusReupload;
      case VendorDocumentModel.statusExpired:
        return StringRes.docStatusExpired;
      default:
        return StringRes.docStatusPendingUpload;
    }
  }

  /// Verified green, re-upload red, expired amber; the in-flight states
  /// teal; nothing uploaded yet a neutral grey.
  static Color color(String status) {
    switch (status) {
      case VendorDocumentModel.statusVerified:
        return ColorRes.successColor;
      case VendorDocumentModel.statusReupload:
        return ColorRes.errorColor;
      case VendorDocumentModel.statusExpired:
        return ColorRes.warningColor;
      case VendorDocumentModel.statusUploaded:
      case VendorDocumentModel.statusInVerification:
        return ColorRes.primaryColor;
      default:
        return ColorRes.grayColor;
    }
  }

  static IconData icon(String status) {
    switch (status) {
      case VendorDocumentModel.statusVerified:
        return Icons.check_circle;
      case VendorDocumentModel.statusUploaded:
      case VendorDocumentModel.statusInVerification:
        return Icons.hourglass_top_rounded;
      case VendorDocumentModel.statusReupload:
        return Icons.error_outline;
      case VendorDocumentModel.statusExpired:
        return Icons.event_busy_outlined;
      default:
        return Icons.radio_button_unchecked;
    }
  }
}

/// Plain white header: back arrow, centred title, an optional action on
/// the right — the provider app's `Utils.header`.
class KycHeader extends StatelessWidget {
  const KycHeader({
    super.key,
    required this.title,
    this.onBack,
    this.backKey,
    this.trailing,
  });

  /// Already translated.
  final String title;

  /// Defaults to `Get.back`.
  final VoidCallback? onBack;
  final Key? backKey;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ColorRes.surfaceColor,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 4.getSize, vertical: 4.getSize),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: ColorRes.borderColor)),
          ),
          child: Row(
            children: [
              IconButton(
                key: backKey,
                onPressed: onBack ?? Get.back,
                icon: Icon(Icons.arrow_back, size: 22.getSize, color: ColorRes.secondaryColor),
              ),
              Expanded(
                child: BaseTextDMSans(
                  text: title,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: ColorRes.secondaryColor,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Same width as the back button, so the title stays centred.
              SizedBox(
                width: 48.getSize,
                child: trailing,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tinted banner with an icon: instructions in teal, warnings in amber,
/// the admin's reason in red, "all done" in green.
class KycBanner extends StatelessWidget {
  const KycBanner({
    super.key,
    required this.message,
    this.title,
    this.color,
    this.icon = Icons.info_outline,
    this.maxLines = 6,
  });

  /// Already translated.
  final String message;
  final String? title;

  /// Defaults to the teal accent.
  final Color? color;
  final IconData icon;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? ColorRes.primaryColor;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.getSize),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.getSize),
        border: Border.all(color: tint.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20.getSize, color: tint),
          10.widthSpacer,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  BaseTextDMSans(
                    text: title!,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tint,
                    textAlign: TextAlign.start,
                  ),
                  4.heightSpacer,
                ],
                BaseTextDMSans(
                  text: message,
                  fontSize: 13,
                  color: ColorRes.secondaryColor,
                  textAlign: TextAlign.start,
                  maxLines: maxLines,
                  lineHeight: 1.4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One document as the provider app lists it: an icon tile, the name with
/// its Required/Optional tag, the status in its colour, and the status
/// icon — or [trailing] in its place for an action ("Add").
class KycDocumentRow extends StatelessWidget {
  const KycDocumentRow({
    super.key,
    required this.document,
    this.onTap,
    this.trailing,
    this.showRequirement = true,
    this.flat = false,
  });

  final VendorDocumentModel document;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// The Required / Optional tag beside the name.
  final bool showRequirement;

  /// No border or padding of its own — for the top of a card that already
  /// has them (the documents list).
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final type = document.documentType;
    final color = KycStatus.color(document.status);

    final row = Row(
      children: [
        Container(
          height: 46.getSize,
          width: 46.getSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14.getSize),
          ),
          child: Icon(Icons.description_outlined, size: 22.getSize, color: color),
        ),
        14.widthSpacer,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BaseTextDMSans(
                text: type.name ?? '',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: ColorRes.secondaryColor,
                textAlign: TextAlign.start,
                maxLines: 2,
              ),
              4.heightSpacer,
              // Wraps: a long translated status and the tag share one line
              // only when a narrow phone has room for both.
              Wrap(
                spacing: 8.getSize,
                runSpacing: 4.getSize,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  BaseTextDMSans(
                    text: tr(KycStatus.label(document.status)),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                    textAlign: TextAlign.start,
                    maxLines: 1,
                  ),
                  if (showRequirement) _RequirementTag(compulsory: type.isCompulsory),
                ],
              ),
            ],
          ),
        ),
        8.widthSpacer,
        // Flexible: a long translated action shrinks, not the row.
        if (trailing != null)
          Flexible(child: trailing!)
        else
          Icon(KycStatus.icon(document.status), size: 22.getSize, color: color),
      ],
    );

    if (flat) {
      return row;
    }

    return Material(
      color: ColorRes.surfaceColor,
      borderRadius: BorderRadius.circular(14.getSize),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.getSize),
        child: Container(
          padding: EdgeInsets.all(12.getSize),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.getSize),
            border: Border.all(color: ColorRes.borderColor),
          ),
          child: row,
        ),
      ),
    );
  }
}

class _RequirementTag extends StatelessWidget {
  const _RequirementTag({required this.compulsory});

  final bool compulsory;

  @override
  Widget build(BuildContext context) {
    final color = compulsory ? ColorRes.primaryColor : ColorRes.grayColor;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.getSize, vertical: 2.getSize),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20.getSize),
      ),
      child: BaseTextDMSans(
        text: tr(compulsory ? StringRes.documentRequired : StringRes.documentOptional),
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: color,
        maxLines: 1,
      ),
    );
  }
}

/// A field label with a red asterisk when the field must be filled.
class KycFieldLabel extends StatelessWidget {
  const KycFieldLabel({super.key, required this.text, this.required = true});

  /// Already translated.
  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: text,
        children: [
          if (required)
            TextSpan(text: ' *', style: TextStyle(color: ColorRes.errorColor)),
        ],
      ),
      textScaler: const TextScaler.linear(0.80),
      style: TextStyle(
        fontSize: (14 + 4).getFontSize,
        fontWeight: FontWeight.w600,
        color: ColorRes.secondaryColor,
        fontFamily: FontFamily.poppins,
      ),
    );
  }
}
