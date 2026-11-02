import 'package:easy_localization/easy_localization.dart';

import '../../../constants/app.export.dart';
import '../../../constants/constant.dart';
import 'splash_controller.dart';

/// Brand splash shared by all three flavours (feed-redesign.html, "Splash
/// screen"): a radial petrol-teal glow with three soft rings pulsing out
/// from behind the app's icon; the icon pops in, then the name, strapline
/// and three tags rise into place; a gold loading bar and the version sit
/// at the foot.
///
/// White text is correct here — the splash is a dark surface (CLAUDE.md,
/// Theme). The animations are decorative and switch off when the system
/// asks for reduced motion.
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  /// The CSS cubic-bezier(.2,.8,.2,1) every motion in the design uses.
  static const Curve ease = Cubic(0.2, 0.8, 0.2, 1);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<SplashController>(
      init: SplashController(),
      dispose: (_) => Get.delete<SplashController>(),
      builder: (controller) {
        final still = MediaQuery.of(context).disableAnimations;

        return Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.24),
                radius: 1.1,
                colors: [ColorRes.splashGlow, ColorRes.splashMid, ColorRes.splashDeep],
                stops: const [0, 0.55, 1],
              ),
            ),
            child: Stack(
              children: [
                // The content block centred on the screen, nudged 40 px up
                // (the design's margin-top: -40px). The rings are drawn
                // around the logo inside it, so they always share its centre.
                Center(
                  child: Transform.translate(
                    offset: Offset(0, -40.getSize),
                    child: _SplashEntrance(
                      still: still,
                      rings: _SplashRings(still: still),
                      logo: logo(controller),
                      title: BaseTextDMSans(
                        text: tr(controller.brandTitle),
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: ColorRes.whiteColor,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                      subtitle: BaseTextDMSans(
                        text: tr(controller.brandSubtitle),
                        fontSize: 14,
                        color: ColorRes.whiteColor.withValues(alpha: 0.72),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                      ),
                      tags: Wrap(
                        spacing: 6.getSize,
                        runSpacing: 6.getSize,
                        alignment: WrapAlignment.center,
                        children: [for (final tag in controller.brandTags) tagPill(tr(tag))],
                      ),
                    ),
                  ),
                ),
                // Loading bar and version, 44 px above the bottom edge.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 44.getSize),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SplashLoadingBar(still: still),
                          14.heightSpacer,
                          BaseTextDMSans(
                            text: tr(StringRes.splashVersion, args: [SplashController.appVersion]),
                            fontSize: 10,
                            color: ColorRes.whiteColor.withValues(alpha: 0.72),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The app's icon on a white rounded tile, with a deep shadow and a faint
  /// white halo; the plain icon if the image cannot load.
  Widget logo(SplashController controller) {
    final size = 132.getSize;
    final radius = BorderRadius.circular(30.getSize);

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: ColorRes.whiteColor,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 48.getSize,
            offset: Offset(0, 24.getSize),
            spreadRadius: -12.getSize,
          ),
          BoxShadow(color: ColorRes.whiteColor.withValues(alpha: 0.08), spreadRadius: 6.getSize),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Transform.scale(
          scale: 1.04,
          child: Image.asset(
            controller.brandImage,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Center(
              child: Icon(controller.brandIcon, size: 56.getSize, color: ColorRes.primaryColor),
            ),
          ),
        ),
      ),
    );
  }

  Widget tagPill(String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.getSize, vertical: 5.getSize),
      decoration: BoxDecoration(color: ColorRes.whiteColor.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20.getSize)),
      child: BaseTextDMSans(text: label, fontSize: 10, fontWeight: FontWeight.w600, color: ColorRes.whiteColor),
    );
  }
}

/// Three thin white rings (220, 320, 440 across) that grow from 60% to 110%
/// while fading in then out, 2.4 s each, 0.3 s apart, forever.
class _SplashRings extends StatefulWidget {
  const _SplashRings({required this.still});

  final bool still;

  @override
  State<_SplashRings> createState() => _SplashRingsState();
}

class _SplashRingsState extends State<_SplashRings> with SingleTickerProviderStateMixin {
  static const double cycleSeconds = 2.4;

  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void initState() {
    super.initState();
    if (!widget.still) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.still) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => SizedBox(
        width: 440.getSize * 1.1,
        height: 440.getSize * 1.1,
        child: Stack(alignment: Alignment.center, children: [ring(220, 0), ring(320, 0.3), ring(440, 0.6)]),
      ),
    );
  }

  Widget ring(double diameter, double delaySeconds) {
    // Where this ring is in its own 2.4 s cycle, 0..1.
    final phase = ((_controller.value * cycleSeconds - delaySeconds) / cycleSeconds) % 1.0;
    final grown = SplashView.ease.transform(phase);
    // 0 → 1 over the first 30%, then back to 0.
    final opacity = phase < 0.3 ? phase / 0.3 : 1 - (phase - 0.3) / 0.7;

    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 0.6 + 0.5 * grown,
        child: Container(
          width: diameter.getSize,
          height: diameter.getSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ColorRes.whiteColor.withValues(alpha: 0.08)),
          ),
        ),
      ),
    );
  }
}

/// The logo pops in (0.8 → 1.04 → 1, fading in), then the title, strapline
/// and tags rise 10 px and fade in, one after another — about 1.2 s in all.
class _SplashEntrance extends StatefulWidget {
  const _SplashEntrance({
    required this.still,
    required this.rings,
    required this.logo,
    required this.title,
    required this.subtitle,
    required this.tags,
  });

  final bool still;

  /// Drawn centred on the logo, overflowing it, and not part of its pop-in.
  final Widget rings;
  final Widget logo;
  final Widget title;
  final Widget subtitle;
  final Widget tags;

  @override
  State<_SplashEntrance> createState() => _SplashEntranceState();
}

class _SplashEntranceState extends State<_SplashEntrance> with SingleTickerProviderStateMixin {
  static const double totalMs = 1180;

  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1180));

  @override
  void initState() {
    super.initState();
    widget.still ? _controller.value = 1 : _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 0..1 progress of a step that starts at [startMs] and lasts [lengthMs].
  double step(double startMs, double lengthMs) {
    final ms = _controller.value * totalMs;

    return ((ms - startMs) / lengthMs).clamp(0.0, 1.0);
  }

  Widget rise(Widget child, double startMs) {
    final t = SplashView.ease.transform(step(startMs, 500));

    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 10.getSize * (1 - t)), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Logo: 100–800 ms; overshoots to 1.04 at 60%, settles at 1.
        final logoT = step(100, 700);
        final popIn = SplashView.ease.transform((logoT / 0.6).clamp(0.0, 1.0));
        final settle = logoT <= 0.6 ? 0.0 : SplashView.ease.transform((logoT - 0.6) / 0.4);
        final scale = logoT <= 0.6 ? 0.8 + 0.24 * popIn : 1.04 - 0.04 * settle;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.getSize),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // A logo-sized box the rings overflow, centred on it — the
                  // rings never push the layout around.
                  SizedBox(
                    width: 132.getSize,
                    height: 132.getSize,
                    child: OverflowBox(maxWidth: 484.getSize, maxHeight: 484.getSize, child: widget.rings),
                  ),
                  Opacity(
                    opacity: popIn,
                    child: Transform.scale(scale: scale, child: widget.logo),
                  ),
                ],
              ),
              28.heightSpacer,
              rise(widget.title, 450),
              6.heightSpacer,
              rise(widget.subtitle, 560),
              18.heightSpacer,
              rise(widget.tags, 680),
            ],
          ),
        );
      },
    );
  }
}

/// 120 × 4 track with a gold segment (40% wide) sliding across, 1.2 s a pass.
class _SplashLoadingBar extends StatefulWidget {
  const _SplashLoadingBar({required this.still});

  final bool still;

  @override
  State<_SplashLoadingBar> createState() => _SplashLoadingBarState();
}

class _SplashLoadingBarState extends State<_SplashLoadingBar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void initState() {
    super.initState();
    if (!widget.still) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = 120.getSize;
    final segment = width * 0.4;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4.getSize),
      child: Container(
        width: width,
        height: 4.getSize,
        color: ColorRes.whiteColor.withValues(alpha: 0.15),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // translateX(-100%) → translateX(250%) of the segment's own width.
            final t = Curves.easeInOut.transform(_controller.value);
            final left = widget.still ? (width - segment) / 2 : segment * (-1 + 3.5 * t);

            return Stack(
              children: [
                Positioned(
                  left: left,
                  top: 0,
                  bottom: 0,
                  width: segment,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: ColorRes.splashGold, borderRadius: BorderRadius.circular(4.getSize)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
