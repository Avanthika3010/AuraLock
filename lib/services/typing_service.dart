import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TypingService {
  final TextEditingController _textController = TextEditingController();
  final List<DateTime> _keyPressTimes = [];
  final List<int> _interKeyDelays = [];
  
  // Typing metrics
  int _totalWords = 0;
  int _totalCharacters = 0;
  DateTime? _startTime;
  DateTime? _endTime;
  
  // Stream controllers for real-time updates
  final StreamController<double> _typingSpeedController = StreamController<double>.broadcast();
  final StreamController<double> _averageDelayController = StreamController<double>.broadcast();
  final StreamController<int> _wordCountController = StreamController<int>.broadcast();

  // Getters for streams
  Stream<double> get typingSpeedStream => _typingSpeedController.stream;
  Stream<double> get averageDelayStream => _averageDelayController.stream;
  Stream<int> get wordCountStream => _wordCountController.stream;

  /// Get the text controller for use in widgets
  TextEditingController get textController => _textController;

  /// Start monitoring typing
  void startMonitoring() {
    _resetMetrics();
    _startTime = DateTime.now();
    _textController.addListener(_onTextChanged);
    debugPrint('Typing monitoring started');
  }

  /// Stop monitoring typing and calculate final metrics
  Future<void> stopMonitoring() async {
    _endTime = DateTime.now();
    _textController.removeListener(_onTextChanged);
    
    await _calculateAndUploadMetrics();
    debugPrint('Typing monitoring stopped');
  }

  /// Reset all metrics
  void _resetMetrics() {
    _keyPressTimes.clear();
    _interKeyDelays.clear();
    _totalWords = 0;
    _totalCharacters = 0;
    _startTime = null;
    _endTime = null;
  }

  /// Handle text changes and record key press times
  void _onTextChanged() {
    final currentTime = DateTime.now();
    _keyPressTimes.add(currentTime);
    
    // Calculate inter-key delay if we have at least 2 key presses
    if (_keyPressTimes.length >= 2) {
      final delay = currentTime.difference(_keyPressTimes[_keyPressTimes.length - 2]).inMilliseconds;
      _interKeyDelays.add(delay);
      
      // Update average delay stream
      final averageDelay = _interKeyDelays.reduce((a, b) => a + b) / _interKeyDelays.length;
      _averageDelayController.add(averageDelay);
    }
    
    // Calculate word count
    final text = _textController.text;
    _totalCharacters = text.length;
    _totalWords = text.split(' ').where((word) => word.isNotEmpty).length;
    
    // Update word count stream
    _wordCountController.add(_totalWords);
    
    // Calculate and update typing speed
    if (_startTime != null) {
      final elapsedMinutes = currentTime.difference(_startTime!).inMilliseconds / 60000;
      if (elapsedMinutes > 0) {
        final wordsPerMinute = _totalWords / elapsedMinutes;
        _typingSpeedController.add(wordsPerMinute);
      }
    }
  }

  /// Calculate final metrics and upload to Firestore
  Future<void> _calculateAndUploadMetrics() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      if (_startTime == null || _endTime == null) return;

      final elapsedMinutes = _endTime!.difference(_startTime!).inMilliseconds / 60000;
      final wordsPerMinute = elapsedMinutes > 0 ? _totalWords / elapsedMinutes : 0.0;
      final averageDelay = _interKeyDelays.isNotEmpty 
          ? _interKeyDelays.reduce((a, b) => a + b) / _interKeyDelays.length 
          : 0.0;

      // Upload to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'typingSpeed': wordsPerMinute,
        'averageInterKeyDelay': averageDelay,
        'totalWordsTyped': _totalWords,
        'totalCharactersTyped': _totalCharacters,
        'lastTypingUpdate': FieldValue.serverTimestamp(),
      });

      debugPrint('Typing metrics uploaded: ${wordsPerMinute.toStringAsFixed(1)} WPM, ${averageDelay.toStringAsFixed(1)}ms avg delay');
    } catch (e) {
      debugPrint('Error uploading typing metrics: $e');
    }
  }

  /// Get current typing speed in words per minute
  double get currentTypingSpeed {
    if (_startTime == null) return 0.0;
    final elapsedMinutes = DateTime.now().difference(_startTime!).inMilliseconds / 60000;
    return elapsedMinutes > 0 ? _totalWords / elapsedMinutes : 0.0;
  }

  /// Get average inter-key delay in milliseconds
  double get averageInterKeyDelay {
    if (_interKeyDelays.isEmpty) return 0.0;
    return _interKeyDelays.reduce((a, b) => a + b) / _interKeyDelays.length;
  }

  /// Get total words typed
  int get totalWords => _totalWords;

  /// Get total characters typed
  int get totalCharacters => _totalCharacters;

  /// Check if monitoring is active
  bool get isMonitoring => _startTime != null;

  /// Dispose of resources
  void dispose() {
    _textController.dispose();
    _typingSpeedController.close();
    _averageDelayController.close();
    _wordCountController.close();
  }
}

/// Example widget to demonstrate TypingService usage
class TypingMonitorWidget extends StatefulWidget {
  const TypingMonitorWidget({super.key});

  @override
  State<TypingMonitorWidget> createState() => _TypingMonitorWidgetState();
}

class _TypingMonitorWidgetState extends State<TypingMonitorWidget> {
  final TypingService _typingService = TypingService();
  bool _isMonitoring = false;

  @override
  void initState() {
    super.initState();
    _typingService.startMonitoring();
    setState(() {
      _isMonitoring = true;
    });
  }

  Future<void> _toggleMonitoring() async {
    if (_isMonitoring) {
      await _typingService.stopMonitoring();
    } else {
      _typingService.startMonitoring();
    }
    setState(() {
      _isMonitoring = _typingService.isMonitoring;
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
                  Icons.keyboard,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Typing Monitor',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Sample text field
            TextField(
              controller: _typingService.textController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Type here to test...',
                border: OutlineInputBorder(),
                hintText: 'Start typing to see your metrics...',
              ),
            ),
            const SizedBox(height: 16),
            
            // Real-time metrics
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<double>(
                    stream: _typingService.typingSpeedStream,
                    builder: (context, snapshot) {
                      return Column(
                        children: [
                          Text(
                            '${(snapshot.data ?? 0.0).toStringAsFixed(1)}',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Text(
                            'WPM',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Expanded(
                  child: StreamBuilder<double>(
                    stream: _typingService.averageDelayStream,
                    builder: (context, snapshot) {
                      return Column(
                        children: [
                          Text(
                            '${(snapshot.data ?? 0.0).toStringAsFixed(0)}',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Text(
                            'ms delay',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Expanded(
                  child: StreamBuilder<int>(
                    stream: _typingService.wordCountStream,
                    builder: (context, snapshot) {
                      return Column(
                        children: [
                          Text(
                            '${snapshot.data ?? 0}',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Text(
                            'words',
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
            
            // Control button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _toggleMonitoring,
                child: Text(_isMonitoring ? 'Stop Monitoring' : 'Start Monitoring'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _typingService.dispose();
    super.dispose();
  }
} 