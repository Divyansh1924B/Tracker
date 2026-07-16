import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/role_selection_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/auth/presentation/settings_screen.dart';
import '../../features/members/presentation/admin_dashboard.dart';
import '../../features/members/presentation/member_dashboard.dart';
import '../../features/members/presentation/create_member_screen.dart';
import '../../features/members/presentation/member_detail_screen.dart';
import '../../features/tracking/presentation/diagnostics_screen.dart';
import '../../features/live_map/presentation/live_map_screen.dart';
import '../../features/history/presentation/history_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/role-selection',
        builder: (context, state) => const RoleSelectionScreen(),
      ),
      GoRoute(
        path: '/login/:role',
        builder: (context, state) {
          final role = state.pathParameters['role'] ?? 'member';
          return LoginScreen(role: role);
        },
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) => const AdminDashboard(),
      ),
      GoRoute(
        path: '/admin/map',
        builder: (context, state) => const LiveMapScreen(),
      ),
      GoRoute(
        path: '/admin/members/create',
        builder: (context, state) => const CreateMemberScreen(),
      ),
      GoRoute(
        path: '/admin/members/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return MemberDetailScreen(memberId: id);
        },
      ),
      GoRoute(
        path: '/admin/history/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return HistoryScreen(memberId: id);
        },
      ),
      GoRoute(
        path: '/member/dashboard',
        builder: (context, state) => const MemberDashboard(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/diagnostics',
        builder: (context, state) => const DiagnosticsScreen(),
      ),
    ],
    redirect: (context, state) {
      final isLoggingIn = state.matchedLocation.startsWith('/login');
      final isSplash = state.matchedLocation == '/splash';
      final isRegistering = state.matchedLocation == '/register';
      final isRoleSelection = state.matchedLocation == '/role-selection';

      if (authState is AuthInitial || authState is AuthLoading) {
        return isSplash ? null : '/splash';
      }

      if (authState is Unauthenticated) {
        return (isLoggingIn || isRegistering || isRoleSelection) ? null : '/role-selection';
      }

      if (authState is Authenticated) {
        if (isLoggingIn || isSplash || isRegistering || isRoleSelection) {
          return authState.user.isAdmin ? '/admin/dashboard' : '/member/dashboard';
        }
        
        final isAdminRoute = state.matchedLocation.startsWith('/admin');
        if (isAdminRoute && !authState.user.isAdmin) {
          return '/member/dashboard';
        }
      }

      return null;
    },
  );
});

