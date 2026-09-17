import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/social_card.dart';
import '../theme.dart';
import '../widgets/cards.dart';

class QrScreen extends StatelessWidget {
  final SocialCard card;
  const QrScreen({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final p = card.platform;
    final url = card.url;

    return Scaffold(
      appBar: AppBar(title: Text('${p.name} QR')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: AppTheme.line),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Avatar(card: card, size: 42),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                card.label.isEmpty ? p.name : card.label,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15),
                              ),
                              Text(card.handle,
                                  style: const TextStyle(
                                      color: AppTheme.sub, fontSize: 12.5)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      if (url.isEmpty)
                        const Text('This card has no link yet.')
                      else
                        QrImageView(
                          data: url,
                          version: QrVersions.auto,
                          size: 240,
                          gapless: true,
                          eyeStyle: QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: p.color,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: AppTheme.ink,
                          ),
                          errorStateBuilder: (_, __) => const SizedBox(
                            height: 240,
                            child: Center(
                              child: Text('Could not build the QR code.'),
                            ),
                          ),
                        ),
                      const SizedBox(height: 18),
                      Text(
                        url.replaceFirst(RegExp(r'^https?://'), ''),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppTheme.sub, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Ask them to point any camera at this code.',
                  style: TextStyle(color: AppTheme.sub),
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: url));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link copied')),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy link'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
