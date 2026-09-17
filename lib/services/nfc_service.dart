import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';

enum NfcState { ready, disabled, unsupported, unknown }

class NfcResult {
  final bool ok;
  final String message;
  const NfcResult(this.ok, this.message);
}

/// NFC has three very different jobs in this app. Read the README before
/// judging why it is split like this - phone-to-phone NFC is not one API.
///
///  1. HCE  : this phone pretends to be an NFC tag holding a URL.
///            The other phone just needs stock Android NFC ON. No app needed.
///            Android only (implemented in Kotlin, see android/ folder).
///  2. WRITE : burn the URL onto a real NFC sticker/card.
///  3. READ  : receive - read a sticker or another NexTap phone in HCE mode.
class NfcService {
  NfcService._();
  static final NfcService instance = NfcService._();

  static const _hce = MethodChannel('nextap/hce');

  bool _sessionOpen = false;

  Future<NfcState> state() async {
    try {
      if (!(Platform.isAndroid || Platform.isIOS)) return NfcState.unsupported;
      final available = await NfcManager.instance.isAvailable();
      if (available) return NfcState.ready;
      // isAvailable() is false both when there is no chip and when NFC is off.
      // On Android we ask the native side to tell them apart.
      if (Platform.isAndroid) {
        final has = await _hce.invokeMethod<bool>('hasNfcHardware') ?? false;
        return has ? NfcState.disabled : NfcState.unsupported;
      }
      return NfcState.unsupported;
    } catch (e) {
      debugPrint('NfcService.state: $e');
      return NfcState.unknown;
    }
  }

  /// Open Android's NFC settings page so the user can switch it on.
  Future<void> openNfcSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _hce.invokeMethod('openNfcSettings');
    } catch (e) {
      debugPrint('openNfcSettings: $e');
    }
  }

  // ---------------------------------------------------------------- HCE ----

  Future<bool> get hceSupported async {
    if (!Platform.isAndroid) return false;
    try {
      return await _hce.invokeMethod<bool>('isHceSupported') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Start emulating an NDEF tag that contains [url].
  Future<NfcResult> startHce(String url) async {
    if (!Platform.isAndroid) {
      return const NfcResult(
          false, 'iOS does not allow apps to emulate NFC tags. Use QR instead.');
    }
    if (url.isEmpty) return const NfcResult(false, 'Nothing to share.');
    try {
      final ok = await _hce.invokeMethod<bool>('startHce', {'url': url});
      if (ok == true) {
        return const NfcResult(true, 'Hold the phones back to back.');
      }
      return const NfcResult(false, 'This phone cannot emulate NFC tags.');
    } on PlatformException catch (e) {
      return NfcResult(false, e.message ?? 'NFC emulation failed.');
    } catch (e) {
      return NfcResult(false, 'NFC emulation failed: $e');
    }
  }

  Future<void> stopHce() async {
    if (!Platform.isAndroid) return;
    try {
      await _hce.invokeMethod('stopHce');
    } catch (_) {}
  }

  // -------------------------------------------------------------- WRITE ----

  /// Write [url] to a physical NFC tag held against the phone.
  Future<NfcResult> writeTag(String url,
      {Duration timeout = const Duration(seconds: 20)}) async {
    final st = await state();
    if (st != NfcState.ready) return NfcResult(false, _stateMessage(st));

    final done = Completer<NfcResult>();
    try {
      _sessionOpen = true;
      await NfcManager.instance.startSession(
        alertMessage: 'Hold your phone near the NFC tag',
        onDiscovered: (NfcTag tag) async {
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null) {
              await _finish(done, const NfcResult(false, 'Tag is not NDEF.'));
              return;
            }
            if (!ndef.isWritable) {
              await _finish(
                  done, const NfcResult(false, 'This tag is write protected.'));
              return;
            }
            final message = NdefMessage([NdefRecord.createUri(Uri.parse(url))]);
            if (message.byteLength > ndef.maxSize) {
              await _finish(
                  done,
                  NfcResult(false,
                      'Link is too long for this tag (${ndef.maxSize} bytes).'));
              return;
            }
            await ndef.write(message);
            await _finish(done, const NfcResult(true, 'Tag written.'));
          } catch (e) {
            await _finish(done, NfcResult(false, 'Write failed: $e'));
          }
        },
      );
    } catch (e) {
      _sessionOpen = false;
      return NfcResult(false, 'Could not start NFC: $e');
    }

    return done.future.timeout(timeout, onTimeout: () async {
      await stopSession();
      return const NfcResult(false, 'No tag detected. Try again.');
    });
  }

  // --------------------------------------------------------------- READ ----

  /// Read a URL from a tag (or from another phone running HCE).
  Future<NfcResult> readUrl(
      {Duration timeout = const Duration(seconds: 25)}) async {
    final st = await state();
    if (st != NfcState.ready) return NfcResult(false, _stateMessage(st));

    final done = Completer<NfcResult>();
    try {
      _sessionOpen = true;
      await NfcManager.instance.startSession(
        alertMessage: 'Hold the phones together',
        onDiscovered: (NfcTag tag) async {
          try {
            final ndef = Ndef.from(tag);
            final msg = ndef?.cachedMessage ?? await ndef?.read();
            if (msg == null || msg.records.isEmpty) {
              await _finish(done, const NfcResult(false, 'Tag is empty.'));
              return;
            }
            final url = _urlFromRecord(msg.records.first);
            if (url == null) {
              await _finish(
                  done, const NfcResult(false, 'No link found on the tag.'));
              return;
            }
            await _finish(done, NfcResult(true, url));
          } catch (e) {
            await _finish(done, NfcResult(false, 'Read failed: $e'));
          }
        },
      );
    } catch (e) {
      _sessionOpen = false;
      return NfcResult(false, 'Could not start NFC: $e');
    }

    return done.future.timeout(timeout, onTimeout: () async {
      await stopSession();
      return const NfcResult(false, 'Nothing detected. Try again.');
    });
  }

  /// Decode a well known URI record (prefix byte + rest) or a TEXT record.
  String? _urlFromRecord(NdefRecord r) {
    try {
      if (r.typeNameFormat == NdefTypeNameFormat.nfcWellknown &&
          r.type.isNotEmpty) {
        final t = String.fromCharCodes(r.type);
        if (t == 'U') {
          const prefixes = [
            '', 'http://www.', 'https://www.', 'http://', 'https://',
            'tel:', 'mailto:', // 5,6
          ];
          final code = r.payload.first;
          final body = String.fromCharCodes(r.payload.sublist(1));
          final prefix = code < prefixes.length ? prefixes[code] : '';
          return '$prefix$body';
        }
        if (t == 'T') {
          final status = r.payload.first;
          final langLen = status & 0x3F;
          return String.fromCharCodes(r.payload.sublist(1 + langLen));
        }
      }
      return String.fromCharCodes(r.payload);
    } catch (_) {
      return null;
    }
  }

  Future<void> _finish(Completer<NfcResult> c, NfcResult r) async {
    await stopSession();
    if (!c.isCompleted) c.complete(r);
  }

  Future<void> stopSession() async {
    if (!_sessionOpen) return;
    _sessionOpen = false;
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
  }

  String _stateMessage(NfcState s) => switch (s) {
        NfcState.disabled => 'NFC is switched off. Turn it on in settings.',
        NfcState.unsupported => 'This phone has no NFC chip.',
        NfcState.unknown => 'Could not check NFC status.',
        NfcState.ready => 'ok',
      };
}
