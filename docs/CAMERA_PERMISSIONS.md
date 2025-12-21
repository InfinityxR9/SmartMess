# Camera Permissions Configuration

This document covers the setup of camera permissions for the SmartMess mobile application.

## Overview

The SmartMess application uses the `mobile_scanner` package for QR code scanning on mobile devices. This requires proper camera permissions on both Android and iOS platforms.

## Android Configuration

### Step 1: Update AndroidManifest.xml

Edit `android/app/src/main/AndroidManifest.xml` and add the following permissions:

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Add camera permission -->
    <uses-permission android:name="android.permission.CAMERA" />
    
    <!-- Rest of your manifest... -->
    
    <application>
        <!-- Your application configuration -->
    </application>
</manifest>
```

### Step 2: Gradle Configuration

Ensure `android/app/build.gradle` has the correct target SDK:

```gradle
android {
    compileSdkVersion 34  // Use latest stable
    
    defaultConfig {
        targetSdkVersion 34  // Use latest stable
        minSdkVersion 21
    }
}
```

## iOS Configuration

### Step 1: Update Info.plist

Edit `ios/Runner/Info.plist` and add the following keys:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Camera usage permission description (REQUIRED) -->
    <key>NSCameraUsageDescription</key>
    <string>Camera is needed to scan QR codes for attendance marking</string>
    
    <!-- Microphone (optional, only if audio recording is needed) -->
    <!-- <key>NSMicrophoneUsageDescription</key>
    <string>Microphone access description</string> -->
    
    <!-- Rest of your plist... -->
</dict>
</plist>
```

### Step 2: Podfile Configuration

Check `ios/Podfile` and ensure platform is set correctly:

```ruby
platform :ios, '12.0'  # or higher, recommend 13.0+
```

## Runtime Permission Handling

The application implements runtime permission handling in the `QRScannerScreen`:

```dart
// Permissions are automatically requested by mobile_scanner
// when camera access is needed. Users will see a native dialog
// asking for permission to use the camera.

// The _handleBarcode method will only be called after permission is granted
void _handleBarcode(BarcodeCapture barcodes) async {
  // Permission already granted to reach here
  for (final barcode in barcodes.barcodes) {
    // Process QR code
  }
}
```

## Permission Status Checking

To check camera permission status at runtime:

```dart
import 'package:permission_handler/permission_handler.dart';

// Check current permission status
PermissionStatus status = await Permission.camera.request();

if (status.isDenied) {
  // Permission denied, show error message
  print('Camera permission denied');
} else if (status.isGranted) {
  // Permission granted, proceed with scanning
  print('Camera permission granted');
}
```

**Note:** The current implementation relies on `mobile_scanner` to handle permissions automatically. For more granular control, add the `permission_handler` package to pubspec.yaml.

## Testing on Simulators/Emulators

### iOS Simulator
- Open Xcode and go to Hardware → Camera → [Choose option]
- Select "External camera" to enable simulated camera for QR scanning

### Android Emulator
- Open Android AVD Manager
- Ensure the emulator has camera support enabled in its configuration
- Use Webcam for simulated camera input

## Common Issues and Solutions

### Issue: "Camera permission denied" dialog keeps appearing

**Solution:** 
- Ensure `NSCameraUsageDescription` is properly set in Info.plist (iOS)
- Ensure `android.permission.CAMERA` is added to AndroidManifest.xml (Android)
- Clear app data and reinstall

### Issue: Camera not working on physical device

**Solution:**
- Verify permissions are granted in device settings:
  - iOS: Settings > SmartMess > Camera
  - Android: Settings > Apps > SmartMess > Permissions > Camera
- Restart the device
- Update to the latest mobile_scanner version

### Issue: Web platform doesn't require camera permissions

**Solution:**
- Web builds run in the browser's permission model
- Users will see a browser dialog asking for camera access
- This is handled automatically by the web_camera implementation

## Production Deployment

Before releasing to production:

1. ✅ Test on both iOS and Android devices
2. ✅ Verify permission dialogs display correctly
3. ✅ Ensure QR scanning works properly
4. ✅ Review privacy policy to mention camera usage
5. ✅ Update app store descriptions about camera requirements

## Additional Resources

- [mobile_scanner Documentation](https://pub.dev/packages/mobile_scanner)
- [Flutter Camera Documentation](https://flutter.dev/docs/development/packages-and-plugins/using-packages)
- [Android Camera Permissions](https://developer.android.com/training/permissions/requesting)
- [iOS Camera Permissions](https://developer.apple.com/documentation/avfoundation/cameras_and_media_capture)
