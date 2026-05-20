import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/api_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';

class AddEmployeeScreen extends ConsumerStatefulWidget {
  const AddEmployeeScreen({super.key});

  @override
  ConsumerState<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends ConsumerState<AddEmployeeScreen> {
  final _form = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _dojCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _aadharCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _bankAccCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _basicSalCtrl = TextEditingController();

  String _gender = 'male';
  String _empType = 'full_time';
  String? _deptId;
  String? _desigId;
  bool _loading = false;

  List _departments = [];
  List _designations = [];

  @override
  void initState() {
    super.initState();
    _loadDepts();
  }

  Future<void> _loadDepts() async {
    try {
      final api = ref.read(apiServiceProvider);
      final d = await api.getDepartments();
      final des = await api.getDesignations();
      setState(() {
        _departments = d['departments'] as List? ?? [];
        _designations = des['designations'] as List? ?? [];
      });
    } catch (_) {}
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(
        colorScheme: const ColorScheme.light(primary: AppTheme.primary),
      ), child: child!),
    );
    if (picked != null) ctrl.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(apiServiceProvider).createEmployee({
        'firstName': _firstNameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'dateOfBirth': _dobCtrl.text,
        'dateOfJoining': _dojCtrl.text,
        'gender': _gender,
        'employmentType': _empType,
        'departmentId': _deptId,
        'designationId': _desigId,
        'panNumber': _panCtrl.text.trim(),
        'aadharNumber': _aadharCtrl.text.trim(),
        'bankName': _bankNameCtrl.text.trim(),
        'bankAccountNumber': _bankAccCtrl.text.trim(),
        'ifscCode': _ifscCtrl.text.trim(),
        'basicSalary': double.tryParse(_basicSalCtrl.text) ?? 0,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Employee added successfully!'), backgroundColor: AppTheme.success));
        context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppTheme.error));
    } finally { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Employee')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _SectionHeader('Personal Information'),
            AppTextField(controller: _firstNameCtrl, label: 'First Name', validator: (v) => v!.isEmpty ? 'Required' : null),
            AppTextField(controller: _lastNameCtrl, label: 'Last Name', validator: (v) => v!.isEmpty ? 'Required' : null),
            AppTextField(controller: _emailCtrl, label: 'Email', keyboardType: TextInputType.emailAddress,
                validator: (v) => v!.isEmpty ? 'Required' : null),
            AppTextField(controller: _phoneCtrl, label: 'Phone', keyboardType: TextInputType.phone),
            // DOB
            const Text('Date of Birth', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _dobCtrl, readOnly: true,
              decoration: const InputDecoration(hintText: 'Select date', suffixIcon: Icon(Icons.calendar_today, size: 18)),
              onTap: () => _pickDate(_dobCtrl),
            ),
            const SizedBox(height: 16),
            const Text('Gender', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _gender,
              items: const [
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'female', child: Text('Female')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) => setState(() => _gender = v!),
            ),
            const SizedBox(height: 20),

            _SectionHeader('Employment Details'),
            const Text('Date of Joining', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _dojCtrl, readOnly: true,
              decoration: const InputDecoration(hintText: 'Select date', suffixIcon: Icon(Icons.calendar_today, size: 18)),
              onTap: () => _pickDate(_dojCtrl),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            const Text('Department', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _deptId,
              hint: const Text('Select department'),
              items: _departments.map((d) => DropdownMenuItem(value: d['id'] as String, child: Text(d['name'] as String))).toList(),
              onChanged: (v) => setState(() => _deptId = v),
            ),
            const SizedBox(height: 16),
            const Text('Designation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _desigId,
              hint: const Text('Select designation'),
              items: _designations.map((d) => DropdownMenuItem(value: d['id'] as String, child: Text(d['name'] as String))).toList(),
              onChanged: (v) => setState(() => _desigId = v),
            ),
            const SizedBox(height: 16),
            const Text('Employment Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _empType,
              items: const [
                DropdownMenuItem(value: 'full_time', child: Text('Full Time')),
                DropdownMenuItem(value: 'part_time', child: Text('Part Time')),
                DropdownMenuItem(value: 'contract', child: Text('Contract')),
                DropdownMenuItem(value: 'intern', child: Text('Intern')),
              ],
              onChanged: (v) => setState(() => _empType = v!),
            ),
            const SizedBox(height: 20),

            _SectionHeader('Salary'),
            AppTextField(controller: _basicSalCtrl, label: 'Basic Salary (₹)', keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Required' : null),
            const SizedBox(height: 20),

            _SectionHeader('Documents'),
            AppTextField(controller: _panCtrl, label: 'PAN Number'),
            AppTextField(controller: _aadharCtrl, label: 'Aadhar Number'),
            const SizedBox(height: 20),

            _SectionHeader('Bank Details'),
            AppTextField(controller: _bankNameCtrl, label: 'Bank Name'),
            AppTextField(controller: _bankAccCtrl, label: 'Account Number'),
            AppTextField(controller: _ifscCtrl, label: 'IFSC Code'),
            const SizedBox(height: 28),

            AppButton(text: 'Add Employee', onPressed: _loading ? null : _submit, isLoading: _loading, width: double.infinity),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.primary)),
        const SizedBox(height: 4),
        Container(height: 2, width: 40, decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.3), borderRadius: BorderRadius.circular(1))),
      ]),
    );
  }
}
