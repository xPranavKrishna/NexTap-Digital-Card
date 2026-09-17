import 'package:flutter/material.dart';

import '../models/social_card.dart';
import '../services/card_store.dart';
import '../theme.dart';
import 'edit_card_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AddCardScreen extends StatefulWidget {
  const AddCardScreen({super.key});

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final list = kPlatforms
        .where((p) => p.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Add an ID')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search platform',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.95,
              ),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final p = list[i];
                final already = CardStore.instance.hasPlatform(p.id);
                return Card(
                  color: Colors.white,
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: AppTheme.cardShape,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () async {
                      final added = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                            builder: (_) => EditCardScreen(platform: p)),
                      );
                      if (added == true && context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: p.color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child:
                                    FaIcon(p.icon, color: p.color, size: 24),
                              ),
                              const SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6),
                                child: Text(
                                  p.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.ink),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (already)
                          const Positioned(
                            top: 8,
                            right: 8,
                            child: Icon(Icons.check_circle_rounded,
                                size: 16, color: Color(0xFF00B894)),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
