import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'history_controller.dart';
import 'playback_controller.dart';
import '../../tracking/domain/location_point.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  final String memberId;
  const HistoryScreen({super.key, required this.memberId});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final MapController _mapController = MapController();
  final ScrollController _scrollController = ScrollController();
  final double _itemHeight = 72.0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _recenterRoute(List<LocationPoint> points) {
    if (points.isEmpty) return;
    final latLngs = points.map((p) => LatLng(p.latitude, p.longitude)).toList();
    final bounds = LatLngBounds.fromPoints(latLngs);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50.0)),
    );
  }

  void _selectCustomDate() async {
    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );

    if (pickedRange != null) {
      ref.read(historyControllerProvider(widget.memberId).notifier).setRange(
            HistoryRange.custom,
            customRange: pickedRange,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(historyControllerProvider(widget.memberId));
    final controller = ref.read(historyControllerProvider(widget.memberId).notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Route History'),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip(context, controller, HistoryRange.today, 'Today'),
                const SizedBox(width: 8),
                _buildFilterChip(context, controller, HistoryRange.yesterday, 'Yesterday'),
                const SizedBox(width: 8),
                _buildFilterChip(context, controller, HistoryRange.last7Days, '7 Days'),
                const SizedBox(width: 8),
                _buildFilterChip(context, controller, HistoryRange.last30Days, '30 Days'),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Calendar'),
                  selected: controller.selectedRange == HistoryRange.custom,
                  onSelected: (_) => _selectCustomDate(),
                ),
              ],
            ),
          ),

          Expanded(
            child: historyState.when(
              data: (historyData) {
                if (historyData == null || historyData.points.isEmpty) {
                  return const Center(child: Text('No routes recorded for the selected period.'));
                }

                final points = historyData.points;
                final stats = historyData.statistics;

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ref.read(playbackControllerProvider.notifier).setMaxIndex(points.length - 1);
                });

                final playbackState = ref.watch(playbackControllerProvider);
                final activePoint = points[playbackState.currentIndex];

                ref.listen<PlaybackState>(playbackControllerProvider, (prev, next) {
                  if (next.currentIndex != prev?.currentIndex) {
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        next.currentIndex * _itemHeight,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  }
                });

                final pathLatLngs = points.map((p) => LatLng(p.latitude, p.longitude)).toList();
                final startPoint = LatLng(points.first.latitude, points.first.longitude);
                final endPoint = LatLng(points.last.latitude, points.last.longitude);
                final currentPlaybackPoint = LatLng(activePoint.latitude, activePoint.longitude);

                return Column(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: currentPlaybackPoint,
                              initialZoom: 14.0,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.family.tracker',
                              ),
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: pathLatLngs,
                                    color: Colors.deepPurple.withValues(alpha: 0.6),
                                    strokeWidth: 4.0,
                                  )
                                ],
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: startPoint,
                                    width: 32,
                                    height: 32,
                                    child: const Icon(Icons.location_on, color: Colors.green, size: 32),
                                  ),
                                  Marker(
                                    point: endPoint,
                                    width: 32,
                                    height: 32,
                                    child: const Icon(Icons.location_on, color: Colors.red, size: 32),
                                  ),
                                  Marker(
                                    point: currentPlaybackPoint,
                                    width: 24,
                                    height: 24,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          Positioned(
                            top: 16,
                            right: 16,
                            child: FloatingActionButton.small(
                              heroTag: 'recenter_route',
                              onPressed: () => _recenterRoute(points),
                              child: const Icon(Icons.zoom_out_map),
                            ),
                          ),
                        ],
                      ),
                    ),

                    _buildStatsPanel(context, stats),

                    _buildReplayBar(context, ref, playbackState, points.length),

                    Expanded(
                      flex: 3,
                      child: ListView.builder(
                        controller: _scrollController,
                        itemCount: points.length,
                        itemExtent: _itemHeight,
                        itemBuilder: (context, index) {
                          final p = points[index];
                          final isActive = index == playbackState.currentIndex;

                          return Container(
                            color: isActive ? Theme.of(context).colorScheme.primaryContainer : null,
                            child: ListTile(
                              leading: Text(
                                '${p.timestamp.toLocal().hour.toString().padLeft(2, "0")}:${p.timestamp.toLocal().minute.toString().padLeft(2, "0")}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              title: Text('${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}'),
                              subtitle: Text('Battery: ${p.batteryPercentage ?? 100}% | Speed: ${(p.speed ?? 0).toStringAsFixed(1)} m/s'),
                              trailing: Icon(
                                isActive ? Icons.play_arrow : Icons.location_pin,
                                color: isActive ? Colors.deepPurple : Colors.grey,
                              ),
                              onTap: () {
                                ref.read(playbackControllerProvider.notifier).setIndex(index);
                                _mapController.move(LatLng(p.latitude, p.longitude), 15);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Failed to load history: $err')),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    HistoryController controller,
    HistoryRange range,
    String label,
  ) {
    return ChoiceChip(
      label: Text(label),
      selected: controller.selectedRange == range,
      onSelected: (_) => controller.setRange(range),
    );
  }

  Widget _buildStatsPanel(BuildContext context, dynamic stats) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Distance', '${stats.totalDistanceKm} km'),
            _buildStatItem('Avg Speed', '${stats.averageSpeedKmh} km/h'),
            _buildStatItem('Max Speed', '${stats.maxSpeedKmh} km/h'),
            _buildStatItem('Points', '${stats.pointsCount}'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildReplayBar(
    BuildContext context,
    WidgetRef ref,
    PlaybackState state,
    int totalCount,
  ) {
    final notifier = ref.read(playbackControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
            onPressed: () => state.isPlaying ? notifier.pause() : notifier.play(),
          ),
          IconButton(
            icon: const Icon(Icons.stop),
            onPressed: () => notifier.stop(),
          ),
          Expanded(
            child: Slider(
              value: state.currentIndex.toDouble(),
              min: 0,
              max: (totalCount - 1).toDouble(),
              onChanged: (val) => notifier.setIndex(val.toInt()),
            ),
          ),
          DropdownButton<double>(
            value: state.speed,
            items: const [
              DropdownMenuItem(value: 0.5, child: Text('0.5x')),
              DropdownMenuItem(value: 1.0, child: Text('1.0x')),
              DropdownMenuItem(value: 2.0, child: Text('2.0x')),
              DropdownMenuItem(value: 4.0, child: Text('4.0x')),
            ],
            onChanged: (val) {
              if (val != null) notifier.setSpeed(val);
            },
          )
        ],
      ),
    );
  }
}
