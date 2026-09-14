import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:chess_master/models/bot_profile.dart';

/// Animated, theme-rich character avatar for Chess.com-style bots
class BotAvatar extends StatefulWidget {
  final BotProfile bot;
  final double size;
  final int stars; // 0: not beaten, 1-3: stars
  final bool showElo;
  final bool animateGlow;
  final VoidCallback? onTap;

  const BotAvatar({
    super.key,
    required this.bot,
    this.size = 64,
    this.stars = 0,
    this.showElo = true,
    this.animateGlow = false,
    this.onTap,
  });

  @override
  State<BotAvatar> createState() => _BotAvatarState();
}

class _BotAvatarState extends State<BotAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _glowAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    if (widget.animateGlow || widget.bot.tier == BotTier.master) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant BotAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animateGlow && !_glowController.isAnimating) {
      _glowController.repeat(reverse: true);
    } else if (!widget.animateGlow &&
        widget.bot.tier != BotTier.master &&
        _glowController.isAnimating) {
      _glowController.stop();
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tier = widget.bot.tier;
    final primaryColor = tier.color;

    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Animated Tier Glow (for Master bots or selected state)
              if (widget.animateGlow || widget.bot.tier == BotTier.master)
                AnimatedBuilder(
                  animation: _glowAnimation,
                  builder: (context, child) {
                    return Container(
                      width: widget.size * _glowAnimation.value,
                      height: widget.size * _glowAnimation.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.35),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    );
                  },
                ),

              // Outer Ring Container
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      primaryColor,
                      primaryColor.withValues(alpha: 0.6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(2.5),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: widget.bot.avatarGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      widget.bot.avatarIcon,
                      size: widget.size * 0.52,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // Crown Stars Badge (if beaten)
              if (widget.stars > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB300),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        widget.stars,
                        (index) => const Icon(
                          Icons.star_rounded,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // ELO Badge Pill
          if (widget.showElo) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.5),
                  width: 0.8,
                ),
              ),
              child: Text(
                '${widget.bot.elo}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
