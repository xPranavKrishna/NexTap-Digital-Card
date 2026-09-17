import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// How the raw text the user typed should be cleaned before building a link.
enum ValueMode { handle, phone, email, url }

class SocialPlatform {
  final String id;
  final String name;
  final FaIconData icon;
  final Color color;
  final String urlTemplate;
  final String hint;
  final ValueMode mode;

  const SocialPlatform({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.urlTemplate,
    required this.hint,
    this.mode = ValueMode.handle,
  });

  String clean(String raw) {
    var v = raw.trim();
    switch (mode) {
      case ValueMode.handle:
        v = v.replaceAll(RegExp(r'^@+'), '');
        // if the user pasted a full profile link, keep only the last segment
        if (v.startsWith('http')) {
          final parts = Uri.tryParse(v)?.pathSegments ?? const [];
          if (parts.isNotEmpty) v = parts.last;
        }
        return v;
      case ValueMode.phone:
        final plus = v.startsWith('+');
        v = v.replaceAll(RegExp(r'[^0-9]'), '');
        return plus ? '+$v' : v;
      case ValueMode.email:
        return v.toLowerCase();
      case ValueMode.url:
        if (v.isEmpty) return v;
        if (!v.startsWith('http://') && !v.startsWith('https://')) {
          v = 'https://$v';
        }
        return v;
    }
  }

  /// Final link that gets shared / encoded into the QR / NFC payload.
  String buildUrl(String raw) {
    final v = clean(raw);
    if (v.isEmpty) return '';
    if (mode == ValueMode.url) return v;
    return urlTemplate.replaceAll('{v}', Uri.encodeComponent(v));
  }

  /// What we print on the card under the name.
  String display(String raw) {
    final v = clean(raw);
    switch (mode) {
      case ValueMode.handle:
        return '@$v';
      case ValueMode.url:
        return v.replaceFirst(RegExp(r'^https?://'), '');
      default:
        return v;
    }
  }
}

/// Everything NexTap can hold. Add more here, the UI picks them up automatically.
const List<SocialPlatform> kPlatforms = [
  SocialPlatform(
    id: 'instagram',
    name: 'Instagram',
    icon: FontAwesomeIcons.instagram,
    color: Color(0xFFE1306C),
    urlTemplate: 'https://instagram.com/{v}',
    hint: 'your username',
  ),
  SocialPlatform(
    id: 'linkedin',
    name: 'LinkedIn',
    icon: FontAwesomeIcons.linkedinIn,
    color: Color(0xFF0A66C2),
    urlTemplate: 'https://www.linkedin.com/in/{v}',
    hint: 'profile id (linkedin.com/in/THIS)',
  ),
  SocialPlatform(
    id: 'whatsapp',
    name: 'WhatsApp',
    icon: FontAwesomeIcons.whatsapp,
    color: Color(0xFF25D366),
    urlTemplate: 'https://wa.me/{v}',
    hint: 'phone with country code, e.g. 919876543210',
    mode: ValueMode.phone,
  ),
  SocialPlatform(
    id: 'telegram',
    name: 'Telegram',
    icon: FontAwesomeIcons.telegram,
    color: Color(0xFF229ED9),
    urlTemplate: 'https://t.me/{v}',
    hint: 'your username',
  ),
  SocialPlatform(
    id: 'snapchat',
    name: 'Snapchat',
    icon: FontAwesomeIcons.snapchat,
    color: Color(0xFFF7C600),
    urlTemplate: 'https://snapchat.com/add/{v}',
    hint: 'your username',
  ),
  SocialPlatform(
    id: 'github',
    name: 'GitHub',
    icon: FontAwesomeIcons.github,
    color: Color(0xFF24292F),
    urlTemplate: 'https://github.com/{v}',
    hint: 'your username',
  ),
  SocialPlatform(
    id: 'x',
    name: 'X (Twitter)',
    icon: FontAwesomeIcons.xTwitter,
    color: Color(0xFF14171A),
    urlTemplate: 'https://x.com/{v}',
    hint: 'your handle',
  ),
  SocialPlatform(
    id: 'facebook',
    name: 'Facebook',
    icon: FontAwesomeIcons.facebookF,
    color: Color(0xFF1877F2),
    urlTemplate: 'https://facebook.com/{v}',
    hint: 'username or page id',
  ),
  SocialPlatform(
    id: 'youtube',
    name: 'YouTube',
    icon: FontAwesomeIcons.youtube,
    color: Color(0xFFFF0000),
    urlTemplate: 'https://youtube.com/@{v}',
    hint: 'channel handle (without @)',
  ),
  SocialPlatform(
    id: 'discord',
    name: 'Discord',
    icon: FontAwesomeIcons.discord,
    color: Color(0xFF5865F2),
    urlTemplate: 'https://discord.com/users/{v}',
    hint: 'numeric user id',
  ),
  SocialPlatform(
    id: 'reddit',
    name: 'Reddit',
    icon: FontAwesomeIcons.reddit,
    color: Color(0xFFFF4500),
    urlTemplate: 'https://reddit.com/user/{v}',
    hint: 'your username',
  ),
  SocialPlatform(
    id: 'spotify',
    name: 'Spotify',
    icon: FontAwesomeIcons.spotify,
    color: Color(0xFF1DB954),
    urlTemplate: 'https://open.spotify.com/user/{v}',
    hint: 'your user id',
  ),
  SocialPlatform(
    id: 'threads',
    name: 'Threads',
    icon: FontAwesomeIcons.at,
    color: Color(0xFF000000),
    urlTemplate: 'https://threads.net/@{v}',
    hint: 'your username',
  ),
  SocialPlatform(
    id: 'email',
    name: 'Email',
    icon: FontAwesomeIcons.envelope,
    color: Color(0xFF6C5CE7),
    urlTemplate: 'mailto:{v}',
    hint: 'you@example.com',
    mode: ValueMode.email,
  ),
  SocialPlatform(
    id: 'phone',
    name: 'Phone',
    icon: FontAwesomeIcons.phone,
    color: Color(0xFF00B894),
    urlTemplate: 'tel:{v}',
    hint: '+91 98765 43210',
    mode: ValueMode.phone,
  ),
  SocialPlatform(
    id: 'website',
    name: 'Website',
    icon: FontAwesomeIcons.globe,
    color: Color(0xFF636E72),
    urlTemplate: '{v}',
    hint: 'yourdomain.com',
    mode: ValueMode.url,
  ),
];

SocialPlatform platformById(String id) =>
    kPlatforms.firstWhere((p) => p.id == id, orElse: () => kPlatforms.last);

class SocialCard {
  final String id;
  final String platformId;
  final String value;
  final String label; // display name shown on the card
  final String? avatarUrl;

  const SocialCard({
    required this.id,
    required this.platformId,
    required this.value,
    required this.label,
    this.avatarUrl,
  });

  SocialPlatform get platform => platformById(platformId);
  String get url => platform.buildUrl(value);
  String get handle => platform.display(value);

  SocialCard copyWith({String? value, String? label, String? avatarUrl}) =>
      SocialCard(
        id: id,
        platformId: platformId,
        value: value ?? this.value,
        label: label ?? this.label,
        avatarUrl: avatarUrl ?? this.avatarUrl,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'platformId': platformId,
        'value': value,
        'label': label,
        'avatarUrl': avatarUrl,
      };

  factory SocialCard.fromJson(Map<String, dynamic> j) => SocialCard(
        id: j['id'] as String,
        platformId: j['platformId'] as String,
        value: j['value'] as String,
        label: (j['label'] ?? '') as String,
        avatarUrl: j['avatarUrl'] as String?,
      );
}
