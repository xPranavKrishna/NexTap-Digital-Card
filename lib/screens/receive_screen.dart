import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/card_store.dart';
import '../services/nearby_service.dart';
import '../services/nfc_service.dart';
import '../theme.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    NearbyService.instance.stop();
    NfcService.instance.stopSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppTheme.seed,
          unselectedLabelColor: AppTheme.sub,
          indicatorColor: AppTheme.seed,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code_scanner_rounded), text: 'Scan'),
            Tab(icon: Icon(Icons.wifi_tethering_rounded), text: 'Nearby'),
            Tab(icon: Icon(Icons.contactless_rounded), text: 'NFC'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_ScanTab(), _NearbyTab(), _NfcTab()],
      ),
    );
  }
}

// ------------------------------------------------------------ shared ----

Future<void> showReceived(BuildContext context, String raw) async {
  String title = 'Received';
  String url = raw.trim();
  List<Map<String, String>> multi = [];

  // A full NexTap profile arrives as JSON, a single card as a plain URL.
  if (url.startsWith('{')) {
    try {
      final j = jsonDecode(url) as Map<String, dynamic>;
      if (j['app'] == 'nextap') {
        title = (j['name'] as String?)?.isNotEmpty == true
            ? j['name'] as String
            : 'NexTap profile';
        multi = (j['cards'] as List<dynamic>)
            .map((e) => {
                  'p': '${e['p']}',
                  'u': '${e['u']}',
                  'h': '${e['h']}',
                })
            .toList();
        url = '';
      }
    } catch (_) {
      // not our JSON, treat as text
    }
  }

  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (multi.isNotEmpty)
            ...multi.map((m) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(m['p'] ?? ''),
                  subtitle: Text(m['h'] ?? '',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () => _open(ctx, m['u'] ?? ''),
                ))
          else ...[
            Text(url, style: const TextStyle(color: AppTheme.sub)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _open(ctx, url),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open profile'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copy'),
            ),
          ],
        ],
      ),
    ),
  );
}

Future<void> _open(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || url.isEmpty) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Bad link')));
    return;
  }
  try {
    // externalApplication makes Android hand the link to the installed
    // social app (app links) instead of opening a browser tab.
    final ok =
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No app can open this link')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not open: $e')));
    }
  }
}

// --------------------------------------------------------------- scan ----

class _ScanTab extends StatefulWidget {
  const _ScanTab();

  @override
  State<_ScanTab> createState() => _ScanTabState();
}

class _ScanTabState extends State<_ScanTab> {
  final MobileScannerController _c = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool _handled = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(
          controller: _c,
          errorBuilder: (context, error, child) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.no_photography_outlined,
                      size: 40, color: AppTheme.sub),
                  const SizedBox(height: 14),
                  Text(
                    'Camera not available.\n${error.errorCode.name}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.sub),
                  ),
                ],
              ),
            ),
          ),
          onDetect: (capture) async {
            if (_handled) return;
            final value = capture.barcodes
                .map((b) => b.rawValue)
                .firstWhere((v) => v != null && v.isNotEmpty,
                    orElse: () => null);
            if (value == null) return;
            _handled = true;
            await _c.stop();
            if (mounted) await showReceived(context, value);
            _handled = false;
            if (mounted) await _c.start();
          },
        ),
        IgnorePointer(
          child: Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 30,
          child: Center(
            child: Text('Point at a NexTap QR code',
                style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- nearby ----

class _NearbyTab extends StatefulWidget {
  const _NearbyTab();

  @override
  State<_NearbyTab> createState() => _NearbyTabState();
}

class _NearbyTabState extends State<_NearbyTab> {
  String _status = 'Tap start to become visible.';
  bool _on = false;
  StreamSubscription? _sub, _statusSub;

  @override
  void dispose() {
    _sub?.cancel();
    _statusSub?.cancel();
    NearbyService.instance.stop();
    super.dispose();
  }

  Future<void> _start() async {
    if (!NearbyService.instance.supported) {
      setState(() => _status = 'Nearby works on Android only. Use Scan.');
      return;
    }
    final err = await NearbyService.instance
        .startReceiving(CardStore.instance.ownerName);
    if (err != null) {
      setState(() => _status = err);
      return;
    }
    _sub ??= NearbyService.instance.received.listen((data) async {
      if (mounted) await showReceived(context, data);
    });
    _statusSub ??= NearbyService.instance.status.listen((s) {
      if (mounted) setState(() => _status = s);
    });
    setState(() => _on = true);
  }

  Future<void> _stop() async {
    await NearbyService.instance.stop();
    if (mounted) {
      setState(() {
        _on = false;
        _status = 'Stopped.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_tethering_rounded,
              size: 56, color: _on ? AppTheme.seed : AppTheme.sub),
          const SizedBox(height: 18),
          Text(_on ? 'Visible to nearby phones' : 'Not visible',
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(_status,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.sub, height: 1.4)),
          const SizedBox(height: 26),
          FilledButton(
            onPressed: _on ? _stop : _start,
            child: Text(_on ? 'Stop' : 'Start receiving'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- nfc ----

class _NfcTab extends StatefulWidget {
  const _NfcTab();

  @override
  State<_NfcTab> createState() => _NfcTabState();
}

class _NfcTabState extends State<_NfcTab> {
  String _status = 'Tap read, then hold the phones together.';
  bool _busy = false;

  Future<void> _read() async {
    setState(() {
      _busy = true;
      _status = 'Waiting for a tag or a phone...';
    });
    final res = await NfcService.instance.readUrl();
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.ok) {
      setState(() => _status = 'Got it.');
      await showReceived(context, res.message);
    } else {
      setState(() => _status = res.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.contactless_rounded,
              size: 56, color: AppTheme.seed),
          const SizedBox(height: 18),
          const Text('Read an NFC tag',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(_status,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.sub, height: 1.4)),
          const SizedBox(height: 26),
          FilledButton(
            onPressed: _busy ? null : _read,
            child: Text(_busy ? 'Scanning...' : 'Read'),
          ),
          const SizedBox(height: 14),
          const Text(
            'Most Android phones already open NexTap links automatically '
            'when NFC is on, so you usually do not need this tab.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.sub, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}
