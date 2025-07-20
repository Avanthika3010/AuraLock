import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ZKScoreService {
  /// Calculate ZKScore based on behavioral inputs
  /// Returns a score between 0.0 and 1.0, where 1.0 is highest security
  static double calculateZKScore({
    required double blinkRate,
    required double typingSpeed,
    required double swipeStability,
  }) {
    // Normalize inputs to 0-1 range
    final normalizedBlinkRate = _normalizeBlinkRate(blinkRate);
    final normalizedTypingSpeed = _normalizeTypingSpeed(typingSpeed);
    final normalizedSwipeStability = swipeStability.clamp(0.0, 1.0);

    // Weighted average of behavioral factors
    // Weights can be adjusted based on importance
    const double blinkWeight = 0.3;
    const double typingWeight = 0.3;
    const double swipeWeight = 0.4;

    final zkScore = (normalizedBlinkRate * blinkWeight) +
                   (normalizedTypingSpeed * typingWeight) +
                   (normalizedSwipeStability * swipeWeight);

    return zkScore.clamp(0.0, 1.0);
  }

  /// Normalize blink rate to 0-1 range
  /// Normal blink rate is around 15-20 blinks per minute
  static double _normalizeBlinkRate(double blinkRate) {
    const double normalBlinkRate = 17.5; // Average normal blink rate
    const double tolerance = 5.0; // Acceptable deviation

    final deviation = (blinkRate - normalBlinkRate).abs();
    final normalizedScore = 1.0 - (deviation / tolerance);
    
    return normalizedScore.clamp(0.0, 1.0);
  }

  /// Normalize typing speed to 0-1 range
  /// Normal typing speed is around 40-60 WPM
  static double _normalizeTypingSpeed(double typingSpeed) {
    const double minNormalSpeed = 40.0;
    const double maxNormalSpeed = 60.0;
    const double optimalSpeed = 50.0;

    if (typingSpeed >= minNormalSpeed && typingSpeed <= maxNormalSpeed) {
      // Within normal range, calculate how close to optimal
      final deviation = (typingSpeed - optimalSpeed).abs();
      final maxDeviation = maxNormalSpeed - optimalSpeed;
      return 1.0 - (deviation / maxDeviation);
    } else if (typingSpeed < minNormalSpeed) {
      // Below normal range
      return (typingSpeed / minNormalSpeed).clamp(0.0, 1.0);
    } else {
      // Above normal range, but still acceptable
      const double maxAcceptableSpeed = 80.0;
      if (typingSpeed <= maxAcceptableSpeed) {
        return 1.0 - ((typingSpeed - maxNormalSpeed) / (maxAcceptableSpeed - maxNormalSpeed));
      } else {
        return 0.0;
      }
    }
  }

  /// Store ZKScore in Firestore
  static Future<void> storeZKScore(double zkScore) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'zkScore': zkScore,
        'lastZKScoreUpdate': FieldValue.serverTimestamp(),
        'riskLevel': _getRiskLevel(zkScore),
      });

      print('ZKScore stored: ${zkScore.toStringAsFixed(3)}');
    } catch (e) {
      print('Error storing ZKScore: $e');
    }
  }

  /// Get risk level based on ZKScore
  static String _getRiskLevel(double zkScore) {
    if (zkScore >= 0.8) return 'Low';
    if (zkScore >= 0.6) return 'Medium';
    if (zkScore >= 0.4) return 'High';
    return 'Critical';
  }

  /// Calculate and store ZKScore from user data
  static Future<double> calculateAndStoreZKScore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0.0;

      // Get user data from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) return 0.0;

      final data = doc.data()!;
      
      // Extract behavioral metrics
      final blinkRate = (data['blinkRate'] ?? 0.0).toDouble();
      final typingSpeed = (data['typingSpeed'] ?? 0.0).toDouble();
      final swipeStability = (data['swipeMetrics']?['stability'] ?? 1.0).toDouble();

      // Calculate ZKScore
      final zkScore = calculateZKScore(
        blinkRate: blinkRate,
        typingSpeed: typingSpeed,
        swipeStability: swipeStability,
      );

      // Store the calculated score
      await storeZKScore(zkScore);

      return zkScore;
    } catch (e) {
      print('Error calculating ZKScore: $e');
      return 0.0;
    }
  }

  /// Get current ZKScore from Firestore
  static Future<double> getCurrentZKScore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 0.0;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) return 0.0;

      return (doc.data()?['zkScore'] ?? 0.0).toDouble();
    } catch (e) {
      print('Error getting ZKScore: $e');
      return 0.0;
    }
  }

  /// Get risk level description
  static String getRiskLevelDescription(double zkScore) {
    if (zkScore >= 0.8) {
      return 'Low Risk - Normal behavioral patterns detected';
    } else if (zkScore >= 0.6) {
      return 'Medium Risk - Slight behavioral deviations detected';
    } else if (zkScore >= 0.4) {
      return 'High Risk - Significant behavioral changes detected';
    } else {
      return 'Critical Risk - Unusual behavioral patterns detected';
    }
  }

  /// Get security recommendations based on ZKScore
  static List<String> getSecurityRecommendations(double zkScore) {
    final recommendations = <String>[];

    if (zkScore < 0.8) {
      recommendations.add('Consider additional authentication factors');
    }
    
    if (zkScore < 0.6) {
      recommendations.add('Monitor for suspicious activity');
      recommendations.add('Consider temporary access restrictions');
    }
    
    if (zkScore < 0.4) {
      recommendations.add('Immediate security review recommended');
      recommendations.add('Consider account lockout');
    }

    return recommendations;
  }
}

/// Example usage:
/// 
/// ```dart
/// // Calculate ZKScore from behavioral data
/// final zkScore = ZKScoreService.calculateZKScore(
///   blinkRate: 15.0,
///   typingSpeed: 45.0,
///   swipeStability: 0.85,
/// );
/// 
/// // Store in Firestore
/// await ZKScoreService.storeZKScore(zkScore);
/// 
/// // Or calculate and store in one step
/// final score = await ZKScoreService.calculateAndStoreZKScore();
/// 
/// // Get current score
/// final currentScore = await ZKScoreService.getCurrentZKScore();
/// 
/// // Get risk level description
/// final description = ZKScoreService.getRiskLevelDescription(score);
/// 
/// // Get recommendations
/// final recommendations = ZKScoreService.getSecurityRecommendations(score);
/// ``` 