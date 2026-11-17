import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

/// CCVO-69: Possible outcomes of a location request.
enum ResourceLocationStatus {
  available,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

/// Represents the result of requesting the user's location.
class ResourceLocationResult {
  final ResourceLocationStatus status;
  final double? latitude;
  final double? longitude;

  const ResourceLocationResult({
    required this.status,
    this.latitude,
    this.longitude,
  });

  bool get isAvailable =>
      status == ResourceLocationStatus.available &&
      latitude != null &&
      longitude != null;

  String get message {
    switch (status) {
      case ResourceLocationStatus.available:
        return 'Current location available.';

      case ResourceLocationStatus.serviceDisabled:
        return 'Location services are disabled. '
            'Please select an area manually.';

      case ResourceLocationStatus.permissionDenied:
        return 'Location permission was denied. '
            'You can still search by area.';

      case ResourceLocationStatus.permissionDeniedForever:
        return 'Location permission is disabled in your '
            'device settings. You can still search by area.';

      case ResourceLocationStatus.unavailable:
        return 'Your current location could not be determined. '
            'Please select an area manually.';
    }
  }
}

/// Interface allows location behavior to be mocked in tests.
abstract class ResourceLocationRepository {
  Future<ResourceLocationResult> getCurrentLocation();
}

/// Handles optional foreground location access.
class LocationService implements ResourceLocationRepository {
  @override
  Future<ResourceLocationResult> getCurrentLocation() async {
    try {
      debugPrint('CCVO-69: Checking location services...');

      final enabled = await Geolocator.isLocationServiceEnabled();

      debugPrint('CCVO-69: Location enabled: $enabled');

      if (!enabled) {
        return const ResourceLocationResult(
          status: ResourceLocationStatus.serviceDisabled,
        );
      }

      var permission = await Geolocator.checkPermission();

      debugPrint('CCVO-69: Initial permission: $permission');

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      debugPrint('CCVO-69: Final permission: $permission');

      if (permission == LocationPermission.denied) {
        return const ResourceLocationResult(
          status: ResourceLocationStatus.permissionDenied,
        );
      }

      if (permission == LocationPermission.deniedForever) {
        return const ResourceLocationResult(
          status: ResourceLocationStatus.permissionDeniedForever,
        );
      }

      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return const ResourceLocationResult(
          status: ResourceLocationStatus.unavailable,
        );
      }

      debugPrint('CCVO-69: Requesting GPS position...');

      final position = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.high,
          forceLocationManager: true,
          timeLimit: const Duration(seconds: 30),
        ),
      );

      debugPrint('CCVO-69: GPS position acquired.');

      return ResourceLocationResult(
        status: ResourceLocationStatus.available,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (error, stackTrace) {
      debugPrint('CCVO-69: Location error: $error');
      debugPrintStack(stackTrace: stackTrace);

      return const ResourceLocationResult(
        status: ResourceLocationStatus.unavailable,
      );
    }
  }
}
