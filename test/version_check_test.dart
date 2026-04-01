import 'package:flutter_test/flutter_test.dart';

// Helper function to test (copied from provider for testing purposes)
bool isVersionGreater(String latest, String current) {
  try {
    final latestParts = latest.split('.').map(int.parse).toList();
    final currentParts = current.split('.').map(int.parse).toList();

    for (var i = 0; i < latestParts.length && i < currentParts.length; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return latestParts.length > currentParts.length;
  } catch (_) {
    return false;
  }
}

void main() {
  group('Version Check Tests', () {
    test('Greater major version', () {
      expect(isVersionGreater('2.0.0', '1.0.0'), isTrue);
    });

    test('Greater minor version', () {
      expect(isVersionGreater('1.1.0', '1.0.9'), isTrue);
    });

    test('Greater patch version', () {
      expect(isVersionGreater('1.0.1', '1.0.0'), isTrue);
    });

    test('Same version should be false', () {
      expect(isVersionGreater('1.0.0', '1.0.0'), isFalse);
    });

    test('Lower version should be false', () {
      expect(isVersionGreater('0.9.0', '1.0.0'), isFalse);
    });
    
    test('Build numbers (if any) are ignored or handled by logic', () {
        expect(isVersionGreater('1.0.0.1', '1.0.0'), isTrue);
    });
  });
}
