// lib/features/report_bugs.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path_helper;

class BugReportDatabase {
  static final BugReportDatabase instance = BugReportDatabase._init();
  static Database? _database;

  BugReportDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('bug_reports.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = path_helper.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE bug_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        severity TEXT NOT NULL,
        category TEXT NOT NULL,
        status TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        syncedToFirebase INTEGER NOT NULL DEFAULT 0,
        firebaseId TEXT
      )
    ''');
  }

  Future<int> insertBugReport(Map<String, dynamic> report) async {
    final db = await instance.database;
    return await db.insert('bug_reports', report);
  }

  Future<List<Map<String, dynamic>>> getAllBugReports() async {
    final db = await instance.database;
    return await db.query('bug_reports', orderBy: 'createdAt DESC');
  }

  Future<int> updateSyncStatus(int id, String firebaseId) async {
    final db = await instance.database;
    return await db.update(
      'bug_reports',
      {'syncedToFirebase': 1, 'firebaseId': firebaseId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateReportStatus(String firebaseId, String status) async {
    final db = await instance.database;
    return await db.update(
      'bug_reports',
      {'status': status},
      where: 'firebaseId = ?',
      whereArgs: [firebaseId],
    );
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}

class ReportBugsPage extends StatefulWidget {
  const ReportBugsPage({super.key});

  @override
  State<ReportBugsPage> createState() => _ReportBugsPageState();
}

class _ReportBugsPageState extends State<ReportBugsPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedSeverity = 'Medium';
  String _selectedCategory = 'General';
  bool _isSubmitting = false;

  final List<String> _severityLevels = ['Low', 'Medium', 'High', 'Critical'];
  final List<String> _categories = [
    'General',
    'Music Player',
    'Image Gallery',
    'Shared Notes',
    'Class Scheduler',
    'Budget Planner',
    'Authentication',
    'UI/Design',
    'Performance',
    'Other'
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitBugReport() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title for the bug')),
      );
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a description')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final now = DateTime.now().toIso8601String();

      // Save to local SQLite database first
      final localReport = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'severity': _selectedSeverity,
        'category': _selectedCategory,
        'status': 'Open',
        'createdAt': now,
        'syncedToFirebase': 0,
      };

      final localId = await BugReportDatabase.instance.insertBugReport(localReport);

      // Try to sync to Firebase
      try {
        final docRef = await FirebaseFirestore.instance.collection('bug_reports').add({
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'severity': _selectedSeverity,
          'category': _selectedCategory,
          'userId': user.uid,
          'userEmail': user.email,
          'status': 'Open',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Update local database with Firebase ID
        await BugReportDatabase.instance.updateSyncStatus(localId, docRef.id);
      } catch (e) {
        // Firebase sync failed, but local save succeeded
        debugPrint('Firebase sync failed: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bug report submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear form
        _titleController.clear();
        _descriptionController.clear();
        setState(() {
          _selectedSeverity = 'Medium';
          _selectedCategory = 'General';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting report: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Feedbacks or Report Bugs', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bug_report, color: Colors.red, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Help Us Improve',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Offer Feedbacks or Report any issues and bugs you encounter',
                          style: TextStyle(color: Colors.grey[400], fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Bug Title
            Text(
              'Bug Title',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Brief summary of the issue',
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: Colors.grey[850],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 20),

            // Category Dropdown
            Text(
              'Category',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  dropdownColor: Colors.grey[850],
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Severity Dropdown
            Text(
              'Severity',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedSeverity,
                  isExpanded: true,
                  dropdownColor: Colors.grey[850],
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                  items: _severityLevels.map((severity) {
                    Color severityColor;
                    switch (severity) {
                      case 'Low':
                        severityColor = Colors.green;
                        break;
                      case 'Medium':
                        severityColor = Colors.orange;
                        break;
                      case 'High':
                        severityColor = Colors.deepOrange;
                        break;
                      case 'Critical':
                        severityColor = Colors.red;
                        break;
                      default:
                        severityColor = Colors.grey;
                    }
                    return DropdownMenuItem(
                      value: severity,
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: severityColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(severity),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedSeverity = value;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Description
            Text(
              'Description',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              style: const TextStyle(color: Colors.white),
              maxLines: 8,
              decoration: InputDecoration(
                hintText: 'Describe the feedback/bug in detail:\n• What happened?\n• What did you expect to happen?\n• Steps to reproduce?',
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: Colors.grey[850],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitBugReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey[700],
                ),
                child: _isSubmitting
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Text(
                  'Submit Feedback/Bug Report',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // View My Reports Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MyBugReportsPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.history, color: Colors.white70),
                label: const Text(
                  'View My Reports',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(color: Colors.grey[700]!),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Page to view user's submitted bug reports
class MyBugReportsPage extends StatefulWidget {
  const MyBugReportsPage({super.key});

  @override
  State<MyBugReportsPage> createState() => _MyBugReportsPageState();
}

class _MyBugReportsPageState extends State<MyBugReportsPage> {
  List<Map<String, dynamic>> _localReports = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLocalReports();
  }

  Future<void> _loadLocalReports() async {
    final reports = await BugReportDatabase.instance.getAllBugReports();
    setState(() {
      _localReports = reports;
      _isLoading = false;
    });
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'Low':
        return Colors.green;
      case 'Medium':
        return Colors.orange;
      case 'High':
        return Colors.deepOrange;
      case 'Critical':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Open':
        return Colors.blue;
      case 'In Progress':
        return Colors.orange;
      case 'Resolved':
        return Colors.green;
      case 'Closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('My Bug Reports', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _localReports.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bug_report_outlined,
                size: 64, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              'No bug reports yet',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _localReports.length,
        itemBuilder: (context, index) {
          final report = _localReports[index];
          final createdAt = DateTime.tryParse(report['createdAt'] ?? '');
          final dateStr = createdAt != null
              ? DateFormat('MMM dd, yyyy • hh:mm a').format(createdAt)
              : 'Unknown date';
          final isSynced = report['syncedToFirebase'] == 1;

          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BugReportDetailPage(report: report),
                ),
              ).then((_) => _loadLocalReports());
            },
            child: Card(
              color: Colors.grey[850],
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            report['title'] ?? 'Untitled',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                                report['status'] ?? 'Open')
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getStatusColor(
                                  report['status'] ?? 'Open'),
                            ),
                          ),
                          child: Text(
                            report['status'] ?? 'Open',
                            style: TextStyle(
                              color: _getStatusColor(
                                  report['status'] ?? 'Open'),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _getSeverityColor(
                                report['severity'] ?? 'Medium'),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          report['severity'] ?? 'Medium',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.category,
                            size: 16, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          report['category'] ?? 'General',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        if (!isSynced)
                          Tooltip(
                            message: 'Not synced to cloud',
                            child: Icon(
                              Icons.cloud_off,
                              size: 16,
                              color: Colors.orange[300],
                            ),
                          ),
                        if (isSynced)
                          Tooltip(
                            message: 'Synced to cloud',
                            child: Icon(
                              Icons.cloud_done,
                              size: 16,
                              color: Colors.green[300],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      report['description'] ?? '',
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 14,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      dateStr,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Page to view and update individual bug report details
class BugReportDetailPage extends StatefulWidget {
  final Map<String, dynamic> report;

  const BugReportDetailPage({super.key, required this.report});

  @override
  State<BugReportDetailPage> createState() => _BugReportDetailPageState();
}

class _BugReportDetailPageState extends State<BugReportDetailPage> {
  late String _currentStatus;
  bool _isUpdating = false;

  final List<String> _statusOptions = ['Open', 'In Progress', 'Resolved', 'Closed'];

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.report['status'] ?? 'Open';
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'Low':
        return Colors.green;
      case 'Medium':
        return Colors.orange;
      case 'High':
        return Colors.deepOrange;
      case 'Critical':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Open':
        return Colors.blue;
      case 'In Progress':
        return Colors.orange;
      case 'Resolved':
        return Colors.green;
      case 'Closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() {
      _isUpdating = true;
    });

    try {
      // Update local database
      final firebaseId = widget.report['firebaseId'];
      if (firebaseId != null && firebaseId.isNotEmpty) {
        await BugReportDatabase.instance.updateReportStatus(firebaseId, newStatus);

        // Try to update Firebase as well
        try {
          await FirebaseFirestore.instance
              .collection('bug_reports')
              .doc(firebaseId)
              .update({'status': newStatus});
        } catch (e) {
          debugPrint('Firebase update failed: $e');
        }
      } else {
        // If no Firebase ID, update by local ID
        final db = await BugReportDatabase.instance.database;
        await db.update(
          'bug_reports',
          {'status': newStatus},
          where: 'id = ?',
          whereArgs: [widget.report['id']],
        );
      }

      if (mounted) {
        setState(() {
          _currentStatus = newStatus;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to $newStatus'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = DateTime.tryParse(widget.report['createdAt'] ?? '');
    final dateStr = createdAt != null
        ? DateFormat('MMMM dd, yyyy • hh:mm a').format(createdAt)
        : 'Unknown date';
    final isSynced = widget.report['syncedToFirebase'] == 1;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Bug Report Details', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Card
            Card(
              color: Colors.grey[850],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bug_report, color: Colors.red, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.report['title'] ?? 'Untitled',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: Colors.grey[500]),
                        const SizedBox(width: 8),
                        Text(
                          dateStr,
                          style: TextStyle(color: Colors.grey[400], fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (isSynced)
                          Row(
                            children: [
                              Icon(Icons.cloud_done, size: 16, color: Colors.green[300]),
                              const SizedBox(width: 4),
                              Text(
                                'Synced',
                                style: TextStyle(color: Colors.green[300], fontSize: 14),
                              ),
                            ],
                          ),
                        if (!isSynced)
                          Row(
                            children: [
                              Icon(Icons.cloud_off, size: 16, color: Colors.orange[300]),
                              const SizedBox(width: 4),
                              Text(
                                'Not synced',
                                style: TextStyle(color: Colors.orange[300], fontSize: 14),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Status Update Section
            Card(
              color: Colors.grey[850],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status',
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _currentStatus,
                          isExpanded: true,
                          dropdownColor: Colors.grey[800],
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          icon: _isUpdating
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                              : const Icon(Icons.arrow_drop_down, color: Colors.white70),
                          items: _statusOptions.map((status) {
                            return DropdownMenuItem(
                              value: status,
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(status),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: _isUpdating
                              ? null
                              : (value) {
                            if (value != null && value != _currentStatus) {
                              _updateStatus(value);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Details Card
            Card(
              color: Colors.grey[850],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Details',
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Category',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.category, size: 16, color: Colors.grey[400]),
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.report['category'] ?? 'General',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Severity',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: _getSeverityColor(
                                          widget.report['severity'] ?? 'Medium'),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.report['severity'] ?? 'Medium',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Description Card
            Card(
              color: Colors.grey[850],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Description',
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(
                        minHeight: 200,
                      ),
                      child: Text(
                        widget.report['description'] ?? 'No description provided',
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}