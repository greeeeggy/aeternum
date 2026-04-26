// lib/study_planner/study_planner_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'study_event_model.dart';
import 'study_planner_service.dart';
import 'add_study_event_dialog.dart';

class StudyPlannerPage extends StatefulWidget {
  const StudyPlannerPage({super.key});

  @override
  State<StudyPlannerPage> createState() => _StudyPlannerPageState();
}

class _StudyPlannerPageState extends State<StudyPlannerPage>
    with SingleTickerProviderStateMixin {
  final _service = StudyPlannerService();
  final String? _myUid = FirebaseAuth.instance.currentUser?.uid;

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  
  // Gesture tracking
  int _tapCount = 0;
  String? _lastTappedEventId;
  DateTime _lastTapTime = DateTime.now();

  late AnimationController _fabAnimController;

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  Map<DateTime, List<StudyEvent>> _buildEventMap(List<StudyEvent> events) {
    final map = <DateTime, List<StudyEvent>>{};
    for (final e in events) {
      final key = _normalize(e.date);
      map.putIfAbsent(key, () => []).add(e);
    }
    return map;
  }

  @override
  void initState() {
    super.initState();
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _fabAnimController.dispose();
    super.dispose();
  }

  // ─── Dialogs ───────────────────────────────────────────────────

  Future<void> _showAddDialog([StudyEvent? existing]) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddStudyEventDialog(
        initialDate: _selectedDay,
        existingEvent: existing,
        onSave: (event) async {
          if (existing == null) {
            await _service.addEvent(event);
          } else {
            await _service.updateEvent(event);
          }
        },
      ),
    );
  }

  Future<void> _confirmDelete(StudyEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Event',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Remove "${event.title}"? This cannot be undone.',
          style: GoogleFonts.nunito(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.nunito(color: const Color(0xFF9B8090))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: GoogleFonts.nunito(
                    color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _service.deleteEvent(event);
    }
  }

  void _handleTripleTap(StudyEvent event) {
    if (event.ownerUid != _myUid) return; // Only owner can edit

    final now = DateTime.now();
    if (_lastTappedEventId != event.firestoreId ||
        now.difference(_lastTapTime) > const Duration(milliseconds: 500)) {
      _tapCount = 1;
    } else {
      _tapCount++;
    }
    _lastTappedEventId = event.firestoreId;
    _lastTapTime = now;

    if (_tapCount == 3) {
      _tapCount = 0;
      _showAddDialog(event);
    }
  }

  // ─── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF4F0),
      body: StreamBuilder<List<StudyEvent>>(
        stream: _service.eventsStream(),
        builder: (context, snapshot) {
          final events = snapshot.data ?? [];
          final eventMap = _buildEventMap(events);
          final dayEvents = eventMap[_normalize(_selectedDay)] ?? [];

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Calendar card
                      _buildCalendarCard(eventMap),
                      const SizedBox(height: 18),

                      // Legend
                      _buildLegend(),
                      const SizedBox(height: 22),

                      // Selected day header
                      _buildDayHeader(dayEvents),
                      const SizedBox(height: 12),

                      // Events
                      if (dayEvents.isEmpty)
                        _buildEmptyDay()
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: dayEvents.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) =>
                              _buildEventCard(dayEvents[i]),
                        ),

                      const SizedBox(height: 28),

                      // Upcoming section
                      _buildUpcomingSection(events),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _buildFab(),
    );
  }

  // ─── App Bar ──────────────────────────────────────────────────

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 130.0,
      floating: false,
      pinned: true,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF4A3340), size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEAE0F5), Color(0xFFFAF4F0)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                top: -20,
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFB39DDB).withOpacity(0.22),
                  ),
                ),
              ),
              Positioned(
                left: -20,
                bottom: -40,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFD4849A).withOpacity(0.12),
                  ),
                ),
              ),
            ],
          ),
        ),
        titlePadding: const EdgeInsets.fromLTRB(60, 0, 22, 18),
        centerTitle: false,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Study Planner',
              style: GoogleFonts.playfairDisplay(
                color: const Color(0xFF2A1A1A),
                fontWeight: FontWeight.w700,
                fontSize: 24,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'stay on track, together',
              style: GoogleFonts.nunito(
                color: const Color(0xFF7B6080),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Calendar Card ────────────────────────────────────────────

  Widget _buildCalendarCard(Map<DateTime, List<StudyEvent>> eventMap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C7BB0).withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: TableCalendar<StudyEvent>(
          firstDay: DateTime(2020),
          lastDay: DateTime(2030),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) =>
              isSameDay(day, _selectedDay),
          calendarFormat: CalendarFormat.month,
          availableCalendarFormats: const {CalendarFormat.month: 'Month'},
          eventLoader: (day) => eventMap[_normalize(day)] ?? [],
          startingDayOfWeek: StartingDayOfWeek.sunday,
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onPageChanged: (focusedDay) {
            setState(() => _focusedDay = focusedDay);
          },
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            leftChevronIcon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0E8F4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.chevron_left_rounded,
                  size: 18, color: Color(0xFF7B4FA0)),
            ),
            rightChevronIcon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF0E8F4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.chevron_right_rounded,
                  size: 18, color: Color(0xFF7B4FA0)),
            ),
            headerPadding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
            titleTextStyle: GoogleFonts.playfairDisplay(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2A1A1A),
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
            ),
          ),
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF9B8090),
            ),
            weekendStyle: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFD4849A),
            ),
          ),
          calendarStyle: CalendarStyle(
            outsideDaysVisible: true,
            outsideTextStyle: GoogleFonts.nunito(
              color: const Color(0xFFCCC0C8),
              fontSize: 13,
            ),
            defaultTextStyle: GoogleFonts.nunito(
              color: const Color(0xFF2A1A1A),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            weekendTextStyle: GoogleFonts.nunito(
              color: const Color(0xFFD4849A),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            todayDecoration: BoxDecoration(
              color: const Color(0xFFF0E8F4),
              shape: BoxShape.circle,
            ),
            todayTextStyle: GoogleFonts.nunito(
              color: const Color(0xFF7B4FA0),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
            selectedDecoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFD4849A), Color(0xFFB86A86)],
              ),
              shape: BoxShape.circle,
            ),
            selectedTextStyle: GoogleFonts.nunito(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
            markerDecoration: const BoxDecoration(
              color: Colors.transparent,
            ),
            markersMaxCount: 3,
            markersAlignment: Alignment.bottomCenter,
            cellMargin: const EdgeInsets.all(4),
          ),
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, day, events) {
              final activeEvents =
                  events.where((e) => !(e as StudyEvent).isDone).toList();
              if (activeEvents.isEmpty) return const SizedBox.shrink();

              final uniqueTypes = activeEvents
                  .map((e) => (e as StudyEvent).type)
                  .toSet()
                  .take(3)
                  .toList();
              return Positioned(
                bottom: 2,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: uniqueTypes.map((type) {
                    return Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: type.color,
                        shape: BoxShape.circle,
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ─── Legend ───────────────────────────────────────────────────

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0E8EC)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: StudyEventType.values.map((type) {
          return Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: type.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                type.label,
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF7A6070),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ─── Day header ───────────────────────────────────────────────

  Widget _buildDayHeader(List<StudyEvent> dayEvents) {
    final isToday = isSameDay(_selectedDay, DateTime.now());
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF9C7BB0), Color(0xFFD4849A)],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            isToday
                ? 'Today — ${DateFormat('MMMM d').format(_selectedDay)}'
                : DateFormat('EEEE, MMMM d').format(_selectedDay),
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF4A3340),
              letterSpacing: 0.2,
            ),
          ),
        ),
        if (dayEvents.isNotEmpty)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF0E8F4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${dayEvents.length} event${dayEvents.length == 1 ? '' : 's'}',
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF7B4FA0),
              ),
            ),
          ),
      ],
    );
  }

  // ─── Empty day ────────────────────────────────────────────────

  Widget _buildEmptyDay() {
    final isOwner = _myUid != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0E8EC)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0E8F4),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.event_available_rounded,
                color: Color(0xFF9C7BB0), size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            'No events this day',
            style: GoogleFonts.playfairDisplay(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF4A3340),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isOwner
                ? 'Tap + to add an exam, deadline,\nor mark yourself as busy.'
                : 'Your partner has nothing\nscheduled here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: const Color(0xFF9B8090),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Event card ───────────────────────────────────────────────

  Widget _buildEventCard(StudyEvent event) {
    final isOwner = event.ownerUid == _myUid;

    return GestureDetector(
      onLongPress: (isOwner && !event.isDone) ? () => _confirmDelete(event) : null,
      onTap: (isOwner && !event.isDone) ? () => _handleTripleTap(event) : null,
      child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: event.type.lightColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: event.type.color.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left accent bar
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: event.type.color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Row(
                  children: [
                    // Type icon
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: event.type.lightColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(event.type.icon,
                          color: event.type.color, size: 18),
                    ),
                    const SizedBox(width: 12),

                    // Text
                    Expanded(
                      child: Opacity(
                        opacity: event.isDone ? 0.5 : 1.0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF2A1A1A),
                                decoration: event.isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          if (event.description != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              event.description!,
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                color: const Color(0xFF9B8090),
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: event.type.lightColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  event.type.label,
                                  style: GoogleFonts.nunito(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: event.type.color,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isOwner
                                      ? const Color(0xFFE8F5E9)
                                      : const Color(0xFFF3E8FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isOwner ? 'You' : event.ownerName,
                                  style: GoogleFonts.nunito(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isOwner
                                        ? const Color(0xFF388E3C)
                                        : const Color(0xFF7B4FA0),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      ),
                    ),

                    // Toggle Done Button
                    if (isOwner)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: _buildIconBtn(
                          icon: event.isDone
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: event.isDone
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFF9B8090),
                          bgColor: event.isDone
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFF5F5F5),
                          onTap: () => _service.toggleDone(event),
                        ),
                      ),

                    // Actions — only for owner
                    // (Removed icons: now using long-press to delete, triple-tap to edit)
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildIconBtn({
    required IconData icon,
    required Color color,
    required Color bgColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  // ─── Upcoming section ─────────────────────────────────────────

  Widget _buildUpcomingSection(List<StudyEvent> allEvents) {
    final now = _normalize(DateTime.now());
    final upcoming = allEvents
        .where((e) => !_normalize(e.date).isBefore(now))
        .where((e) => !isSameDay(e.date, _selectedDay))
        .take(5)
        .toList();

    if (upcoming.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF9C7BB0), Color(0xFFD4849A)],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Upcoming',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF4A3340),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...upcoming.map((e) => _buildUpcomingTile(e)),
      ],
    );
  }

  Widget _buildUpcomingTile(StudyEvent event) {
    final isOwner = event.ownerUid == _myUid;
    final daysAway =
        _normalize(event.date).difference(_normalize(DateTime.now())).inDays;
    final dueLabel = daysAway == 0
        ? 'Today'
        : daysAway == 1
            ? 'Tomorrow'
            : 'In $daysAway days';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedDay = event.date;
            _focusedDay = event.date;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFF0E8EC)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: event.type.lightColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(event.type.icon,
                    color: event.type.color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2A1A1A),
                      ),
                    ),
                    Text(
                      '${DateFormat('MMM d').format(event.date)} · ${isOwner ? 'You' : event.ownerName}',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        color: const Color(0xFF9B8090),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: daysAway <= 3
                      ? const Color(0xFFFFF0F0)
                      : const Color(0xFFF0E8F4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  dueLabel,
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: daysAway <= 3
                        ? const Color(0xFFE57373)
                        : const Color(0xFF7B4FA0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── FAB ──────────────────────────────────────────────────────

  Widget _buildFab() {
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: _fabAnimController,
        curve: Curves.elasticOut,
      ),
      child: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(),
        backgroundColor: const Color(0xFF9C7BB0),
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        icon: const Icon(Icons.add_rounded, size: 22),
        label: Text(
          'Add Event',
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
