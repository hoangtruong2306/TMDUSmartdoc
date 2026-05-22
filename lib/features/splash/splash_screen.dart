import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';

// ── Animation durations ──────────────────────────────────────────────────────
const _splashTotal = Duration(milliseconds: 2400);
const _bookDelay = Duration(milliseconds: 200);
const _titleDelay = Duration(milliseconds: 700);
const _taglineDelay = Duration(milliseconds: 1000);
const _loaderDelay = Duration(milliseconds: 1400);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _bookCtrl;

  @override
  void initState() {
    super.initState();
    _bookCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _navigate();
  }

  Future<void> _navigate() async {
    final results = await Future.wait([
      Future.delayed(_splashTotal),
      FirebaseAuth.instance.authStateChanges().first,
    ]);
    if (!mounted) return;
    final user = results[1] as User?;
    context.go(user != null ? '/home' : '/login');
  }

  @override
  void dispose() {
    _bookCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryDark,
              AppColors.primary,
              Color(0xFF3B82F6),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),

              // ── Book Icon with pulse + breathing ───────────────────────────
              _BookIcon(controller: _bookCtrl),

              const SizedBox(height: AppSpacing.xl),

              // ── App Name ───────────────────────────────────────────────────
              Text(
                'TDMU SmartDoc',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              )
                  .animate(delay: _titleDelay)
                  .fadeIn(duration: AppMotion.slow, curve: AppMotion.curve)
                  .slideY(
                    begin: 0.25,
                    end: 0,
                    duration: AppMotion.slow,
                    curve: AppMotion.curve,
                  )
                  .scale(
                    begin: const Offset(0.92, 0.92),
                    end: const Offset(1, 1),
                    duration: AppMotion.slow,
                    curve: AppMotion.curve,
                  ),

              const SizedBox(height: AppSpacing.sm),

              // ── Tagline ────────────────────────────────────────────────────
              Text(
                'Trợ lý Học tập AI của Bạn',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              )
                  .animate(delay: _taglineDelay)
                  .fadeIn(duration: AppMotion.normal, curve: AppMotion.curve)
                  .slideY(
                    begin: 0.2,
                    end: 0,
                    duration: AppMotion.normal,
                    curve: AppMotion.curve,
                  ),

              const Spacer(flex: 2),

              // ── Loading dots ───────────────────────────────────────────────
              _LoadingDots()
                  .animate(delay: _loaderDelay)
                  .fadeIn(duration: AppMotion.normal),

              const SizedBox(height: AppSpacing.xl + AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _BookIcon — Animated book icon with rotation + scale + glow
// ═════════════════════════════════════════════════════════════════════════════

class _BookIcon extends StatelessWidget {
  final AnimationController controller;

  const _BookIcon({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow ring (pulses)
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.06),
          ),
        )
            .animate(
              onPlay: (c) => c.repeat(reverse: true),
            )
            .scale(
              begin: const Offset(0.85, 0.85),
              end: const Offset(1.15, 1.15),
              duration: const Duration(milliseconds: 2000),
              curve: Curves.easeInOutSine,
            ),

        // Inner glow ring (pulses offset)
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.1),
          ),
        )
            .animate(
              delay: const Duration(milliseconds: 400),
              onPlay: (c) => c.repeat(reverse: true),
            )
            .scale(
              begin: const Offset(0.9, 0.9),
              end: const Offset(1.1, 1.1),
              duration: const Duration(milliseconds: 1800),
              curve: Curves.easeInOutSine,
            ),

        // Main book icon
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.2),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_stories_rounded,
            size: 44,
            color: Colors.white,
          ),
        )
            .animate(delay: _bookDelay)
            .fadeIn(duration: AppMotion.slow, curve: AppMotion.curve)
            .scale(
              begin: const Offset(0.3, 0.3),
              end: const Offset(1, 1),
              duration: AppMotion.slow,
              curve: Curves.elasticOut,
            )
            .then(delay: const Duration(milliseconds: 300))
            .rotate(
              begin: -0.05,
              end: 0.05,
              duration: const Duration(milliseconds: 3000),
              curve: Curves.easeInOutSine,
            )
            .animate(
              onPlay: (c) => c.repeat(reverse: true),
            )
            .rotate(
              begin: 0.05,
              end: -0.05,
              duration: const Duration(milliseconds: 3000),
              curve: Curves.easeInOutSine,
            ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _LoadingDots — Bouncing dots loader
// ═════════════════════════════════════════════════════════════════════════════

class _LoadingDots extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            shape: BoxShape.circle,
          ),
        )
            .animate(
              delay: Duration(milliseconds: i * 150),
              onPlay: (c) => c.repeat(reverse: true),
            )
            .scale(
              begin: const Offset(0.5, 0.5),
              end: const Offset(1.2, 1.2),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOutQuad,
            )
            .fade(
              begin: 0.4,
              end: 1.0,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOutQuad,
            );
      }),
    );
  }
}
