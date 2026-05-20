import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_button.dart';

final todayAttendanceProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(apiServiceProvider).getTodayAttendance();
});

final attendanceHistoryProvider = FutureProvider.family<Map<String, dynamic>, Map<String, int>>(
  (ref, params) async {
    final user = ref.watch(currentUserProvider);
    return ref.watch(apiServiceProvider).getAttendanceHistory(
      user?.employeeId ?? '',
      month: params['month'],
      year: params['year'],
    );
  },
);

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool _isLoading = false;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<Position?> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) return null;
    }
    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> _checkIn() async {
    setState(() => _isLoading = true);
    try {
      final pos = await _getLocation();
      final result = await ref.read(apiServiceProvider).checkIn(
        lat: pos?.latitude,
        lng: pos?.longitude,
        source: pos != null ? 'gps' : 'manual',
      );
      ref.invalidate(todayAttendanceProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message'] ?? 'Checked in!'),
          backgroundColor: result['isLate'] == true ? AppTheme.warning : AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Check-in failed: $e'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkOut() async {
    setState(() => _isLoading = true);
    try {
      final pos = await _getLocation();
      final result = await ref.read(apiServiceProvider).checkOut(
        lat: pos?.latitude,
        lng: pos?.longitude,
        source: pos != null ? 'gps' : 'manual',
      );
      ref.invalidate(todayAttendanceProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Checked out! ${result['effectiveHours']}h worked'),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Check-out failed: $e'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'QR Attendance',
            onPressed: () => context.push('/attendance/qr-scan'),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          tabs: const [Tab(text: 'Today'), Tab(text: 'History')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _TodayTab(onCheckIn: _checkIn, onCheckOut: _checkOut, isLoading: _isLoading),
          _HistoryTab(month: _month, year: _year, onMonthChanged: (m, y) {
            setState(() { _month = m; _year = y; });
          }),
        ],
      ),
    );
  }
}

class _TodayTab extends ConsumerWidget {
  final VoidCallback onCheckIn, onCheckOut;
  final bool isLoading;
  const _TodayTab({required this.onCheckIn, required this.onCheckOut, required this.isLoading});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attAsync = ref.watch(todayAttendanceProvider);

    return attAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (data) {
        final record = data['record'] as Map?;
        final isCheckedIn = record?['check_in'] != null;
        final isCheckedOut = record?['check_out'] != null;
        final isLate = record?['is_late'] == true;
        final status = record?['status'] ?? 'absent';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Big status circle
              Container(
                width: 180, height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isCheckedIn && !isCheckedOut
                        ? [AppTheme.success, const Color(0xFF00E676)]
                        : isCheckedOut
                            ? [AppTheme.primary, AppTheme.primaryLight]
                            : [Colors.grey.shade300, Colors.grey.shade200],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isCheckedIn ? AppTheme.success : Colors.grey).withOpacity(0.3),
                      blurRadius: 30, offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isCheckedOut ? Icons.check_circle : isCheckedIn ? Icons.work_outline : Icons.access_time,
                      color: Colors.white, size: 40,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isCheckedOut ? 'Completed' : isCheckedIn ? 'Working' : 'Not Started',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    if (isLate)
                      const Text('Late', style: TextStyle(color: Colors.amber, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Time cards
              Row(children: [
                Expanded(child: _TimeCard(
                  label: 'Check In',
                  value: record?['check_in'] != null
                      ? DateFormat('hh:mm a').format(DateTime.parse(record!['check_in']))
                      : '--:--',
                  icon: Icons.login,
                  color: AppTheme.success,
                )),
                const SizedBox(width: 12),
                Expanded(child: _TimeCard(
                  label: 'Check Out',
                  value: record?['check_out'] != null
                      ? DateFormat('hh:mm a').format(DateTime.parse(record!['check_out']))
                      : '--:--',
                  icon: Icons.logout,
                  color: AppTheme.error,
                )),
              ]),
              const SizedBox(height: 12),

              if (isCheckedIn && !isCheckedOut)
                Row(children: [
                  Expanded(child: _TimeCard(
                    label: 'Hours So Far',
                    value: _calcHours(record?['check_in']),
                    icon: Icons.timer_outlined, color: AppTheme.info,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _TimeCard(
                    label: 'Status',
                    value: isLate ? 'Late ${record!['late_minutes']}min' : 'On Time',
                    icon: isLate ? Icons.warning_amber : Icons.check,
                    color: isLate ? AppTheme.warning : AppTheme.success,
                  )),
                ]),
              const SizedBox(height: 28),

              // Action buttons
              if (!isCheckedIn)
                AppButton(
                  text: 'Check In',
                  onPressed: isLoading ? null : onCheckIn,
                  isLoading: isLoading,
                  width: double.infinity,
                  icon: Icons.login,
                  color: AppTheme.success,
                )
              else if (!isCheckedOut)
                AppButton(
                  text: 'Check Out',
                  onPressed: isLoading ? null : onCheckOut,
                  isLoading: isLoading,
                  width: double.infinity,
                  icon: Icons.logout,
                  color: AppTheme.error,
                )
              else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: AppTheme.success),
                      const SizedBox(width: 8),
                      Text('Attendance completed for today', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _calcHours(String? checkIn) {
    if (checkIn == null) return '0h 0m';
    final diff = DateTime.now().difference(DateTime.parse(checkIn));
    return '${diff.inHours}h ${diff.inMinutes % 60}m';
  }
}

class _TimeCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _TimeCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
        ]),
      ),
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  final int month, year;
  final void Function(int, int) onMonthChanged;
  const _HistoryTab({required this.month, required this.year, required this.onMonthChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final histAsync = ref.watch(attendanceHistoryProvider({'month': month, 'year': year}));

    return Column(
      children: [
        // Month selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  final prev = DateTime(year, month - 1);
                  onMonthChanged(prev.month, prev.year);
                },
              ),
              Text(DateFormat('MMMM yyyy').format(DateTime(year, month)),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: DateTime(year, month) < DateTime.now()
                    ? () {
                        final next = DateTime(year, month + 1);
                        onMonthChanged(next.month, next.year);
                      }
                    : null,
              ),
            ],
          ),
        ),
        Expanded(
          child: histAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (data) {
              final records = data['records'] as List? ?? [];
              final summary = data['summary'] as Map? ?? {};

              return Column(
                children: [
                  // Summary chips
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _SummaryChip('P: ${summary['present'] ?? 0}', AppTheme.success),
                        const SizedBox(width: 8),
                        _SummaryChip('A: ${summary['absent'] ?? 0}', AppTheme.error),
                        const SizedBox(width: 8),
                        _SummaryChip('L: ${summary['on_leave'] ?? 0}', AppTheme.warning),
                        const SizedBox(width: 8),
                        _SummaryChip('Late: ${summary['late_count'] ?? 0}', AppTheme.info),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: records.length,
                      itemBuilder: (_, i) => _AttendanceRow(record: records[i]),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final Color color;
  const _SummaryChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  final Map record;
  const _AttendanceRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final status = record['status'] as String? ?? 'absent';
    final date = DateTime.parse(record['date']);
    final checkIn = record['check_in'];
    final checkOut = record['check_out'];
    final isLate = record['is_late'] == true;

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'present': statusColor = AppTheme.success; statusIcon = Icons.check_circle; break;
      case 'absent': statusColor = AppTheme.error; statusIcon = Icons.cancel; break;
      case 'half_day': statusColor = AppTheme.warning; statusIcon = Icons.adjust; break;
      case 'on_leave': statusColor = AppTheme.info; statusIcon = Icons.beach_access; break;
      case 'holiday': statusColor = Colors.purple; statusIcon = Icons.celebration; break;
      default: statusColor = Colors.grey; statusIcon = Icons.remove_circle_outline;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.1),
          child: Icon(statusIcon, color: statusColor, size: 20),
        ),
        title: Row(children: [
          Text(DateFormat('EEE, d MMM').format(date), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(width: 8),
          if (isLate) Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: AppTheme.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
            child: Text('Late', style: TextStyle(color: AppTheme.warning, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        ]),
        subtitle: checkIn != null
            ? Text('${DateFormat('hh:mm a').format(DateTime.parse(checkIn))} - ${checkOut != null ? DateFormat('hh:mm a').format(DateTime.parse(checkOut)) : 'Active'}',
                style: const TextStyle(fontSize: 12))
            : Text(status.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 12)),
        trailing: checkOut != null
            ? Text('${(double.tryParse('${record['effective_hours']}') ?? 0).toStringAsFixed(1)}h',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))
            : null,
      ),
    );
  }
}
