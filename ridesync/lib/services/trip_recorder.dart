import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sensor_data.dart';

/// Summary of a finished motorcycle ride
class RideSummary {
  final double distanceKm;
  final double maxSpeedKmh;
  final double averageSpeedKmh;
  final Duration duration;
  final DateTime startTime;
  final DateTime endTime;

  const RideSummary({
    required this.distanceKm,
    required this.maxSpeedKmh,
    required this.averageSpeedKmh,
    required this.duration,
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toJson() => {
        'distanceKm': distanceKm,
        'maxSpeedKmh': maxSpeedKmh,
        'averageSpeedKmh': averageSpeedKmh,
        'durationSeconds': duration.inSeconds,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
      };
}

/// Tracks trip distance, average speed, max speed, and ride duration
/// with stationary drift rejection.
class TripRecorder {
  static const String _historyPrefKey = 'ridesync_ride_history';

  bool _isRiding = false;
  double _tripKm = 0.0;
  double _maxSpeedKmh = 0.0;
  double _averageSpeedKmh = 0.0;
  Duration _rideDuration = Duration.zero;

  DateTime? _startTime;
  double? _lastLat;
  double? _lastLng;

  bool get isRiding => _isRiding;
  double get tripKm => _tripKm;
  double get maxSpeedKmh => _maxSpeedKmh;
  double get averageSpeedKmh => _averageSpeedKmh;
  Duration get rideDuration => _rideDuration;

  void startRide() {
    _isRiding = true;
    _tripKm = 0.0;
    _maxSpeedKmh = 0.0;
    _averageSpeedKmh = 0.0;
    _rideDuration = Duration.zero;
    _startTime = DateTime.now();
    _lastLat = null;
    _lastLng = null;
  }

  void updateTelemetry(SensorData data) {
    if (!_isRiding) return;

    final now = DateTime.now();
    if (_startTime != null) {
      _rideDuration = now.difference(_startTime!);
    }

    // Max speed
    if (data.speedKmh > _maxSpeedKmh) {
      _maxSpeedKmh = data.speedKmh;
    }

    // Accumulate distance from GPS coordinates (if valid)
    if (data.latitude != 0.0 && data.longitude != 0.0) {
      if (_lastLat != null && _lastLng != null) {
        final double distMeters = Geolocator.distanceBetween(
          _lastLat!,
          _lastLng!,
          data.latitude,
          data.longitude,
        );

        // Stationary drift safeguard:
        // Only accumulate distance if speed is non-zero or displacement exceeds 3 meters
        if (data.gpsTier != GpsAccuracyTier.poor) {
          if (data.speedKmh > 1.2 || distMeters > 3.0) {
            _tripKm += distMeters / 1000.0;
          }
        }
      }
      _lastLat = data.latitude;
      _lastLng = data.longitude;
    } else {
      // If GPS coordinates unavailable (e.g. offline simulation), compute from speed * dt
      _tripKm += (data.speedKmh / 3600.0) * 0.1;
    }

    // Average speed calculation
    if (_rideDuration.inSeconds > 0) {
      final hours = _rideDuration.inSeconds / 3600.0;
      _averageSpeedKmh = _tripKm / hours;
    }
  }

  Future<RideSummary> stopRide() async {
    _isRiding = false;
    final summary = RideSummary(
      distanceKm: _tripKm,
      maxSpeedKmh: _maxSpeedKmh,
      averageSpeedKmh: _averageSpeedKmh,
      duration: _rideDuration,
      startTime: _startTime ?? DateTime.now(),
      endTime: DateTime.now(),
    );

    // Save ride summary to history
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyList = prefs.getStringList(_historyPrefKey) ?? [];
      historyList.add(jsonEncode(summary.toJson()));
      await prefs.setStringList(_historyPrefKey, historyList);
    } catch (_) {}

    return summary;
  }
}
