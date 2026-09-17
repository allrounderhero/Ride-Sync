import '../models/sensor_data.dart';

enum RidingMode {
  eco,
  power,
}

/// Dynamic riding telemetry analyzer.
/// Evaluates speed, acceleration rate, braking intensity, and variability
/// to compute Power Score and transition between ECO and POWER riding modes.
class RidingAnalyzer {
  RidingMode _ridingMode = RidingMode.eco;
  double _powerScore = 0.0;

  RidingMode get ridingMode => _ridingMode;
  double get powerScore => _powerScore;

  // Smoothing memory
  double _smoothedPowerScore = 0.0;

  /// Analyze incoming telemetry
  void processTelemetry(SensorData data) {
    final speed = data.speedKmh;
    final forwardAcc = data.longitudinalAcceleration;

    // 1. Acceleration effort (throttle punch)
    // 0 to 3.5 m/s² maps to 0 to 50 pts
    double accelScore = 0.0;
    if (forwardAcc > 0.1) {
      accelScore = (forwardAcc / 3.5).clamp(0.0, 1.0) * 50.0;
    } else if (forwardAcc < -0.3) {
      // Hard braking also contributes to dynamic riding score
      accelScore = (forwardAcc.abs() / 4.0).clamp(0.0, 1.0) * 35.0;
    }

    // 2. Speed contribution:
    // Gentle cruising at 70 km/h is still ECO, but > 100 km/h enters high power territory
    double speedScore = 0.0;
    if (speed > 40.0) {
      speedScore = ((speed - 40.0) / 80.0).clamp(0.0, 1.0) * 30.0;
    }

    // 3. Dynamic Aggressiveness (Rapid burst)
    double aggressionBonus = 0.0;
    if (forwardAcc > 1.8) {
      aggressionBonus = 20.0;
    } else if (forwardAcc > 1.2) {
      aggressionBonus = 10.0;
    }

    final rawScore = (accelScore + speedScore + aggressionBonus).clamp(0.0, 100.0);

    // Exponential smoothing for power score
    _smoothedPowerScore = 0.3 * rawScore + 0.7 * _smoothedPowerScore;
    _powerScore = _smoothedPowerScore.clamp(0.0, 100.0);

    // Hysteresis mode switching:
    // Prevents rapid flickering between ECO and POWER
    if (_ridingMode == RidingMode.eco) {
      if (_powerScore >= 62.0) {
        _ridingMode = RidingMode.power;
      }
    } else {
      if (_powerScore <= 35.0) {
        _ridingMode = RidingMode.eco;
      }
    }
  }

  void reset() {
    _ridingMode = RidingMode.eco;
    _powerScore = 0.0;
    _smoothedPowerScore = 0.0;
  }
}
