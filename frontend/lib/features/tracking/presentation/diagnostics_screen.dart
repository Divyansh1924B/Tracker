import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'tracking_controller.dart';
import 'package:geolocator/geolocator.dart';

class DiagnosticsScreen extends ConsumerWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackingState = ref.watch(trackingControllerProvider);
    final notifier = ref.read(trackingControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Tracking Diagnostics')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Permissions Status', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: Icon(
                        trackingState.permissionStatus == LocationPermission.always ||
                                trackingState.permissionStatus == LocationPermission.whileInUse
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        color: trackingState.permissionStatus == LocationPermission.always ||
                                trackingState.permissionStatus == LocationPermission.whileInUse
                            ? Colors.green
                            : Colors.red,
                      ),
                      title: const Text('Location Permission'),
                      subtitle: Text(trackingState.permissionStatus.toString().split('.').last),
                      trailing: trackingState.permissionStatus == LocationPermission.denied ||
                              trackingState.permissionStatus == LocationPermission.deniedForever
                          ? TextButton(
                              onPressed: () => notifier.requestPermissions(),
                              child: const Text('Grant'),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hardware & Network Status', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _buildStatusTile(
                      context,
                      icon: Icons.gps_fixed,
                      title: 'GPS Service',
                      status: trackingState.gpsEnabled ? 'Enabled' : 'Disabled',
                      isActive: trackingState.gpsEnabled,
                    ),
                    const Divider(height: 1),
                    _buildStatusTile(
                      context,
                      icon: Icons.wifi,
                      title: 'Internet Connection',
                      status: trackingState.internetAvailable ? 'Online' : 'Offline',
                      isActive: trackingState.internetAvailable,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sync Engine Status', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ListTile(
                      leading: const Icon(Icons.storage),
                      title: const Text('Unsynced Points Cache'),
                      subtitle: Text('${trackingState.pendingUploadCount} points pending upload'),
                      trailing: ElevatedButton(
                        onPressed: trackingState.pendingUploadCount > 0 ? () => notifier.triggerSync() : null,
                        child: const Text('Sync Now'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Card(
              color: trackingState.isTracking
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Background Location Engine',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          trackingState.isTracking ? 'Active & Recording' : 'Engine Idle',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    Switch(
                      value: trackingState.isTracking,
                      onChanged: (trackingState.permissionStatus == LocationPermission.denied ||
                              trackingState.permissionStatus == LocationPermission.deniedForever)
                          ? null
                          : (_) => notifier.toggleTracking(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Live Location Capture', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    if (trackingState.lastCapturedPoint != null) ...[
                      _buildDiagnosticField('Latitude', trackingState.lastCapturedPoint!.latitude.toString()),
                      _buildDiagnosticField('Longitude', trackingState.lastCapturedPoint!.longitude.toString()),
                      _buildDiagnosticField('Accuracy', '${trackingState.lastCapturedPoint!.accuracy.toStringAsFixed(1)} m'),
                      _buildDiagnosticField('Speed', '${(trackingState.lastCapturedPoint!.speed ?? 0).toStringAsFixed(1)} m/s'),
                      _buildDiagnosticField('Battery', '${trackingState.lastCapturedPoint!.batteryPercentage}%'),
                      _buildDiagnosticField('Charging', trackingState.lastCapturedPoint!.chargingStatus == true ? 'Yes' : 'No'),
                      _buildDiagnosticField('Timestamp', trackingState.lastCapturedPoint!.timestamp.toLocal().toString()),
                    ] else
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: Text('No location coordinates recorded yet. Turn switch on to capture.'),
                        ),
                      )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String status,
    required bool isActive,
  }) {
    return ListTile(
      leading: Icon(icon, color: isActive ? Colors.green : Colors.orange),
      title: Text(title),
      trailing: Text(
        status,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isActive ? Colors.green : Colors.orange,
        ),
      ),
    );
  }

  Widget _buildDiagnosticField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
