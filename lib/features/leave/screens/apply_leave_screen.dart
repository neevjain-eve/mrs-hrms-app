import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_button.dart';

class ApplyLeaveScreen extends ConsumerStatefulWidget {
  const ApplyLeaveScreen({super.key});

  @override
  ConsumerState<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends ConsumerState<ApplyLeaveScreen> {
  final _form = GlobalKey<FormState>();
  String? _leaveTypeId;
  DateTime? _fromDate, _toDate;
  bool _halfDay = false;
  String _halfDaySession = 'morning';
  final _reasonCtrl = TextEditingController();
  bool _loading = false;
  List<dynamic> _leaveTypes = [];

  @override
  void initState() {
    super.initState();
    _loadLeaveTypes();
  }

  Future<void> _loadLeaveTypes() async {
    try {
      final data = await ref.read(apiServiceProvider).getLeaveTypes();
      setState(() => _leaveTypes = data['leaveTypes'] as List? ?? []);
    } catch (_) {}
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(
        colorScheme: const ColorScheme.light(primary: AppTheme.primary),
      ), child: child!),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) { _fromDate = picked; if (_toDate == null || _toDate!.isBefore(picked)) _toDate = picked; }
        else _toDate = picked;
      });
    }
  }

  int _calcDays() {
    if (_fromDate == null || _toDate == null) return 0;
    if (_halfDay) return 1;
    int days = 0;
    for (var d = _fromDate!; !d.isAfter(_toDate!); d = d.add(const Duration(days: 1))) {
      if (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) days++;
    }
    return days;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_fromDate == null || _toDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select dates')));
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(apiServiceProvider).applyLeave({
        'leaveTypeId': _leaveTypeId,
        'fromDate': DateFormat('yyyy-MM-dd').format(_fromDate!),
        'toDate': DateFormat('yyyy-MM-dd').format(_toDate!),
        'reason': _reasonCtrl.text.trim(),
        'halfDay': _halfDay,
        'halfDaySession': _halfDaySession,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Leave applied successfully!'), backgroundColor: AppTheme.success,
        ));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
    } finally { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final days = _calcDays();
    return Scaffold(
      appBar: AppBar(title: const Text('Apply for Leave')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Leave Type
            const Text('Leave Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _leaveTypeId,
              decoration: const InputDecoration(hintText: 'Select leave type'),
              items: _leaveTypes.map((t) => DropdownMenuItem(
                value: t['id'] as String,
                child: Text(t['name'] as String),
              )).toList(),
              validator: (v) => v == null ? 'Select a leave type' : null,
              onChanged: (v) => setState(() => _leaveTypeId = v),
            ),
            const SizedBox(height: 20),

            // Dates
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('From Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => _pickDate(true),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F2FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_today, size: 16, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      Text(_fromDate != null ? DateFormat('dd MMM yyyy').format(_fromDate!) : 'Select',
                          style: TextStyle(fontSize: 13, color: _fromDate != null ? Colors.black : Colors.grey)),
                    ]),
                  ),
                ),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('To Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => _pickDate(false),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F2FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_today, size: 16, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      Text(_toDate != null ? DateFormat('dd MMM yyyy').format(_toDate!) : 'Select',
                          style: TextStyle(fontSize: 13, color: _toDate != null ? Colors.black : Colors.grey)),
                    ]),
                  ),
                ),
              ])),
            ]),
            const SizedBox(height: 16),

            // Half day toggle
            SwitchListTile(
              value: _halfDay,
              onChanged: (v) => setState(() => _halfDay = v),
              title: const Text('Half Day', style: TextStyle(fontWeight: FontWeight.w500)),
              activeColor: AppTheme.primary,
              contentPadding: EdgeInsets.zero,
            ),
            if (_halfDay) ...[
              Row(children: [
                Expanded(child: RadioListTile(
                  value: 'morning', groupValue: _halfDaySession, title: const Text('Morning'),
                  activeColor: AppTheme.primary, contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() => _halfDaySession = v!),
                )),
                Expanded(child: RadioListTile(
                  value: 'afternoon', groupValue: _halfDaySession, title: const Text('Afternoon'),
                  activeColor: AppTheme.primary, contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() => _halfDaySession = v!),
                )),
              ]),
            ],

            if (days > 0) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.info_outline, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text('$days working day(s) will be deducted', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(height: 16),
            ],

            // Reason
            const Text('Reason', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _reasonCtrl,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Describe your reason for leave...'),
              validator: (v) => v!.isEmpty ? 'Please provide a reason' : null,
            ),
            const SizedBox(height: 28),
            AppButton(text: 'Apply Leave', onPressed: _loading ? null : _submit, isLoading: _loading, width: double.infinity),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
