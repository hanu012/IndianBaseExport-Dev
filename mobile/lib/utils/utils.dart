import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/color_res.dart';
import '../constants/constant.dart';
import '../constants/pref_keys.dart';
import '../constants/string_res.dart';
import '../network/data_source.dart';
import '../widgets/base_text.dart';
import 'injector.dart';

/// Shared helpers. Trimmed to what the app actually uses — the demo-app's
/// 2,228-line Utils also carried image picking, webview, audio and Firebase
/// helpers that this project has no use for yet. Add helpers here as screens
/// genuinely need them, rather than porting speculatively.
class Utils {
  /// Navigator key, also used by [getSize] to tell whether the widget tree is
  /// mounted yet.
  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  /// The languages the admin has switched on (Settings → App). Falls back
  /// to every bundled language if the server can't be reached, so the
  /// picker still works offline.
  /// Reads the admin's app switches from GET settings and remembers them
  /// on the device. Called without awaiting at startup, so a slow or
  /// failed request just keeps the last known values.
  static Future<void> refreshAppSettings() async {
    try {
      final response = await DataSource.instance.settingsAPI();

      if (!(response?.isSuccess ?? false) || response!.data is! Map<String, dynamic>) {
        return;
      }

      final data = response.data as Map<String, dynamic>;
      final callTracking = data['call_tracking_enabled'];

      if (callTracking is bool) {
        Injector.callTrackingEnabled = callTracking;
        await Injector.prefs?.setBool(PrefKeys.callTrackingEnabled, callTracking);
      }

      final answerDetection = data['call_answer_detection_enabled'];

      if (answerDetection is bool) {
        Injector.callAnswerDetectionEnabled = answerDetection;
        await Injector.prefs?.setBool(PrefKeys.callAnswerDetectionEnabled, answerDetection);
      }

      final mapLocation = data['customer_map_location_enabled'];

      if (mapLocation is bool) {
        Injector.mapLocationEnabled = mapLocation;
        await Injector.prefs?.setBool(PrefKeys.customerMapLocationEnabled, mapLocation);
      }
    } catch (e) {
      if (kDebugMode) {
        print('App settings error $e');
      }
    }
  }

  /// "~3 min" / "<1 min" for an approximate call length; empty when there
  /// is none (WhatsApp, or not reported).
  static String approxCallLength(int? seconds) {
    if (seconds == null) {
      return '';
    }

    final unit = tr(StringRes.minutesShort);

    if (seconds < 60) {
      return '<1 $unit';
    }

    return '~${(seconds / 60).round()} $unit';
  }

  /// How a call went, for the call lists: "Answered · 3 min" or "Not
  /// answered" when the vendor app confirmed it (CallOutcomeMatcher), else
  /// the approximate length ("~3 min"), else empty.
  static String callLabel({
    String? outcome,
    int? talkSeconds,
    int? approxSeconds,
  }) {
    if (outcome == 'not_answered') {
      return tr(StringRes.callNotAnswered);
    }

    if (outcome == 'answered') {
      if (talkSeconds == null) {
        return tr(StringRes.callAnswered);
      }

      final unit = tr(StringRes.minutesShort);
      final length = talkSeconds < 60 ? '<1 $unit' : '${(talkSeconds / 60).round()} $unit';

      return '${tr(StringRes.callAnswered)} · $length';
    }

    return approxCallLength(approxSeconds);
  }

  static Future<List<String>> enabledLanguages() async {
    try {
      final response = await DataSource.instance.settingsAPI();
      final codes = (response?.isSuccess ?? false)
          ? (response!.data as Map<String, dynamic>)['enabled_languages']
          : null;

      if (codes is List) {
        final enabled = codes
            .whereType<String>()
            .where(Constants.languages.containsKey)
            .toList();

        if (enabled.isNotEmpty) {
          return enabled;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Enabled languages error $e');
      }
    }

    return Constants.languages.keys.toList();
  }

  /// Moves the app back to English if the admin has since switched off
  /// the language it is using. Called once at startup, off the critical
  /// path — the app opens in the saved language either way.
  static Future<void> enforceEnabledLanguage() async {
    if (Injector.language == Constants.english) {
      return;
    }

    final enabled = await enabledLanguages();

    if (!enabled.contains(Injector.language)) {
      await applyLanguage(Constants.english);
    }
  }

  /// Switches every screen to [code] and remembers it on this device.
  /// The device copy is the one that decides the next launch; the server
  /// copy (PATCH user/preferences) is saved by the caller, best-effort.
  static Future<void> applyLanguage(String code) async {
    if (!Constants.languages.containsKey(code)) {
      return;
    }

    await Injector.setLanguage(code);

    final context = key.currentContext;
    if (context != null && context.mounted) {
      await context.setLocale(Locale(code));
    }

    await Get.updateLocale(Locale(code));
  }

  static double getScreenWidth(BuildContext context) => Get.width;

  static double getScreenHeight(BuildContext context) => Get.height;

  static String getAssetsImg(String name) => 'assets/images/$name.png';

  static String getAssetsSVGImg(String name) => 'assets/images/$name.svg';

  /// Scales a design-pixel value against a 414pt-wide reference device.
  ///
  /// Returns the raw value before the navigator is mounted, because Get.width
  /// is not available then.
  static double getSize(double px) {
    // The navigator check must come FIRST and stay a separate statement:
    // Get.width throws outside a running app (it null-checks the view), so
    // reading it before this guard breaks every widget test that builds a
    // Base* widget without pumping a GetMaterialApp.
    if (Utils.key.currentState == null) {
      return px;
    }

    // Even with a navigator mounted, Get.width is 0 until the platform
    // reports a surface size, which lands after the warm-up frame. Scaling
    // by 0 collapses every sized value — which asserts on params that
    // require a positive number (IconButton.splashRadius) and silently
    // disappears everywhere else.
    final width = Get.width;

    return width > 0 ? px * (width / 414) : px;
  }

  /// Font sizes scale more gently than layout so text stays legible on small
  /// screens without overflowing on large ones.
  static double getFontSize(double px) {
    // Same ordering requirement as getSize() above.
    if (Utils.key.currentState == null) {
      return px;
    }

    final width = Get.width;

    if (width <= 0) {
      return px;
    }

    // The trailing +2 matches the provider app's getFontSize, so the same
    // design size renders the same in both apps. The clamp stays as a
    // guard for tablets and wide web frames, where the provider's
    // unclamped formula grows text without limit.
    return px * (width / 414).clamp(0.85, 1.15) + 2;
  }

  /// Blocking progress overlay.
  ///
  /// Named for the demo-app's Lottie-based original, but that implementation
  /// also used a CupertinoActivityIndicator — no Lottie asset was ever
  /// involved. The name is kept so ported screens compile unchanged.
  ///
  /// Call with `true` before an API call and `false` after, always in a
  /// try/catch so a thrown request cannot strand the dialog on screen.
  static void showCircularProgressLottie(bool isLoading) {
    if (!isLoading) {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }
      return;
    }

    Get.dialog(
      AlertDialog(
        backgroundColor: ColorRes.transparent,
        contentPadding: EdgeInsets.zero,
        elevation: 0.0,
        content: Center(
          child: CupertinoActivityIndicator(
            color: ColorRes.primaryColor,
            radius: 16.getSize,
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  /// Replaces the whole navigation stack — used after sign-in and sign-out.
  static void transitionWithOffAll(
    dynamic page, {
    dynamic argument,
    Function? voidCallback,
    Transition? transition,
  }) {
    if (kDebugMode) {
      print('IN OFF ALL FUNCTION UTILS');
    }

    Get.offAll(
      page,
      transition: transition ?? Transition.fadeIn,
      duration: const Duration(milliseconds: 300),
      arguments: argument,
    )?.then((value) {
      if (voidCallback != null) {
        voidCallback(value ?? '');
      }
    });
  }

  /// Yes/no before something hard to undo — signing out, deleting the
  /// account. True only when the user taps [confirmLabel]; Cancel, a tap
  /// outside or the back button all mean no.
  ///
  /// Goes through [confirmFn] so tests, which have no dialog to tap, can
  /// answer it.
  static Future<bool> confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) =>
      confirmFn(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        destructive: destructive,
      );

  /// Swappable seam for tests — see [confirm].
  static Future<bool> Function({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive,
  }) confirmFn = _confirmDialog;

  static Future<bool> _confirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: ColorRes.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.getSize)),
        title: BaseTextDMSans(
          text: title,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: ColorRes.secondaryColor,
          textAlign: TextAlign.start,
        ),
        content: BaseTextDMSans(
          text: message,
          fontSize: 13,
          color: ColorRes.grayColor,
          textAlign: TextAlign.start,
          maxLines: 6,
        ),
        actions: [
          TextButton(
            key: const ValueKey('confirmCancel'),
            onPressed: () => Get.back(result: false),
            child: BaseTextDMSans(
              text: tr(StringRes.cancel),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ColorRes.grayColor,
            ),
          ),
          TextButton(
            key: const ValueKey('confirmOk'),
            onPressed: () => Get.back(result: true),
            child: BaseTextDMSans(
              text: confirmLabel,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: destructive ? ColorRes.errorColor : ColorRes.primaryColor,
            ),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  /// "Sign out?" — shared by every app's sign-out button.
  static Future<bool> confirmSignOut() => confirm(
        title: tr(StringRes.confirmSignOutTitle),
        message: tr(StringRes.confirmSignOutMessage),
        confirmLabel: tr(StringRes.logout),
        destructive: true,
      );

  /// Every message in the apps: a card at the foot of the screen — round
  /// status icon (green tick / red "!"), the message in bold and, with
  /// [title], the message under the title in muted ink. No Retry and no
  /// close button (decided 2026-11-01): it slides away after 3 s or on a
  /// swipe.
  static void showToast(String message, {bool isError = false, String? title}) {
    // No navigator yet (or a widget test without one): nothing to show on.
    if (Get.overlayContext == null) {
      return;
    }

    final color = isError ? ColorRes.errorColor : ColorRes.successColor;

    try {
      Get.closeCurrentSnackbar();
      Get.showSnackbar(
        GetSnackBar(
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.transparent,
          padding: EdgeInsets.zero,
          margin: EdgeInsets.fromLTRB(16.getSize, 0, 16.getSize, 16.getSize),
          duration: const Duration(seconds: 3),
          isDismissible: true,
          dismissDirection: DismissDirection.horizontal,
          animationDuration: const Duration(milliseconds: 250),
          messageText: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.getSize, vertical: 12.getSize),
            decoration: BoxDecoration(
              // A light tint of the status colour over the card white, with
              // a matching border — the light-theme take on the design.
              color: Color.alphaBlend(color.withValues(alpha: 0.08), ColorRes.surfaceColor),
              borderRadius: BorderRadius.circular(14.getSize),
              border: Border.all(color: color.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(color: ColorRes.secondaryColor.withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  height: 30.getSize,
                  width: 30.getSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Icon(
                    isError ? Icons.priority_high_rounded : Icons.check_rounded,
                    size: 18.getSize,
                    color: ColorRes.whiteColor,
                  ),
                ),
                12.widthSpacer,
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BaseTextDMSans(
                        text: title ?? message,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ColorRes.secondaryColor,
                        textAlign: TextAlign.start,
                        maxLines: 3,
                      ),
                      if (title != null) ...[
                        2.heightSpacer,
                        BaseTextDMSans(
                          text: message,
                          fontSize: 11,
                          color: ColorRes.grayColor,
                          textAlign: TextAlign.start,
                          maxLines: 4,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Show toast error $e');
      }
    }
  }

  /// Shared chrome for the auth screens: a coloured header carrying the title,
  /// description and optional Skip action, with the screen's own fields
  /// scrolling underneath.
  ///
  /// The demo-app painted this header with an `assets/images/blue_bg.png`
  /// bitmap. That asset is light-blue branding and does not exist here, so the
  /// header is a teal-to-slate gradient instead — same layout, no asset, and
  /// it recolours with the palette rather than needing a new export.
  /// Paise → "₹1,234.50".
  ///
  /// Money is stored as integer paise everywhere (CLAUDE.md), so every
  /// screen that shows an amount has to divide by 100 — doing it inline is
  /// how two screens end up disagreeing about the same figure.
  static String rupees(int paise) {
    final rupees = paise / 100;
    final fixed = rupees.toStringAsFixed(2);
    final parts = fixed.split('.');

    return '₹${_withThousandsSeparators(parts[0])}.${parts[1]}';
  }

  /// Paise → "₹2,499", dropping a zero paise part.
  ///
  /// Plan prices are whole rupees in practice and the headline figure on a
  /// pricing card reads better without a permanent ".00" hanging off it.
  /// A price that genuinely has paise still shows them rather than being
  /// silently rounded — a wrong price is worse than an untidy one.
  static String rupeesWhole(int paise) {
    if (paise % 100 != 0) {
      return rupees(paise);
    }

    return '₹${_withThousandsSeparators((paise ~/ 100).toString())}';
  }

  /// Paise → "₹12k" for a stat tile, where the exact figure matters less
  /// than fitting in the box. Falls back to the full form under ₹1,000.
  static String compactRupees(int paise) {
    final rupees = paise / 100;

    if (rupees >= 10000000) {
      return '₹${(rupees / 10000000).toStringAsFixed(1)}Cr';
    }
    if (rupees >= 100000) {
      return '₹${(rupees / 100000).toStringAsFixed(1)}L';
    }
    if (rupees >= 1000) {
      return '₹${(rupees / 1000).toStringAsFixed(rupees % 1000 == 0 ? 0 : 1)}k';
    }

    return '₹${rupees.toStringAsFixed(0)}';
  }

  /// Indian grouping — 12,34,567 rather than 1,234,567: the last three
  /// digits, then twos.
  static String _withThousandsSeparators(String digits) {
    if (digits.length <= 3) {
      return digits;
    }

    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final groups = <String>[];

    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }

    if (rest.isNotEmpty) {
      groups.insert(0, rest);
    }

    return '${groups.join(',')},$last3';
  }

  static Widget authLayout({
    required Widget contentWidget,
    required String title,
    required String desc,
    required bool isLogin,
    required bool skipTap,
    required bool isForCustomer,
    required void Function()? onSkipTap,
    EdgeInsetsGeometry? contentPadding,
  }) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: 200.getSize),
          padding: EdgeInsets.only(
            left: 24.getSize,
            right: 24.getSize,
            top: 20.getSize,
            bottom: 26.getSize,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              // Stays dark end to end: the title and subtitle are white,
              // and the old fade to the white surface swallowed them.
              colors: [
                ColorRes.primaryColor,
                ColorRes.primaryColorDark,
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (skipTap) ...[
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: Icon(
                      Icons.arrow_back,
                      size: 24.getSize,
                      color: ColorRes.whiteColor,
                    ),
                  ),
                  10.heightSpacer,
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: BaseTextDMSans(
                        text: title,
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                        color: ColorRes.whiteColor,
                        textAlign: TextAlign.start,
                        maxLines: 2,
                      ).tr(),
                    ),
                    if (!skipTap && onSkipTap != null)
                      Padding(
                        padding: EdgeInsets.only(top: 10.getSize),
                        child: InkWell(
                          // The demo-app hardcoded its own landing page here
                          // and ignored the onSkipTap parameter. Honouring the
                          // callback keeps this reusable across the three
                          // flavours, which land on different screens.
                          onTap: () {
                            Injector.skipTap = true;
                            Injector.prefs?.setBool(PrefKeys.skipTap, true);
                            onSkipTap();
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.getSize,
                              vertical: 4.getSize,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8.getSize),
                              color: ColorRes.whiteColor,
                            ),
                            child: BaseTextDMSans(
                              text: StringRes.skip,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              color: ColorRes.primaryColorDark,
                            ).tr(),
                          ),
                        ),
                      ),
                  ],
                ),
                8.heightSpacer,
                BaseTextDMSans(
                  text: desc,
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                  color: ColorRes.whiteColor.withValues(alpha: 0.85),
                  textAlign: TextAlign.start,
                  maxLines: 3,
                ).tr(),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: contentPadding ??
                EdgeInsets.only(
                  left: 24.getSize,
                  right: 24.getSize,
                  top: 40.getSize,
                  bottom: 40.getSize,
                ),
            child: contentWidget,
          ),
        ),
      ],
    );
  }
}
