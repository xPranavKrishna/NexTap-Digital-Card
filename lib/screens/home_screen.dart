import 'package:flutter/material.dart';

import '../models/social_card.dart';
import '../services/card_store.dart';
import '../theme.dart';
import '../widgets/cards.dart';
import 'add_card_screen.dart';
import 'card_detail_screen.dart';
import 'receive_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = CardStore.instance;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final cards = store.cards;
        return Scaffold(
          appBar: AppBar(
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NexTap'),
                Text('Your identity, one tap away',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.sub,
                        fontWeight: FontWeight.w400)),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Receive',
                icon: const Icon(Icons.download_rounded),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReceiveScreen()),
                ),
              ),
              IconButton(
                tooltip: 'Your name',
                icon: const Icon(Icons.person_outline_rounded),
                onPressed: () => _editName(context),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: cards.isEmpty
              ? _empty(context)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: cards.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    if (i == cards.length) return _addTile(context);
                    final card = cards[i];
                    return Dismissible(
                      key: ValueKey(card.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(Icons.delete_outline_rounded,
                            color: Colors.red.shade400),
                      ),
                      confirmDismiss: (_) => _confirmDelete(context, card),
                      onDismissed: (_) => store.remove(card.id),
                      child: CardTile(
                        card: card,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => CardDetailScreen(card: card)),
                        ),
                      ),
                    );
                  },
                ),
          floatingActionButton: cards.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _openAdd(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add ID'),
                ),
        );
      },
    );
  }

  Widget _addTile(BuildContext context) => Card(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: AppTheme.cardShape,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openAdd(context),
          child: const Padding(
            padding: EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(Icons.add_circle_outline_rounded, color: AppTheme.seed),
                SizedBox(width: 12),
                Text('Add another ID',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: AppTheme.seed)),
              ],
            ),
          ),
        ),
      );

  Widget _empty(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: AppTheme.seed.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.contactless_rounded,
                    size: 44, color: AppTheme.seed),
              ),
              const SizedBox(height: 22),
              const Text('No IDs yet',
                  style:
                      TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text(
                'Add your social profiles once, then share them with a tap, '
                'a swipe or a QR code.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.sub, height: 1.45),
              ),
              const SizedBox(height: 26),
              FilledButton.icon(
                onPressed: () => _openAdd(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add your first ID'),
              ),
            ],
          ),
        ),
      );

  void _openAdd(BuildContext context) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddCardScreen()),
      );

  Future<bool> _confirmDelete(BuildContext context, SocialCard card) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove card?'),
        content: Text('${card.platform.name} - ${card.handle}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove')),
        ],
      ),
    );
    return res ?? false;
  }

  Future<void> _editName(BuildContext context) async {
    final controller =
        TextEditingController(text: CardStore.instance.ownerName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Shown to the receiver'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Save')),
        ],
      ),
    );
    if (name != null) await CardStore.instance.setOwnerName(name);
  }
}
