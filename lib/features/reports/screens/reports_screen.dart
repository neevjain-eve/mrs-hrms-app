import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/api_service.dart';

final payrollReportProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final now = DateTime.now();
  return ref.watch(apiServiceProvider).getPayrollSummaryReport(now.year, now.month);
});

final deptSalaryProvider = FutureProvider<List<dynamic>>((ref) async {
  final data = await ref.watch(apiServiceProvider).getDepartmentSalaryReport();
  return data['departments'] as List? ?? [];
});

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(payrollReportProvider);
    final deptAsync = ref.watch(deptSalaryProvider);
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports & Analytics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Payroll Summary
          reportAsync.when(
            loading: () => const Card(child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))),
            error: (e, _) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Text('$e'))),
            data: (report) {
              final gross = double.tryParse('${report['total_gross']}') ?? 0;
              final net = double.tryParse('${report['total_net']}') ?? 0;
              final deductions = gross - net;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Payroll Summary', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text('${DateFormat('MMMM yyyy').format(DateTime.now())}',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    const SizedBox(height: 20),
                    Row(children: [
                      _ReportStat('Total Employees', '${report['employee_count'] ?? 0}', AppTheme.primary),
                      _ReportStat('Gross Payroll', formatter.format(gross), AppTheme.info),
                      _ReportStat('Net Payroll', formatter.format(net), AppTheme.success),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      _ReportStat('PF (Employer)', formatter.format(double.tryParse('${report['total_pf_employer']}') ?? 0), AppTheme.warning),
                      _ReportStat('ESI (Employer)', formatter.format(double.tryParse('${report['total_esi_employer']}') ?? 0), AppTheme.warning),
                      _ReportStat('Total Deductions', formatter.format(deductions), AppTheme.error),
                    ]),
                  ]),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Department-wise salary pie chart
          deptAsync.when(
            loading: () => const Card(child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))),
            error: (e, _) => const SizedBox.shrink(),
            data: (depts) {
              if (depts.isEmpty) return const SizedBox.shrink();
              final colors = [AppTheme.primary, AppTheme.success, AppTheme.warning, AppTheme.error, AppTheme.info,
                const Color(0xFF9C27B0), const Color(0xFF00BCD4), const Color(0xFFFF5722)];
              final sections = depts.asMap().entries.map((entry) {
                final i = entry.key;
                final d = entry.value as Map;
                final val = double.tryParse('${d['total_net']}') ?? 0;
                return PieChartSectionData(
                  value: val, color: colors[i % colors.length],
                  title: '', radius: 60,
                );
              }).toList();

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Department-wise Salary', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: Row(children: [
                        Expanded(child: PieChart(PieChartData(sections: sections, centerSpaceRadius: 40, sectionsSpace: 2))),
                        const SizedBox(width: 12),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: depts.asMap().entries.map((entry) {
                            final i = entry.key;
                            final d = entry.value as Map;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(children: [
                                Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                Text('${d['department'] ?? ''}', style: const TextStyle(fontSize: 11)),
                              ]),
                            );
                          }).toList(),
                        ),
                      ]),
                    ),
                    const Divider(height: 20),
                    ...depts.asMap().entries.map((entry) {
                      final i = entry.key;
                      final d = entry.value as Map;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Expanded(child: Text('${d['department'] ?? ''}', style: const TextStyle(fontSize: 13))),
                          Text('${d['count']} employees', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                          const SizedBox(width: 8),
                          Text(formatter.format(double.tryParse('${d['total_net']}') ?? 0),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        ]),
                      );
                    }),
                  ]),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Quick links
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.description_outlined, color: AppTheme.primary),
                title: const Text('Attendance Report', style: TextStyle(fontWeight: FontWeight.w500)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {},
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.beach_access_outlined, color: AppTheme.warning),
                title: const Text('Leave Report', style: TextStyle(fontWeight: FontWeight.w500)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {},
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.account_balance_outlined, color: AppTheme.success),
                title: const Text('PF/ESI Compliance Report', style: TextStyle(fontWeight: FontWeight.w500)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {},
              ),
            ]),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _ReportStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _ReportStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
      ]),
    );
  }
}
