// lib/class_schedule/class_scheduler.dart
// MODIFIED: Added background image support (change line 12 and lines in build method)
import 'dart:async';
import 'package:flutter/material.dart';
import 'add_class_dialog.dart';
import 'edit_day_schedule_page.dart';
import 'class_model.dart';
import 'notification_service.dart';
import 'class_schedule_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'class_schedule_sync_service.dart';
import 'schedule_group_model.dart';

class ClassScheduler extends StatefulWidget {
  const ClassScheduler({super.key});

  @override
  State<ClassScheduler> createState() => _ClassSchedulerState();
}

class _ClassSchedulerState extends State<ClassScheduler> {
  final NotificationService _notificationService = NotificationService();
  final ClassScheduleDatabase _database = ClassScheduleDatabase();
  final ClassScheduleSyncService _syncService = ClassScheduleSyncService();
  final TransformationController _transformationController = TransformationController();
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  List<ClassSchedule> _classes = [];
  bool _isLoading = true;

  // ── Tab / Group state ───────────────────────────────────────────────────
  List<ScheduleGroup> _groups = [];
  int _activeGroupIndex = 0; // index into _groups

  String get _myUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  /// Classes filtered to active group
  List<ClassSchedule> get _activeClasses {
    if (_groups.isEmpty) return [];
    final activeGroup = _groups[_activeGroupIndex];
    return _classes
        .where((c) => c.groupId == activeGroup.firestoreId)
        .toList();
  }

  /// Whether the current user owns the active group
  bool get _isActiveGroupOwner {
    if (_groups.isEmpty) return false;
    return _groups[_activeGroupIndex].ownerUid == _myUid;
  }

  // Adjustable column widths (will be loaded from database)
  List<double> _columnWidths = List.filled(7, 150.0);

  // Adjustable row heights for each hour (will be loaded from database)
  Map<int, double> _rowHeights = {};

  // Time settings
  static const int startHour = 7; // Start display at 7 AM
  static const int endHour = 20; // End display at 8 PM
  static const double headerHeight = 50.0;
  static const double timeColumnWidth = 80.0;

  late StreamSubscription<void> _syncSubscription;
  Timer? _syncDebounce;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadUIPreferences();
    _initialLoad();
  }

  @override
  void dispose() {
    _syncDebounce?.cancel();
    _syncSubscription.cancel();
    _syncService.dispose();
    _transformationController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  /// First load: fetch local data immediately (no spinner delay), then sync
  /// from Firestore in the background. The listener handles live updates.
  Future<void> _initialLoad() async {
    // 1. Show local data right away — no loading spinner flicker
    final groups = await _database.getAllGroups();
    final classes = await _database.getAllClasses();
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _classes = classes;
      _isLoading = false;
    });
    // Schedule notifications from local data immediately (works offline)
    await _rescheduleNotifications();

    // 2. Subscribe to sync-done events with debounce so rapid Firestore
    //    changes collapse into a single silent refresh (no spinner).
    _syncSubscription = _syncService.onSyncDone.listen((_) {
      _syncDebounce?.cancel();
      _syncDebounce = Timer(const Duration(milliseconds: 400), () {
        if (mounted) _silentReload();
      });
    });

    // 3. Pull from Firestore once in the background, then start listener.
    await _syncService.syncFromFirestore();
    await _syncService.startListening();
  }

  /// Reload data without showing the loading spinner.
  Future<void> _silentReload() async {
    final groups = await _database.getAllGroups();
    final classes = await _database.getAllClasses();
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _classes = classes;
      if (_activeGroupIndex >= groups.length && groups.isNotEmpty) {
        _activeGroupIndex = groups.length - 1;
      }
    });
    // Re-schedule notifications after every sync so new/deleted classes are reflected
    await _rescheduleNotifications();
  }

  Future<void> _initializeNotifications() async {
    try {
      await _notificationService.initialize();
    } catch (e) {
      // Notifications are optional, so we just log the error
      debugPrint('Failed to initialize notifications: $e');
    }
  }

  /// Schedule notifications for all currently loaded classes.
  /// Called after every load/reload so offline data still triggers scheduling.
  Future<void> _rescheduleNotifications() async {
    try {
      await _notificationService.scheduleAllClassNotifications(_classes);
    } catch (e) {
      debugPrint('Failed to reschedule notifications: $e');
    }
  }

  Future<void> _loadUIPreferences() async {
    try {
      final columnWidths = await _database.loadColumnWidths();
      final rowHeights = await _database.loadRowHeights();

      setState(() {
        _columnWidths = columnWidths;
        _rowHeights = rowHeights;
      });
    } catch (e) {
      debugPrint('Error loading UI preferences: $e');
    }
  }

  Future<void> _saveColumnWidths() async {
    try {
      await _database.saveColumnWidths(_columnWidths);
    } catch (e) {
      debugPrint('Error saving column widths: $e');
    }
  }

  Future<void> _saveRowHeights() async {
    try {
      await _database.saveRowHeights(_rowHeights);
    } catch (e) {
      debugPrint('Error saving row heights: $e');
    }
  }

  // _loadData kept for delete/rename paths that need a forced reload
  Future<void> _loadData() async {
    final groups = await _database.getAllGroups();
    final classes = await _database.getAllClasses();
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _classes = classes;
      if (_activeGroupIndex >= groups.length && groups.isNotEmpty) {
        _activeGroupIndex = groups.length - 1;
      }
    });
  }

  /// Add a new schedule group (tab)
  Future<void> _addGroup() async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => const _NameInputDialog(
        title: 'New Schedule',
        hint: 'e.g. BSIE 2-E',
        confirmLabel: 'Create',
        confirmColor: Colors.green,
      ),
    );

    if (name == null) return;

    // ── Pause the real-time listener so it doesn't fire during our insert ──
    _syncService.pauseListener();

    try {
      final newGroup = ScheduleGroup(name: name, ownerUid: _myUid);
      final localId = await _database.insertGroup(newGroup);
      final firestoreId = await _syncService.pushGroup(newGroup);
      // Write firestoreId back immediately so upsert finds it if sync runs
      if (firestoreId != null) {
        await _database.setGroupFirestoreId(localId, firestoreId);
      }
      final groups = await _database.getAllGroups();
      final classes = await _database.getAllClasses();
      if (mounted) {
        setState(() {
          _groups = groups;
          _classes = classes;
          _activeGroupIndex = groups.length - 1;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating schedule: $e')),
        );
      }
    } finally {
      // ── Resume listener after everything is committed ──
      _syncService.resumeListener();
    }
  }

  /// Long-press tab → bottom sheet with Rename / Delete options
  Future<void> _onTabLongPress(ScheduleGroup group) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                group.displayName,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(color: Colors.grey),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.white70),
              title: const Text('Rename (local only)', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            if (group.ownerUid == _myUid)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Delete schedule', style: TextStyle(color: Colors.redAccent)),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == 'rename') await _renameGroupLocally(group);
    if (action == 'delete') await _deleteGroup(group);
  }

  /// Delete a group locally and from Firestore
  Future<void> _deleteGroup(ScheduleGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Delete Schedule', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete "${group.displayName}" and all its classes? This cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (group.id != null) await _database.deleteGroupById(int.parse(group.id!));
    if (group.firestoreId != null) {
      // Also delete from Firestore so partner's sync removes it too
      await _syncService.deleteGroup(group.firestoreId!);
    }
    setState(() {
      if (_activeGroupIndex > 0) _activeGroupIndex--;
    });
    await _loadData();
  }

  /// Rename a tab locally (only saves localName, not synced)
  Future<void> _renameGroupLocally(ScheduleGroup group) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => _NameInputDialog(
        title: 'Rename Schedule',
        hint: group.displayName,
        initialValue: group.displayName,
        subtitle: 'This rename is only saved on your device.',
        confirmLabel: 'Save',
        confirmColor: Colors.blue,
      ),
    );

    if (newName == null || group.id == null) return;
    await _database.renameGroupLocally(int.parse(group.id!), newName);
    await _loadData();
  }

  Future<void> _addClass() async {
    // Must have an active group that the user owns
    if (_groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a schedule tab first using the + button')),
      );
      return;
    }
    if (!_isActiveGroupOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can't add classes to your partner's schedule")),
      );
      return;
    }

    final activeGroup = _groups[_activeGroupIndex];

    final result = await showDialog<ClassSchedule>(
      context: context,
      builder: (context) => AddClassDialog(
        activeGroupId: activeGroup.firestoreId,
      ),
    );

    if (result != null) {
      final classWithGroup = result.copyWith(
        groupId: activeGroup.firestoreId,
        ownerUid: _myUid,
      );
      try {
        final localId = await _database.insertClass(classWithGroup);
        // Show class immediately — don't wait for Firestore
        setState(() {
          _classes = [..._classes, classWithGroup.copyWith()];
        });
        final firestoreId = await _syncService.pushClass(classWithGroup);
        if (firestoreId != null) {
          await _database.setFirestoreId(localId, firestoreId);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Class added successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error adding class: $e')),
          );
        }
      }
    }
  }

  Future<void> _editClass(ClassSchedule classItem) async {
    // Only owner can edit — non-owners get read-only view
    final readOnly = classItem.ownerUid != null && classItem.ownerUid != _myUid;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditDaySchedulePage(
          dayName: _getDayName(classItem.dayOfWeek),
          dayIndex: classItem.dayOfWeek,
          classes: [classItem],
          isReadOnly: readOnly,
        ),
      ),
    );
    if (result == true) await _loadData();
  }

  String _getDayName(int index) {
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday'
    ];
    return days[index];
  }

  bool _isLunchTime(int hour) {
    return hour == 12;
  }

  String _formatHour(int hour) {
    if (hour == 12) return '12:00 PM\nLUNCH';
    if (hour == 0) return '12:00 AM';
    if (hour < 12) return '$hour:00 AM';
    return '${hour - 12}:00 PM';
  }

  // ========== OVERLAY POSITION CALCULATIONS ==========

  /// Calculate the Y position for a given time
  double _yForTime(TimeOfDay time) {
    double y = headerHeight;

    // Add heights of all hours before this time
    for (int h = startHour; h < time.hour; h++) {
      y += _rowHeights[h] ?? 60.0;
    }

    // Add partial height for minutes within the hour
    y += (_rowHeights[time.hour] ?? 60.0) * (time.minute / 60.0);

    return y;
  }

  /// Calculate the X position for a given day
  double _xForDay(int dayIndex) {
    double x = timeColumnWidth;

    // Add widths of all columns before this day
    for (int i = 0; i < dayIndex; i++) {
      x += _columnWidths[i];
    }

    return x;
  }

  /// Calculate the height of a class block
  double _classHeight(ClassSchedule c) {
    return _yForTime(c.endTime) - _yForTime(c.startTime);
  }

  // ========== GRID BUILDING (DUMB VISUAL LAYER) ==========

  Widget _buildTimeCell(int hour) {
    final isLunch = _isLunchTime(hour);
    final currentHeight = _rowHeights[hour] ?? 60.0;

    return GestureDetector(
      onVerticalDragUpdate: (details) {
        setState(() {
          _rowHeights[hour] =
              (currentHeight + details.delta.dy).clamp(40.0, 150.0);
        });
      },
      onVerticalDragEnd: (_) {
        _saveRowHeights();
      },
      child: Container(
        height: currentHeight,
        width: timeColumnWidth,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[800]!, width: 1),
            right: BorderSide(color: Colors.grey[700]!, width: 2),
          ),
        ),
        child: Stack(
          children: [
            // Background image
            Positioned.fill(
              child: Opacity(
                opacity: 0.5,
                child: Image.asset(
                  'assets/images/class_schedule_background.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: isLunch ? Colors.orange.withOpacity(0.1) : Colors.grey[900],
                    );
                  },
                ),
              ),
            ),
            // Optional lunch overlay
            if (isLunch)
              Positioned.fill(
                child: Container(
                  color: Colors.orange.withOpacity(0.1),
                ),
              ),
            Center(
              child: Text(
                _formatHour(hour),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isLunch ? Colors.orange : Colors.white70,
                  fontSize: 12,
                  fontWeight: isLunch ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            // Resize handle at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 16,
                color: Colors.transparent,
                child: Center(
                  child: Icon(
                    Icons.drag_handle,
                    color: Colors.grey[700],
                    size: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dumb background cell - no class logic
  Widget _buildDayCell(int dayIndex, int hour) {
    final isLunch = _isLunchTime(hour);
    final height = _rowHeights[hour] ?? 60.0;
    final width = _columnWidths[dayIndex];

    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!),
          right: BorderSide(color: Colors.grey[700]!),
        ),
      ),
      child: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Opacity(
              opacity: 0.5,
              child: Image.asset(
                'assets/images/class_schedule_background.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: isLunch
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.grey[900],
                  );
                },
              ),
            ),
          ),
          // Optional lunch overlay
          if (isLunch)
            Positioned.fill(
              child: Container(
                color: Colors.orange.withOpacity(0.1),
              ),
            ),
          // Lunch emoji
          if (isLunch)
            const Center(
              child: Text('🍽️', style: TextStyle(fontSize: 20)),
            ),
        ],
      ),
    );
  }

  /// Build the entire grid (header + time + cells)
  Widget _buildGrid() {
    return Column(
      children: [
        // Header row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time header
            Container(
              height: headerHeight,
              width: timeColumnWidth,
              decoration: BoxDecoration(
                color: Colors.grey[850],
                border: Border(
                  bottom: BorderSide(
                      color: Colors.grey[700]!, width: 2),
                  right: BorderSide(
                      color: Colors.grey[700]!, width: 2),
                ),
              ),
              child: const Center(
                child: Text(
                  'Time',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            // Day headers
            ...List.generate(7, (dayIndex) {
              final dayName = _getDayName(dayIndex);
              final columnWidth = _columnWidths[dayIndex];

              return GestureDetector(
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _columnWidths[dayIndex] =
                        (_columnWidths[dayIndex] +
                            details.delta.dx).clamp(100.0, 300.0);
                  });
                },
                onHorizontalDragEnd: (_) {
                  _saveColumnWidths();
                },
                child: Container(
                  height: headerHeight,
                  width: columnWidth,
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    border: Border(
                      bottom: BorderSide(
                          color: Colors.grey[700]!, width: 2),
                      right: BorderSide(
                          color: Colors.grey[700]!, width: 1),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          dayName.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      // Resize handle
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 20,
                          color: Colors.transparent,
                          child: Center(
                            child: Icon(
                              Icons.drag_handle,
                              color: Colors.grey[600],
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
        // Time rows
        ...List.generate(endHour - startHour, (index) {
          final hour = startHour + index;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time cell
              _buildTimeCell(hour),
              // Day cells (dumb background only)
              ...List.generate(
                  7, (dayIndex) => _buildDayCell(dayIndex, hour)),
            ],
          );
        }),
      ],
    );
  }

  // ========== CLASS OVERLAYS (SMART LAYER) ==========

  /// Build all class overlays as positioned widgets (active group only)
  List<Widget> _buildClassOverlays() {
    return _activeClasses.map((c) {
      final top = _yForTime(c.startTime);
      final left = _xForDay(c.dayOfWeek);
      final height = _classHeight(c);
      final width = _columnWidths[c.dayOfWeek];

      return Positioned(
        top: top,
        left: left,
        width: width,
        height: height,
        child: GestureDetector(
          onTap: () => _editClass(c),
          child: Container(
            decoration: BoxDecoration(
              color: c.color.withOpacity(0.85),
              shape: BoxShape.rectangle,
              border: Border.all(
                color: c.color.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Time (small but crisp)
                    Text(
                      c.getTimeRange(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Subject (visual anchor)
                    Text(
                      c.subjectName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),

                    const SizedBox(height: 3),

                    // Professor (de-emphasized)
                    Text(
                      c.professorName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  // ========== TAB BAR UI ==========

  static const double _tabBarHeight = 80.0;

  // ── Y offset for the schedule-group pill row ──────────────────────────
  static const double _tabBarBottomOffset = 10.0;

  // ── Size of the schedule-group pills — change this only ──────────────
  static const double _pillFontSize = 14.0;       // text size
  static const double _pillIconSize = 16.0;       // icon size
  static const double _pillPaddingH = 20.0;       // left/right padding
  static const double _pillPaddingV = 12.0;       // top/bottom padding

  // ── Y offset for the "Add Class" neumorphic button — change this only ──
  static const double _addClassButtonBottom = 70.0;

  Widget _buildTabBar() {
    return Positioned(
      bottom: _tabBarBottomOffset,
      left: 12,
      right: 12,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Pills (floating, no background container) ──────────
            ..._groups.asMap().entries.map((entry) {
              final idx = entry.key;
              final group = entry.value;
              final isActive = idx == _activeGroupIndex;
              final isOwner = group.ownerUid == _myUid;
              final accentColor =
                  isOwner ? const Color(0xFF4FC3F7) : const Color(0xFFCE93D8);

              return GestureDetector(
                onTap: () => setState(() => _activeGroupIndex = idx),
                onLongPress: () => _onTabLongPress(group),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.only(right: 8),
                  padding: EdgeInsets.symmetric(horizontal: _pillPaddingH, vertical: _pillPaddingV),
                  decoration: BoxDecoration(
                    color: isActive ? accentColor : Colors.grey[850]!.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                      if (isActive)
                        BoxShadow(
                          color: accentColor.withOpacity(0.45),
                          blurRadius: 14,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOwner ? Icons.school_rounded : Icons.favorite_rounded,
                        size: _pillIconSize,
                        color: isActive ? Colors.white : Colors.grey[400],
                      ),
                      const SizedBox(width: 7),
                      Text(
                        group.displayName,
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.grey[400],
                          fontSize: _pillFontSize,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

            // ── Red + button ────────────────────────────────────────
            GestureDetector(
              onTap: _addGroup,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEF5350),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                    BoxShadow(
                      color: const Color(0xFFEF5350).withOpacity(0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== BUILD ==========

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text(
            'Class Scheduler', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active, color: Colors.amber),
            onPressed: () async {
              await _notificationService.sendTestNotification();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Test notification sent! Check your notifications.'),
                    duration: Duration(seconds: 2),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            tooltip: 'Test Notification',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // ========== BACKGROUND IMAGE ==========
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.15,
                    child: Image.asset(
                      'assets/images/class_schedule_background.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(color: Colors.grey[900]);
                      },
                    ),
                  ),
                ),
                // ========== MAIN CONTENT ==========
                Column(
                  children: [
                    // Instructions bar
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.grey[850],
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline, color: Colors.grey[400], size: 16),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Drag headers to resize • Tap class to edit • Long-press tab to rename',
                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Schedule grid
                    Expanded(
                      child: _groups.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.calendar_today,
                                      size: 64, color: Colors.grey[600]),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No schedules yet',
                                    style: TextStyle(
                                        fontSize: 18, color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap the red ➕ button below to create one',
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.grey[700]),
                                  ),
                                ],
                              ),
                            )
                          : InteractiveViewer(
                              transformationController: _transformationController,
                              boundaryMargin: const EdgeInsets.all(double.infinity),
                              minScale: 0.5,
                              maxScale: 3.0,
                              child: SingleChildScrollView(
                                controller: _horizontalScrollController,
                                scrollDirection: Axis.horizontal,
                                child: SingleChildScrollView(
                                  controller: _verticalScrollController,
                                  scrollDirection: Axis.vertical,
                                  child: Stack(
                                    children: [
                                      _buildGrid(),
                                      ..._buildClassOverlays(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
                // ========== FLOATING PILLS (on top of everything) ==========
                _buildTabBar(),
                // ========== ADD CLASS BUTTON (on top of everything) ==========
                Positioned(
                  bottom: _addClassButtonBottom,
                  right: 16,
                  child: _NeumorphicButton(
                    onPressed: _addClass,
                    label: 'Add Class',
                  ),
                ),
              ],
            ),
    );
  }
}

// ============================================================
// _NeumorphicButton  — CSS port of the Uiverse button by FColombati
// ============================================================
class _NeumorphicButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String label;

  const _NeumorphicButton({required this.onPressed, required this.label});

  @override
  State<_NeumorphicButton> createState() => _NeumorphicButtonState();
}

class _NeumorphicButtonState extends State<_NeumorphicButton> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool active = _pressed || _hovered;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Container(
          // .button — outer dark pill
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            color: const Color(0xBF000000), // rgba(0,0,0,0.75)
            boxShadow: [
              BoxShadow(
                color: const Color(0x40050505),
                offset: const Offset(-2.4, -2.4),
                blurRadius: 2.4,
                spreadRadius: -1.2,
              ),
              BoxShadow(
                color: const Color(0x1A050505),
                offset: const Offset(0.6, 0.6),
                blurRadius: 1.08,
              ),
            ],
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            // .button-outer — lift shadow
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              boxShadow: active
                  ? [] // shadow collapses on hover/press
                  : [
                      const BoxShadow(
                        color: Color(0xFF050505),
                        offset: Offset(0, 0.8),
                        blurRadius: 0.8,
                        spreadRadius: -0.16,
                      ),
                      const BoxShadow(
                        color: Color(0x80050505),
                        offset: Offset(0, 0.16),
                        blurRadius: 0.16,
                        spreadRadius: -0.16,
                      ),
                      const BoxShadow(
                        color: Color(0x40050505),
                        offset: Offset(2.4, 4.8),
                        blurRadius: 1.6,
                        spreadRadius: -0.16,
                      ),
                    ],
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              transform: _pressed
                  ? (Matrix4.identity()..scale(0.975))
                  : Matrix4.identity(),
              transformAlignment: Alignment.center,
              // .button-inner — silver gradient surface
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE6E6E6),
                    Color(0xFFB4B4B4),
                  ],
                ),
                boxShadow: active
                    ? [
                        // pressed inset state
                        BoxShadow(
                          color: const Color(0xBF050505),
                          offset: const Offset(1.6, 2.4),
                          blurRadius: 0.8,
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color: const Color(0x80050505),
                          offset: const Offset(-0.4, -0.48),
                          blurRadius: 0.8,
                          spreadRadius: 0.4,
                        ),
                        BoxShadow(
                          color: const Color(0x80050505),
                          offset: const Offset(4.0, 4.0),
                          blurRadius: 3.2,
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color: const Color(0x26FFFFFF),
                          offset: Offset.zero,
                          blurRadius: 0.8,
                          spreadRadius: 8.0,
                        ),
                      ]
                    : [
                        // resting inset highlights
                        BoxShadow(
                          color: const Color(0x1A050505),
                          offset: Offset.zero,
                          blurRadius: 0,
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color: const Color(0x40050505),
                          offset: const Offset(-0.8, -0.8),
                          blurRadius: 0.8,
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color: const Color(0x40FFFFFF),
                          offset: Offset.zero,
                          blurRadius: 0.8,
                          spreadRadius: 3.2,
                        ),
                        BoxShadow(
                          color: Colors.white,
                          offset: const Offset(0.4, 0.8),
                          blurRadius: 1.6,
                          spreadRadius: 0,
                        ),
                        BoxShadow(
                          color: const Color(0x40FFFFFF),
                          offset: const Offset(1.92, 1.92),
                          blurRadius: 1.92,
                        ),
                        BoxShadow(
                          color: const Color(0x40050505),
                          offset: const Offset(-1.2, -4.0),
                          blurRadius: 4.0,
                          spreadRadius: 1.6,
                        ),
                      ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 250),
                scale: active ? 0.975 : 1.0,
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF191919), Color(0xFF4B4B4B)],
                  ).createShader(bounds),
                  blendMode: BlendMode.srcIn,
                  child: Text(
                    widget.label,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.75,
                      color: Colors.white, // masked by ShaderMask
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// _NameInputDialog
// A self-contained StatefulWidget that owns its TextEditingController.
// This avoids the "controller used after disposed" crash that occurs
// when the controller is created in the caller and disposed immediately
// after showDialog returns while the IME dismiss animation is still
// holding a reference through _dependents.
// ============================================================
class _NameInputDialog extends StatefulWidget {
  final String title;
  final String hint;
  final String? initialValue;
  final String? subtitle;
  final String confirmLabel;
  final Color confirmColor;

  const _NameInputDialog({
    required this.title,
    required this.hint,
    this.initialValue,
    this.subtitle,
    required this.confirmLabel,
    required this.confirmColor,
  });

  @override
  State<_NameInputDialog> createState() => _NameInputDialogState();
}

class _NameInputDialogState extends State<_NameInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose(); // safe: widget tree owns and disposes this
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(widget.title, style: const TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.subtitle != null) ...
            [
              Text(
                widget.subtitle!,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              const SizedBox(height: 12),
            ],
          TextField(
            controller: _controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(color: Colors.grey[600]),
              filled: true,
              fillColor: Colors.grey[850],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (v) {
              final trimmed = v.trim();
              if (trimmed.isNotEmpty) Navigator.pop(context, trimmed);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            final v = _controller.text.trim();
            if (v.isNotEmpty) Navigator.pop(context, v);
          },
          style: ElevatedButton.styleFrom(backgroundColor: widget.confirmColor),
          child: Text(
            widget.confirmLabel,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}