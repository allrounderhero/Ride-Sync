import 'dart:async';
import 'package:flutter/material.dart';
import '../services/motion_service.dart';
import '../services/mount_calibration.dart';

/// Modal dialog allowing the rider to perform two-stage mount calibration
class CalibrationDialog extends StatefulWidget {
  final MotionService motionService;
  final MountCalibration mountCalibration;
  final VoidCallback onCalibrationComplete;

  const CalibrationDialog({
    super.key,
    required this.motionService,
    required this.mountCalibration,
    required this.onCalibrationComplete,
  });

  @override
  State<CalibrationDialog> createState() => _CalibrationDialogState();
}

class _CalibrationDialogState extends State<CalibrationDialog> {
  MountOrientationPreset _selectedPreset =
      MountOrientationPreset.portraitTopForward;

  bool _isCalibrating = false;
  double _progress = 0.0;
  String _statusText = 'Ready to calibrate';
  bool _calibrationSuccess = false;

  final List<double> _samplesX = [];
  final List<double> _samplesY = [];
  final List<double> _samplesZ = [];

  StreamSubscription<MotionReading>? _motionSub;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _motionSub?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCalibration() {
    setState(() {
      _isCalibrating = true;
      _progress = 0.0;
      _statusText = 'Sampling resting gravity vector...';
      _calibrationSuccess = false;
      _samplesX.clear();
      _samplesY.clear();
      _samplesZ.clear();
    });

    // Collect IMU samples for 2 seconds (20 ticks at 100ms)
    int ticks = 0;
    const totalTicks = 20;

    _motionSub = widget.motionService.motionStream.listen((reading) {
      if (_samplesX.length < 50) {
        _samplesX.add(reading.accelX);
        _samplesY.add(reading.accelY);
        _samplesZ.add(reading.accelZ);
      }
    });

    _countdownTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      ticks++;
      if (!mounted) return;

      setState(() {
        _progress = (ticks / totalTicks).clamp(0.0, 1.0);
      });

      if (ticks >= totalTicks) {
        timer.cancel();
        _motionSub?.cancel();

        // Calculate average stationary acceleration
        double avgX = 0.0;
        double avgY = 0.0;
        double avgZ = 9.81;

        if (_samplesX.isNotEmpty) {
          avgX = _samplesX.reduce((a, b) => a + b) / _samplesX.length;
          avgY = _samplesY.reduce((a, b) => a + b) / _samplesY.length;
          avgZ = _samplesZ.reduce((a, b) => a + b) / _samplesZ.length;
        }

        final success = await widget.mountCalibration.calibrate(
          avgX: avgX,
          avgY: avgY,
          avgZ: avgZ,
          preset: _selectedPreset,
        );

        if (mounted) {
          setState(() {
            _isCalibrating = false;
            _calibrationSuccess = success;
            _statusText = success
                ? 'Calibration successful! Mount frame aligned.'
                : 'Calibration failed: excessive movement detected.';
          });
          if (success) {
            widget.onCalibrationComplete();
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0D141C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: Colors.blueAccent.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.compass_calibration,
                    color: Colors.blueAccent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'MOUNT CALIBRATION',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Instructions
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.two_wheeler, size: 16, color: Colors.greenAccent),
                      SizedBox(width: 8),
                      Text(
                        'Keep motorcycle upright and stationary.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.phonelink_ring, size: 16, color: Colors.blueAccent),
                      SizedBox(width: 8),
                      Text(
                        'Keep phone firmly secured in handlebar mount.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Orientation Preset Selection
            const Text(
              'PHONE MOUNT ORIENTATION',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<MountOrientationPreset>(
              initialValue: _selectedPreset,
              dropdownColor: const Color(0xFF141F2B),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: MountOrientationPreset.portraitTopForward,
                  child: Text('Portrait (Top facing forward)'),
                ),
                DropdownMenuItem(
                  value: MountOrientationPreset.landscapeTopRight,
                  child: Text('Landscape (Top facing right)'),
                ),
                DropdownMenuItem(
                  value: MountOrientationPreset.landscapeTopLeft,
                  child: Text('Landscape (Top facing left)'),
                ),
                DropdownMenuItem(
                  value: MountOrientationPreset.flatPortrait,
                  child: Text('Flat on tank (Top facing forward)'),
                ),
              ],
              onChanged: _isCalibrating
                  ? null
                  : (val) {
                      if (val != null) {
                        setState(() => _selectedPreset = val);
                      }
                    },
            ),
            const SizedBox(height: 18),

            // Progress or Status
            if (_isCalibrating) ...[
              LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation(Colors.blueAccent),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 8),
            ],

            Text(
              _statusText,
              style: TextStyle(
                color: _calibrationSuccess
                    ? Colors.greenAccent
                    : (_isCalibrating ? Colors.cyanAccent : Colors.white60),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isCalibrating
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('CLOSE', style: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isCalibrating ? null : _startCalibration,
                  icon: const Icon(Icons.flash_on, size: 16),
                  label: Text(_isCalibrating ? 'CALIBRATING...' : 'CALIBRATE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
