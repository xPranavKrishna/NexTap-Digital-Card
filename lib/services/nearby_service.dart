import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:location/location.dart';
/// Offline phone-to-phone transfer over BLE + Wi-Fi Direct.
///
/// This uses Google Nearby Connections (P2P_POINT_TO_POINT). It does NOT need
/// both phones on the same Wi-Fi network - it brings up its own link. Both
/// phones DO need NexTap installed, because raw BLE/Wi-Fi Direct has no
/// "system default handler" the way NFC and QR do.
///
/// Android only. On iOS this class reports unsupported and the UI hides it.
class NearbyService {
  NearbyService._();
  static final NearbyService instance = NearbyService._();

  static const String _serviceId = 'com.nextap.app';
  static const Strategy _strategy = Strategy.P2P_POINT_TO_POINT;

  bool get supported => Platform.isAndroid;

  final _peers = StreamController<List<NearbyPeer>>.broadcast();
  final _status = StreamController<String>.broadcast();
  final _received = StreamController<String>.broadcast();

  Stream<List<NearbyPeer>> get peers => _peers.stream;
  Stream<String> get status => _status.stream;
  Stream<String> get received => _received.stream;

  final Map<String, NearbyPeer> _found = {};
  String? _pendingPayload;
  bool _advertising = false;
  bool _discovering = false;

  void _emitPeers() => _peers.add(_found.values.toList());

  /// Android 12+ wants the new Bluetooth permissions, older ones want location.
  Future<String?> ensurePermissions() async {
    if (!supported) return 'Only supported on Android.';
    try {
      final asked = await [
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.location,
        Permission.nearbyWifiDevices,
      ].request();

      final denied = asked.entries
          .where((e) =>
              e.value.isPermanentlyDenied ||
              (e.value.isDenied && e.key != Permission.nearbyWifiDevices))
          .toList();

      if (denied.any((e) => e.value.isPermanentlyDenied)) {
        return 'Some permissions are blocked. Enable them in app settings.';
      }
      if (denied.isNotEmpty) {
        return 'Bluetooth and location permission are needed to find phones.';
      }

      final location = Location();

if (!await location.serviceEnabled()) {
  final enabled = await location.requestService();

  if (!enabled) {
    return 'Turn on Location - Android needs it for nearby scanning.';
  }
}
      return null;
    } catch (e) {
      return 'Permission check failed: $e';
    }
  }

  // ------------------------------------------------------------- SENDER ----

  /// Start looking for a nearby receiver and auto-send [payload] on connect.
  Future<String?> startSending(String payload, String myName) async {
    final err = await ensurePermissions();
    if (err != null) return err;

    _pendingPayload = payload;
    _found.clear();
    _emitPeers();

    try {
      _discovering = await Nearby().startDiscovery(
        myName.isEmpty ? 'NexTap user' : myName,
        _strategy,
        serviceId: _serviceId,
        onEndpointFound: (id, name, serviceId) {
          _found[id] = NearbyPeer(id: id, name: name);
          _emitPeers();
        },
        onEndpointLost: (id) {
          if (id != null) _found.remove(id);
          _emitPeers();
        },
      );
      if (!_discovering) return 'Could not start scanning.';
      _status.add('Looking for nearby phones...');
      return null;
    } catch (e) {
      return 'Scan failed: $e';
    }
  }

  /// Ask a discovered phone to connect, then push the payload.
  Future<String?> sendTo(NearbyPeer peer, String myName) async {
    try {
      _status.add('Connecting to ${peer.name}...');
      await Nearby().requestConnection(
        myName.isEmpty ? 'NexTap user' : myName,
        peer.id,
        onConnectionInitiated: (id, info) async {
          // Both sides must accept. We auto accept: the token is shown in UI.
          await Nearby().acceptConnection(
            id,
            onPayLoadRecieved: (endpointId, payload) {
              if (payload.bytes != null) {
                _received.add(utf8.decode(payload.bytes!));
              }
            },
          );
        },
        onConnectionResult: (id, statusCode) async {
          if (statusCode == Status.CONNECTED) {
            final data = _pendingPayload;
            if (data != null) {
              await Nearby().sendBytesPayload(
                  id, Uint8List.fromList(utf8.encode(data)));
              _status.add('Sent.');
            }
          } else {
            _status.add('Connection rejected or failed.');
          }
        },
        onDisconnected: (id) => _status.add('Disconnected.'),
      );
      return null;
    } catch (e) {
      return 'Could not connect: $e';
    }
  }

  // ----------------------------------------------------------- RECEIVER ----

  /// Become visible so a sender can find this phone.
  Future<String?> startReceiving(String myName) async {
    final err = await ensurePermissions();
    if (err != null) return err;
    try {
      _advertising = await Nearby().startAdvertising(
        myName.isEmpty ? 'NexTap user' : myName,
        _strategy,
        serviceId: _serviceId,
        onConnectionInitiated: (id, info) async {
          await Nearby().acceptConnection(
            id,
            onPayLoadRecieved: (endpointId, payload) {
              if (payload.bytes != null) {
                _received.add(utf8.decode(payload.bytes!));
              }
            },
          );
        },
        onConnectionResult: (id, status) => _status.add(
            status == Status.CONNECTED ? 'Connected.' : 'Connection failed.'),
        onDisconnected: (id) => _status.add('Disconnected.'),
      );
      if (!_advertising) return 'Could not make this phone visible.';
      _status.add('Visible as "$myName". Waiting...');
      return null;
    } catch (e) {
      return 'Could not start: $e';
    }
  }

  Future<void> stop() async {
    try {
      if (_discovering) await Nearby().stopDiscovery();
      if (_advertising) await Nearby().stopAdvertising();
      await Nearby().stopAllEndpoints();
    } catch (e) {
      debugPrint('NearbyService.stop: $e');
    } finally {
      _discovering = false;
      _advertising = false;
      _found.clear();
      _pendingPayload = null;
    }
  }
}

class NearbyPeer {
  final String id;
  final String name;
  const NearbyPeer({required this.id, required this.name});
}
