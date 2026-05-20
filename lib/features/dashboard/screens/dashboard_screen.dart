import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/stat_card.dart';

final dashboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiServiceProvider);
  final user = ref.watch(currentUserProvider);
  if (user?.canViewAllEmployees ?? false) {
    return api.getAdminDashboard();
  }
  return api.getEmployeeDashboard();
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final dash = ref.watch(dashboardProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Good ${_greeting()}, ${user?.name?.split(' ').first ?? ''}!',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text(DateFormat('EEEE, MMM d').format(DateTime.now()),
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(dashboardProvider.future),
        child: dash.when(
          loading: () => _buildSkeleton(context),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (data) => isAdmin
              ? _AdminDashboard(data: data)
              : _EmployeeDashboard(data: data),
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  Widget _buildSkeleton(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(6, (_) => Container(
          height: 100, margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        )),
      ),
    );
  }
}

class _AdminDashboard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AdminDashboard({required this.data});

  @override
  Widget build(BuildContext context) {
    final emp = data['employees'] as Map? ?? {};
    final att = (data['attendance'] as Map?)?['today'] as Map? ?? {};
    final deptData = (data['departmentHeadcount'] as List? ?? []);
    final trend = (data['attendanceTrend'] as List? ?? []);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Employee Stats Row
        Row(children: [
          Expanded(child: StatCard(
            title: 'Total Active', value: '${emp['total_active'] ?? 0}',
            icon: Icons.people_outline, gradient: AppTheme.primaryGradient,
          )),
          const SizedBox(width: 12),
          Expanded(child: StatCard(
            title: 'On Probation', value: '${emp['on_probation'] ?? 0}',
            icon: Icons.hourglass_outline, gradient: AppTheme.infoGradient,
          )),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: StatCard(
            title: 'New Joiners', value: '${emp['new_joiners_30d'] ?? 0}',
            icon: Icons.person_add_outlined, gradient: AppTheme.successGradient,
          )),
          const SizedBox(width: 12),
          Expanded(child: StatCard(
            title: 'Pending Leaves', value: '${data['pendingLeaves'] ?? 0}',
            icon: Icons.event_busy_outlined, gradient: AppTheme.warningGradient,
          )),
        ]),
        const SizedBox(height: 20),

        // Today's Attendance
        _SectionHeader(title: "Today's Attendance", icon: Icons.today_outlined),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _AttStat('Present', '${att['present'] ?? 0}', AppTheme.success),
                _AttStat('Absent', '${att['absent'] ?? 0}', AppTheme.error),
                _AttStat('On Leave', '${att['on_leave'] ?? 0}', AppTheme.warning),
                _AttStat('Late', '${att['late'] ?? 0}', AppTheme.info),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Attendance Trend Chart
        if (trend.isNotEmpty) ...[
          _SectionHeader(title: 'Attendance Trend (6 months)', icon: Icons.show_chart),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 200,
                child: LineChart(LineChartData(
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          const months = ['J','F','M','A','M','J','J','A','S','O','N','D'];
                          final idx = v.toInt();
                          if (idx >= 0 && idx < trend.length) {
                            final m = (trend[idx]['month'] as num?)?.toInt() ?? 1;
                            return Text(months[m - 1], style: const TextStyle(fontSize: 11));
                          }
                          return const Text('');
                        },
                        interval: 1,
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: trend.asMap().entries.map((e) =>
                          FlSpot(e.key.toDouble(), (e.value['present'] as num?)?.toDouble() ?? 0)).toList(),
                      isCurved: true,
                      color: AppTheme.primary,
                      barWidth: 3,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.primary.withOpacity(0.1),
                      ),
                    ),
                  ],
                )),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Department Headcount
        if (deptData.isNotEmpty) ...[
          _SectionHeader(title: 'Department Headcount', icon: Icons.business_outlined),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 220,
                child: BarChart(BarChartData(
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(drawVerticalLine: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx >= 0 && idx < deptData.length) {
                            final name = deptData[idx]['name']?.toString() ?? '';
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(name.length > 6 ? name.substring(0, 6) : name,
                                  style: const TextStyle(fontSize: 9)),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  barGroups: deptData.asMap().entries.map((e) => BarChartGroupData(
                    x: e.key,
                    barRods: [BarChartRodData(
                      toY: (e.value['count'] as num?)?.toDouble() ?? 0,
                      color: AppTheme.primary,
                      width: 16,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    )],
                  )).toList(),
                )),
              ),
            ),
          ),
        ],
        const SizedBox(height: 80),
      ],
    );
  }
}

class _EmployeeDashboard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _EmployeeDashboard({required this.data});

  @override
  Widget build(BuildContext context) {
    final todayAtt = data['todayAttendance'] as Map?;
    final monthSummary = data['monthSummary'] as Map? ?? {};
    final balances = data['leaveBalances'] as List? ?? [];
    final latestPayslip = data['latestPayslip'] as Map?;
    final announcements = data['announcements'] as List? ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Today's Check-in Status
        _TodayAttendanceCard(record: todayAtt),
        const SizedBox(height: 16),

        // Monthly Summary
        _SectionHeader(title: 'This Month', icon: Icons.calendar_month_outlined),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: StatCard(
            title: 'Days Present', value: '${monthSummary['present'] ?? 0}',
            icon: Icons.check_circle_outline, gradient: AppTheme.successGradient,
          )),
          const SizedBox(width: 12),
          Expanded(child: StatCard(
            title: 'Hours Worked', value: '${double.tryParse('${monthSummary['total_hours']}')?.toStringAsFixed(1) ?? 0}h',
            icon: Icons.timer_outlined, gradient: AppTheme.infoGradient,
          )),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: StatCard(
            title: 'On Leave', value: '${monthSummary['on_leave'] ?? 0}',
            icon: Icons.beach_access_outlined, gradient: AppTheme.warningGradient,
          )),
          const SizedBox(width: 12),
          Expanded(child: StatCard(
            title: 'Late Count', value: '${monthSummary['late_count'] ?? 0}',
            icon: Icons.alarm_outlined, gradient: AppTheme.primaryGradient,
          )),
        ]),
        const SizedBox(height: 20),

        // Leave Balances
        if (balances.isNotEmpty) ...[
          _SectionHeader(title: 'Leave Balance', icon: Icons.event_available_outlined),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: balances.take(4).map((b) => _LeaveBalanceRow(balance: b)).toList(),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Latest Payslip
        if (latestPayslip != null) ...[
          _SectionHeader(title: 'Latest Payslip', icon: Icons.receipt_outlined),
          const SizedBox(height: 12),
          _PayslipCard(payslip: latestPayslip),
          const SizedBox(height: 20),
        ],

        // Announcements
        if (announcements.isNotEmpty) ...[
          _SectionHeader(title: 'Announcements', icon: Icons.campaign_outlined),
          const SizedBox(height: 12),
          ...announcements.map((a) => _AnnouncementCard(announcement: a)),
        ],
        const SizedBox(height: 80),
      ],
    );
  }
}

class _TodayAttendanceCard extends StatelessWidget {
  final Map? record;
  const _TodayAttendanceCard({this.record});

  @override
  Widget build(BuildContext context) {
    final isCheckedIn = record?['check_in'] != null;
    final isCheckedOut = record?['check_out'] != null;
    final checkIn = record?['check_in'];
    final checkOut = record?['check_out'];
    final isLate = record?['is_late'] == true;

    Color statusColor = isCheckedIn ? AppTheme.success : Colors.grey;
    String statusText = isCheckedIn ? (isCheckedOut ? 'Completed' : 'Working') : 'Not Checked In';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Today\'s Attendance', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text(DateFormat('EEEE, MMM d, yyyy').format(DateTime.now()),
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(statusText, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _TimeBox(
                label: 'Check In',
                time: checkIn != null ? DateFormat('hh:mm a').format(DateTime.parse(checkIn)) : '--:--',
                icon: Icons.login,
                warning: isLate,
              )),
              const SizedBox(width: 12),
              Expanded(child: _TimeBox(
                label: 'Check Out',
                time: checkOut != null ? DateFormat('hh:mm a').format(DateTime.parse(checkOut)) : '--:--',
                icon: Icons.logout,
              )),
              if (isCheckedIn && !isCheckedOut) ...[
                const SizedBox(width: 12),
                Expanded(child: _TimeBox(
                  label: 'Hours',
                  time: _calcHours(checkIn),
                  icon: Icons.timer_outlined,
                )),
              ],
            ],
          ),
          if (isLate) ...[
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.warning_amber, color: Colors.amber, size: 14),
              const SizedBox(width: 4),
              Text('Late by ${record!['late_minutes']} min', style: const TextStyle(color: Colors.amber, fontSize: 12)),
            ]),
          ],
        ],
      ),
    );
  }

  String _calcHours(String? checkIn) {
    if (checkIn == null) return '0h';
    final diff = DateTime.now().difference(DateTime.parse(checkIn));
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    return '${h}h ${m}m';
  }
}

class _TimeBox extends StatelessWidget {
  final String label, time;
  final IconData icon;
  final bool warning;
  const _TimeBox({required this.label, required this.time, required this.icon, this.warning = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: warning ? Colors.amber : Colors.white, size: 18),
          const SizedBox(height: 4),
          Text(time, style: TextStyle(color: warning ? Colors.amber : Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ],
      ),
    );
  }
}

class _LeaveBalanceRow extends StatelessWidget {
  final Map balance;
  const _LeaveBalanceRow({required this.balance});

  @override
  Widget build(BuildContext context) {
    final available = double.tryParse('${balance['closing_balance']}') ?? 0;
    final max = double.tryParse('${balance['max_days_per_year']}') ?? 1;
    final progress = (available / max).clamp(0.0, 1.0);
    final color = Color(int.parse((balance['color'] ?? '#2196F3').replaceFirst('#', '0xFF')));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(balance['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              Text('${available.toStringAsFixed(1)} / ${max.toStringAsFixed(0)} days',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: progress, backgroundColor: color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation(color), minHeight: 4,
              borderRadius: BorderRadius.circular(4),
            ),
          ])),
        ],
      ),
    );
  }
}

class _PayslipCard extends StatelessWidget {
  final Map payslip;
  const _PayslipCard({required this.payslip});

  @override
  Widget build(BuildContext context) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final month = (payslip['month'] as num?)?.toInt() ?? 1;
    final year = payslip['year'];
    final net = double.tryParse('${payslip['net_salary']}') ?? 0;
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(gradient: AppTheme.successGradient, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.receipt_long, color: Colors.white, size: 22),
        ),
        title: Text('${months[month - 1]} $year Payslip', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(formatter.format(net), style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w700, fontSize: 16)),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.download_outlined, color: AppTheme.primary, size: 20),
        ),
        onTap: () => context.go('/payroll/payslip/${payslip['id']}'),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Map announcement;
  const _AnnouncementCard({required this.announcement});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (announcement['is_pinned'] == true)
                const Icon(Icons.push_pin, size: 14, color: AppTheme.warning),
              if (announcement['is_pinned'] == true) const SizedBox(width: 4),
              Expanded(child: Text(announcement['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
            ]),
            const SizedBox(height: 4),
            Text(announcement['content'] ?? '', style: TextStyle(fontSize: 13, color: Colors.grey.shade600), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _AttStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _AttStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ]);
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: AppTheme.primary),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
    ]);
  }
}
