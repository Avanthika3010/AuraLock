import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocalStorageRepo {
  static const String _blinkRateKey = 'blink_rate_baseline';
  static const String _typingSpeedKey = 'typing_speed_baseline';
  static const String _swipeStabilityKey = 'swipe_stability_baseline';
  static const String _lastSyncKey = 'last_sync_timestamp';
  static const String _isOnlineKey = 'is_online';

  /// Save blink rate baseline locally
  static Future<void> saveBlinkRate(double blinkRate) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_blinkRateKey, blinkRate);
      print('Blink rate saved locally: $blinkRate');
    } catch (e) {
      print('Error saving blink rate locally: $e');
    }
  }

  /// Get blink rate baseline from local storage
  static Future<double?> getBlinkRate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_blinkRateKey);
    } catch (e) {
      print('Error getting blink rate from local storage: $e');
      return null;
    }
  }

  /// Save typing speed baseline locally
  static Future<void> saveTypingSpeed(double typingSpeed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_typingSpeedKey, typingSpeed);
      print('Typing speed saved locally: $typingSpeed');
    } catch (e) {
      print('Error saving typing speed locally: $e');
    }
  }

  /// Get typing speed baseline from local storage
  static Future<double?> getTypingSpeed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_typingSpeedKey);
    } catch (e) {
      print('Error getting typing speed from local storage: $e');
      return null;
    }
  }

  /// Save swipe stability baseline locally
  static Future<void> saveSwipeStability(double stability) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_swipeStabilityKey, stability);
      print('Swipe stability saved locally: $stability');
    } catch (e) {
      print('Error saving swipe stability locally: $e');
    }
  }

  /// Get swipe stability baseline from local storage
  static Future<double?> getSwipeStability() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_swipeStabilityKey);
    } catch (e) {
      print('Error getting swipe stability from local storage: $e');
      return null;
    }
  }

  /// Save all behavioral baselines locally
  static Future<void> saveBehavioralBaselines({
    required double blinkRate,
    required double typingSpeed,
    required double swipeStability,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.setDouble(_blinkRateKey, blinkRate),
        prefs.setDouble(_typingSpeedKey, typingSpeed),
        prefs.setDouble(_swipeStabilityKey, swipeStability),
        prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch),
      ]);
      print('All behavioral baselines saved locally');
    } catch (e) {
      print('Error saving behavioral baselines locally: $e');
    }
  }

  /// Get all behavioral baselines from local storage
  static Future<Map<String, double?>> getBehavioralBaselines() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'blinkRate': prefs.getDouble(_blinkRateKey),
        'typingSpeed': prefs.getDouble(_typingSpeedKey),
        'swipeStability': prefs.getDouble(_swipeStabilityKey),
      };
    } catch (e) {
      print('Error getting behavioral baselines from local storage: $e');
      return {
        'blinkRate': null,
        'typingSpeed': null,
        'swipeStability': null,
      };
    }
  }

  /// Sync local data to Firebase Firestore
  static Future<bool> syncToFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No authenticated user for sync');
        return false;
      }

      final baselines = await getBehavioralBaselines();
      
      // Only sync if we have data
      if (baselines.values.every((value) => value != null)) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'localBaselines': {
            'blinkRate': baselines['blinkRate'],
            'typingSpeed': baselines['typingSpeed'],
            'swipeStability': baselines['swipeStability'],
            'lastLocalUpdate': FieldValue.serverTimestamp(),
          },
        });

        // Update last sync timestamp
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_lastSyncKey, DateTime.now().millisecondsSinceEpoch);

        print('Local data synced to Firestore successfully');
        return true;
      } else {
        print('No complete baseline data to sync');
        return false;
      }
    } catch (e) {
      print('Error syncing to Firestore: $e');
      return false;
    }
  }

  /// Sync data from Firebase Firestore to local storage
  static Future<bool> syncFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No authenticated user for sync');
        return false;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        print('No user document found for sync');
        return false;
      }

      final data = doc.data()!;
      final localBaselines = data['localBaselines'] as Map<String, dynamic>?;

      if (localBaselines != null) {
        await saveBehavioralBaselines(
          blinkRate: (localBaselines['blinkRate'] ?? 0.0).toDouble(),
          typingSpeed: (localBaselines['typingSpeed'] ?? 0.0).toDouble(),
          swipeStability: (localBaselines['swipeStability'] ?? 1.0).toDouble(),
        );

        print('Data synced from Firestore to local storage');
        return true;
      } else {
        print('No local baselines found in Firestore');
        return false;
      }
    } catch (e) {
      print('Error syncing from Firestore: $e');
      return false;
    }
  }

  /// Check if data needs to be synced (older than 24 hours)
  static Future<bool> needsSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getInt(_lastSyncKey);
      
      if (lastSync == null) return true;

      final lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSync);
      final now = DateTime.now();
      final difference = now.difference(lastSyncTime);

      // Sync if more than 24 hours have passed
      return difference.inHours >= 24;
    } catch (e) {
      print('Error checking sync status: $e');
      return true;
    }
  }

  /// Get last sync timestamp
  static Future<DateTime?> getLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getInt(_lastSyncKey);
      
      if (lastSync != null) {
        return DateTime.fromMillisecondsSinceEpoch(lastSync);
      }
      return null;
    } catch (e) {
      print('Error getting last sync time: $e');
      return null;
    }
  }

  /// Clear all local data
  static Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await Future.wait([
        prefs.remove(_blinkRateKey),
        prefs.remove(_typingSpeedKey),
        prefs.remove(_swipeStabilityKey),
        prefs.remove(_lastSyncKey),
        prefs.remove(_isOnlineKey),
      ]);
      print('All local data cleared');
    } catch (e) {
      print('Error clearing local data: $e');
    }
  }

  /// Set online status
  static Future<void> setOnlineStatus(bool isOnline) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isOnlineKey, isOnline);
    } catch (e) {
      print('Error setting online status: $e');
    }
  }

  /// Get online status
  static Future<bool> getOnlineStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_isOnlineKey) ?? false;
    } catch (e) {
      print('Error getting online status: $e');
      return false;
    }
  }

  /// Auto-sync data when online
  static Future<void> autoSync() async {
    try {
      final isOnline = await getOnlineStatus();
      if (isOnline) {
        final needsSyncData = await needsSync();
        if (needsSyncData) {
          await syncToFirestore();
        }
      }
    } catch (e) {
      print('Error in auto sync: $e');
    }
  }
}

/// Example usage:
/// 
/// ```dart
/// // Save behavioral data locally
/// await LocalStorageRepo.saveBlinkRate(15.0);
/// await LocalStorageRepo.saveTypingSpeed(45.0);
/// await LocalStorageRepo.saveSwipeStability(0.85);
/// 
/// // Or save all at once
/// await LocalStorageRepo.saveBehavioralBaselines(
///   blinkRate: 15.0,
///   typingSpeed: 45.0,
///   swipeStability: 0.85,
/// );
/// 
/// // Get data locally
/// final blinkRate = await LocalStorageRepo.getBlinkRate();
/// final typingSpeed = await LocalStorageRepo.getTypingSpeed();
/// final swipeStability = await LocalStorageRepo.getSwipeStability();
/// 
/// // Or get all at once
/// final baselines = await LocalStorageRepo.getBehavioralBaselines();
/// 
/// // Sync to Firestore
/// final syncSuccess = await LocalStorageRepo.syncToFirestore();
/// 
/// // Sync from Firestore
/// final syncFromSuccess = await LocalStorageRepo.syncFromFirestore();
/// 
/// // Check if sync is needed
/// final needsSync = await LocalStorageRepo.needsSync();
/// 
/// // Auto sync
/// await LocalStorageRepo.autoSync();
/// ``` 