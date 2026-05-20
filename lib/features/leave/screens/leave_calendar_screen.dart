import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/api_service.dart';

class LeaveCalendarScreen extends ConsumerStatefulWidget {
  const LeaveCalendarScreen({super.key});
  @override ConsumerState<LeaveCalendarScreen> createState() => _State();
}
class _State extends ConsumerState<LeaveCalendarScreen> {
  DateTime _focused = DateTime.now();
  List<dynamic> _holidays = [];

  @override void initState() { super.initState(); _loadHolidays(); }

  Future<void> _loadHolidays() async {
    try {
      final data = await ref.read(apiServiceProvider).getHolidays(year: _focused.year);
      setState(() => _holidays = data['holidays'] as List? ?? []);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Holiday Calendar')),
      body: Column(children: [
        TableCalendar(
          firstDay: DateTime(2024, 1, 1), lastDay: DateTime(2026, 12, 31), focusedDay: _focused,
          calendarStyle: const CalendarStyle(
            todayDecoration: BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
            selectedDecoration: BoxDecoration(color: AppTheme.secondary, shape: BoxShape.circle),
          ),
          headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
          onPageChanged: (f) { setState(() => _focused = f); _loadHolidays(); },
          onDaySelected: (s, f) => setState(() => _focused = f),
          calendarBuilders: CalendarBuilders(
            markerBuilder: (ctx, day, _) {
              final isHoliday = _holidays.any((h) {
                final hd = DateTime.parse(h['date']);
                return hd.year == day.year && hd.month == day.month && hd.day == day.day;
              });
              if (isHoliday) return Positioned(bottom: 4, child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle)));
              return null;
            },
          ),
        ),
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _holidays.length,
          itemBuilder: (_, i) {
            final h = _holidays[i] as Map;
            return ListTile(
              leading: const Icon(Icons.celebration, color: AppTheme.error),
              title: Text(h['name'] ?? ''),
              subtitle: Text(h['date'] ?? ''),
              trailing: h['is_optional'] == true ? const Chip(label: Text('Optional', style: TextStyle(fontSize: 10))) : null,
            );
          },
        )),
      ]),
    );
  }
}
