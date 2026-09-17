import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/social_card.dart';
import '../services/card_store.dart';
import '../services/nearby_service.dart';
import '../services/nfc_service.dart';
import '../theme.dart';
import '../widgets/cards.dart';
import '../widgets/swipe_to_send.dart';
import 'edit_card_screen.dart';
import 'qr_screen.dart';

enum ShareMethod { nfc, nearby, qr }

class CardDetailScreen extends StatefulWidget {
  final SocialCard card;
  const CardDetailScreen({super.key, required this.card});

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> {
  ShareMethod _method = ShareMethod.nfc;
  bool _busy = false;
  String? _note;
  bool _noteIsError = false;

  NfcState _nfcState = NfcState.unknown;
  bool _hceOk = false;

  late SocialCard _card;

  @override
  void initState() {
    super.initState();
    _card = widget.card;
    _checkNfc();
  }

  @override
  void dispose() {
    NfcService.instance.stopHce();
    NfcService.instance.stopSession();
    NearbyService.instance.stop();
    super.dispose();
  }

  Future<void> _checkNfc() async {
    final st = await NfcService.instance.state();
    final hce = await NfcService.instance.hceSupported;
    if (!mounted) return;
    setState(() {
      _nfcState = st;
      _hceOk = hce;
      if (st != NfcState.ready) _method = ShareMethod.qr;
    });
  }

  void _say(String msg, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _note = msg;
      _noteIsError = error;
    });
  }

  // ------------------------------------------------------------- actions --

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      switch (_method) {
        case ShareMethod.nfc:
          await _sendNfc();
          break;
        case ShareMethod.nearby:
          await _sendNearby();
          break;
        case ShareMethod.qr:
          await _showQr();
          break;
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendNfc() async {
    final st = await NfcService.instance.state();
    if (st == NfcState.disabled) {
      _say('NFC is off.', error: true);
      await _offerNfcSettings();
      return;
    }
    if (st != NfcState.ready) {
      _say('NFC is not available on this phone. Use QR instead.', error: true);
      return;
    }
    if (!_hceOk) {
      _say(
          'This phone cannot act as an NFC tag. You can still write your link '
          'to an NFC sticker from the menu.',
          error: true);
      return;
    }

    final res = await NfcService.instance.startHce(_card.url);
    if (!res.ok) {
      _say(res.message, error: true);
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isDismissible: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _NfcReadySheet(card: _card),
    );
    await NfcService.instance.stopHce();
  }

  Future<void> _offerNfcSettings() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Turn on NFC'),
        content: const Text(
            'NexTap needs NFC switched on to share with a tap.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Open settings')),
        ],
      ),
    );
    if (go == true) {
      await NfcService.instance.openNfcSettings();
      await _checkNfc();
    }
  }

  Future<void> _sendNearby() async {
    if (!NearbyService.instance.supported) {
      _say('Nearby sharing works on Android only. Use QR.', error: true);
      return;
    }
    final err = await NearbyService.instance
        .startSending(_card.url, CardStore.instance.ownerName);
    if (err != null) {
      _say(err, error: true);
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _NearbySheet(),
    );
    await NearbyService.instance.stop();
  }

  Future<void> _showQr() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QrScreen(card: _card)),
    );
  }

  Future<void> _writeToTag() async {
    setState(() => _busy = true);
    _say('Hold an NFC sticker against the phone...');
    final res = await NfcService.instance.writeTag(_card.url);
    if (mounted) setState(() => _busy = false);
    _say(res.message, error: !res.ok);
  }

  // ---------------------------------------------------------------- UI ----

  @override
  Widget build(BuildContext context) {
    final p = _card.platform;

    return Scaffold(
      appBar: AppBar(
        title: Text(p.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'copy':
                  await Clipboard.setData(ClipboardData(text: _card.url));
                  _say('Link copied.');
                  break;
                case 'tag':
                  await _writeToTag();
                  break;
                case 'edit':
                  final ok = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          EditCardScreen(platform: p, existing: _card),
                    ),
                  );
                  if (ok == true) {
                    final fresh = CardStore.instance.cards
                        .firstWhere((c) => c.id == _card.id,
                            orElse: () => _card);
                    setState(() => _card = fresh);
                  }
                  break;
                case 'delete':
                  await CardStore.instance.remove(_card.id);
                  if (mounted) Navigator.pop(context);
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'copy', child: Text('Copy link')),
              PopupMenuItem(
                  value: 'tag', child: Text('Write to NFC sticker')),
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          ProfileHeroCard(card: _card),
          const SizedBox(height: 26),
          const Text('Share using',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppTheme.ink)),
          const SizedBox(height: 12),
          Row(
            children: [
              _methodChip(
                method: ShareMethod.nfc,
                icon: Icons.contactless_rounded,
                title: 'NFC',
                subtitle: 'Tap phones',
                enabled: _nfcState == NfcState.ready,
              ),
              const SizedBox(width: 10),
              _methodChip(
                method: ShareMethod.nearby,
                icon: Icons.wifi_tethering_rounded,
                title: 'Nearby',
                subtitle: 'BLE + Wi-Fi',
                enabled: NearbyService.instance.supported,
              ),
              const SizedBox(width: 10),
              _methodChip(
                method: ShareMethod.qr,
                icon: Icons.qr_code_2_rounded,
                title: 'QR',
                subtitle: 'Works always',
                enabled: true,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _explainer(),
          if (_note != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _noteIsError
                    ? const Color(0xFFFFF1F0)
                    : const Color(0xFFF0F7FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: _noteIsError
                        ? const Color(0xFFFFD5D1)
                        : const Color(0xFFD6E6FF)),
              ),
              child: Row(
                children: [
                  Icon(
                    _noteIsError
                        ? Icons.error_outline_rounded
                        : Icons.info_outline_rounded,
                    size: 20,
                    color: _noteIsError
                        ? const Color(0xFFD83A2D)
                        : AppTheme.seed,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(_note!,
                          style: const TextStyle(
                              fontSize: 13.5, height: 1.35))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          SwipeToSend(
            busy: _busy,
            color: p.color,
            label: switch (_method) {
              ShareMethod.nfc => 'Swipe to tap & share',
              ShareMethod.nearby => 'Swipe to find phones',
              ShareMethod.qr => 'Swipe to show QR',
            },
            confirmedLabel: 'Working...',
            onConfirm: _send,
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text('Nothing leaves your phone until you swipe.',
                style: TextStyle(color: AppTheme.sub, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _methodChip({
    required ShareMethod method,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool enabled,
  }) {
    final selected = _method == method;
    final color = _card.platform.color;
    return Expanded(
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              _method = method;
              _note = null;
            });
            if (!enabled) {
              _say(
                  method == ShareMethod.nfc
                      ? 'NFC is not ready on this phone.'
                      : 'Not supported on this platform.',
                  error: true);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: selected ? color.withOpacity(0.10) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? color : AppTheme.line,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(icon,
                    size: 24, color: selected ? color : AppTheme.sub),
                const SizedBox(height: 8),
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: selected ? color : AppTheme.ink)),
                const SizedBox(height: 2),
                Text(subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.sub)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _explainer() {
    final (String title, String body) = switch (_method) {
      ShareMethod.nfc => (
          'Tap to share',
          _hceOk
              ? 'Your phone becomes an NFC tag holding this link. The other '
                  'phone only needs NFC switched on - no app required. Hold '
                  'the backs together.'
              : 'This phone has NFC but cannot emulate a tag. Use QR, or '
                  'write the link to an NFC sticker from the menu.'
        ),
      ShareMethod.nearby => (
          'Nearby share',
          'Uses Bluetooth LE and Wi-Fi Direct - no common Wi-Fi network '
              'needed. The other person must have NexTap open on Receive. '
              'Android only.'
        ),
      ShareMethod.qr => (
          'QR code',
          'Works with any phone camera. They scan, their phone opens the '
              'profile in the installed app.'
        ),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppTheme.ink)),
          const SizedBox(height: 6),
          Text(body,
              style: const TextStyle(
                  color: AppTheme.sub, fontSize: 13.5, height: 1.45)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- sheets ----

class _NfcReadySheet extends StatelessWidget {
  final SocialCard card;
  const _NfcReadySheet({required this.card});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseRing(color: card.platform.color),
          const SizedBox(height: 22),
          const Text('Ready to tap',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Hold the two phones back to back until the other phone reacts. '
            'Your ${card.platform.name} link will open there.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.sub, height: 1.45),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _PulseRing extends StatefulWidget {
  final Color color;
  const _PulseRing({required this.color});

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      height: 130,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              for (final d in [0.0, 0.33, 0.66])
                Builder(builder: (_) {
                  final t = (_c.value + d) % 1.0;
                  return Container(
                    width: 60 + 70 * t,
                    height: 60 + 70 * t,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.color.withOpacity((1 - t) * 0.5),
                        width: 2,
                      ),
                    ),
                  );
                }),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.contactless_rounded,
                    color: Colors.white, size: 28),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NearbySheet extends StatefulWidget {
  const _NearbySheet();

  @override
  State<_NearbySheet> createState() => _NearbySheetState();
}

class _NearbySheetState extends State<_NearbySheet> {
  List<NearbyPeer> _peers = const [];
  String _status = 'Looking for nearby phones...';
  late final StreamSubscription _s1, _s2;

  @override
  void initState() {
    super.initState();
    _s1 = NearbyService.instance.peers.listen((p) {
      if (mounted) setState(() => _peers = p);
    });
    _s2 = NearbyService.instance.status.listen((s) {
      if (mounted) setState(() => _status = s);
    });
  }

  @override
  void dispose() {
    _s1.cancel();
    _s2.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Nearby phones',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(_status,
              style: const TextStyle(color: AppTheme.sub, fontSize: 13)),
          const SizedBox(height: 16),
          if (_peers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'Ask the other person to open NexTap and tap Receive.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.sub, height: 1.4),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _peers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final peer = _peers[i];
                  return Card(
                    color: Colors.white,
                    elevation: 0,
                    margin: EdgeInsets.zero,
                    shape: AppTheme.cardShape,
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFEFF3FF),
                        child: Icon(Icons.smartphone_rounded,
                            color: AppTheme.seed, size: 20),
                      ),
                      title: Text(peer.name,
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.send_rounded, size: 18),
                      onTap: () async {
                        final err = await NearbyService.instance.sendTo(
                            peer, CardStore.instance.ownerName);
                        if (err != null && mounted) {
                          setState(() => _status = err);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
  }
}
