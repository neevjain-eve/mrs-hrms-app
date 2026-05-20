import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_button.dart';

final payslipDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  return ref.watch(apiServiceProvider).getPayslip(id);
});

class PayslipDetailScreen extends ConsumerStatefulWidget {
  final String payslipId;
  const PayslipDetailScreen({super.key, required this.payslipId});

  @override
  ConsumerState<PayslipDetailScreen> createState() => _PayslipDetailScreenState();
}

class _PayslipDetailScreenState extends ConsumerState<PayslipDetailScreen> {
  bool _downloading = false;

  Future<void> _download(Map<String, dynamic> payslip) async {
    setState(() => _downloading = true);
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      final api = ref.read(apiServiceProvider);
      final url = await api.downloadPayslipUrl(widget.payslipId);
      final dir = await getApplicationDocumentsDirectory();
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final month = (payslip['month'] as num).toInt();
      final fname = 'Payslip_${months[month - 1]}_${payslip['year']}.pdf';
      final path = '${dir.path}/$fname';

      await Dio().download(url, path, options: Options(headers: {'Authorization': 'Bearer $token'}));

      if (mounted) {
        // Show password dialog
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Download Complete'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check_circle, color: AppTheme.success, size: 48),
              const SizedBox(height: 16),
              const Text('Payslip downloaded successfully.', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                child: Column(children: [
                  const Text('PDF Password:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Your Date of Birth\n(DDMMYYYY format)', textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ]),
              ),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
              ElevatedButton(
                onPressed: () { Navigator.pop(context); OpenFile.open(path); },
                child: const Text('Open PDF'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: AppTheme.error,
        ));
      }
    } finally {
      setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final payslipAsync = ref.watch(payslipDetailProvider(widget.payslipId));
    final formatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

    return Scaffold(
      appBar: AppBar(title: const Text('Payslip Details')),
      body: payslipAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (p) {
          final month = (p['month'] as num).toInt();
          final earnings = p['earnings_components'] as Map? ?? {};
          final deductions = p['deduction_components'] as Map? ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(children: [
                    Text('${months[month - 1]} ${p['year']} Payslip',
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(formatter.format(double.tryParse('${p['net_salary']}') ?? 0),
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                    const Text('Net Pay', style: TextStyle(color: Colors.white60, fontSize: 12)),
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                      _HeaderStat('Days Present', '${p['days_present']}'),
                      _HeaderStat('LOP Days', '${p['lop_days']}'),
                      _HeaderStat('Gross', formatter.format(double.tryParse('${p['gross_salary']}') ?? 0)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 16),

                // Earnings
                _PayslipSection(
                  title: 'Earnings',
                  icon: Icons.trending_up,
                  color: AppTheme.success,
                  items: _buildItems(earnings, formatter),
                  total: formatter.format(double.tryParse('${p['gross_salary']}') ?? 0),
                  totalLabel: 'Gross Salary',
                ),
                const SizedBox(height: 12),

                // Deductions
                _PayslipSection(
                  title: 'Deductions',
                  icon: Icons.trending_down,
                  color: AppTheme.error,
                  items: _buildItems(deductions, formatter),
                  total: formatter.format(double.tryParse('${p['total_deductions']}') ?? 0),
                  totalLabel: 'Total Deductions',
                ),
                const SizedBox(height: 12),

                // Employer Contributions
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Employer Contributions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text('(Not deducted from your salary)', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      const Divider(height: 20),
                      _LineItem('PF (Employer)', formatter.format(double.tryParse('${p['pf_employer']}') ?? 0), Colors.grey),
                      _LineItem('ESI (Employer)', formatter.format(double.tryParse('${p['esi_employer']}') ?? 0), Colors.grey),
                    ]),
                  ),
                ),
                const SizedBox(height: 24),

                // Download button
                if (p['is_published'] == true)
                  AppButton(
                    text: 'Download PDF',
                    onPressed: _downloading ? null : () => _download(p),
                    isLoading: _downloading,
                    width: double.infinity,
                    icon: Icons.download_outlined,
                  ),
                const SizedBox(height: 12),
                if (p['is_published'] == true)
                  Text(
                    'PDF is password protected.\nPassword: Date of Birth (DDMMYYYY)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  List<MapEntry<String, String>> _buildItems(Map comps, NumberFormat fmt) {
    const labels = {
      'BASIC': 'Basic Salary', 'HRA': 'House Rent Allowance', 'SPEC': 'Special Allowance',
      'OT': 'Overtime', 'BONUS': 'Bonus / Incentive',
      'PF_EMP': 'Provident Fund', 'ESI_EMP': 'ESI Employee',
      'PT': 'Professional Tax', 'TDS': 'Income Tax (TDS)', 'LOAN': 'Loan Deduction',
    };
    return comps.entries
        .where((e) => (double.tryParse('${e.value}') ?? 0) > 0)
        .map((e) => MapEntry(labels[e.key] ?? e.key, fmt.format(double.tryParse('${e.value}') ?? 0)))
        .toList();
  }
}

class _HeaderStat extends StatelessWidget {
  final String label, value;
  const _HeaderStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
    ]);
  }
}

class _PayslipSection extends StatelessWidget {
  final String title, total, totalLabel;
  final IconData icon;
  final Color color;
  final List<MapEntry<String, String>> items;

  const _PayslipSection({required this.title, required this.icon, required this.color, required this.items, required this.total, required this.totalLabel});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ]),
          const Divider(height: 20),
          ...items.map((e) => _LineItem(e.key, e.value, Colors.black87)),
          const Divider(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(totalLabel, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
            Text(total, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color)),
          ]),
        ]),
      ),
    );
  }
}

class _LineItem extends StatelessWidget {
  final String label, value;
  final Color color;
  const _LineItem(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}
