import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'budget_planner_theme.dart';
import 'joint_savings_service.dart';
import 'joint_deposit_screen.dart';
import 'transaction_repository.dart';

class JointSavingsDetailScreen extends StatelessWidget {
  final String pairId;
  final JointSavingsPot pot;

  const JointSavingsDetailScreen({
    super.key,
    required this.pairId,
    required this.pot,
  });

  @override
  Widget build(BuildContext context) {
    final service = JointSavingsService();
    final fmt = NumberFormat('#,##0.00');

    return Scaffold(
      backgroundColor: BPTheme.background,
      appBar: bpAppBar(
        title: pot.name,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.white70),
            tooltip: 'Delete savings pot',
            onPressed: () => _confirmDelete(context, service),
          ),
        ],
      ),

      // ── Body uses a StreamBuilder so both partners see live updates ──────
      body: StreamBuilder<List<JointTransaction>>(
        stream: service.savingsTxStream(pairId, pot.id),
        builder: (context, snapshot) {
          final transactions = snapshot.data ?? [];

          double total = 0;
          for (final tx in transactions) {
            total += tx.type == 'deposit' ? tx.amount : -tx.amount;
          }

          return Column(
            children: [
              // ── Balance banner ─────────────────────────────────────────
              _BalanceBanner(pot: pot, total: total, fmt: fmt,
                  txCount: transactions.length),

              // ── Action buttons ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Row(children: [
                  Expanded(
                    child: _ActionBtn(
                      label: 'Deposit',
                      icon: Icons.add_circle_outline_rounded,
                      color: BPTheme.income,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => JointDepositScreen(
                            pairId: pairId,
                            targetId: pot.id,
                            targetName: pot.name,
                            txContext: JointTxContext.savings,
                            initialType: 'deposit',
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionBtn(
                      label: 'Withdraw',
                      icon: Icons.remove_circle_outline_rounded,
                      color: BPTheme.expense,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => JointDepositScreen(
                            pairId: pairId,
                            targetId: pot.id,
                            targetName: pot.name,
                            txContext: JointTxContext.savings,
                            initialType: 'withdraw',
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 20),

              // ── Transactions header ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  Text('All Transactions',
                      style: TextStyle(
                          color: BPTheme.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('${transactions.length} total',
                      style: TextStyle(
                          color: BPTheme.textSecondary, fontSize: 13)),
                ]),
              ),
              const SizedBox(height: 12),

              // ── Transaction list ───────────────────────────────────────
              Expanded(
                child: snapshot.connectionState ==
                            ConnectionState.waiting &&
                        transactions.isEmpty
                    ? Center(
                        child: CircularProgressIndicator(
                            color: BPTheme.accentAmber))
                    : transactions.isEmpty
                        ? _EmptyTransactions()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(
                                16, 0, 16, 100),
                            itemCount: transactions.length,
                            itemBuilder: (ctx, i) =>
                                _TxTile(
                              tx: transactions[i],
                              fmt: fmt,
                              onEdit: () => Navigator.push(
                                ctx,
                                MaterialPageRoute(
                                  builder: (_) => JointDepositScreen(
                                    pairId: pairId,
                                    targetId: pot.id,
                                    targetName: pot.name,
                                    txContext: JointTxContext.savings,
                                    editingTx: transactions[i],
                                  ),
                                ),
                              ),
                              onDelete: () => _confirmDeleteTx(
                                  ctx, service, transactions[i]),
                            ),
                          ),
              ),
            ],
          );
        },
      ),

      floatingActionButton: BPGradientFab(
        icon: Icons.add,
        colors: BPTheme.gradientSavings,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => JointDepositScreen(
              pairId: pairId,
              targetId: pot.id,
              targetName: pot.name,
              txContext: JointTxContext.savings,
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, JointSavingsService service) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BPTheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Delete "${pot.name}"?',
            style: TextStyle(
                color: BPTheme.textPrimary,
                fontWeight: FontWeight.w700)),
        content: Text(
            'All transactions will be deleted. This cannot be undone.',
            style: TextStyle(color: BPTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: BPTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                Text('Delete', style: TextStyle(color: BPTheme.expense)),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await service.deletePot(pairId, pot.id);
      if (context.mounted) Navigator.pop(context);
    }
  }

  void _confirmDeleteTx(BuildContext context,
      JointSavingsService service, JointTransaction tx) async {
    final txId = tx.id;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BPTheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Delete this transaction?',
            style: TextStyle(color: BPTheme.textPrimary)),
        content: Text('This cannot be undone.',
            style: TextStyle(color: BPTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: BPTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                Text('Delete', style: TextStyle(color: BPTheme.expense)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await service.deleteSavingsTransaction(
          pairId: pairId, potId: pot.id, txId: txId);
      // Also delete the mirrored local transaction in SQLite
      await TransactionRepository().deleteByJointTx(
        firestoreTxId: txId,
        jointTargetId: pot.id,
        potName: pot.name,
        amount: tx.amount,
        categoryId: -1,
      );
    }
  }
}

// ─────────────────────────────────────────────
// BALANCE BANNER
// ─────────────────────────────────────────────

class _BalanceBanner extends StatelessWidget {
  final JointSavingsPot pot;
  final double total;
  final NumberFormat fmt;
  final int txCount;

  const _BalanceBanner({
    required this.pot,
    required this.total,
    required this.fmt,
    required this.txCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: BPTheme.gradientSavings,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('👫', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(pot.name,
                  style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          if (pot.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(pot.description,
                style: TextStyle(
                    color: Colors.black.withOpacity(0.55),
                    fontSize: 13)),
          ],
          const SizedBox(height: 16),
          Text(
            '₱${fmt.format(total)}',
            style: const TextStyle(
                color: Colors.black,
                fontSize: 36,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '$txCount transaction${txCount == 1 ? '' : 's'}',
            style: TextStyle(
                color: Colors.black.withOpacity(0.5), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ACTION BUTTON
// ─────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TRANSACTION TILE
// ─────────────────────────────────────────────

class _TxTile extends StatelessWidget {
  final JointTransaction tx;
  final NumberFormat fmt;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TxTile({
    required this.tx,
    required this.fmt,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDeposit = tx.type == 'deposit';
    final color = isDeposit ? BPTheme.income : BPTheme.expense;
    final sign = isDeposit ? '+' : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BPTheme.cardDecoration,
      child: Row(children: [
        // Avatar
        _Avatar(avatarBase64: tx.avatarBase64, photoUrl: tx.photoUrl, name: tx.displayName),
        const SizedBox(width: 12),

        // Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tx.displayName,
                  style: TextStyle(
                      color: BPTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
              const SizedBox(height: 2),
              if (tx.notes != null && tx.notes!.isNotEmpty)
                Text(tx.notes!,
                    style: TextStyle(
                        color: BPTheme.textSecondary, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              Text(
                DateFormat('MMM d, y • h:mm a').format(tx.createdAt),
                style: TextStyle(
                    color: BPTheme.textDisabled, fontSize: 11),
              ),
            ],
          ),
        ),

        // Amount
        Text(
          '$sign₱${fmt.format(tx.amount)}',
          style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 15),
        ),
        const SizedBox(width: 4),

        // Edit / Delete popup menu
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert,
              color: BPTheme.textSecondary, size: 20),
          color: BPTheme.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(children: [
                Icon(Icons.edit_outlined,
                    color: BPTheme.textSecondary, size: 18),
                const SizedBox(width: 8),
                Text('Edit',
                    style:
                        TextStyle(color: BPTheme.textPrimary)),
              ]),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete_outline,
                    color: BPTheme.expense, size: 18),
                const SizedBox(width: 8),
                Text('Delete',
                    style: TextStyle(color: BPTheme.expense)),
              ]),
            ),
          ],
        ),
      ]),
    );
  }


}

// ─────────────────────────────────────────────
// AVATAR WIDGET (reused in tiles)
// ─────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String? avatarBase64;
  final String? photoUrl;
  final String name;
  final double size;

  const _Avatar(
      {required this.avatarBase64,
      this.photoUrl,
      required this.name,
      this.size = 40});

  @override
  Widget build(BuildContext context) {
    if (avatarBase64 != null && avatarBase64!.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: MemoryImage(base64Decode(avatarBase64!)),
      );
    }
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(photoUrl!),
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: BPTheme.accentAmber.withOpacity(0.2),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
            color: BPTheme.accentAmber,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.4),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────

class _EmptyTransactions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 52, color: BPTheme.textDisabled),
          const SizedBox(height: 14),
          Text('No transactions yet',
              style: TextStyle(
                  color: BPTheme.textSecondary, fontSize: 16)),
          const SizedBox(height: 6),
          Text('Tap Deposit or the + button to add the first one',
              style: TextStyle(
                  color: BPTheme.textDisabled, fontSize: 13),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}