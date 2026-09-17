import 'dart:async';
import 'dart:math';
import '../models/sensor_data.dart';

/// Simulator engine preserving Phase 1 simulation capabilities
/// for Desktop, Web, and offline UI testing.
class SimulatorService {
  final _controller = StreamController<SensorData>.broadcast();
  Stream<SensorData> get stream => _controller.stream;

  Timer? _timer;
  final Random _random = Random();

  double _speedKmh = 0.0;
  double _previousSpeedKmh = 0.0;
  double _acceleration = 0.0;
  bool _isManualControl = false;

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  double get currentSpeed => _speedKmh;
  double get currentAcceleration => _acceleration;

  void start() {
    if (_isRunning) return;
    _isRunning = true;

    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _tick();
    });
  }

  void setManualSpeed(double targetSpeed) {
    _isManualControl = true;
    final delta = targetSpeed - _speedKmh;
    _acceleration = (delta * 0.8).clamp(-4.5, 4.5);
    _speedKmh = targetSpeed.clamp(0.0, 140.0);
    _emit();
  }

  void setAutoSimulation() {
    _isManualControl = false;
  }

  void _tick() {
    if (!_isManualControl) {
      double delta;
      if (_speedKmh < 30) {
        delta = 0.8 + _random.nextDouble() * 2.0;
      } else if (_speedKmh < 75) {
        delta = (_random.nextDouble() - 0.4) * 2.5;
      } else if (_speedKmh < 115) {
        delta = (_random.nextDouble() - 0.5) * 3.0;
      } else {
        delta = (_random.nextDouble() - 0.6) * 3.5;
      }

      _speedKmh = (_speedKmh + delta).clamp(0.0, 138.0);
      _acceleration =
          ((_speedKmh - _previousSpeedKmh) / 0.1).clamp(-4.0, 4.0);
      _previousSpeedKmh = _speedKmh;
    }

    _emit();
  }

  void _emit() {
    // Add subtle synthetic vibration to raw accelerometer
    final vibrationX = (_random.nextDouble() - 0.5) * 0.4;
    final vibrationY = (_random.nextDouble() - 0.5) * 0.4;
    final vibrationZ = (_random.nextDouble() - 0.5) * 0.5;

    final data = SensorData(
      speedKmh: _speedKmh,
      latitude: 12.9716 + (_random.nextDouble() * 0.0001),
      longitude: 77.5946 + (_random.nextDouble() * 0.0001),
      gpsAccuracy: 4.2,
      gpsTier: GpsAccuracyTier.good,
      rawAccelerationX: vibrationX,
      rawAccelerationY: _acceleration + vibrationY,
      rawAccelerationZ: 9.81 + vibrationZ,
      calibratedAccelerationX: vibrationX,
      calibratedAccelerationY: _acceleration,
      calibratedAccelerationZ: vibrationZ,
      longitudinalAcceleration: _acceleration,
      lateralAcceleration: (_random.nextDouble() - 0.5) * 0.2,
      gyroX: 0.01,
      gyroY: -0.01,
      gyroZ: 0.02,
      isCalibrated: true,
      timestamp: DateTime.now(),
    );

    if (!_controller.isClosed) {
      _controller.add(data);
    }
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
