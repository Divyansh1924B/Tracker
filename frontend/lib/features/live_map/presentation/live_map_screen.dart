import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/network/websocket_manager.dart';
import 'live_map_controller.dart';
import 'package:go_router/go_router.dart';

class LiveMapScreen extends ConsumerStatefulWidget {
  const LiveMapScreen({super.key});

  @override
  ConsumerState<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends ConsumerState<LiveMapScreen> {
  final MapController _mapController = MapController();
  LiveMember? _selectedMember;

  void _recenterAll(List<LiveMember> members) {
    final points = members
        .where((m) => m.latitude != null && m.longitude != null)
        .map((m) => LatLng(m.latitude!, m.longitude!))
        .toList();

    if (points.isEmpty) return;

    if (points.length == 1) {
      _mapController.move(points.first, 15);
    } else {
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50.0),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersState = ref.watch(liveMembersProvider);
    final wsState = ref.watch(wsStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Family Map'),
      ),
      body: membersState.when(
        data: (members) {
          final markers = members
              .where((m) => m.latitude != null && m.longitude != null)
              .map((m) {
            final position = LatLng(m.latitude!, m.longitude!);
            return Marker(
              point: position,
              width: 60,
              height: 60,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedMember = m;
                  });
                  _mapController.move(position, 15);
                },
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        m.member.name,
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: m.online ? Colors.green : Colors.red,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundImage: m.member.photoUrl != null && m.member.photoUrl!.isNotEmpty
                            ? NetworkImage(m.member.photoUrl!)
                            : null,
                        child: m.member.photoUrl == null || m.member.photoUrl!.isEmpty
                            ? Text(
                                m.member.name[0].toUpperCase(),
                                style: const TextStyle(fontSize: 12, color: Colors.white),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList();

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: markers.isNotEmpty ? markers.first.point : const LatLng(0, 0),
                  initialZoom: 13.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.family.tracker',
                  ),
                  MarkerLayer(markers: markers),
                ],
              ),

              Positioned(
                top: 16,
                left: 16,
                child: Card(
                  color: Colors.black87,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: wsState.value == WsConnectionState.connected ? Colors.green : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          wsState.value == WsConnectionState.connected
                              ? 'Live'
                              : wsState.value == WsConnectionState.connecting
                                  ? 'Connecting'
                                  : 'Disconnected',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (_selectedMember != null)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedMember!.member.name,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(() => _selectedMember = null),
                              )
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Last Seen: ${_selectedMember!.lastSeen?.toLocal().toString() ?? "Never"}'),
                          const SizedBox(height: 4),
                          Text('Battery: ${_selectedMember!.batteryPercentage ?? 100}% (${_selectedMember!.chargingStatus == true ? "Charging" : "Discharging"})'),
                          const SizedBox(height: 4),
                          Text('Speed: ${(_selectedMember!.speed ?? 0).toStringAsFixed(1)} m/s'),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () {
                                  context.push('/admin/members/${_selectedMember!.member.id}');
                                },
                                child: const Text('View Profile Details'),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),

              Positioned(
                bottom: _selectedMember != null ? 180 : 16,
                right: 16,
                child: Column(
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'zoom_in',
                      onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1),
                      child: const Icon(Icons.add),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'zoom_out',
                      onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1),
                      child: const Icon(Icons.remove),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      heroTag: 'recenter',
                      onPressed: () => _recenterAll(members),
                      child: const Icon(Icons.my_location),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Failed to load live map: $err')),
      ),
    );
  }
}
