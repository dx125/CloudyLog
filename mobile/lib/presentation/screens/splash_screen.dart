import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../branding/gust.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/puff_theme.dart';

/// The launch splash (Design Book §09): Gust floating above the wordmark and
/// tagline, with three pulsing loading dots low on the screen. It is the
/// brand's handshake — calm, never busy, and never making the user wait longer
/// than the app actually needs.
///
/// This is *stage two*: the in-app widget shown while local initialization runs
/// (opening Drift, migrations, warming the last-7-days cache, entitlement
/// state). The static native launch image (`flutter_native_splash`) is stage
/// one; [SplashGate] decides whether stage two is ever visible.
///
/// Motion is deliberately withheld for the first [_dotsRevealDelay]: Gust and
/// the wordmark are drawn immediately (seamless with the static native image),
/// and the loading dots + float only appear once we know init is taking a
/// moment — a static spinner-like dot reads as broken rather than idle.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// Below this, init is fast enough that the loading affordance never shows.
  static const _dotsRevealDelay = Duration(milliseconds: 300);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Gust's 4.5 s breath.
  late final AnimationController _float;
  // The three-dot pulse: 1.4 s cycle, 200 ms stagger per dot.
  late final AnimationController _dots;

  Timer? _revealTimer;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    // Eagerly created (not lazily in build) so dispose never triggers an
    // ancestor lookup while the element is being torn down.
    _float = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );
    _dots = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _revealTimer = Timer(SplashScreen._dotsRevealDelay, () {
      if (!mounted) return;
      setState(() => _revealed = true);
      _float.repeat(reverse: true);
      _dots.repeat();
    });
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    _float.dispose();
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final puff = context.puff;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reducedMotion = MediaQuery.of(context).disableAnimations;

    // Splash palette straight from the design book's §09 exports.
    final body = dark ? PuffPalette.mintBright : PuffPalette.deepTeal;
    final face = dark ? PuffPalette.inkDeep : PuffPalette.cloud;
    final wordmark = body;
    final tagline = dark ? PuffPalette.mintSoft : PuffPalette.teal;
    final dotColor = dark ? PuffPalette.teal : PuffPalette.mintBright;

    return Semantics(
      label: strings.appTitle,
      child: Container(
        color: puff.canvas,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Gust sits at roughly a quarter of screen height, centered.
              final gustSize = math.min(
                constraints.maxWidth * 0.58,
                constraints.maxHeight * 0.42,
              );
              return Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _FloatingSplashGust(
                          controller: _float,
                          animate: _revealed && !reducedMotion,
                          amplitude: gustSize * 0.045,
                          child: Gust(
                            body: body,
                            face: face,
                            gustLines: true,
                            size: gustSize,
                          ),
                        ),
                        SizedBox(height: gustSize * 0.06),
                        Text(
                          strings.appTitle,
                          style: GoogleFonts.baloo2(
                            fontWeight: FontWeight.w700,
                            fontSize: gustSize * 0.26,
                            height: 1.0,
                            color: wordmark,
                          ),
                        ),
                        SizedBox(height: gustSize * 0.02),
                        Text(
                          strings.splashTagline,
                          style: GoogleFonts.baloo2(
                            fontWeight: FontWeight.w600,
                            fontSize: gustSize * 0.085,
                            color: tagline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Loading dots, low on the screen — animated stage only.
                  if (_revealed)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: constraints.maxHeight * 0.12,
                      child: _LoadingDots(
                        controller: _dots,
                        color: dotColor,
                        animate: !reducedMotion,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Gust bobbing on the splash. Larger amplitude than the home-screen bob, and
/// only while [animate] (reveal delay passed, reduced-motion off).
class _FloatingSplashGust extends StatelessWidget {
  const _FloatingSplashGust({
    required this.controller,
    required this.animate,
    required this.amplitude,
    required this.child,
  });

  final AnimationController controller;
  final bool animate;
  final double amplitude;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!animate) return child;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -amplitude * Curves.easeInOut.transform(controller.value)),
        child: child,
      ),
      child: child,
    );
  }
}

/// Three dots pulsing in opacity and lift, staggered 200 ms apart (Design Book
/// §09). Under reduced motion they hold steady — the brand's only loading
/// indicator, never a spinner or bar.
class _LoadingDots extends StatelessWidget {
  const _LoadingDots({
    required this.controller,
    required this.color,
    required this.animate,
  });

  final AnimationController controller;
  final Color color;
  final bool animate;

  static const _count = 3;
  static const _staggerFraction = 0.2 / 1.4; // 200 ms of the 1.4 s cycle.

  @override
  Widget build(BuildContext context) {
    if (!animate) {
      return _row([for (var i = 0; i < _count; i++) _dot(1, 0)]);
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final dots = <Widget>[];
        for (var i = 0; i < _count; i++) {
          final phase = (controller.value - i * _staggerFraction) % 1.0;
          // 0 → 1 → 0 pulse.
          final pulse = 0.5 - 0.5 * math.cos(2 * math.pi * phase);
          dots.add(_dot(0.35 + 0.65 * pulse, -6.0 * pulse));
        }
        return _row(dots);
      },
    );
  }

  Widget _row(List<Widget> dots) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < dots.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            dots[i],
          ],
        ],
      );

  Widget _dot(double opacity, double dy) => Transform.translate(
        offset: Offset(0, dy),
        child: Opacity(
          opacity: opacity,
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      );
}

/// Gates the app behind the launch splash. Shows [SplashScreen] while
/// [initialization] (local-only work) runs, then hands off to [child].
///
/// Timing is minimum-not-maximum: if init finishes within [_skipThreshold],
/// stage two's visible frame is skipped entirely and we cut straight to the
/// home screen. If it takes longer, the splash is already showing and simply
/// continues until ready, then Gust floats up and off the top over 300 ms while
/// the home screen cross-fades in beneath him — the one moment the mascot and
/// the core loop visually connect. Under reduced motion the float-up is
/// replaced by a 150 ms opacity cross-fade.
///
/// The splash is never gated on the network: account sync, world averages and
/// entitlement refresh all happen after home is visible, never before.
class SplashGate extends StatefulWidget {
  const SplashGate({
    super.key,
    required this.initialization,
    required this.child,
    this.skipThreshold = const Duration(milliseconds: 300),
  });

  final Future<void> initialization;
  final Widget child;

  /// Below this elapsed time, stage two's animated frame is skipped and we cut
  /// straight to [child]. Exposed for deterministic tests.
  @visibleForTesting
  final Duration skipThreshold;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

enum _Phase { showing, exiting, done }

class _SplashGateState extends State<SplashGate>
    with SingleTickerProviderStateMixin {
  final Stopwatch _elapsed = Stopwatch()..start();
  final GlobalKey _splashKey = GlobalKey();
  late final Widget _splash = SplashScreen(key: _splashKey);
  late final AnimationController _exit;

  _Phase _phase = _Phase.showing;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    // Eagerly created so dispose never lazily builds a ticker (which would look
    // up an ancestor mid-teardown) on the fast-boot path that skips the exit.
    _exit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    widget.initialization
        .then((_) => _onReady())
        .catchError((_) => _onReady());
  }

  void _onReady() {
    if (!mounted || _phase != _Phase.showing) return;
    _reducedMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    // Fast boot: never show stage two's animated frame — cut to home.
    if (_elapsed.elapsed < widget.skipThreshold) {
      setState(() => _phase = _Phase.done);
      return;
    }

    _exit.duration = Duration(milliseconds: _reducedMotion ? 150 : 300);
    setState(() => _phase = _Phase.exiting);
    _exit.forward().whenComplete(() {
      if (mounted) setState(() => _phase = _Phase.done);
    });
  }

  @override
  void dispose() {
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _Phase.done) return widget.child;
    if (_phase == _Phase.showing) return _splash;

    // Exiting: home cross-fades in while Gust floats up and off the top.
    final curve = CurvedAnimation(parent: _exit, curve: Curves.easeIn);
    final fadeOut = Tween<double>(begin: 1, end: 0).animate(curve);
    final slideUp = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -1),
    ).animate(curve);

    Widget exitingSplash = FadeTransition(opacity: fadeOut, child: _splash);
    if (!_reducedMotion) {
      exitingSplash =
          SlideTransition(position: slideUp, child: exitingSplash);
    }

    return Stack(
      children: [
        Positioned.fill(
          child: FadeTransition(opacity: curve, child: widget.child),
        ),
        Positioned.fill(child: IgnorePointer(child: exitingSplash)),
      ],
    );
  }
}
