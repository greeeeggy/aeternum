// lib/screens/features_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'shared_notes_page.dart';
import '../image_gallery_feature/image_gallery_page.dart';
import '../features/music_audio_service.dart';
import '../features/music_player_tile.dart';
import '../class_schedule/class_scheduler.dart';
import '../budget_planner/budget_planner_page.dart';
import '../report_bugs/report_bugs.dart';
import '../study_planner/study_planner_page.dart';
import 'agent_screen.dart';

class FeaturesPage extends StatefulWidget {
  const FeaturesPage({super.key});

  @override
  State<FeaturesPage> createState() => _FeaturesPageState();
}

class _FeaturesPageState extends State<FeaturesPage>
    with TickerProviderStateMixin {
  final MusicAudioService _audioService = MusicAudioService();

  late AnimationController _animController;
  late List<Animation<double>> _cardAnimations;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _cardAnimations = List.generate(8, (i) {
      final start = (i * 0.08).clamp(0.0, 1.0);
      final end = (0.55 + i * 0.08).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _animController,
        curve: Interval(
          start,
          end,
          curve: Curves.easeOutCubic,
        ),
      );
    });
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ─── Navigation methods (logic untouched) ─────────────────────

  void _navigateToSharedNotes(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in.')),
      );
      return;
    }
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = userDoc.data();
      final pairId = data?['pairId'] as String?;
      if (pairId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are not paired with anyone yet.')),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SharedNotesPage(pairId: pairId),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading pair info: $e')),
      );
    }
  }

  void _navigateToImageGallery(BuildContext context) {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const ImageGalleryPage()));
  }

  void _navigateToClassScheduler(BuildContext context) {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const ClassScheduler()));
  }

  void _navigateToBudgetPlanner(BuildContext context) {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const BudgetPlannerPage()));
  }

  void _navigateToReportBugs(BuildContext context) {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const ReportBugsPage()));
  }

  void _navigateToStudyPlanner(BuildContext context) {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const StudyPlannerPage()));
  }

  void _navigateToAgentScreen(BuildContext context) {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const AgentScreen()));
  }

  // ─── Build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF4F0),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App Bar ──────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFF7E0E8), Color(0xFFFAF4F0)],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -30,
                      top: -20,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFEDB8CB).withOpacity(0.28),
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
                          color: const Color(0xFFC9A96E).withOpacity(0.14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              titlePadding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
              centerTitle: false,
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Features',
                    style: GoogleFonts.playfairDisplay(
                      color: const Color(0xFF2A1A1A),
                      fontWeight: FontWeight.w700,
                      fontSize: 26,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'everything you need, together',
                    style: GoogleFonts.nunito(
                      color: const Color(0xFF8B6070),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Music Player — completely untouched
                  MusicPlayerTile(audioService: _audioService),
                  const SizedBox(height: 28),

                  // Section heading
                  _buildSectionHeading(),
                  const SizedBox(height: 16),

                  // 2×2 feature grid
                  _buildFeatureGrid(),
                  const SizedBox(height: 14),

                  // Report Bugs card
                  _buildAnimated(6, _buildReportBugsCard(context)),
                  const SizedBox(height: 32),

                  // Coming soon
                  _buildAnimated(7, _buildComingSoon()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Animation helper ─────────────────────────────────────────────

  Widget _buildAnimated(int index, Widget child) {
    return AnimatedBuilder(
      animation: _cardAnimations[index],
      builder: (context, _) => Opacity(
        opacity: _cardAnimations[index].value,
        child: Transform.translate(
          offset: Offset(0, 28 * (1 - _cardAnimations[index].value)),
          child: child,
        ),
      ),
    );
  }

  // ─── Section heading ──────────────────────────────────────────────

  Widget _buildSectionHeading() {
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
              colors: [Color(0xFFD4849A), Color(0xFFC9A96E)],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Tools & Features',
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF4A3340),
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  // ─── Feature grid ─────────────────────────────────────────────────

  Widget _buildFeatureGrid() {
    final cards = [
      _FeatureCardData(
        icon: Icons.photo_library_rounded,
        label: 'Image Gallery',
        description: 'Share & view\nphotos together',
        iconGradient: [const Color(0xFFE8A0B4), const Color(0xFFD47B96)],
        bgGradient: [const Color(0xFFFDF0F4), const Color(0xFFF8E0E8)],
        onTap: () => _navigateToImageGallery(context),
      ),
      _FeatureCardData(
        icon: Icons.sticky_note_2_rounded,
        label: 'Shared Notes',
        description: 'Write notes with\nyour partner',
        iconGradient: [const Color(0xFF91B4D9), const Color(0xFF6A95C2)],
        bgGradient: [const Color(0xFFF0F5FC), const Color(0xFFE3EEF8)],
        onTap: () => _navigateToSharedNotes(context),
      ),
      _FeatureCardData(
        icon: Icons.school_rounded,
        label: 'Class Schedule',
        description: 'Manage your\nclass timetable',
        iconGradient: [const Color(0xFF82C4A0), const Color(0xFF5BA881)],
        bgGradient: [const Color(0xFFF0F9F4), const Color(0xFFE3F4EB)],
        onTap: () => _navigateToClassScheduler(context),
      ),
      _FeatureCardData(
        icon: Icons.account_balance_wallet_rounded,
        label: 'Budget Planner',
        description: 'Track expenses\n& savings',
        iconGradient: [const Color(0xFFD4AA70), const Color(0xFFBD9050)],
        bgGradient: [const Color(0xFFFBF6EC), const Color(0xFFF5ECDB)],
        onTap: () => _navigateToBudgetPlanner(context),
      ),
      _FeatureCardData(
        icon: Icons.calendar_month_rounded,
        label: 'Study Planner',
        description: 'Exams, deadlines\n& busy blocks',
        iconGradient: [const Color(0xFFAB8CD4), const Color(0xFF7B4FA0)],
        bgGradient: [const Color(0xFFF3EEFA), const Color(0xFFE8DCF5)],
        onTap: () => _navigateToStudyPlanner(context),
      ),
      _FeatureCardData(
        icon: Icons.smart_toy_rounded,
        label: 'Aeternum Agent',
        description: 'Classroom alerts\n& AI assistant',
        iconGradient: [const Color(0xFF9B6FD4), const Color(0xFF5C3494)],
        bgGradient: [const Color(0xFFF0EAF9), const Color(0xFFE4D5F5)],
        onTap: () => _navigateToAgentScreen(context),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.88,
      ),
      itemCount: cards.length,
      itemBuilder: (context, i) =>
          _buildAnimated(i, _buildFeatureCard(cards[i])),
    );
  }

  // ─── Feature card widget ──────────────────────────────────────────

  Widget _buildFeatureCard(_FeatureCardData data) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(22),
        splashColor: data.iconGradient[0].withOpacity(0.18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: data.iconGradient[1].withOpacity(0.17),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
              const BoxShadow(
                color: Colors.white,
                blurRadius: 4,
                offset: Offset(0, -1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gradient header with icon
              Container(
                height: 88,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: data.bgGradient,
                  ),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(22)),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      right: -10,
                      top: -10,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: data.iconGradient[0].withOpacity(0.22),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      bottom: 14,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: data.iconGradient,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: data.iconGradient[1].withOpacity(0.38),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(data.icon, color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                ),
              ),
              // Text section
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.label,
                        style: GoogleFonts.nunito(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF2A1A1A),
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.description,
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF9B8090),
                          height: 1.4,
                        ),
                      ),
                      const Spacer(),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: data.bgGradient[1],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 12,
                            color: data.iconGradient[1],
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
      ),
    );
  }

  // ─── Report Bugs card ─────────────────────────────────────────────

  Widget _buildReportBugsCard(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => _navigateToReportBugs(context),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFF7F7), Color(0xFFFFF0F0)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFD5D5), width: 1),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE57373).withOpacity(0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE57373), Color(0xFFC62828)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFC62828).withOpacity(0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                    Icons.bug_report_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Feedback & Bug Reports',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF2A1A1A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Help us improve the app',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF9B7070),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE5E5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFFE57373), size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Coming soon banner ───────────────────────────────────────────

  Widget _buildComingSoon() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0E8EC), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE8A0B4), Color(0xFFD4849A)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.rocket_launch_rounded,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coming soon',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    color: const Color(0xFF4A3340),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Water Tracker · Memories · More Dates',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF9B8090),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────

class _FeatureCardData {
  final IconData icon;
  final String label;
  final String description;
  final List<Color> iconGradient;
  final List<Color> bgGradient;
  final VoidCallback onTap;

  const _FeatureCardData({
    required this.icon,
    required this.label,
    required this.description,
    required this.iconGradient,
    required this.bgGradient,
    required this.onTap,
  });
}
