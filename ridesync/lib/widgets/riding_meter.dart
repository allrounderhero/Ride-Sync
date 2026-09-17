import 'dart:math';
import 'package:flutter/material.dart';

/// Professional Superbike / EV Riding Meter
/// Combines an illuminated 270° Analog Speedometer Dial
/// with an integrated High-Contrast Digital Cockpit Display.
class RidingMeter extends StatelessWidget {
  final double speed; // Current speed in km/h (0 - 140+)
  final double maxGaugeSpeed; // Maximum scale for analog gauge, default 140
  final double acceleration; // Current acceleration in m/s²
  final double powerScore; // 0 - 100%
  final bool isEcoMode; // Eco vs Power/Sport mode
  final bool isRiding; // Whether ride is active
  final double tripDistance; // Current trip in km

  const RidingMeter({
    super.key,
    required this.speed,
    this.maxGaugeSpeed = 140.0,
    required this.acceleration,
    required this.powerScore,
    required this.isEcoMode,
    required this.isRiding,
    required this.tripDistance,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = isEcoMode ? const Color(0xFF00E676) : const Color(0xFFFF3D00);
    final secondaryColor = isEcoMode ? const Color(0xFF00E5FF) : const Color(0xFFFF9100);

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: RadialGradient(
          center: const Alignment(0, -0.1),
          radius: 1.1,
          colors: [
            isEcoMode ? const Color(0xFF0A1F18) : const Color(0xFF260D0A),
            const Color(0xFF060B10),
            const Color(0xFF030508),
          ],
        ),
        border: Border.all(
          color: themeColor.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.08),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background cockpit subtle grid / carbon texture lines
            CustomPaint(
              size: Size.infinite,
              painter: CockpitBackgroundPainter(),
            ),

            // Top Status Bar (Turn signals, ABS, Headlight, Mode)
            Positioned(
              top: 18,
              left: 24,
              right: 24,
              child: _buildCockpitStatusBar(themeColor),
            ),

            // Main Analog & Digital Gauge Cluster
            Positioned.fill(
              top: 40,
              bottom: 16,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final dialSize = min(constraints.maxWidth, constraints.maxHeight);
                    return Center(
                      child: SizedBox(
                        width: dialSize,
                        height: dialSize,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 1. Analog Gauge Dial Painter (Ticks, Numbers, Arcs, Needle)
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: speed.clamp(0, maxGaugeSpeed)),
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutCubic,
                              builder: (context, animatedSpeed, child) {
                                return CustomPaint(
                                  size: Size(dialSize, dialSize),
                                  painter: AnalogSpeedometerPainter(
                                    speed: animatedSpeed,
                                    maxSpeed: maxGaugeSpeed,
                                    isEcoMode: isEcoMode,
                                    themeColor: themeColor,
                                    secondaryColor: secondaryColor,
                                  ),
                                );
                              },
                            ),

                            // 2. Central High-Tech Digital Cockpit Readout
                            _buildDigitalCockpit(dialSize, themeColor, secondaryColor),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Bottom Telemetry Bar (Instant Accel / G-Force, Trip & Status)
            Positioned(
              bottom: 16,
              left: 28,
              right: 28,
              child: _buildBottomTelemetry(themeColor, secondaryColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCockpitStatusBar(Color themeColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left Indicators
        Row(
          children: [
            _buildStatusIcon(
              Icons.arrow_back_ios_new_rounded,
              'LEFT',
              false,
              const Color(0xFF00E676),
            ),
            const SizedBox(width: 12),
            _buildStatusIcon(
              Icons.wb_sunny_rounded,
              'HIGH BEAM',
              true,
              const Color(0xFF2979FF),
            ),
          ],
        ),

        // Center Mode Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: themeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: themeColor.withValues(alpha: 0.4), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isEcoMode ? Icons.eco_rounded : Icons.flash_on_rounded,
                size: 14,
                color: themeColor,
              ),
              const SizedBox(width: 6),
              Text(
                isEcoMode ? 'ECO ACTIVE' : 'SPORT / POWER',
                style: TextStyle(
                  color: themeColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),

        // Right Indicators
        Row(
          children: [
            _buildStatusIcon(
              Icons.safety_check_rounded,
              'ABS',
              true,
              const Color(0xFFFFB300),
            ),
            const SizedBox(width: 12),
            _buildStatusIcon(
              Icons.arrow_forward_ios_rounded,
              'RIGHT',
              false,
              const Color(0xFF00E676),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusIcon(IconData icon, String tooltip, bool active, Color activeColor) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: active ? activeColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active ? activeColor.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08),
          width: 0.8,
        ),
      ),
      child: Icon(
        icon,
        size: 14,
        color: active ? activeColor : Colors.white24,
      ),
    );
  }

  Widget _buildDigitalCockpit(double size, Color themeColor, Color secondaryColor) {
    // Proportional positioning inside the dial
    final clusterWidth = size * 0.44;
    final clusterHeight = size * 0.40;

    final displaySpeed = speed.clamp(0, 199.0);
    final speedInt = displaySpeed.toInt();

    return Container(
      width: clusterWidth,
      height: clusterHeight,
      margin: EdgeInsets.only(top: size * 0.12),
      decoration: BoxDecoration(
        color: const Color(0xFF090E14).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: themeColor.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: themeColor.withValues(alpha: 0.1),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Drive state & Unit
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isRiding ? themeColor.withValues(alpha: 0.2) : Colors.white12,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isRiding ? (isEcoMode ? 'D' : 'S') : 'N',
                  style: TextStyle(
                    color: isRiding ? themeColor : Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'DIGITAL HUD',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 8,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 2),

          // Big Digital Speed with Leading Zero styling
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                speedInt.toString().padLeft(speedInt < 100 ? 2 : 3, '0'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.135,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                  letterSpacing: -1,
                  height: 1.0,
                  shadows: [
                    Shadow(
                      color: themeColor.withValues(alpha: 0.6),
                      blurRadius: 14,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'KM/H',
                style: TextStyle(
                  color: themeColor,
                  fontSize: size * 0.035,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Digital Power Output / RPM mini bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEcoMode ? 'EFFICIENCY' : 'PWR OUTPUT',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 7.5,
                        letterSpacing: 1,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${powerScore.toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: themeColor,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (powerScore / 100).clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomTelemetry(Color themeColor, Color secondaryColor) {
    final bool accelerating = acceleration > 0.4;
    final bool braking = acceleration < -0.4;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Instant acceleration
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                accelerating
                    ? Icons.arrow_upward_rounded
                    : (braking ? Icons.arrow_downward_rounded : Icons.drag_handle_rounded),
                size: 14,
                color: accelerating
                    ? Colors.orangeAccent
                    : (braking ? Colors.cyanAccent : Colors.white38),
              ),
              const SizedBox(width: 6),
              Text(
                '${acceleration >= 0 ? '+' : ''}${acceleration.toStringAsFixed(1)} m/s²',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),

        // Live trip distance readout
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.navigation_rounded, size: 13, color: Colors.white38),
              const SizedBox(width: 6),
              const Text(
                'TRIP ',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              Text(
                '${tripDistance.toStringAsFixed(2)} KM',
                style: TextStyle(
                  color: secondaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Custom painter for analog dial background grid
class CockpitBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.015)
      ..strokeWidth = 1.0;

    // Light circular sonar rings for cockpit instrument depth
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = min(size.width, size.height) * 0.48;

    for (double r = maxR * 0.3; r <= maxR; r += maxR * 0.25) {
      canvas.drawCircle(center, r, paint..style = PaintingStyle.stroke);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// CustomPainter for the complete Analog Speedometer
/// Renders:
/// - Outer instrument bezel ring
/// - 270° graduated dial track (minor & major ticks)
/// - Radial speed text labels (0, 20, 40, 60, 80, 100, 120, 140)
/// - Glowing active speed progress arc
/// - High speed / redline zone (100 - 140 km/h)
/// - Analog luminous sports needle & metallic hub
class AnalogSpeedometerPainter extends CustomPainter {
  final double speed;
  final double maxSpeed;
  final bool isEcoMode;
  final Color themeColor;
  final Color secondaryColor;

  // 270 degrees sweep: from 135° (bottom left) to 405° (bottom right)
  static const double startAngle = 135 * (pi / 180);
  static const double sweepAngle = 270 * (pi / 180);

  AnalogSpeedometerPainter({
    required this.speed,
    required this.maxSpeed,
    required this.isEcoMode,
    required this.themeColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 12;

    // 1. Draw outer cockpit bezel
    _drawBezel(canvas, center, radius);

    // 2. Draw gauge tracks (background track & redline segment)
    _drawTracks(canvas, center, radius);

    // 3. Draw active speed arc (glowing progress up to current speed)
    _drawActiveArc(canvas, center, radius);

    // 4. Draw tick marks & radial speed numbers
    _drawTicksAndLabels(canvas, center, radius);

    // 5. Draw the luminous analog needle & center metallic pivot
    _drawNeedle(canvas, center, radius);
  }

  void _drawBezel(Canvas canvas, Offset center, double radius) {
    // Outer shadow ring
    final outerRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawCircle(center, radius + 8, outerRingPaint);

    // Dark bezel fill ring
    final bezelPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14.0
      ..shader = SweepGradient(
        colors: [
          const Color(0xFF141920),
          const Color(0xFF0B0F14),
          const Color(0xFF1A212B),
          const Color(0xFF141920),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, bezelPaint);
  }

  void _drawTracks(Canvas canvas, Offset center, double radius) {
    final trackRadius = radius - 16;
    final rect = Rect.fromCircle(center: center, radius: trackRadius);

    // Subtle background track
    final bgTrackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.08);

    canvas.drawArc(rect, startAngle, sweepAngle, false, bgTrackPaint);

    // Redline zone track (last 25% of speed: 105 - 140 km/h)
    final redlineStartFactor = 100.0 / maxSpeed;
    final redlineStartAngle = startAngle + sweepAngle * redlineStartFactor;
    final redlineSweep = sweepAngle * (1.0 - redlineStartFactor);

    final redlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFF1744).withValues(alpha: 0.25);

    canvas.drawArc(rect, redlineStartAngle, redlineSweep, false, redlinePaint);
  }

  void _drawActiveArc(Canvas canvas, Offset center, double radius) {
    if (speed <= 0.5) return;

    final trackRadius = radius - 16;
    final rect = Rect.fromCircle(center: center, radius: trackRadius);
    final speedFraction = (speed / maxSpeed).clamp(0.0, 1.0);
    final currentSweep = sweepAngle * speedFraction;

    // Glow under-arc
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12.0
      ..strokeCap = StrokeCap.round
      ..color = themeColor.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawArc(rect, startAngle, currentSweep, false, glowPaint);

    // Sharp active arc
    final activePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: [
          themeColor.withValues(alpha: 0.6),
          themeColor,
          secondaryColor,
          if (speed > 100) const Color(0xFFFF1744),
        ],
      ).createShader(rect);

    canvas.drawArc(rect, startAngle, currentSweep, false, activePaint);
  }

  void _drawTicksAndLabels(Canvas canvas, Offset center, double radius) {
    const int totalDivisions = 28; // Every 5 km/h on 140 scale (140 / 5 = 28)
    final outerTickRadius = radius - 24;
    final majorTickLength = 14.0;
    final minorTickLength = 7.0;

    final majorTickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final minorTickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    final redlineTickPaint = Paint()
      ..color = const Color(0xFFFF5252)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i <= totalDivisions; i++) {
      final tickSpeed = (i / totalDivisions) * maxSpeed;
      final angle = startAngle + (i / totalDivisions) * sweepAngle;
      final isMajor = i % 4 == 0; // Every 20 km/h (0, 20, 40, 60, 80, 100, 120, 140)
      final isRedline = tickSpeed >= 100;

      final tickLength = isMajor ? majorTickLength : minorTickLength;
      final innerRadius = outerTickRadius - tickLength;

      final cosA = cos(angle);
      final sinA = sin(angle);

      final p1 = Offset(center.dx + outerTickRadius * cosA, center.dy + outerTickRadius * sinA);
      final p2 = Offset(center.dx + innerRadius * cosA, center.dy + innerRadius * sinA);

      Paint selectedPaint = isMajor ? majorTickPaint : minorTickPaint;
      if (isRedline && isMajor) {
        selectedPaint = redlineTickPaint;
      }

      canvas.drawLine(p1, p2, selectedPaint);

      // Draw numerical labels on major ticks
      if (isMajor) {
        final labelRadius = outerTickRadius - majorTickLength - 16;
        final labelPos = Offset(center.dx + labelRadius * cosA, center.dy + labelRadius * sinA);

        final textSpan = TextSpan(
          text: tickSpeed.toInt().toString(),
          style: TextStyle(
            color: isRedline ? const Color(0xFFFF5252) : Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
          ),
        );

        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();

        // Center the text bounding box around labelPos
        final textOffset = Offset(
          labelPos.dx - textPainter.width / 2,
          labelPos.dy - textPainter.height / 2,
        );
        textPainter.paint(canvas, textOffset);
      }
    }
  }

  void _drawNeedle(Canvas canvas, Offset center, double radius) {
    final speedFraction = (speed / maxSpeed).clamp(0.0, 1.0);
    final needleAngle = startAngle + speedFraction * sweepAngle;

    final needleLength = radius - 30;
    final tailLength = 22.0;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(needleAngle);

    // Needle shadow / glow
    final glowPaint = Paint()
      ..color = themeColor.withValues(alpha: 0.4)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawLine(Offset(-tailLength * 0.5, 0), Offset(needleLength, 0), glowPaint);

    // Tapered Sports Needle Path
    final needlePath = Path()
      ..moveTo(-tailLength, -3.5)
      ..lineTo(-tailLength * 0.5, -4.5)
      ..lineTo(needleLength - 12, -1.8)
      ..lineTo(needleLength, 0) // Sharp glowing tip
      ..lineTo(needleLength - 12, 1.8)
      ..lineTo(-tailLength * 0.5, 4.5)
      ..lineTo(-tailLength, 3.5)
      ..close();

    final needlePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white,
          themeColor,
          themeColor,
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromLTWH(-tailLength, -5, needleLength + tailLength, 10));

    canvas.drawPath(needlePath, needlePaint);

    // Sharp luminous needle center line
    final needleCorePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(0, 0), Offset(needleLength - 6, 0), needleCorePaint);

    canvas.restore();

    // Center metallic hub / cap
    final hubRadius = 18.0;

    // Outer hub shadow
    canvas.drawCircle(
      center,
      hubRadius + 3,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Metallic outer ring
    canvas.drawCircle(
      center,
      hubRadius,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF3A4452), Color(0xFF141920)],
        ).createShader(Rect.fromCircle(center: center, radius: hubRadius)),
    );

    // Inner bevel ring
    canvas.drawCircle(
      center,
      hubRadius * 0.65,
      Paint()
        ..color = const Color(0xFF0A0E14)
        ..style = PaintingStyle.fill,
    );

    // Core jewel / theme LED
    canvas.drawCircle(
      center,
      hubRadius * 0.35,
      Paint()..color = themeColor,
    );
  }

  @override
  bool shouldRepaint(covariant AnalogSpeedometerPainter oldDelegate) {
    return oldDelegate.speed != speed ||
        oldDelegate.isEcoMode != isEcoMode ||
        oldDelegate.themeColor != themeColor;
  }
}
