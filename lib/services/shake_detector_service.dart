import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

class ShakeDetectorService {
  final VoidCallback onShake;
  final double shakeThresholdGravity;
  final int shakeSlopTimeMs;
  final int shakeCountResetTimeMs;
  final int minShakeCount;

  StreamSubscription<AccelerometerEvent>? _subscription;
  int _lastShakeTimestamp = 0;
  int _shakeCount = 0;
  bool _isListening = false;

  ShakeDetectorService({
    required this.onShake,
    this.shakeThresholdGravity = 2.6,
    this.shakeSlopTimeMs = 450,
    this.shakeCountResetTimeMs = 2800,
    this.minShakeCount = 2,
  });

  bool get isListening => _isListening;

  void startListening() {
    if (_isListening) return;
    _isListening = true;
    try {
      _subscription = accelerometerEventStream().listen(
        (AccelerometerEvent event) {
          final gX = event.x / 9.80665;
          final gY = event.y / 9.80665;
          final gZ = event.z / 9.80665;

          final gForce = math.sqrt(gX * gX + gY * gY + gZ * gZ);

          if (gForce > shakeThresholdGravity) {
            final now = DateTime.now().millisecondsSinceEpoch;
            // Ignore events too close to each other
            if (_lastShakeTimestamp + shakeSlopTimeMs > now) {
              return;
            }

            // Reset shake count if too much time has passed
            if (_lastShakeTimestamp + shakeCountResetTimeMs < now) {
              _shakeCount = 0;
            }

            _lastShakeTimestamp = now;
            _shakeCount++;

            if (_shakeCount >= minShakeCount) {
              _shakeCount = 0;
              onShake();
            }
          }
        },
        onError: (error) {
          debugPrint('Accelerometer shake detection error: $error');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('Failed to start shake detector: $e');
    }
  }

  void stopListening() {
    _isListening = false;
    _subscription?.cancel();
    _subscription = null;
  }
}
