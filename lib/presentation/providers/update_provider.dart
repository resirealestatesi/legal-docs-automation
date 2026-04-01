import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateInfo {
  final bool hasUpdate;
  final String latestVersion;
  final String updateUrl;

  AppUpdateInfo({
    required this.hasUpdate,
    required this.latestVersion,
    required this.updateUrl,
  });
}

final updateProvider = FutureProvider<AppUpdateInfo>((ref) async {
  try {
    final supabase = Supabase.instance.client;
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    print('DEBUG: App Version - Current: $currentVersion');

    // We assume there's a 'app_config' table with 'key' and 'value'
    final response = await supabase
        .from('app_config')
        .select()
        .or('key.eq.latest_version,key.eq.update_url');
    
    print('DEBUG: Supabase response: $response');

    String latestVersion = currentVersion;
    String updateUrl = '';

    for (var row in response) {
      if (row['key'] == 'latest_version') latestVersion = row['value'];
      if (row['key'] == 'update_url') updateUrl = row['value'];
    }
    
    print('DEBUG: Comparing $latestVersion with $currentVersion');

    // Version comparison (simple string comparison for now, can be improved)
    final hasUpdate = _isVersionGreater(latestVersion, currentVersion);

    return AppUpdateInfo(
      hasUpdate: hasUpdate,
      latestVersion: latestVersion,
      updateUrl: updateUrl,
    );
  } catch (e) {
    print('DEBUG: Update check error: $e');
    // If table doesn't exist yet or other error, assume no update
    return AppUpdateInfo(hasUpdate: false, latestVersion: '', updateUrl: '');
  }
});

bool _isVersionGreater(String latest, String current) {
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
