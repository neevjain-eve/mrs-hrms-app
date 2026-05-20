import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../services/api_service.dart';

final employeeDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  return ref.watch(apiServiceProvider).getEmployee(id);
});

class EmployeeDetailScreen extends ConsumerWidget {
  final String employeeId;
  const EmployeeDetailScreen({super.key, required this.employeeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final empAsync = ref.watch(employeeDetailProvider(employeeId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Profile'),
        actions: [
          if (isAdmin) IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/employees/$employeeId/edit'),
          ),
        ],
      ),
      body: empAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (emp) {
          final e = emp['employee'] as Map? ?? emp;
          return SingleChildScrollView(
            child: Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
                  child: Column(children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundImage: e['photo_url'] != null ? CachedNetworkImageProvider(e['photo_url']) : null,
                      backgroundColor: Colors.white24,
                      child: e['photo_url'] == null
                          ? Text('${e['first_name']?[0] ?? ''}${e['last_name']?[0] ?? ''}',
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white))
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text('${e['first_name'] ?? ''} ${e['last_name'] ?? ''}',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(e['designation'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(e['employee_id'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: e['status'] == 'active' ? AppTheme.success.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text((e['status'] ?? 'active').toUpperCase(),
                          style: TextStyle(color: e['status'] == 'active' ? AppTheme.success : Colors.grey,
                              fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    _InfoCard('Work Information', Icons.work_outline, [
                      _InfoRow('Department', e['department'] ?? 'N/A'),
                      _InfoRow('Designation', e['designation'] ?? 'N/A'),
                      _InfoRow('Employment Type', e['employment_type'] ?? 'N/A'),
                      _InfoRow('Date of Joining', e['date_of_joining'] != null
                          ? DateFormat('dd MMM yyyy').format(DateTime.parse(e['date_of_joining']))
                          : 'N/A'),
                    ]),
                    const SizedBox(height: 12),
                    _InfoCard('Contact Information', Icons.contact_mail_outlined, [
                      _InfoRow('Email', e['email'] ?? 'N/A'),
                      _InfoRow('Phone', e['phone'] ?? 'N/A'),
                    ]),
                    const SizedBox(height: 12),
                    _InfoCard('Personal Information', Icons.person_outline, [
                      _InfoRow('Date of Birth', e['date_of_birth'] != null
                          ? DateFormat('dd MMM yyyy').format(DateTime.parse(e['date_of_birth']))
                          : 'N/A'),
                      _InfoRow('Gender', e['gender'] ?? 'N/A'),
                      _InfoRow('PAN Number', e['pan_number'] ?? 'N/A'),
                      _InfoRow('Aadhar Number', e['aadhar_number'] ?? 'N/A'),
                    ]),
                    const SizedBox(height: 12),
                    _InfoCard('Bank Details', Icons.account_balance_outlined, [
                      _InfoRow('Bank Name', e['bank_name'] ?? 'N/A'),
                      _InfoRow('Account Number', e['bank_account_number'] ?? 'N/A'),
                      _InfoRow('IFSC Code', e['ifsc_code'] ?? 'N/A'),
                    ]),
                    const SizedBox(height: 32),
                  ]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> rows;
  const _InfoCard(this.title, this.icon, this.rows);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 18, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
          const Divider(height: 20),
          ...rows,
        ]),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 130, child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade500))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}
