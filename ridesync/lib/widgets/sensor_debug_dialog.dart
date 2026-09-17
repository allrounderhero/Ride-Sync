import 'dart:async';
import 'package:flutter/material.dart';
import '../models/sensor_data.dart';

/// Live diagnostic modal showing real-time sensor streams and transformations
class SensorDebugDialog extends StatefulWidget {
  final Stream<SensorData> sensorStream;
  final SensorData initialData;

  const SensorDebugDialog({
    super.key,
    required this.sensorStream,
    required this.initialData,
  });

  @override
  State<SensorDebugDialog> createState() => _SensorDebugDialogState();
}

class _SensorDebugDialogState extends State<SensorDebugDialog> {
  late SensorData _data;
  StreamSubscription<SensorData>? _sub;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    _sub = widget.sensorStream.listen((event) {
      if (mounted) {
        setState(() => _data = event);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF090E14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(22),
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.developer_board,
                        color: Colors.cyanAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'SENSOR DIAGNOSTICS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Scrollable diagnostic content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _buildSectionHeader('GPS TELEMETRY', Icons.satellite_alt),
                    _buildDataRow('Speed', '${_data.speedKmh.toStringAsFixed(1)} km/h'),
                    _buildDataRow('Accuracy', '${_data.gpsAccuracy.toStringAsFixed(1)} m'),
                    _buildDataRow('Tier Status', _data.gpsTier.label,
                        valueColor: _getTierColor(_data.gpsTier)),
                    _buildDataRow('Latitude', _data.latitude.toStringAsFixed(5)),
                    _buildDataRow('Longitude', _data.longitude.toStringAsFixed(5)),

                    const SizedBox(height: 14),
                    _buildSectionHeader('RAW ACCELEROMETER (PHONE)', Icons.sensors),
                    _buildDataRow('X (Lateral)', '${_data.rawAccelerationX.toStringAsFixed(2)} m/s²'),
                    _buildDataRow('Y (Longitudinal)', '${_data.rawAccelerationY.toStringAsFixed(2)} m/s²'),
                    _buildDataRow('Z (Vertical/Gravity)', '${_data.rawAccelerationZ.toStringAsFixed(2)} m/s²'),

                    const SizedBox(height: 14),
                    _buildSectionHeader('BIKE FRAME FORCES (CALIBRATED)', Icons.two_wheeler),
                    _buildDataRow('Forward / Thrust',
                        '${_formatSign(_data.calibratedAccelerationY)} m/s²',
                        valueColor: _data.calibratedAccelerationY >= 0
                            ? Colors.greenAccent
                            : Colors.redAccent),
                    _buildDataRow('Lateral / Cornering',
                        '${_formatSign(_data.calibratedAccelerationX)} m/s²'),
                    _buildDataRow('Vertical / Suspension',
                        '${_formatSign(_data.calibratedAccelerationZ)} m/s²'),
                    _buildDataRow('Fused Longitudinal',
                        '${_formatSign(_data.longitudinalAcceleration)} m/s²',
                        valueColor: Colors.amberAccent),

                    const SizedBox(height: 14),
                    _buildSectionHeader('GYROSCOPE (ANGULAR RATE)', Icons.screen_rotation),
                    _buildDataRow('Roll (X)', '${_data.gyroX.toStringAsFixed(3)} rad/s'),
                    _buildDataRow('Pitch (Y)', '${_data.gyroY.toStringAsFixed(3)} rad/s'),
                    _buildDataRow('Yaw (Z)', '${_data.gyroZ.toStringAsFixed(3)} rad/s'),

                    const SizedBox(height: 14),
                    _buildSectionHeader('SYSTEM READINESS', Icons.verified_user),
                    _buildStatusBadge('GPS Satellite Fix', _data.gpsTier.isReady),
                    _buildStatusBadge('IMU Hardware Stream', true),
                    _buildStatusBadge('Mount Calibration Aligned', _data.isCalibrated),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white12, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white38),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String title, bool isOk) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Row(
            children: [
              Icon(
                isOk ? Icons.check_circle : Icons.warning_amber_rounded,
                size: 14,
                color: isOk ? Colors.greenAccent : Colors.orangeAccent,
              ),
              const SizedBox(width: 6),
              Text(
                isOk ? 'READY' : 'PENDING',
                style: TextStyle(
                  color: isOk ? Colors.greenAccent : Colors.orangeAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getTierColor(GpsAccuracyTier tier) {
    switch (tier) {
      case GpsAccuracyTier.good:
        return Colors.greenAccent;
      case GpsAccuracyTier.acceptable:
        return Colors.lightGreenAccent;
      case GpsAccuracyTier.weak:
        return Colors.orangeAccent;
      case GpsAccuracyTier.poor:
        return Colors.redAccent;
      case GpsAccuracyTier.searching:
        return Colors.amberAccent;
      case GpsAccuracyTier.unavailable:
        return Colors.red;
    }
  }

  String _formatSign(double val) {
    return val >= 0 ? '+${val.toStringAsFixed(2)}' : val.toStringAsFixed(2);
  }
}
