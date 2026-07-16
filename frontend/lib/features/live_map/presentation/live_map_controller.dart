import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/websocket_manager.dart';
import '../../../../core/utils/constants.dart';
import '../../members/domain/member.dart';
import '../../members/presentation/members_controller.dart';

class LiveMember {
  final Member member;
  final bool online;
  final DateTime? lastSeen;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final double? speed;
  final int? batteryPercentage;
  final bool? chargingStatus;
  final bool? gpsEnabled;
  final bool? internetAvailable;

  LiveMember({
    required this.member,
    required this.online,
    this.lastSeen,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.speed,
    this.batteryPercentage,
    this.chargingStatus,
    this.gpsEnabled,
    this.internetAvailable,
  });

  LiveMember copyWith({
    Member? member,
    bool? online,
    DateTime? lastSeen,
    double? latitude,
    double? longitude,
    double? accuracy,
    double? speed,
    int? batteryPercentage,
    bool? chargingStatus,
    bool? gpsEnabled,
    bool? internetAvailable,
  }) {
    return LiveMember(
      member: member ?? this.member,
      online: online ?? this.online,
      lastSeen: lastSeen ?? this.lastSeen,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      speed: speed ?? this.speed,
      batteryPercentage: batteryPercentage ?? this.batteryPercentage,
      chargingStatus: chargingStatus ?? this.chargingStatus,
      gpsEnabled: gpsEnabled ?? this.gpsEnabled,
      internetAvailable: internetAvailable ?? this.internetAvailable,
    );
  }
}

final wsManagerProvider = Provider<WebSocketManager>((ref) {
  final manager = WebSocketManager(AppConstants.wsUrl);
  ref.onDispose(() => manager.disconnect());
  return manager;
});

final wsStateProvider = StreamProvider<WsConnectionState>((ref) {
  final manager = ref.watch(wsManagerProvider);
  return manager.connectionStateStream;
});

class LiveMembersController extends StateNotifier<AsyncValue<List<LiveMember>>> {
  final WebSocketManager _wsManager;
  final Ref _ref;
  StreamSubscription? _msgSubscription;

  LiveMembersController(this._wsManager, this._ref) : super(const AsyncLoading()) {
    init();
  }

  void init() async {
    _wsManager.connect();
    
    // 1. Fetch initial HTTP members list
    final membersRepo = _ref.read(membersRepositoryProvider);
    try {
      final membersList = await membersRepo.getMembers();
      final liveMembers = membersList.map((m) => LiveMember(
        member: m,
        online: false,
        lastSeen: null,
      )).toList();
      state = AsyncData(liveMembers);
    } catch (e, stack) {
      state = AsyncError(e, stack);
      return;
    }

    // 2. Listen to WebSocket updates
    _msgSubscription = _wsManager.messages.listen((msg) {
      final currentList = state.value;
      if (currentList == null) return;

      final type = msg['type'] as String;
      final payload = msg['payload'] as Map<String, dynamic>;

      if (type == 'presence_update') {
        final userId = payload['userId'] as String;
        final online = payload['online'] as bool;
        final lastSeen = DateTime.parse(payload['lastSeen'] as String);

        state = AsyncData(
          currentList.map((m) {
            if (m.member.id == userId) {
              return m.copyWith(online: online, lastSeen: lastSeen);
            }
            return m;
          }).toList(),
        );
      } else if (type == 'location_update') {
        final userId = payload['userId'] as String;
        final lat = (payload['latitude'] as num).toDouble();
        final lng = (payload['longitude'] as num).toDouble();
        final acc = (payload['accuracy'] as num).toDouble();
        final speed = (payload['speed'] as num?)?.toDouble();
        final bat = payload['batteryPercentage'] as int?;
        final charging = payload['chargingStatus'] as bool?;
        final gps = payload['gpsEnabled'] as bool?;
        final internet = payload['internetAvailable'] as bool?;
        final time = DateTime.parse(payload['timestamp'] as String);

        state = AsyncData(
          currentList.map((m) {
            if (m.member.id == userId) {
              return m.copyWith(
                online: true,
                latitude: lat,
                longitude: lng,
                accuracy: acc,
                speed: speed,
                batteryPercentage: bat,
                chargingStatus: charging,
                gpsEnabled: gps,
                internetAvailable: internet,
                lastSeen: time,
              );
            }
            return m;
          }).toList(),
        );
      }
    });
  }

  @override
  void dispose() {
    _msgSubscription?.cancel();
    super.dispose();
  }
}

final liveMembersProvider =
    StateNotifierProvider<LiveMembersController, AsyncValue<List<LiveMember>>>((ref) {
  final wsManager = ref.watch(wsManagerProvider);
  return LiveMembersController(wsManager, ref);
});
