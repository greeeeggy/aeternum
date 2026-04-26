import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'budget_planner_theme.dart';
import 'joint_savings_service.dart';
import 'transaction.dart' as bp_transaction;
import 'transaction_repository.dart';

/// Whether this deposit/withdraw is for a savings pot or a goal.
enum JointTxContext { savings, goal }

class JointDepositScreen extends StatefulWidget {
  final String pairId;
  final String targetId; // potId or goalId
  final String targetName; // pot name or goal name — stored in local transaction
  final JointTxContext txContext;
  final String initialType; // 'deposit' | 'withdraw'
  final JointTransaction? editingTx; // non-null = edit mode

  const JointDepositScreen({
    super.key,
    required this.pairId,
    required this.targetId,
    required this.targetName,
    required this.txContext,
    this.initialType = 'deposit',
    this.editingTx,
  });

  @override
  State<JointDepositScreen> createState() => _JointDepositScreenState();
}

class _JointDepositScreenState extends State<JointDepositScreen> {
  final _service = JointSavingsService();
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  late String _type;
  bool _isLoading = false;

  bool get _isEditing => widget.editingTx != null;

  @override
  void initState() {
    super.initState();
    _type = widget.editingTx?.type ?? widget.initialType;
    if (_isEditing) {
      _amountCtrl.text = widget.editingTx!.amount.toStringAsFixed(0);
      _notesCtrl.text = widget.editingTx!.notes ?? '';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final amount =
          double.parse(_amountCtrl.text.replaceAll(',', ''));
      final notes = _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim();

      if (_isEditing) {
        // Edit — preserve original displayName/avatar snapshot
        if (widget.txContext == JointTxContext.savings) {
          await _service.editSavingsTransaction(
            pairId: widget.pairId,
            potId: widget.targetId,
            txId: widget.editingTx!.id,
            amount: amount,
            type: _type,
            notes: notes,
          );
        } else {
          await _service.editGoalTransaction(
            pairId: widget.pairId,
            goalId: widget.targetId,
            txId: widget.editingTx!.id,
            amount: amount,
            type: _type,
            notes: notes,
          );
        }
      } else {
        // New — snapshot current user info into the transaction
        final info = await _service.getCurrentUserInfo();
        String firestoreTxId;
        if (widget.txContext == JointTxContext.savings) {
          firestoreTxId = await _service.addSavingsTransaction(
            pairId: widget.pairId,
            potId: widget.targetId,
            amount: amount,
            type: _type,
            displayName: info['displayName'] ?? 'Unknown',
            avatarBase64: info['avatarBase64'],
            photoUrl: info['photoUrl'],
            notes: notes,
          );
        } else {
          firestoreTxId = await _service.addGoalTransaction(
            pairId: widget.pairId,
            goalId: widget.targetId,
            amount: amount,
            type: _type,
            displayName: info['displayName'] ?? 'Unknown',
            avatarBase64: info['avatarBase64'],
            photoUrl: info['photoUrl'],
            notes: notes,
          );
        }
        // Reflect the contribution in the local balance:
        // deposit → savings (money is being saved/contributed)
        // withdraw → income (money returns to your wallet)
        final localType = _type == 'deposit' ? 'savings' : 'income';
        // categoryId encodes joint type: -1 = joint savings, -2 = joint goal
        // (never conflicts with real categories; tile uses this to show the right label)
        final jointCategoryId =
            widget.txContext == JointTxContext.savings ? -1 : -2;
        final localTx = bp_transaction.Transaction(
          name: widget.targetName, // pot/goal name shown as tile title
          amount: amount,
          type: localType,
          categoryId: jointCategoryId,
          date: DateTime.now(),
          notes: notes,
          // Firestore back-link — used to sync edits/deletes from transactions screen
          jointPairId: widget.pairId,
          jointTargetId: widget.targetId,
          jointFirestoreTxId: firestoreTxId,
        );
        await TransactionRepository().insert(localTx);
      }

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
    final isDeposit = _type == 'deposit';
    final accentColor = isDeposit ? BPTheme.income : BPTheme.expense;

    return Scaffold(
      backgroundColor: BPTheme.background,
      appBar: bpAppBar(
          title: _isEditing ? 'Edit Transaction' : 'New Transaction'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Type toggle ────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: BPTheme.surfaceEl,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: BPTheme.divider),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _typeBtn('deposit', '💰  Deposit', BPTheme.income),
                    _typeBtn('withdraw', '💸  Withdraw', BPTheme.expense),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── QR — only on fresh deposits ────────────────────────────
              if (!_isEditing && isDeposit) ...[
                Text('Scan to Pay',
                    style: TextStyle(
                        color: BPTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: BPTheme.divider),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/gcash_hannah.jpg',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Padding(
                        padding: const EdgeInsets.all(40),
                        child: Icon(Icons.qr_code,
                            size: 80, color: BPTheme.textDisabled),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Partner scans this to send real money via GoTyme',
                    style: TextStyle(
                        color: BPTheme.textSecondary, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 28),
              ],

              // ── Amount ────────────────────────────────────────────────
              Text('Amount',
                  style: TextStyle(
                      color: BPTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d,.]'))
                ],
                style: TextStyle(
                    color: BPTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
                decoration: BPTheme.field('0.00', prefix: '₱ '),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter an amount';
                  final n =
                      double.tryParse(v.replaceAll(',', ''));
                  if (n == null || n <= 0) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // ── Notes ──────────────────────────────────────────────────
              Text('Notes (optional)',
                  style: TextStyle(
                      color: BPTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              TextFormField(
                controller: _notesCtrl,
                style: TextStyle(color: BPTheme.textPrimary),
                decoration: BPTheme.field('e.g. For our trip fund...'),
                maxLines: 3,
              ),
              const SizedBox(height: 40),

              BPGradientButton(
                label: _isEditing
                    ? 'Save Changes'
                    : isDeposit
                        ? 'Confirm Deposit'
                        : 'Confirm Withdrawal',
                gradientColors: isDeposit
                    ? [BPTheme.income, BPTheme.accent]
                    : [BPTheme.expense, const Color(0xFFB91C1C)],
                onPressed: _isLoading ? null : _submit,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeBtn(String value, String label, Color color) {
    final sel = _type == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: sel ? color.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: sel ? color : Colors.transparent, width: 2),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: sel ? color : BPTheme.textSecondary,
                fontWeight:
                    sel ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }
}