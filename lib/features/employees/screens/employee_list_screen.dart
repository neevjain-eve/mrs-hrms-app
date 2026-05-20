import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../services/api_service.dart';

final employeeListProvider = FutureProvider.family<Map<String, dynamic>, Map<String, dynamic>>((ref, params) async {
  return ref.watch(apiServiceProvider).getEmployees(params);
});

class EmployeeListScreen extends ConsumerStatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  ConsumerState<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends ConsumerState<EmployeeListScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String? _dept;
  String _status = 'active';

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);
    final params = {'search': _search, if (_dept != null) 'department': _dept!, 'status': _status, 'limit': '50'};
    final empAsync = ref.watch(employeeListProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employees'),
        actions: [
          if (isAdmin) IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () => context.push('/employees/add'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search employees...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); })
                    : null,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          Expanded(
            child: empAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (data) {
                final employees = data['employees'] as List? ?? [];
                if (employees.isEmpty) {
                  return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.people_outline, size: 64, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('No employees found', style: TextStyle(color: Colors.grey)),
                  ]));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: employees.length,
                  itemBuilder: (_, i) {
                    final e = employees[i] as Map;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundImage: e['photo_url'] != null ? CachedNetworkImageProvider(e['photo_url']) : null,
                          backgroundColor: AppTheme.primary.withOpacity(0.15),
                          child: e['photo_url'] == null
                              ? Text('${e['first_name']?[0] ?? ''}${e['last_name']?[0] ?? ''}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primary, fontSize: 13))
                              : null,
                        ),
                        title: Text('${e['first_name'] ?? ''} ${e['last_name'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e['designation'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                          Text(e['employee_id'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                        ]),
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () => context.push('/employees/${e['id']}'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
