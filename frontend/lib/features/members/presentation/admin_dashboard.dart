import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../live_map/presentation/live_map_controller.dart';
import '../../../../core/network/websocket_manager.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  String _searchQuery = '';
  bool _sortAscending = true;

  @override
  Widget build(BuildContext context) {
    final liveMembersState = ref.watch(liveMembersProvider);
    final wsState = ref.watch(wsStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Tracker - Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            onPressed: () => context.push('/admin/map'),
            tooltip: 'View Live Map',
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: liveMembersState.when(
        data: (members) {
          // Calculate counts
          final total = members.length;
          final online = members.where((m) => m.online).length;
          final offline = total - online;

          // Apply filter
          var filteredMembers = members.where((m) {
            final nameMatch = m.member.name.toLowerCase().contains(_searchQuery.toLowerCase());
            final emailMatch = m.member.email.toLowerCase().contains(_searchQuery.toLowerCase());
            return nameMatch || emailMatch;
          }).toList();

          // Apply sort
          filteredMembers.sort((a, b) {
            final compare = a.member.name.toLowerCase().compareTo(b.member.name.toLowerCase());
            return _sortAscending ? compare : -compare;
          });

          return Column(
            children: [
              // Header Summary Cards
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    _buildSummaryCard(context, 'Total', total.toString(), Colors.blue),
                    const SizedBox(width: 8),
                    _buildSummaryCard(context, 'Online', online.toString(), Colors.green),
                    const SizedBox(width: 8),
                    _buildSummaryCard(context, 'Offline', offline.toString(), Colors.grey),
                  ],
                ),
              ),

              // Search & Filter Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search members...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      icon: Icon(_sortAscending ? Icons.sort_by_alpha : Icons.sort),
                      onPressed: () => setState(() => _sortAscending = !_sortAscending),
                      tooltip: _sortAscending ? 'Sort Z-A' : 'Sort A-Z',
                    )
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Live Status Banner
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Card(
                  color: wsState.value == WsConnectionState.connected
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          wsState.value == WsConnectionState.connected
                              ? 'WebSocket Stream Active (Real-time)'
                              : wsState.value == WsConnectionState.connecting
                                  ? 'Reconnecting WebSocket stream...'
                                  : 'WebSocket Stream Offline',
                          style: TextStyle(
                            fontSize: 12,
                            color: wsState.value == WsConnectionState.connected
                                ? Colors.green.shade800
                                : Colors.orange.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(
                          wsState.value == WsConnectionState.connected
                              ? Icons.wifi_tethering
                              : Icons.portable_wifi_off_outlined,
                          size: 16,
                          color: wsState.value == WsConnectionState.connected
                              ? Colors.green.shade800
                              : Colors.orange.shade800,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Member Directory list
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.read(wsManagerProvider).disconnect();
                    ref.read(wsManagerProvider).connect();
                  },
                  child: filteredMembers.isEmpty
                      ? const Center(child: Text('No matching family members.'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredMembers.length,
                          itemBuilder: (context, index) {
                            final m = filteredMembers[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: m.online ? Colors.green : Colors.grey,
                                  child: CircleAvatar(
                                    radius: 18,
                                    backgroundImage: m.member.photoUrl != null && m.member.photoUrl!.isNotEmpty
                                        ? NetworkImage(m.member.photoUrl!)
                                        : null,
                                    child: m.member.photoUrl == null || m.member.photoUrl!.isEmpty
                                        ? Text(
                                            m.member.name[0].toUpperCase(),
                                            style: const TextStyle(color: Colors.white),
                                          )
                                        : null,
                                  ),
                                ),
                                title: Text(m.member.name),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m.member.email),
                                    const SizedBox(height: 2),
                                    Text(
                                      m.online ? 'Online' : 'Offline - Last seen: ${m.lastSeen?.toLocal().toString() ?? "Never"}',
                                      style: TextStyle(
                                        color: m.online ? Colors.green : Colors.grey,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => context.push('/admin/members/${m.member.id}'),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Error loading dashboard directory.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(liveMembersProvider.notifier).init(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/admin/members/create'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, String title, String value, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
