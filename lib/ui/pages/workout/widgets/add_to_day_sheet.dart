import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../data/models/workout.dart';
import '../../../../data/providers/fitness_provider.dart';

/// Bottom sheet for "Add to Day". Two tabs:
///   - Dates: multi-select calendar; user taps days to toggle them
///   - Repeat: weekday chips + from/to range; expands client-side into
///             concrete dates before submit
///
/// Unlike the Add-to-Program sheet, this one is batch: pick dates, then
/// press the bottom "Add" button to commit. The mental model is a form,
/// not a list of individual decisions.
void showAddToDaySheet(BuildContext context, Workout workout) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddToDaySheet(workout: workout),
  );
}

class _AddToDaySheet extends StatefulWidget {
  final Workout workout;
  const _AddToDaySheet({required this.workout});

  @override
  State<_AddToDaySheet> createState() => _AddToDaySheetState();
}

class _AddToDaySheetState extends State<_AddToDaySheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Tab 1 — multi-select calendar
  final Set<DateTime> _selectedDates = {};
  DateTime _focusedDay = DateTime.now();

  // Tab 2 — weekly repeat
  final Set<int> _selectedWeekdays = {};  // 1..7 = Mon..Sun
  late DateTime _rangeStart;
  late DateTime _rangeEnd;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final now = DateTime.now();
    _rangeStart = DateTime(now.year, now.month, now.day);
    _rangeEnd = _rangeStart.add(const Duration(days: 56));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Collect the final list of dates from whichever tab is active.
  /// Tab 1: the set of user-tapped dates.
  /// Tab 2: expand weekdays × range into a concrete list of dates.
  List<DateTime> _collectDates() {
    if (_tabController.index == 0) {
      return _selectedDates.toList()..sort();
    }
    if (_selectedWeekdays.isEmpty) return [];
    final result = <DateTime>[];
    var day = _rangeStart;
    while (!day.isAfter(_rangeEnd)) {
      if (_selectedWeekdays.contains(day.weekday)) {
        result.add(day);
      }
      day = day.add(const Duration(days: 1));
    }
    return result;
  }

  Future<void> _submit() async {
    final dates = _collectDates();
    if (dates.isEmpty) return;
    setState(() => _isSubmitting = true);
    try {
      await context
          .read<FitnessProvider>()
          .addWorkoutToDays(widget.workout.id, dates);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              dates.length == 1
                  ? '${widget.workout.name} added to 1 day'
                  : '${widget.workout.name} added to ${dates.length} days',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final collected = _collectDates();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _sheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add to Day',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF6B5FFF),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF6B5FFF),
              tabs: const [
                Tab(text: 'Dates'),
                Tab(text: 'Repeat'),
              ],
              onTap: (_) => setState(() {}),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _datesTab(scrollController),
                  _repeatTab(scrollController),
                ],
              ),
            ),
            _bottomBar(collected),
          ],
        ),
      ),
    );
  }

  Widget _sheetHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _datesTab(ScrollController scrollController) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      child: TableCalendar(
        firstDay: DateTime.now().subtract(const Duration(days: 365)),
        lastDay: DateTime.now().add(const Duration(days: 365)),
        focusedDay: _focusedDay,
        // Multi-select: we handle selection manually. The built-in
        // selection mode is single-select only.
        selectedDayPredicate: (day) =>
            _selectedDates.any((d) => isSameDay(d, day)),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _focusedDay = focusedDay;
            final normalized = DateTime(
                selectedDay.year, selectedDay.month, selectedDay.day);
            if (_selectedDates.any((d) => isSameDay(d, normalized))) {
              _selectedDates.removeWhere((d) => isSameDay(d, normalized));
            } else {
              _selectedDates.add(normalized);
            }
          });
        },
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          selectedDecoration: const BoxDecoration(
            color: Color(0xFF6B5FFF),
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: const Color(0xFF6B5FFF).withAlpha(60),
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(
            color: Color(0xFF6B5FFF),
            fontWeight: FontWeight.w600,
          ),
        ),
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
        ),
      ),
    );
  }

  Widget _repeatTab(ScrollController scrollController) {
    const weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekdays',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: List.generate(7, (index) {
              final weekday = index + 1;
              final isSelected = _selectedWeekdays.contains(weekday);
              return GestureDetector(
                onTap: () => setState(() {
                  if (isSelected) {
                    _selectedWeekdays.remove(weekday);
                  } else {
                    _selectedWeekdays.add(weekday);
                  }
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF6B5FFF)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    weekdayLabels[index],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          const Text(
            'Date range',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _rangeField(
                  label: 'From',
                  date: _rangeStart,
                  onPick: (d) => setState(() => _rangeStart = d),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _rangeField(
                  label: 'To',
                  date: _rangeEnd,
                  onPick: (d) => setState(() => _rangeEnd = d),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rangeField({
    required String label,
    required DateTime date,
    required ValueChanged<DateTime> onPick,
  }) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            const SizedBox(height: 2),
            Text(
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomBar(List<DateTime> collected) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                collected.isEmpty
                    ? 'Select at least one day'
                    : collected.length == 1
                        ? '1 day selected'
                        : '${collected.length} days selected',
                style: TextStyle(
                  fontSize: 13,
                  color: collected.isEmpty
                      ? Colors.grey.shade500
                      : Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed:
                  collected.isEmpty || _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B5FFF),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Add',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
