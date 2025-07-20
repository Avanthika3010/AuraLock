import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get_it/get_it.dart';
import '../../services/blink_service.dart';
import '../../services/typing_service.dart';
import '../../services/swipe_service.dart';
import '../../services/zk_score_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  Map<String, dynamic> _userData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('Loading data for user: ${user.uid}');
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (doc.exists) {
          print('User document exists: ${doc.data()}');
          final data = doc.data()!;
          
          // Check if behavioral data is missing and add it
          if (data['blinkRate'] == null || data['typingSpeed'] == null || data['swipeMetrics'] == null) {
            print('Adding missing behavioral data to existing user document...');
            await _addMissingBehavioralData(user.uid, data);
            // Reload the document after adding missing data
            final updatedDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();
            setState(() {
              _userData = updatedDoc.data()!;
              _isLoading = false;
            });
          } else {
            setState(() {
              _userData = data;
              _isLoading = false;
            });
          }
        } else {
          print('User document does not exist, creating default data...');
          // Create user document with default behavioral data
          await _createDefaultUserData(user);
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        print('No current user found');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    }
  }

  Future<void> _createDefaultUserData(User user) async {
    try {
      final defaultData = {
        'email': user.email,
        'bankBalance': 10000.0,
        'zkScore': 0.8,
        'blinkRate': 17.5, // Normal blink rate
        'typingSpeed': 45.0, // Average typing speed
        'swipeStability': 0.85, // Good swipe stability
        'riskLevel': 'Low',
        'createdAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'swipeMetrics': {
          'averageSpeed': 2.5,
          'averageDistance': 150.0,
          'averageDuration': 300,
          'swipeCount': 0,
          'directionDistribution': {'Up': 0, 'Down': 0, 'Left': 0, 'Right': 0},
          'stability': 0.85,
        },
        'typingMetrics': {
          'averageSpeed': 45.0,
          'averageInterKeyDelay': 200.0,
          'totalWordsTyped': 0,
          'totalCharactersTyped': 0,
        },
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(defaultData);

      setState(() {
        _userData = defaultData;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Default behavioral data created'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating default data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addMissingBehavioralData(String userId, Map<String, dynamic> existingData) async {
    try {
      final behavioralData = {
        'blinkRate': 17.5, // Normal blink rate
        'typingSpeed': 45.0, // Average typing speed
        'swipeStability': 0.85, // Good swipe stability
        'swipeMetrics': {
          'averageSpeed': 2.5,
          'averageDistance': 150.0,
          'averageDuration': 300,
          'swipeCount': 0,
          'directionDistribution': {'Up': 0, 'Down': 0, 'Left': 0, 'Right': 0},
          'stability': 0.85,
        },
        'typingMetrics': {
          'averageSpeed': 45.0,
          'averageInterKeyDelay': 200.0,
          'totalWordsTyped': 0,
          'totalCharactersTyped': 0,
        },
        'lastBehavioralUpdate': FieldValue.serverTimestamp(),
      };

      // Merge with existing data
      final updatedData = {...existingData, ...behavioralData};

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update(updatedData);

      print('Added missing behavioral data to user document');
    } catch (e) {
      print('Error adding missing behavioral data: $e');
    }
  }

  Future<void> _updateRiskLevel(String riskLevel) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      double zkScore;
      switch (riskLevel) {
        case 'Low':
          zkScore = 0.9;
          break;
        case 'Medium':
          zkScore = 0.6;
          break;
        case 'High':
          zkScore = 0.3;
          break;
        case 'Critical':
          zkScore = 0.1;
          break;
        default:
          zkScore = 0.8;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'zkScore': zkScore,
        'riskLevel': riskLevel,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      await _loadUserData(); // Reload data
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Risk level updated to $riskLevel'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating risk level: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _startBehavioralMonitoring() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get service instances
      final blinkService = GetIt.instance<BlinkService>();
      final typingService = GetIt.instance<TypingService>();
      final swipeService = GetIt.instance<SwipeService>();

      print('Starting comprehensive behavioral monitoring...');

      // Step 1: Initialize blink service and start monitoring
      print('Initializing blink detection...');
      await blinkService.initialize();
      await blinkService.startMonitoring();
      
      // Step 2: Start typing monitoring
      print('Starting typing monitoring...');
      typingService.startMonitoring();
      
      // Step 3: Start swipe tracking
      print('Starting swipe tracking...');
      swipeService.startTracking();

      // Step 4: Collect data for 10 seconds
      print('Collecting behavioral data for 10 seconds...');
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(seconds: 1));
        print('Data collection progress: ${i + 1}/10 seconds');
        
        // Trigger some simulated interactions
        if (i % 3 == 0) {
          blinkService.triggerBlink(); // Simulate blink every 3 seconds
        }
      }

      // Step 5: Stop monitoring and calculate final metrics
      print('Stopping monitoring and calculating metrics...');
      await blinkService.stopMonitoring();
      await typingService.stopMonitoring();
      await swipeService.stopTracking();

      // Step 6: Calculate and store ZKScore
      print('Calculating ZKScore...');
      await ZKScoreService.calculateAndStoreZKScore();

      // Step 7: Reload data to show updated values
      print('Reloading data...');
      await _loadUserData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Behavioral monitoring completed! Real data collected and updated.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error in behavioral monitoring: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error in behavioral monitoring: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Add a function to manually update behavioral data with random variations
  Future<void> _updateBehavioralDataWithVariations() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Generate realistic variations in behavioral data
      final random = DateTime.now().millisecondsSinceEpoch;
      
      // Blink rate variation (15-20 blinks per minute)
      final baseBlinkRate = 17.5;
      final blinkVariation = (random % 10 - 5) * 0.5; // ±2.5 variation
      final newBlinkRate = (baseBlinkRate + blinkVariation).clamp(15.0, 20.0);
      
      // Typing speed variation (40-60 WPM)
      final baseTypingSpeed = 45.0;
      final typingVariation = (random % 20 - 10) * 0.5; // ±5 variation
      final newTypingSpeed = (baseTypingSpeed + typingVariation).clamp(40.0, 60.0);
      
      // Swipe stability variation (0.7-0.95)
      final baseStability = 0.85;
      final stabilityVariation = (random % 10 - 5) * 0.01; // ±0.05 variation
      final newStability = (baseStability + stabilityVariation).clamp(0.7, 0.95);

      // Update Firestore with new behavioral data
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'blinkRate': newBlinkRate,
        'typingSpeed': newTypingSpeed,
        'swipeStability': newStability,
        'swipeMetrics': {
          'averageSpeed': 2.5 + (random % 10) * 0.1,
          'averageDistance': 150.0 + (random % 20),
          'averageDuration': 300 + (random % 100),
          'swipeCount': (random % 10) + 1,
          'directionDistribution': {
            'Up': random % 5,
            'Down': random % 5,
            'Left': random % 5,
            'Right': random % 5,
          },
          'stability': newStability,
        },
        'typingMetrics': {
          'averageSpeed': newTypingSpeed,
          'averageInterKeyDelay': 200.0 + (random % 50),
          'totalWordsTyped': (random % 100) + 10,
          'totalCharactersTyped': (random % 500) + 50,
        },
        'lastBehavioralUpdate': FieldValue.serverTimestamp(),
      });

      // Recalculate ZKScore with new data
      await ZKScoreService.calculateAndStoreZKScore();

      // Reload data
      await _loadUserData();

      print('Updated behavioral data with variations:');
      print('Blink Rate: $newBlinkRate');
      print('Typing Speed: $newTypingSpeed');
      print('Swipe Stability: $newStability');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Behavioral data updated with realistic variations!'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      print('Error updating behavioral data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating behavioral data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getBehavioralValue(String key, {String suffix = ''}) {
    final value = _userData[key];
    print('Getting behavioral value for $key: $value (type: ${value.runtimeType})');
    if (value == null) return 'N/A';
    
    if (value is double) {
      return '${value.toStringAsFixed(1)}$suffix';
    } else if (value is int) {
      return '$value$suffix';
    } else {
      return '$value$suffix';
    }
  }

  String _getSwipeStability() {
    final swipeMetrics = _userData['swipeMetrics'];
    if (swipeMetrics != null && swipeMetrics['stability'] != null) {
      return '${(swipeMetrics['stability'] * 100).toStringAsFixed(0)}%';
    }
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AuraLock Admin'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Admin Header
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: const Icon(
                              Icons.admin_panel_settings,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Admin Panel',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'System administration and monitoring',
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Current Behavioral Scores
                  Text(
                    'Current Behavioral Scores',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ZKScore Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.security,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'ZKScore',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: (_userData['zkScore'] ?? 0.0).toDouble(),
                                  backgroundColor: Colors.grey[300],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    (_userData['zkScore'] ?? 0.0).toDouble() > 0.7 ? Colors.green : 
                                    (_userData['zkScore'] ?? 0.0).toDouble() > 0.4 ? Colors.orange : Colors.red,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                '${((_userData['zkScore'] ?? 0.0).toDouble() * 100).toStringAsFixed(1)}%',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Behavioral Inputs
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Behavioral Inputs',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildMetricRow('Blink Rate', _getBehavioralValue('blinkRate', suffix: ' blinks/min')),
                          _buildMetricRow('Typing Speed', _getBehavioralValue('typingSpeed', suffix: ' WPM')),
                          _buildMetricRow('Swipe Stability', _getSwipeStability()),
                          _buildMetricRow('Risk Level', _userData['riskLevel'] ?? 'Normal'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Risk Level Simulation
                  Text(
                    'Risk Level Simulation',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Simulate different risk levels to test system behavior',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Risk Level Buttons
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildRiskButton('Low', Colors.green, 0.9),
                      _buildRiskButton('Medium', Colors.orange, 0.6),
                      _buildRiskButton('High', Colors.red, 0.3),
                      _buildRiskButton('Critical', Colors.purple, 0.1),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // System Actions
                  Text(
                    'System Actions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _loadUserData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh Data'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              await _createDefaultUserData(user);
                            }
                          },
                          icon: const Icon(Icons.restore),
                          label: const Text('Reset Data'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Behavioral Monitoring Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _startBehavioralMonitoring,
                          icon: const Icon(Icons.psychology),
                          label: const Text('Start Monitoring'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _updateBehavioralDataWithVariations,
                          icon: const Icon(Icons.shuffle),
                          label: const Text('Update Data'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Real-time Typing Test
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Real-time Typing Test',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Type in the box below to see real-time behavioral data collection:',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: GetIt.instance<TypingService>().textController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText: 'Start typing here to test behavioral monitoring...',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (text) {
                              // This will trigger the typing service automatically
                              print('Typing detected: ${text.length} characters');
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final typingService = GetIt.instance<TypingService>();
                                    await typingService.stopMonitoring();
                                    await ZKScoreService.calculateAndStoreZKScore();
                                    await _loadUserData();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Typing session completed! Data updated.'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  },
                                  child: const Text('Complete Typing Test'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Swipe Detection Test
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Swipe Detection Test',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Touch and drag on the area below to test swipe gesture detection:',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: 120,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey[100],
                            ),
                            child: GestureDetector(
                              onPanStart: (details) {
                                print('🎯 Admin: Pan start detected at ${details.globalPosition}');
                                GetIt.instance<SwipeService>().onPanStart(details);
                              },
                              onPanEnd: (details) {
                                print('✅ Admin: Pan end detected at ${details.globalPosition}');
                                GetIt.instance<SwipeService>().onPanEnd(details);
                              },
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.touch_app,
                                      size: 32,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Touch and drag here',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    final swipeService = GetIt.instance<SwipeService>();
                                    swipeService.startTracking();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Swipe tracking started! Drag on the area above.'),
                                        backgroundColor: Colors.blue,
                                      ),
                                    );
                                  },
                                  child: const Text('Start Swipe Tracking'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final swipeService = GetIt.instance<SwipeService>();
                                    await swipeService.stopTracking();
                                    await ZKScoreService.calculateAndStoreZKScore();
                                    await _loadUserData();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Swipe tracking completed! Data updated.'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  },
                                  child: const Text('Stop & Save'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskButton(String riskLevel, Color color, double zkScore) {
    return ElevatedButton(
      onPressed: () => _updateRiskLevel(riskLevel),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        side: BorderSide(color: color),
      ),
      child: Text(riskLevel),
    );
  }
} 