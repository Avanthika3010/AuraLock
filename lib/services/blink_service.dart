import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BlinkService {
  bool _isInitialized = false;
  bool _isMonitoring = false;
  Timer? _blinkTimer;
  Timer? _simulationTimer;
  
  // Blink detection variables
  int _blinkCount = 0;
  DateTime? _lastBlinkTime;
  double _eyeOpenThreshold = 0.3; // Threshold for eye open probability
  int _blinkCooldownMs = 300; // Minimum time between blinks
  
  // Stream controllers for real-time updates
  final StreamController<int> _blinkCountController = StreamController<int>.broadcast();
  final StreamController<double> _blinkRateController = StreamController<double>.broadcast();

  // Getters for streams
  Stream<int> get blinkCountStream => _blinkCountController.stream;
  Stream<double> get blinkRateStream => _blinkRateController.stream;

  /// Initialize the blink service (simplified version)
  Future<bool> initialize() async {
    try {
      // For now, we'll simulate the service being ready
      _isInitialized = true;
      debugPrint('BlinkService initialized successfully (simulation mode)');
      return true;
    } catch (e) {
      debugPrint('Error initializing BlinkService: $e');
      return false;
    }
  }

  /// Start monitoring blink rate (simulated)
  Future<void> startMonitoring() async {
    if (!_isInitialized || _isMonitoring) return;

    try {
      _isMonitoring = true;
      _blinkCount = 0;
      _lastBlinkTime = null;

      // Simulate blink detection every 3-5 seconds
      _simulationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        _simulateBlink();
      });

      // Start timer to calculate blink rate every minute
      _blinkTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
        _calculateAndUploadBlinkRate();
      });

      debugPrint('Blink monitoring started (simulation mode)');
    } catch (e) {
      debugPrint('Error starting blink monitoring: $e');
      _isMonitoring = false;
    }
  }

  /// Stop monitoring blink rate
  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;

    try {
      _isMonitoring = false;
      _simulationTimer?.cancel();
      _blinkTimer?.cancel();
      
      // Calculate final blink rate
      await _calculateAndUploadBlinkRate();
      
      debugPrint('Blink monitoring stopped');
    } catch (e) {
      debugPrint('Error stopping blink monitoring: $e');
    }
  }

  /// Simulate blink detection (for testing purposes)
  void _simulateBlink() {
    if (!_isMonitoring) return;

    final now = DateTime.now();
    
    // Simulate random blinks (15-20 blinks per minute on average)
    final random = DateTime.now().millisecondsSinceEpoch % 100;
    if (random < 25) { // 25% chance of blink every 3 seconds
      // Check if enough time has passed since last blink
      if (_lastBlinkTime == null || 
          now.difference(_lastBlinkTime!).inMilliseconds > _blinkCooldownMs) {
        _blinkCount++;
        _lastBlinkTime = now;
        
        // Update stream
        _blinkCountController.add(_blinkCount);
        
        debugPrint('Simulated blink detected! Count: $_blinkCount');
      }
    }
  }

  /// Calculate and upload blink rate to Firestore
  Future<void> _calculateAndUploadBlinkRate() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Calculate blink rate (blinks per minute)
      final blinkRate = _blinkCount.toDouble();
      
      // Upload to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'blinkRate': blinkRate,
        'lastBlinkUpdate': FieldValue.serverTimestamp(),
      });

      // Update stream
      _blinkRateController.add(blinkRate);
      
      debugPrint('Blink rate uploaded: $blinkRate blinks/min');
      
      // Reset counter for next minute
      _blinkCount = 0;
      _blinkCountController.add(_blinkCount);
    } catch (e) {
      debugPrint('Error uploading blink rate: $e');
    }
  }

  /// Manually trigger a blink (for testing)
  void triggerBlink() {
    if (!_isMonitoring) return;
    
    final now = DateTime.now();
    if (_lastBlinkTime == null || 
        now.difference(_lastBlinkTime!).inMilliseconds > _blinkCooldownMs) {
      _blinkCount++;
      _lastBlinkTime = now;
      _blinkCountController.add(_blinkCount);
      debugPrint('Manual blink triggered! Count: $_blinkCount');
    }
  }

  /// Get current blink count
  int get currentBlinkCount => _blinkCount;

  /// Get current blink rate
  double get currentBlinkRate {
    if (_lastBlinkTime == null) return 0.0;
    final elapsedMinutes = DateTime.now().difference(_lastBlinkTime!).inMinutes;
    return elapsedMinutes > 0 ? _blinkCount / elapsedMinutes : 0.0;
  }

  /// Check if service is monitoring
  bool get isMonitoring => _isMonitoring;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Dispose of resources
  Future<void> dispose() async {
    await stopMonitoring();
    _blinkCountController.close();
    _blinkRateController.close();
    _simulationTimer?.cancel();
    _blinkTimer?.cancel();
  }
}

/// Example widget to demonstrate BlinkService usage
class BlinkMonitorWidget extends StatefulWidget {
  const BlinkMonitorWidget({super.key});

  @override
  State<BlinkMonitorWidget> createState() => _BlinkMonitorWidgetState();
}

class _BlinkMonitorWidgetState extends State<BlinkMonitorWidget> {
  final BlinkService _blinkService = BlinkService();
  bool _isMonitoring = false;

  @override
  void initState() {
    super.initState();
    _initializeBlinkService();
  }

  Future<void> _initializeBlinkService() async {
    final success = await _blinkService.initialize();
    if (success) {
      setState(() {});
    }
  }

  Future<void> _toggleMonitoring() async {
    if (_isMonitoring) {
      await _blinkService.stopMonitoring();
    } else {
      await _blinkService.startMonitoring();
    }
    setState(() {
      _isMonitoring = _blinkService.isMonitoring;
    });
  }

  void _triggerBlink() {
    _blinkService.triggerBlink();
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
                  Icons.visibility,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Blink Monitor (Simulation)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Status
            Row(
              children: [
                Icon(
                  _blinkService.isInitialized ? Icons.check_circle : Icons.error,
                  color: _blinkService.isInitialized ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _blinkService.isInitialized ? 'Ready (Simulation Mode)' : 'Not Initialized',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Blink count stream
            StreamBuilder<int>(
              stream: _blinkService.blinkCountStream,
              builder: (context, snapshot) {
                return Text(
                  'Blink Count: ${snapshot.data ?? 0}',
                  style: Theme.of(context).textTheme.bodyLarge,
                );
              },
            ),
            
            const SizedBox(height: 12),
            
            // Control buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _blinkService.isInitialized ? _toggleMonitoring : null,
                    child: Text(_isMonitoring ? 'Stop Monitoring' : 'Start Monitoring'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isMonitoring ? _triggerBlink : null,
                  child: const Text('Trigger Blink'),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Note: This is a simulation. Real camera-based detection will be implemented later.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _blinkService.dispose();
    super.dispose();
  }
} 