import 'package:flutter/material.dart';
import 'budget_planner_theme.dart';
import 'joint_savings_service.dart';

class AddJointSavingsScreen extends StatefulWidget {
  final String pairId;

  const AddJointSavingsScreen({super.key, required this.pairId});

  @override
  State<AddJointSavingsScreen> createState() =>
      _AddJointSavingsScreenState();
}

class _AddJointSavingsScreenState extends State<AddJointSavingsScreen> {
  final _service = JointSavingsService();
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _service.createPot(
        widget.pairId,
        _nameCtrl.text.trim(),
        _descCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(BPTheme.snackError('Error: $e'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BPTheme.background,
      appBar: bpAppBar(title: 'New Joint Savings'),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header blurb
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: BPTheme.accentAmber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: BPTheme.accentAmber.withOpacity(0.3)),
                ),
                child: Row(children: [
                  const Text('👫', style: TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Both you and your partner can deposit and withdraw from this shared savings.',
                      style: TextStyle(
                          color: BPTheme.textSecondary,
                          fontSize: 13,
                          height: 1.5),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 28),

              _label('Savings Name'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _nameCtrl,
                style: TextStyle(color: BPTheme.textPrimary),
                decoration: BPTheme.field(
                    'e.g. Trip to Japan, Emergency Fund'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter a name'
                    : null,
              ),
              const SizedBox(height: 24),

              _label('Description (optional)'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descCtrl,
                style: TextStyle(color: BPTheme.textPrimary),
                decoration: BPTheme.field('What is this savings for?'),
                maxLines: 3,
              ),
              const SizedBox(height: 40),

              BPGradientButton(
                label: 'Create Joint Savings',
                gradientColors: BPTheme.gradientSavings,
                onPressed: _isLoading ? null : _save,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: TextStyle(
          color: BPTheme.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      );

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }
}