import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'members_controller.dart';
import '../../live_map/presentation/live_map_controller.dart';
import 'package:go_router/go_router.dart';

class MemberDetailScreen extends ConsumerStatefulWidget {
  final String memberId;
  const MemberDetailScreen({super.key, required this.memberId});

  @override
  ConsumerState<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends ConsumerState<MemberDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _deviceNameController;
  late TextEditingController _photoUrlController;
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final membersState = ref.read(membersControllerProvider);
      final member = membersState.value?.firstWhere((m) => m.id == widget.memberId);
      _nameController = TextEditingController(text: member?.name ?? '');
      _phoneController = TextEditingController(text: member?.phone ?? '');
      _deviceNameController = TextEditingController(text: member?.deviceName ?? '');
      _photoUrlController = TextEditingController(text: member?.photoUrl ?? '');
      _isInit = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _deviceNameController.dispose();
    _photoUrlController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitUpdate() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      try {
        await ref.read(membersControllerProvider.notifier).editMember(
              widget.memberId,
              name: _nameController.text.trim(),
              phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
              deviceName: _deviceNameController.text.trim(),
              photoUrl: _photoUrlController.text.trim().isEmpty ? null : _photoUrlController.text.trim(),
              password: _passwordController.text.trim().isEmpty ? null : _passwordController.text.trim(),
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Member profile updated successfully.')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst('ServerException: ', '')),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Family Member?'),
        content: const Text('Are you sure you want to permanently delete this member? All route history will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              setState(() => _isLoading = true);
              try {
                await ref.read(membersControllerProvider.notifier).removeMember(widget.memberId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Member deleted successfully.')),
                  );
                  Navigator.of(context).pop();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceFirst('ServerException: ', '')),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final liveMembersState = ref.watch(liveMembersProvider);
    final liveMember = liveMembersState.value?.firstWhere(
      (m) => m.member.id == widget.memberId,
      orElse: () => throw Exception('Not found'),
    );

    if (liveMember == null) {
      return const Scaffold(body: Center(child: Text('Member details not found.')));
    }

    final mEntity = liveMember.member;

    return Scaffold(
      appBar: AppBar(
        title: Text(mEntity.name),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
            onPressed: _isLoading ? null : _confirmDelete,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundImage: mEntity.photoUrl != null && mEntity.photoUrl!.isNotEmpty
                      ? NetworkImage(mEntity.photoUrl!)
                      : null,
                  child: mEntity.photoUrl == null || mEntity.photoUrl!.isEmpty
                      ? Text(mEntity.name[0].toUpperCase(), style: const TextStyle(fontSize: 28))
                      : null,
                ),
              ),
              const SizedBox(height: 24),

              // Live Status Card
              Card(
                color: liveMember.online
                    ? Colors.green.shade50
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live Tracking Diagnostics',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow('Presence Status', liveMember.online ? 'Online' : 'Offline'),
                      _buildDetailRow('Last Seen', liveMember.lastSeen?.toLocal().toString() ?? 'Never'),
                      _buildDetailRow('Coordinates', liveMember.latitude != null ? '${liveMember.latitude!.toStringAsFixed(5)}, ${liveMember.longitude!.toStringAsFixed(5)}' : 'No signal'),
                      _buildDetailRow('Accuracy', liveMember.accuracy != null ? '${liveMember.accuracy!.toStringAsFixed(1)} m' : '-'),
                      _buildDetailRow('Speed', liveMember.speed != null ? '${liveMember.speed!.toStringAsFixed(1)} m/s' : '-'),
                      _buildDetailRow('Battery Level', liveMember.batteryPercentage != null ? '${liveMember.batteryPercentage}% (${liveMember.chargingStatus == true ? "Charging" : "Discharging"})' : '-'),
                      _buildDetailRow('GPS Enabled', liveMember.gpsEnabled == true ? 'Yes' : 'No'),
                      _buildDetailRow('Internet Connected', liveMember.internetAvailable == true ? 'Yes' : 'No'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
              
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: mEntity.email,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Email Address (Read-only)',
                  border: OutlineInputBorder(),
                  filled: true,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _deviceNameController,
                decoration: const InputDecoration(
                  labelText: 'Device Name',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Device name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _photoUrlController,
                decoration: const InputDecoration(
                  labelText: 'Photo URL',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password (Leave blank to keep current)',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val != null && val.isNotEmpty && val.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isLoading ? null : _submitUpdate,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Changes'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  context.push('/admin/history/${mEntity.id}');
                },
                icon: const Icon(Icons.history),
                label: const Text('View Route History'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
