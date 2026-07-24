import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Soft glowing gradient blobs over the dark neon canvas. Purely decorative
/// — place behind screen content with `Positioned.fill` inside a `Stack`.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              top: -140,
              left: -90,
              child: _glowBlob(AppTheme.neonEmerald, 340),
            ),
            Positioned(
              top: -80,
              right: -120,
              child: _glowBlob(AppTheme.neonViolet, 300),
            ),
            Positioned(
              bottom: -160,
              left: -70,
              child: _glowBlob(AppTheme.neonCyan, 280),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glowBlob(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.24), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

/// Scales its child down slightly while pressed, for a tactile glass feel.
/// Tracks press state only — it does not own a tap callback, so it can wrap
/// an inner `InkWell`/button without double-firing that widget's `onTap`.
class PressableScale extends StatefulWidget {
  const PressableScale({super.key, required this.child});

  final Widget child;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Fades and slides [child] in shortly after mount, staggered by [index].
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 360),
    vsync: this,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 40 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fade,
      child: widget.child,
      builder: (context, child) {
        return Opacity(
          opacity: _fade.value,
          child: Transform.translate(
            offset: Offset(0, (1 - _fade.value) * 14),
            child: child,
          ),
        );
      },
    );
  }
}
