import 'package:flutter_test/flutter_test.dart';
import 'package:village_outreach/features/resources/services/location_service.dart';

void main() {
  group('ResourceLocationResult', () {
    test('returns available when coordinates exist', () {
      const result = ResourceLocationResult(
        status: ResourceLocationStatus.available,
        latitude: 33.4484,
        longitude: -112.0740,
      );

      expect(result.isAvailable, isTrue);
      expect(result.latitude, 33.4484);
      expect(result.longitude, -112.0740);
    });

    test('returns unavailable when coordinates are missing', () {
      const result = ResourceLocationResult(
        status: ResourceLocationStatus.available,
      );

      expect(result.isAvailable, isFalse);
    });

    test('handles denied location permission', () {
      const result = ResourceLocationResult(
        status: ResourceLocationStatus.permissionDenied,
      );

      expect(result.isAvailable, isFalse);
      expect(result.message, contains('search by area'));
    });

    test('handles permanently denied location permission', () {
      const result = ResourceLocationResult(
        status: ResourceLocationStatus.permissionDeniedForever,
      );

      expect(result.isAvailable, isFalse);
      expect(result.message, contains('device settings'));
    });

    test('handles disabled location services', () {
      const result = ResourceLocationResult(
        status: ResourceLocationStatus.serviceDisabled,
      );

      expect(result.isAvailable, isFalse);
      expect(result.message, contains('disabled'));
    });

    test('handles unavailable location', () {
      const result = ResourceLocationResult(
        status: ResourceLocationStatus.unavailable,
      );

      expect(result.isAvailable, isFalse);
      expect(result.message, contains('manually'));
    });
  });
}
