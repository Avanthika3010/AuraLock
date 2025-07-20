import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SwipeService {
  final List<SwipeGesture> _swipeGestures = [];
  final List<double> _swipeSpeeds = [];
  final List<String> _swipeDirections = [];
  
  // Swipe detection variables
  DateTime? _startTime;
  Offset? _startPosition;
  bool _isTracking = false;
  
  // Stream controllers for real-time updates
  final StreamController<SwipeGesture> _swipeController = StreamController<SwipeGesture>.broadcast();
  final StreamController<double> _stabilityController = StreamController<double>.broadcast();

  // Getters for streams
  Stream<SwipeGesture> get swipeStream => _swipeController.stream;
  Stream<double> get stabilityStream => _stabilityController.stream;

  /// Start tracking swipe gestures
  void startTracking() {
    _resetMetrics();
    _isTracking = true;
    debugPrint('🔄 SwipeService: Tracking started - Ready to detect swipe gestures');
    print('📱 Swipe tracking initialized - Touch and drag on screen to record gestures');
  }

  /// Stop tracking swipe gestures
  Future<void> stopTracking() async {
    _isTracking = false;
    debugPrint('🛑 SwipeService: Tracking stopped');
    print('📊 SwipeService: Final swipe count: ${_swipeGestures.length}');
    await _calculateAndUploadMetrics();
    debugPrint('✅ SwipeService: Tracking stopped and metrics uploaded');
  }

  /// Reset all metrics
  void _resetMetrics() {
    _swipeGestures.clear();
    _swipeSpeeds.clear();
    _swipeDirections.clear();
    _startTime = null;
    _startPosition = null;
    debugPrint('🔄 SwipeService: Metrics reset - Clean slate for new tracking session');
  }

  /// Handle pan start (beginning of swipe)
  void onPanStart(DragStartDetails details) {
    if (!_isTracking) {
      debugPrint('⚠️ SwipeService: Ignoring pan start - tracking not active');
      return;
    }
    
    _startTime = DateTime.now();
    _startPosition = details.globalPosition;
    debugPrint('👆 SwipeService: Pan start detected at position: ${_startPosition}');
    print('🎯 Swipe started at: (${_startPosition!.dx.toStringAsFixed(1)}, ${_startPosition!.dy.toStringAsFixed(1)})');
  }

  /// Handle pan end (end of swipe)
  void onPanEnd(DragEndDetails details) {
    if (!_isTracking) {
      debugPrint('⚠️ SwipeService: Ignoring pan end - tracking not active');
      return;
    }
    
    if (_startTime == null || _startPosition == null) {
      debugPrint('⚠️ SwipeService: Pan end without start - ignoring gesture');
      return;
    }

    final endTime = DateTime.now();
    final endPosition = details.globalPosition;
    
    // Calculate swipe metrics
    final duration = endTime.difference(_startTime!).inMilliseconds;
    final distance = _calculateDistance(_startPosition!, endPosition);
    final speed = duration > 0 ? distance / duration : 0.0; // pixels per millisecond
    final direction = _calculateDirection(_startPosition!, endPosition);
    
    // Create swipe gesture object
    final swipeGesture = SwipeGesture(
      startPosition: _startPosition!,
      endPosition: endPosition,
      startTime: _startTime!,
      endTime: endTime,
      duration: duration,
      distance: distance,
      speed: speed,
      direction: direction,
    );
    
    // Store metrics
    _swipeGestures.add(swipeGesture);
    _swipeSpeeds.add(speed);
    _swipeDirections.add(direction);
    
    // Update streams
    _swipeController.add(swipeGesture);
    _updateStability();
    
    debugPrint('✅ SwipeService: Swipe detected - Direction: $direction, Speed: ${speed.toStringAsFixed(3)} px/ms, Distance: ${distance.toStringAsFixed(1)}px, Duration: ${duration}ms');
    print('📱 Swipe #${_swipeGestures.length}: $direction direction, ${speed.toStringAsFixed(2)} px/ms speed, ${distance.toStringAsFixed(0)}px distance');
    
    // Reset for next swipe
    _startTime = null;
    _startPosition = null;
  }

  /// Calculate distance between two points
  double _calculateDistance(Offset start, Offset end) {
    return sqrt(pow(end.dx - start.dx, 2) + pow(end.dy - start.dy, 2));
  }

  /// Calculate swipe direction
  String _calculateDirection(Offset start, Offset end) {
    final deltaX = end.dx - start.dx;
    final deltaY = end.dy - start.dy;
    
    // Determine primary direction
    if (deltaX.abs() > deltaY.abs()) {
      return deltaX > 0 ? 'Right' : 'Left';
    } else {
      return deltaY > 0 ? 'Down' : 'Up';
    }
  }

  /// Calculate swipe pattern stability
  void _updateStability() {
    if (_swipeSpeeds.length < 2) {
      debugPrint('📊 SwipeService: Not enough swipes for stability calculation (${_swipeSpeeds.length} swipes)');
      return;
    }
    
    // Calculate coefficient of variation (standard deviation / mean)
    final mean = _swipeSpeeds.reduce((a, b) => a + b) / _swipeSpeeds.length;
    final variance = _swipeSpeeds.map((speed) => pow(speed - mean, 2)).reduce((a, b) => a + b) / _swipeSpeeds.length;
    final standardDeviation = sqrt(variance);
    final coefficientOfVariation = mean > 0 ? standardDeviation / mean : 0.0;
    
    // Convert to stability score (0-1, where 1 is most stable)
    final stability = (1.0 - coefficientOfVariation).clamp(0.0, 1.0);
    
    _stabilityController.add(stability);
    
    debugPrint('📊 SwipeService: Stability updated - Mean: ${mean.toStringAsFixed(3)}, StdDev: ${standardDeviation.toStringAsFixed(3)}, Stability: ${stability.toStringAsFixed(3)}');
    print('🎯 Swipe stability: ${(stability * 100).toStringAsFixed(1)}% (${_swipeSpeeds.length} swipes analyzed)');
  }

  /// Calculate and upload metrics to Firestore
  Future<void> _calculateAndUploadMetrics() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('⚠️ SwipeService: No user logged in - cannot upload metrics');
        return;
      }

      if (_swipeGestures.isEmpty) {
        debugPrint('📊 SwipeService: No swipe gestures to upload');
        return;
      }

      debugPrint('📤 SwipeService: Starting metrics upload for ${_swipeGestures.length} swipes');

      // Calculate metrics
      final averageSpeed = _swipeSpeeds.reduce((a, b) => a + b) / _swipeSpeeds.length;
      final averageDistance = _swipeGestures.map((swipe) => swipe.distance).reduce((a, b) => a + b) / _swipeGestures.length;
      final averageDuration = _swipeGestures.map((swipe) => swipe.duration).reduce((a, b) => a + b) / _swipeGestures.length;
      
      // Calculate direction distribution
      final directionCounts = <String, int>{};
      for (final direction in _swipeDirections) {
        directionCounts[direction] = (directionCounts[direction] ?? 0) + 1;
      }
      
      // Calculate stability
      final mean = _swipeSpeeds.reduce((a, b) => a + b) / _swipeSpeeds.length;
      final variance = _swipeSpeeds.map((speed) => pow(speed - mean, 2)).reduce((a, b) => a + b) / _swipeSpeeds.length;
      final standardDeviation = sqrt(variance);
      final coefficientOfVariation = mean > 0 ? standardDeviation / mean : 0.0;
      final stability = (1.0 - coefficientOfVariation).clamp(0.0, 1.0);

      debugPrint('📊 SwipeService: Calculated metrics - AvgSpeed: ${averageSpeed.toStringAsFixed(3)}, AvgDistance: ${averageDistance.toStringAsFixed(1)}, AvgDuration: ${averageDuration.toStringAsFixed(0)}ms, Stability: ${stability.toStringAsFixed(3)}');
      print('📈 Swipe metrics: ${averageSpeed.toStringAsFixed(2)} px/ms avg speed, ${averageDistance.toStringAsFixed(0)}px avg distance, ${(stability * 100).toStringAsFixed(1)}% stability');

      // Upload to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'swipeMetrics': {
          'averageSpeed': averageSpeed,
          'averageDistance': averageDistance,
          'averageDuration': averageDuration,
          'swipeCount': _swipeGestures.length,
          'directionDistribution': directionCounts,
          'stability': stability,
        },
        'lastSwipeUpdate': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ SwipeService: Metrics uploaded successfully to Firestore');
      print('📤 Swipe data uploaded: ${_swipeGestures.length} swipes, ${(stability * 100).toStringAsFixed(1)}% stability, Direction distribution: $directionCounts');
    } catch (e) {
      debugPrint('❌ SwipeService: Error uploading metrics: $e');
      print('💥 Failed to upload swipe metrics: $e');
    }
  }

  /// Get current swipe count
  int get swipeCount => _swipeGestures.length;

  /// Get average swipe speed
  double get averageSpeed {
    if (_swipeSpeeds.isEmpty) return 0.0;
    return _swipeSpeeds.reduce((a, b) => a + b) / _swipeSpeeds.length;
  }

  /// Get swipe pattern stability
  double get stability {
    if (_swipeSpeeds.length < 2) return 1.0;
    
    final mean = _swipeSpeeds.reduce((a, b) => a + b) / _swipeSpeeds.length;
    final variance = _swipeSpeeds.map((speed) => pow(speed - mean, 2)).reduce((a, b) => a + b) / _swipeSpeeds.length;
    final standardDeviation = sqrt(variance);
    final coefficientOfVariation = mean > 0 ? standardDeviation / mean : 0.0;
    
    return (1.0 - coefficientOfVariation).clamp(0.0, 1.0);
  }

  /// Check if tracking is active
  bool get isTracking => _isTracking;

  /// Dispose of resources
  void dispose() {
    _swipeController.close();
    _stabilityController.close();
  }
}

/// Data class for swipe gesture
class SwipeGesture {
  final Offset startPosition;
  final Offset endPosition;
  final DateTime startTime;
  final DateTime endTime;
  final int duration;
  final double distance;
  final double speed;
  final String direction;

  SwipeGesture({
    required this.startPosition,
    required this.endPosition,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.distance,
    required this.speed,
    required this.direction,
  });

  @override
  String toString() {
    return 'SwipeGesture(direction: $direction, speed: ${speed.toStringAsFixed(2)}, distance: ${distance.toStringAsFixed(1)})';
  }
}

/// Example widget to demonstrate SwipeService usage
class SwipeMonitorWidget extends StatefulWidget {
  const SwipeMonitorWidget({super.key});

  @override
  State<SwipeMonitorWidget> createState() => _SwipeMonitorWidgetState();
}

class _SwipeMonitorWidgetState extends State<SwipeMonitorWidget> {
  final SwipeService _swipeService = SwipeService();
  bool _isTracking = false;

  @override
  void initState() {
    super.initState();
    _swipeService.startTracking();
    setState(() {
      _isTracking = true;
    });
  }

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      await _swipeService.stopTracking();
    } else {
      _swipeService.startTracking();
    }
    setState(() {
      _isTracking = _swipeService.isTracking;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.touch_app,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Swipe Monitor',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Swipe area
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outline),
                borderRadius: BorderRadius.circular(12),
              ),
              child: GestureDetector(
                onPanStart: _swipeService.onPanStart,
                onPanEnd: _swipeService.onPanEnd,
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.swipe,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Swipe here to test',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Real-time metrics
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<SwipeGesture>(
                    stream: _swipeService.swipeStream,
                    builder: (context, snapshot) {
                      final swipe = snapshot.data;
                      return Column(
                        children: [
                          Text(
                            swipe?.direction ?? 'None',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Text(
                            'Direction',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Expanded(
                  child: StreamBuilder<SwipeGesture>(
                    stream: _swipeService.swipeStream,
                    builder: (context, snapshot) {
                      final swipe = snapshot.data;
                      return Column(
                        children: [
                          Text(
                            swipe != null ? '${(swipe.speed * 1000).toStringAsFixed(0)}' : '0',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Text(
                            'px/s',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Expanded(
                  child: StreamBuilder<double>(
                    stream: _swipeService.stabilityStream,
                    builder: (context, snapshot) {
                      return Column(
                        children: [
                          Text(
                            '${((snapshot.data ?? 1.0) * 100).toStringAsFixed(0)}',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Text(
                            'Stability %',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Swipe count
            StreamBuilder<SwipeGesture>(
              stream: _swipeService.swipeStream,
              builder: (context, snapshot) {
                return Text(
                  'Total Swipes: ${_swipeService.swipeCount}',
                  style: Theme.of(context).textTheme.bodyMedium,
                );
              },
            ),
            const SizedBox(height: 16),
            
            // Control button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _toggleTracking,
                child: Text(_isTracking ? 'Stop Tracking' : 'Start Tracking'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _swipeService.dispose();
    super.dispose();
  }
} 