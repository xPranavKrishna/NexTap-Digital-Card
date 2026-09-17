import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/social_card.dart';

/// Single source of truth for the saved cards.
/// Simple ChangeNotifier singleton - no extra state package needed.
class CardStore extends ChangeNotifier {
  CardStore._();
  static final CardStore instance = CardStore._();

  static const _kCards = 'nextap_cards_v1';
  static const _kOwnerName = 'nextap_owner_name';

  final List<SocialCard> _cards = [];
  String _ownerName = '';
  bool _loaded = false;

  List<SocialCard> get cards => List.unmodifiable(_cards);
  String get ownerName => _ownerName;
  bool get loaded => _loaded;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _ownerName = prefs.getString(_kOwnerName) ?? '';
      final raw = prefs.getString(_kCards);
      _cards.clear();
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final e in list) {
          try {
            _cards.add(SocialCard.fromJson(e as Map<String, dynamic>));
          } catch (_) {
            // skip a single corrupted entry instead of losing everything
          }
        }
      }
    } catch (e) {
      debugPrint('CardStore.load failed: $e');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _kCards, jsonEncode(_cards.map((c) => c.toJson()).toList()));
      await prefs.setString(_kOwnerName, _ownerName);
    } catch (e) {
      debugPrint('CardStore._persist failed: $e');
    }
  }

  Future<void> setOwnerName(String name) async {
    _ownerName = name.trim();
    notifyListeners();
    await _persist();
  }

  bool hasPlatform(String platformId) =>
      _cards.any((c) => c.platformId == platformId);

  Future<void> add(SocialCard card) async {
    _cards.add(card);
    notifyListeners();
    await _persist();
  }

  Future<void> update(SocialCard card) async {
    final i = _cards.indexWhere((c) => c.id == card.id);
    if (i == -1) return;
    _cards[i] = card;
    notifyListeners();
    await _persist();
  }

  Future<void> remove(String id) async {
    _cards.removeWhere((c) => c.id == id);
    notifyListeners();
    await _persist();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = _cards.removeAt(oldIndex);
    _cards.insert(newIndex, item);
    notifyListeners();
    await _persist();
  }

  /// Payload used when the whole profile is shared at once.
  String buildProfilePayload() => jsonEncode({
        'app': 'nextap',
        'v': 1,
        'name': _ownerName,
        'cards': _cards
            .map((c) => {'p': c.platformId, 'u': c.url, 'h': c.handle})
            .toList(),
      });
}
