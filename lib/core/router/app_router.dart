import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/attendance/screens/attendance_screen.dart';
import '../../features/attendance/screens/qr_scan_screen.dart';
import '../../features/leave/screens/leave_screen.dart';
import '../../features/leave/screens/apply_leave_screen.dart';
import '../../features/leave/screens/leave_calendar_screen.dart';
import '../../features/payroll/screens/payroll_screen.dart';
import '../../features/payroll/screens/payslip_detail_screen.dart';
import '../../features/employees/screens/employee_list_screen.dart';
import '../../features/employees/screens/employee_detail_screen.dart';
import '../../features/employees/screens/add_employee_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/edit_profile_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../core/providers/auth_provider.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isLoggedIn = authState.isLoggedIn;
      final isAuthRoute = state.matchedLocation.startsWith('/auth');
      final isSplash = state.matchedLocation == '/splash';

      if (isSplash) return null;
      if (!isLoggedIn && !isAuthRoute) return '/auth/login';
      if (isLoggedIn && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(
        path: '/auth',
        redirect: (_, __) => '/auth/login',
        routes: [
          GoRoute(path: 'login', builder: (_, __) => const LoginScreen()),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => HomeScreen(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const DashboardScreen()),
          GoRoute(
            path: '/attendance',
            builder: (_, __) => const AttendanceScreen(),
            routes: [
              GoRoute(path: 'qr-scan', builder: (_, __) => const QrScanScreen()),
            ],
          ),
          GoRoute(
            path: '/leave',
            builder: (_, __) => const LeaveScreen(),
            routes: [
              GoRoute(path: 'apply', builder: (_, __) => const ApplyLeaveScreen()),
              GoRoute(path: 'calendar', builder: (_, __) => const LeaveCalendarScreen()),
            ],
          ),
          GoRoute(
            path: '/payroll',
            builder: (_, __) => const PayrollScreen(),
            routes: [
              GoRoute(
                path: 'payslip/:id',
                builder: (_, state) => PayslipDetailScreen(payslipId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/employees',
            builder: (_, __) => const EmployeeListScreen(),
            routes: [
              GoRoute(path: 'add', builder: (_, __) => const AddEmployeeScreen()),
              GoRoute(
                path: ':id',
                builder: (_, state) => EmployeeDetailScreen(employeeId: state.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
          GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
          GoRoute(
            path: '/profile',
            builder: (_, __) => const ProfileScreen(),
            routes: [
              GoRoute(path: 'edit', builder: (_, __) => const EditProfileScreen()),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});
