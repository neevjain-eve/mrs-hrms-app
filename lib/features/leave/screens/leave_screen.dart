import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../services/api_service.dart';

final myLeavesProvider = FutureProvider<List<dynamic>>((ref) async {
  final data = await ref.watch(apiServiceProvider).getMyLeaves();
  return data['applications'] as List? ?? [];
});

final leaveBalancesProvider = FutureProvider<List<dynamic>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user?.employeeId == null) return [];
  final data = await ref.watch(apiServiceProvider).getLeaveBalance(user!.employeeId!);
  return data['balances'] as List? ?? [];
});

final pendingLeavesProvider = FutureProvider<List<dynamic>>((ref) async {
  final data = await ref.watch(apiServiceProvider).getLeaveApplications(status: 'pending');
  return data['applications'] as List? ?? [];
});

class LeaveScreen extends ConsumerStatefulWidget {
  const LeaveScreen({super.key});

  @override
  ConsumerState<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends ConsumerState<LeaveScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    final isManager = ref.read(userRoleProvider) != 'employee';
    _tab = TabController(length: isManager ? 3 : 2, vsync: this);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(userRoleProvider);
    final isManager = role != 'employee';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Management'),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_month), onPressed: () => context.push('/leave/calendar')),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          tabs: [
            const Tab(text: 'Balance'),
            const Tab(text: 'My Leaves'),
            if (isManager) const Tab(text: 'Approvals'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _BalanceTab(),
          _MyLeavesTab(),
          if (isManager) _ApprovalsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/leave/apply'),
        icon: const Icon(Icons.add),
        label: const Text('Apply Leave'),
      ),
    );
  }
}

class _BalanceTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balancesAsync = ref.watch(leaveBalancesProvider);

    return balancesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (balances) => balances.isEmpty
          ? const Center(child: Text('No leave balances configured'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: balances.length,
              itemBuilder: (_, i) {
                final b = balances[i] as Map;
                final available = double.tryParse('${b['closing_balance']}') ?? 0;
                final max = double.tryParse('${b['max_days_per_year']}') ?? 1;
                final used = double.tryParse('${b['used']}') ?? 0;
                final color = Color(int.parse((b['color'] ?? '#2196F3').replaceFirst('#', '0xFF')));
                final progress = (available / max).clamp(0.0, 1.0);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(b['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: Text('${available.toStringAsFixed(1)} left', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: progress, backgroundColor: color.withOpacity(0.1), valueColor: AlwaysStoppedAnimation(color), minHeight: 6, borderRadius: BorderRadius.circular(6)),
                      const SizedBox(height: 10),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        _BalStat('Entitled', max.toStringAsFixed(0), Colors.grey),
                        _BalStat('Used', used.toStringAsFixed(1), AppTheme.error),
                        _BalStat('Balance', available.toStringAsFixed(1), color),
                      ]),
                    ]),
                  ),
                );
              },
            ),
    );
  }
}

class _BalStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _BalStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ]);
  }
}

class _MyLeavesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leavesAsync = ref.watch(myLeavesProvider);
    return leavesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (leaves) => leaves.isEmpty
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.beach_access_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 12),
              Text('No leave applications', style: TextStyle(color: Colors.grey)),
            ]))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: leaves.length,
              itemBuilder: (_, i) => _LeaveCard(leave: leaves[i] as Map),
            ),
    );
  }
}

class _ApprovalsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingLeavesProvider);
    return pendingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (leaves) => leaves.isEmpty
          ? const Center(child: Text('No pending approvals', style: TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: leaves.length,
              itemBuilder: (_, i) => _ApprovalCard(leave: leaves[i] as Map, ref: ref),
            ),
    );
  }
}

class _LeaveCard extends StatelessWidget {
  final Map leave;
  const _LeaveCard({required this.leave});

  @override
  Widget build(BuildContext context) {
    final status = leave['status'] as String? ?? 'pending';
    final color = Color(int.parse((leave['color'] ?? '#2196F3').replaceFirst('#', '0xFF')));
    Color statusColor;
    switch (status) {
      case 'approved': statusColor = AppTheme.success; break;
      case 'rejected': statusColor = AppTheme.error; break;
      case 'cancelled': statusColor = Colors.grey; break;
      default: statusColor = AppTheme.warning;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(leave['leave_type'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 8),
          Text('${DateFormat('dd MMM').format(DateTime.parse(leave['from_date']))} - ${DateFormat('dd MMM yyyy').format(DateTime.parse(leave['to_date']))} · ${leave['days']} day(s)',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          if (leave['reason'] != null) ...[
            const SizedBox(height: 4),
            Text(leave['reason'], style: TextStyle(fontSize: 12, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ]),
      ),
    );
  }
}

class _ApprovalCard extends StatefulWidget {
  final Map leave;
  final WidgetRef ref;
  const _ApprovalCard({required this.leave, required this.ref});

  @override
  State<_ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends State<_ApprovalCard> {
  bool _processing = false;

  Future<void> _act(String status) async {
    setState(() => _processing = true);
    try {
      await widget.ref.read(apiServiceProvider).approveLeave(widget.leave['id'], status);
      widget.ref.invalidate(pendingLeavesProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
    } finally {
      setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final leave = widget.leave;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 18, backgroundImage: leave['photo_url'] != null ? NetworkImage(leave['photo_url']) : null,
                child: leave['photo_url'] == null ? Text(leave['employee_name']?[0] ?? 'E') : null),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(leave['employee_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(leave['department'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ])),
            Text('${leave['days']} day(s)', style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.warning)),
          ]),
          const Divider(height: 16),
          Text('${leave['leave_type'] ?? ''} · ${DateFormat('dd MMM').format(DateTime.parse(leave['from_date']))} - ${DateFormat('dd MMM yyyy').format(DateTime.parse(leave['to_date']))}',
              style: const TextStyle(fontSize: 13)),
          if (leave['reason'] != null) Text(leave['reason'], style: TextStyle(fontSize: 12, color: Colors.grey.shade500), maxLines: 2),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              icon: const Icon(Icons.close, size: 16),
              label: const Text('Reject'),
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error, side: const BorderSide(color: AppTheme.error)),
              onPressed: _processing ? null : () => _act('rejected'),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton.icon(
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Approve'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
              onPressed: _processing ? null : () => _act('approved'),
            )),
          ]),
        ]),
      ),
    );
  }
}
