import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../services/api_service.dart';

final payslipsProvider = FutureProvider<List<dynamic>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user?.employeeId == null) return [];
  final data = await ref.watch(apiServiceProvider).getEmployeePayslips(user!.employeeId!);
  return data['payslips'] as List? ?? [];
});

class PayrollScreen extends ConsumerWidget {
  const PayrollScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final payslipsAsync = ref.watch(payslipsProvider);
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

    return Scaffold(
      appBar: AppBar(title: const Text('Payroll & Payslips')),
      body: payslipsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (payslips) => payslips.isEmpty
            ? const Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No payslips available yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: payslips.length,
                itemBuilder: (_, i) {
                  final p = payslips[i] as Map;
                  final month = (p['month'] as num).toInt();
                  final year = p['year'];
                  final net = double.tryParse('${p['net_salary']}') ?? 0;
                  final gross = double.tryParse('${p['gross_salary']}') ?? 0;
                  final deductions = double.tryParse('${p['total_deductions']}') ?? 0;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => context.push('/payroll/payslip/${p['id']}'),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 50, height: 50,
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(child: Text(
                                    months[month - 1].substring(0, 3),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                                  )),
                                ),
                                const SizedBox(width: 14),
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${months[month - 1]} $year', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                    const SizedBox(height: 2),
                                    Text('${p['days_present']} days present · LOP: ${p['lop_days']} days',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                  ],
                                )),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(formatter.format(net),
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.success)),
                                    Text('Net Pay', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _PayItem('Gross', formatter.format(gross), AppTheme.info),
                                _PayItem('Deductions', formatter.format(deductions), AppTheme.error),
                                _PayItem('Net', formatter.format(net), AppTheme.success),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(children: const [
                                    Icon(Icons.download_outlined, size: 14, color: AppTheme.primary),
                                    SizedBox(width: 4),
                                    Text('PDF', style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                                  ]),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _PayItem extends StatelessWidget {
  final String label, value;
  final Color color;
  const _PayItem(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}
