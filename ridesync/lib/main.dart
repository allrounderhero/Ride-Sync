import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'models/sensor_data.dart';
import 'services/riding_analyzer.dart';
import 'services/sensor_engine.dart';
import 'services/simulator_service.dart';
import 'services/trip_recorder.dart';
import 'widgets/calibration_dialog.dart';
import 'widgets/riding_meter.dart';
import 'widgets/sensor_debug_dialog.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RideSyncApp());
}

// ============================================================
// RIDESYNC APP
// ============================================================

class RideSyncApp extends StatelessWidget {
  const RideSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RideSync',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF05070A),
        fontFamily: 'Arial',
        useMaterial3: true,
      ),
      home: const RideSyncDashboard(),
    );
  }
}

// ============================================================
// TELEMETRY SOURCE MODE
// ============================================================

enum TelemetrySource {
  simulator,
  hardwareSensors,
}

// ============================================================
// DASHBOARD
// ============================================================

class RideSyncDashboard extends StatefulWidget {
  const RideSyncDashboard({super.key});

  @override
  State<RideSyncDashboard> createState() => _RideSyncDashboardState();
}

class _RideSyncDashboardState extends State<RideSyncDashboard> {
  // Telemetry Engines & Services
  final SensorEngine _sensorEngine = SensorEngine();
  final SimulatorService _simulatorService = SimulatorService();
  final RidingAnalyzer _ridingAnalyzer = RidingAnalyzer();
  final TripRecorder _tripRecorder = TripRecorder();

  StreamSubscription<SensorData>? _telemetrySubscription;

  // Active source: defaults to hardwareSensors on mobile, simulator on web/desktop
  TelemetrySource _activeSource =
      kIsWeb ? TelemetrySource.simulator : TelemetrySource.hardwareSensors;

  // Current live telemetry state
  SensorData _latestData = SensorData.zero();
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  bool _riding = false;

  @override
  void initState() {
    super.initState();
    _initEngines();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  Future<void> _initEngines() async {
    await _sensorEngine.initialize();
    _connectTelemetryStream();

    // If starting in simulator mode, fire initial stream
    if (_activeSource == TelemetrySource.simulator) {
      _simulatorService.start();
    }
  }

  void _switchTelemetrySource(TelemetrySource newSource) {
    if (_activeSource == newSource) return;

    setState(() {
      _activeSource = newSource;
    });

    _telemetrySubscription?.cancel();

    if (_activeSource == TelemetrySource.hardwareSensors) {
      _simulatorService.stop();
      if (_riding) {
        _sensorEngine.start();
      }
    } else {
      _sensorEngine.stop();
      _simulatorService.start();
    }

    _connectTelemetryStream();
  }

  void _connectTelemetryStream() {
    final stream = _activeSource == TelemetrySource.hardwareSensors
        ? _sensorEngine.sensorStream
        : _simulatorService.stream;

    _telemetrySubscription = stream.listen((SensorData data) {
      if (!mounted) return;

      if (_riding) {
        _tripRecorder.updateTelemetry(data);
        _ridingAnalyzer.processTelemetry(data);
      }

      setState(() {
        _latestData = data;
      });
    });
  }

  // ============================================================
  // RIDE LIFECYCLE (START / STOP)
  // ============================================================

  Future<void> _startRide() async {
    // Screen wakelock during riding
    try {
      await WakelockPlus.enable();
    } catch (_) {}

    _tripRecorder.startRide();
    _ridingAnalyzer.reset();

    if (_activeSource == TelemetrySource.hardwareSensors) {
      final started = await _sensorEngine.start();
      if (!started && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission required for hardware telemetry. Switched to degraded mode.',
            ),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
    } else {
      _simulatorService.start();
    }

    setState(() {
      _riding = true;
    });
  }

  Future<void> _stopRide() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {}

    final summary = await _tripRecorder.stopRide();

    if (_activeSource == TelemetrySource.hardwareSensors) {
      _sensorEngine.stop();
    }

    setState(() {
      _riding = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ride Completed! Distance: ${summary.distanceKm.toStringAsFixed(2)} km | Max: ${summary.maxSpeedKmh.toStringAsFixed(0)} km/h',
          ),
          backgroundColor: Colors.blueAccent,
        ),
      );
    }
  }

  // ============================================================
  // DIALOGS
  // ============================================================

  void _openCalibration() {
    showDialog(
      context: context,
      builder: (ctx) => CalibrationDialog(
        motionService: _sensorEngine.motionService,
        mountCalibration: _sensorEngine.mountCalibration,
        onCalibrationComplete: () {
          setState(() {});
        },
      ),
    );
  }

  void _openDiagnostics() {
    final stream = _activeSource == TelemetrySource.hardwareSensors
        ? _sensorEngine.sensorStream
        : _simulatorService.stream;

    showDialog(
      context: context,
      builder: (ctx) => SensorDebugDialog(
        sensorStream: stream,
        initialData: _latestData,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              buildTopBar(),
              const SizedBox(height: 14),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 7,
                      child: buildMainCluster(),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: buildRidePanel(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Brand & Mode Switcher
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.two_wheeler,
                color: Colors.blueAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'RideSync',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 16),

            // Source Switcher (Simulator vs Hardware Sensors)
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: [
                  _buildSourceButton(
                    'SIMULATOR',
                    TelemetrySource.simulator,
                    Icons.speed,
                  ),
                  _buildSourceButton(
                    'SENSORS',
                    TelemetrySource.hardwareSensors,
                    Icons.sensors,
                  ),
                ],
              ),
            ),
          ],
        ),

        // Action Buttons & Clock
        Row(
          children: [
            // Mount Calibration Button
            OutlinedButton.icon(
              onPressed: _openCalibration,
              icon: const Icon(Icons.compass_calibration, size: 14),
              label: Text(
                _sensorEngine.mountCalibration.isCalibrated
                    ? 'CALIBRATED'
                    : 'CALIBRATE',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _sensorEngine.mountCalibration.isCalibrated
                    ? Colors.greenAccent
                    : Colors.white70,
                side: BorderSide(
                  color: _sensorEngine.mountCalibration.isCalibrated
                      ? Colors.greenAccent.withValues(alpha: 0.4)
                      : Colors.white24,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Diagnostics Button
            OutlinedButton.icon(
              onPressed: _openDiagnostics,
              icon: const Icon(Icons.developer_board, size: 14),
              label: const Text(
                'DEBUG',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.cyanAccent,
                side: BorderSide(
                  color: Colors.cyanAccent.withValues(alpha: 0.4),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Digital Clock
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatTime(_now),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  formatDate(_now),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSourceButton(
    String label,
    TelemetrySource source,
    IconData icon,
  ) {
    final bool isSelected = _activeSource == source;
    return GestureDetector(
      onTap: () => _switchTelemetrySource(source),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (source == TelemetrySource.hardwareSensors
                  ? Colors.blueAccent
                  : Colors.white12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 12,
              color: isSelected ? Colors.white : Colors.white54,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MAIN SPEED CLUSTER
  // ============================================================

  Widget buildMainCluster() {
    return RidingMeter(
      speed: _latestData.speedKmh,
      maxGaugeSpeed: 140.0,
      acceleration: _latestData.longitudinalAcceleration,
      powerScore: _ridingAnalyzer.powerScore,
      isEcoMode: _ridingAnalyzer.ridingMode == RidingMode.eco,
      isRiding: _riding,
      tripDistance: _tripRecorder.tripKm,
    );
  }

  // ============================================================
  // SIDE PANEL
  // ============================================================

  Widget buildRidePanel() {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0F15),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'RIDE DATA',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          buildData(
                            Icons.route,
                            'TRIP',
                            '${_tripRecorder.tripKm.toStringAsFixed(2)} km',
                            Colors.blueAccent,
                          ),
                          buildData(
                            Icons.speed,
                            'AVERAGE',
                            '${_tripRecorder.averageSpeedKmh.toStringAsFixed(0)} km/h',
                            Colors.greenAccent,
                          ),
                          buildData(
                            Icons.flash_on,
                            'MAXIMUM',
                            '${_tripRecorder.maxSpeedKmh.toStringAsFixed(0)} km/h',
                            Colors.orangeAccent,
                          ),
                          buildData(
                            Icons.timer,
                            'RIDE TIME',
                            formatDuration(_tripRecorder.rideDuration),
                            Colors.cyanAccent,
                          ),
                          const Spacer(),
                          const SizedBox(height: 8),
                          buildPowerScore(),
                          const SizedBox(height: 10),

                          // Show manual throttle control in Simulator Mode
                          if (_activeSource == TelemetrySource.simulator)
                            buildManualThrottleControl(),

                          const SizedBox(height: 10),
                          buildGpsStatus(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        buildStartButton(),
      ],
    );
  }

  // ============================================================
  // DATA CARD
  // ============================================================

  Widget buildData(
    IconData icon,
    String title,
    String value,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MANUAL THROTTLE CONTROL (SIMULATOR ONLY)
  // ============================================================

  Widget buildManualThrottleControl() {
    final bool eco = _ridingAnalyzer.ridingMode == RidingMode.eco;
    final themeColor = eco ? const Color(0xFF00E676) : const Color(0xFFFF3D00);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: themeColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tune_rounded, size: 12, color: themeColor),
                    const SizedBox(width: 6),
                    const Flexible(
                      child: Text(
                        'MANUAL THROTTLE',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${_latestData.speedKmh.toStringAsFixed(0)} KM/H',
                style: TextStyle(
                  color: themeColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: themeColor,
              inactiveTrackColor: Colors.white12,
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: _latestData.speedKmh.clamp(0.0, 140.0),
              min: 0.0,
              max: 140.0,
              onChanged: (val) {
                _simulatorService.setManualSpeed(val);
                if (!_riding && val > 0) {
                  _riding = true;
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // POWER SCORE
  // ============================================================

  Widget buildPowerScore() {
    final bool eco = _ridingAnalyzer.ridingMode == RidingMode.eco;
    final score = _ridingAnalyzer.powerScore;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: eco
            ? Colors.greenAccent.withValues(alpha: 0.06)
            : Colors.redAccent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  eco ? 'ECO BEHAVIOR' : 'POWER LEVEL',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 9,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${score.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: eco ? Colors.greenAccent : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: score / 100,
            minHeight: 5,
            backgroundColor: Colors.white.withValues(alpha: 0.05),
            valueColor: AlwaysStoppedAnimation(
              eco ? Colors.greenAccent : Colors.redAccent,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // GPS STATUS
  // ============================================================

  Widget buildGpsStatus() {
    final tier = _latestData.gpsTier;
    final color = _getTierColor(tier);

    return Wrap(
      spacing: 10,
      runSpacing: 6,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'GPS ● ${tier.label}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _sensorEngine.mountCalibration.isCalibrated
                  ? Icons.check_circle_outline
                  : Icons.radio_button_unchecked,
              size: 11,
              color: _sensorEngine.mountCalibration.isCalibrated
                  ? Colors.greenAccent
                  : Colors.white38,
            ),
            const SizedBox(width: 4),
            Text(
              _sensorEngine.mountCalibration.isCalibrated
                  ? 'IMU CALIBRATED'
                  : 'IMU UNCALIBRATED',
              style: TextStyle(
                color: _sensorEngine.mountCalibration.isCalibrated
                    ? Colors.greenAccent
                    : Colors.white38,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
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

  // ============================================================
  // START BUTTON
  // ============================================================

  Widget buildStartButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _riding ? _stopRide : _startRide,
        icon: Icon(_riding ? Icons.stop : Icons.play_arrow),
        label: Text(
          _riding ? 'STOP RIDE' : 'START RIDE',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              _riding ? Colors.redAccent : Colors.greenAccent,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DATE / TIME / DURATION HELPERS
  // ============================================================

  String formatDate(DateTime date) {
    const months = [
      'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
      'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
    ];
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

    return '${weekdays[date.weekday - 1]} '
        '${date.day.toString().padLeft(2, '0')} '
        '${months[date.month - 1]} '
        '${date.year}';
  }

  String formatTime(DateTime date) {
    int hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    hour %= 12;
    if (hour == 0) hour = 12;
    return '$hour:$minute:$second $period';
  }

  String formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _telemetrySubscription?.cancel();
    _sensorEngine.dispose();
    _simulatorService.dispose();
    super.dispose();
  }
}
