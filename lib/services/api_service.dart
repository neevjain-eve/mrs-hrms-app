import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import '../models/user_model.dart';

const _baseUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:5000/api/v1');
final _logger = Logger();
const _storage = FlutterSecureStorage();

class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final code = error.response?.data?['code'];
          if (code == 'TOKEN_EXPIRED') {
            try {
              final refreshed = await _refreshToken();
              if (refreshed) {
                final token = await _storage.read(key: 'access_token');
                final opts = error.requestOptions;
                opts.headers['Authorization'] = 'Bearer $token';
                final response = await _dio.fetch(opts);
                return handler.resolve(response);
              }
            } catch (_) {}
          }
        }
        handler.next(error);
      },
    ));
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) return false;
      final resp = await Dio().post('$_baseUrl/auth/refresh', data: {'refreshToken': refreshToken});
      await _storage.write(key: 'access_token', value: resp.data['accessToken']);
      await _storage.write(key: 'refresh_token', value: resp.data['refreshToken']);
      return true;
    } catch (_) {
      return false;
    }
  }

  // Auth
  Future<Map<String, dynamic>> login(String email, String password) async {
    final r = await _dio.post('/auth/login', data: {'email': email, 'password': password});
    return r.data;
  }

  Future<void> logout() async => _dio.post('/auth/logout');

  Future<UserModel> getMe() async {
    final r = await _dio.get('/auth/me');
    return UserModel.fromJson(r.data);
  }

  Future<void> updateFcmToken(String token) async =>
      _dio.put('/auth/fcm-token', data: {'fcmToken': token});

  Future<void> changePassword(String current, String newPass) async =>
      _dio.post('/auth/change-password', data: {'currentPassword': current, 'newPassword': newPass});

  // Dashboard
  Future<Map<String, dynamic>> getAdminDashboard() async {
    final r = await _dio.get('/dashboard/admin');
    return r.data;
  }

  Future<Map<String, dynamic>> getEmployeeDashboard() async {
    final r = await _dio.get('/dashboard/employee');
    return r.data;
  }

  // Employees
  Future<Map<String, dynamic>> getEmployees({int page = 1, int limit = 20, String? search, String? department}) async {
    final r = await _dio.get('/employees', queryParameters: {
      'page': page, 'limit': limit,
      if (search != null) 'search': search,
      if (department != null) 'department': department,
    });
    return r.data;
  }

  Future<Map<String, dynamic>> getEmployee(String id) async {
    final r = await _dio.get('/employees/$id');
    return r.data;
  }

  Future<Map<String, dynamic>> getEmployeeStats() async {
    final r = await _dio.get('/employees/stats');
    return r.data;
  }

  // Attendance
  Future<Map<String, dynamic>> checkIn({double? lat, double? lng, String? address, String source = 'manual', String? qrCode}) async {
    final r = await _dio.post('/attendance/checkin', data: {
      'lat': lat, 'lng': lng, 'address': address, 'source': source,
      if (qrCode != null) 'qrSessionCode': qrCode,
    });
    return r.data;
  }

  Future<Map<String, dynamic>> checkOut({double? lat, double? lng, String? address, String source = 'manual'}) async {
    final r = await _dio.post('/attendance/checkout', data: {
      'lat': lat, 'lng': lng, 'address': address, 'source': source,
    });
    return r.data;
  }

  Future<Map<String, dynamic>> getTodayAttendance() async {
    final r = await _dio.get('/attendance/today');
    return r.data;
  }

  Future<Map<String, dynamic>> getAttendanceHistory(String employeeId, {int? month, int? year}) async {
    final r = await _dio.get('/attendance/employee/$employeeId', queryParameters: {
      if (month != null) 'month': month,
      if (year != null) 'year': year,
    });
    return r.data;
  }

  // Leave
  Future<Map<String, dynamic>> getLeaveTypes() async {
    final r = await _dio.get('/leave/types');
    return r.data;
  }

  Future<Map<String, dynamic>> getLeaveBalance(String employeeId, {int? year}) async {
    final r = await _dio.get('/leave/balance/$employeeId', queryParameters: {if (year != null) 'year': year});
    return r.data;
  }

  Future<Map<String, dynamic>> applyLeave(Map<String, dynamic> data) async {
    final r = await _dio.post('/leave/apply', data: data);
    return r.data;
  }

  Future<Map<String, dynamic>> getMyLeaves({String? status, int? year}) async {
    final r = await _dio.get('/leave/my', queryParameters: {
      if (status != null) 'status': status,
      if (year != null) 'year': year,
    });
    return r.data;
  }

  Future<Map<String, dynamic>> getLeaveApplications({String? status}) async {
    final r = await _dio.get('/leave/applications', queryParameters: {if (status != null) 'status': status});
    return r.data;
  }

  Future<void> approveLeave(String id, String status, {String? remarks}) async =>
      _dio.patch('/leave/$id/approve', data: {'status': status, 'remarks': remarks});

  Future<Map<String, dynamic>> getHolidays({int? year}) async {
    final r = await _dio.get('/leave/holidays', queryParameters: {if (year != null) 'year': year});
    return r.data;
  }

  // Payroll
  Future<Map<String, dynamic>> getEmployeePayslips(String employeeId) async {
    final r = await _dio.get('/payroll/employee/$employeeId/payslips');
    return r.data;
  }

  Future<Map<String, dynamic>> getPayslip(String id) async {
    final r = await _dio.get('/payroll/payslip/$id');
    return r.data;
  }

  Future<String> downloadPayslipUrl(String id) async => '$_baseUrl/payroll/payslip/$id/download';

  Future<Map<String, dynamic>> getPayrollDashboard({int? year}) async {
    final r = await _dio.get('/payroll/dashboard', queryParameters: {if (year != null) 'year': year});
    return r.data;
  }

  // Notifications
  Future<Map<String, dynamic>> getNotifications({int page = 1}) async {
    final r = await _dio.get('/notifications', queryParameters: {'page': page});
    return r.data;
  }

  Future<void> markNotificationRead(String id) async => _dio.patch('/notifications/$id/read');
  Future<void> markAllNotificationsRead() async => _dio.patch('/notifications/read-all');

  // Reports
  Future<Map<String, dynamic>> getPayrollReport(int month, int year) async {
    final r = await _dio.get('/reports/payroll-summary', queryParameters: {'month': month, 'year': year});
    return r.data;
  }

  Future<Map<String, dynamic>> getAttendanceReport(int month, int year) async {
    final r = await _dio.get('/reports/attendance-summary', queryParameters: {'month': month, 'year': year});
    return r.data;
  }

  Future<Map<String, dynamic>> getEmployeeAnalytics() async {
    final r = await _dio.get('/reports/employee-analytics');
    return r.data;
  }

  // Departments & Designations
  Future<Map<String, dynamic>> getDepartments() async {
    final r = await _dio.get('/departments');
    return r.data;
  }

  Future<Map<String, dynamic>> getDesignations() async {
    final r = await _dio.get('/designations');
    return r.data;
  }

  // Employees (extended)
  Future<Map<String, dynamic>> getEmployees(Map<String, dynamic> params) async {
    final r = await _dio.get('/employees', queryParameters: params);
    return r.data;
  }

  Future<Map<String, dynamic>> createEmployee(Map<String, dynamic> data) async {
    final r = await _dio.post('/employees', data: data);
    return r.data;
  }

  // Profile
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final r = await _dio.patch('/auth/profile', data: data);
    return r.data;
  }

  // Reports (extended)
  Future<Map<String, dynamic>> getPayrollSummaryReport(int year, int month) async {
    final r = await _dio.get('/reports/payroll-summary', queryParameters: {'year': year, 'month': month});
    return r.data;
  }

  Future<Map<String, dynamic>> getDepartmentSalaryReport() async {
    final r = await _dio.get('/reports/department-salary');
    return r.data;
  }
}

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());
