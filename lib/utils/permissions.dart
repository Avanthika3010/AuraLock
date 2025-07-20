import 'package:permission_handler/permission_handler.dart';

class Permissions {
  /// Check if camera permission is granted
  static Future<bool> isCameraPermissionGranted() async {
    try {
      final status = await Permission.camera.status;
      return status.isGranted;
    } catch (e) {
      print('Error checking camera permission: $e');
      return false;
    }
  }

  /// Request camera permission
  static Future<bool> requestCameraPermission() async {
    try {
      final status = await Permission.camera.request();
      return status.isGranted;
    } catch (e) {
      print('Error requesting camera permission: $e');
      return false;
    }
  }

  /// Check if microphone permission is granted
  static Future<bool> isMicrophonePermissionGranted() async {
    try {
      final status = await Permission.microphone.status;
      return status.isGranted;
    } catch (e) {
      print('Error checking microphone permission: $e');
      return false;
    }
  }

  /// Request microphone permission
  static Future<bool> requestMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      return status.isGranted;
    } catch (e) {
      print('Error requesting microphone permission: $e');
      return false;
    }
  }

  /// Check if storage permission is granted (for saving data)
  static Future<bool> isStoragePermissionGranted() async {
    try {
      final status = await Permission.storage.status;
      return status.isGranted;
    } catch (e) {
      print('Error checking storage permission: $e');
      return false;
    }
  }

  /// Request storage permission
  static Future<bool> requestStoragePermission() async {
    try {
      final status = await Permission.storage.request();
      return status.isGranted;
    } catch (e) {
      print('Error requesting storage permission: $e');
      return false;
    }
  }

  /// Request all necessary permissions for the app
  static Future<Map<Permission, bool>> requestAllPermissions() async {
    try {
      final permissions = await [
        Permission.camera,
        Permission.microphone,
        Permission.storage,
      ].request();

      // Convert PermissionStatus to bool
      final result = <Permission, bool>{};
      permissions.forEach((permission, status) {
        result[permission] = status.isGranted;
      });

      print('Permission results: $result');
      return result;
    } catch (e) {
      print('Error requesting all permissions: $e');
      return {};
    }
  }

  /// Check if all necessary permissions are granted
  static Future<bool> areAllPermissionsGranted() async {
    try {
      final cameraGranted = await isCameraPermissionGranted();
      final microphoneGranted = await isMicrophonePermissionGranted();
      final storageGranted = await isStoragePermissionGranted();

      return cameraGranted && microphoneGranted && storageGranted;
    } catch (e) {
      print('Error checking all permissions: $e');
      return false;
    }
  }

  /// Open app settings if permissions are permanently denied
  static Future<bool> openAppSettings() async {
    try {
      final opened = await openAppSettings();
      return opened;
    } catch (e) {
      print('Error opening app settings: $e');
      return false;
    }
  }

  /// Check if permission is permanently denied
  static Future<bool> isPermissionPermanentlyDenied(Permission permission) async {
    try {
      final status = await permission.status;
      return status.isPermanentlyDenied;
    } catch (e) {
      print('Error checking if permission is permanently denied: $e');
      return false;
    }
  }

  /// Get permission status description
  static String getPermissionStatusDescription(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return 'Permission granted';
      case PermissionStatus.denied:
        return 'Permission denied';
      case PermissionStatus.permanentlyDenied:
        return 'Permission permanently denied - please enable in settings';
      case PermissionStatus.restricted:
        return 'Permission restricted';
      case PermissionStatus.limited:
        return 'Permission limited';
      case PermissionStatus.provisional:
        return 'Permission provisional';
      default:
        return 'Unknown permission status';
    }
  }

  /// Request camera permission with user-friendly messaging
  static Future<bool> requestCameraPermissionWithMessage() async {
    try {
      // Check current status
      final status = await Permission.camera.status;
      
      if (status.isGranted) {
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        print('Camera permission permanently denied. Please enable in app settings.');
        return false;
      }
      
      // Request permission
      final result = await Permission.camera.request();
      return result.isGranted;
    } catch (e) {
      print('Error requesting camera permission: $e');
      return false;
    }
  }

  /// Request microphone permission with user-friendly messaging
  static Future<bool> requestMicrophonePermissionWithMessage() async {
    try {
      // Check current status
      final status = await Permission.microphone.status;
      
      if (status.isGranted) {
        return true;
      }
      
      if (status.isPermanentlyDenied) {
        print('Microphone permission permanently denied. Please enable in app settings.');
        return false;
      }
      
      // Request permission
      final result = await Permission.microphone.request();
      return result.isGranted;
    } catch (e) {
      print('Error requesting microphone permission: $e');
      return false;
    }
  }

  /// Check and request permissions needed for blink detection
  static Future<bool> ensureBlinkDetectionPermissions() async {
    try {
      final cameraGranted = await requestCameraPermissionWithMessage();
      if (!cameraGranted) {
        print('Camera permission required for blink detection');
        return false;
      }
      
      return true;
    } catch (e) {
      print('Error ensuring blink detection permissions: $e');
      return false;
    }
  }

  /// Check and request permissions needed for voice analysis
  static Future<bool> ensureVoiceAnalysisPermissions() async {
    try {
      final microphoneGranted = await requestMicrophonePermissionWithMessage();
      if (!microphoneGranted) {
        print('Microphone permission required for voice analysis');
        return false;
      }
      
      return true;
    } catch (e) {
      print('Error ensuring voice analysis permissions: $e');
      return false;
    }
  }

  /// Get a summary of all permission statuses
  static Future<Map<String, String>> getPermissionStatusSummary() async {
    try {
      final cameraStatus = await Permission.camera.status;
      final microphoneStatus = await Permission.microphone.status;
      final storageStatus = await Permission.storage.status;

      return {
        'camera': getPermissionStatusDescription(cameraStatus),
        'microphone': getPermissionStatusDescription(microphoneStatus),
        'storage': getPermissionStatusDescription(storageStatus),
      };
    } catch (e) {
      print('Error getting permission status summary: $e');
      return {
        'camera': 'Error checking status',
        'microphone': 'Error checking status',
        'storage': 'Error checking status',
      };
    }
  }
}

/// Example usage:
/// 
/// ```dart
/// // Check if camera permission is granted
/// final hasCameraPermission = await Permissions.isCameraPermissionGranted();
/// 
/// // Request camera permission
/// final cameraGranted = await Permissions.requestCameraPermission();
/// 
/// // Check all permissions
/// final allGranted = await Permissions.areAllPermissionsGranted();
/// 
/// // Request all permissions
/// final results = await Permissions.requestAllPermissions();
/// 
/// // Ensure permissions for specific features
/// final blinkPermissions = await Permissions.ensureBlinkDetectionPermissions();
/// final voicePermissions = await Permissions.ensureVoiceAnalysisPermissions();
/// 
/// // Get permission status summary
/// final summary = await Permissions.getPermissionStatusSummary();
/// print('Camera: ${summary['camera']}');
/// print('Microphone: ${summary['microphone']}');
/// print('Storage: ${summary['storage']}');
/// 
/// // Open app settings if needed
/// if (await Permissions.isPermissionPermanentlyDenied(Permission.camera)) {
///   await Permissions.openAppSettings();
/// }
/// ``` 