import 'package:flutter/material.dart';

import '../models/social_card.dart';
import '../theme.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
/// Best guess at a public avatar image without logging in anywhere.
/// GitHub exposes one directly. Everyone else needs OAuth, so we fall back to
/// the user's own pasted image URL, else a letter avatar.
String? avatarFor(SocialCard card) {
  if (card.avatarUrl != null && card.avatarUrl!.trim().isNotEmpty) {
    return card.avatarUrl!.trim();
  }
  if (card.platformId == 'github') {
    final u = card.platform.clean(card.value);
    if (u.isNotEmpty) return 'https://github.com/$u.png?size=200';
  }
  return null;
}

class Avatar extends StatelessWidget {
  final SocialCard card;
  final double size;
  final Color? ring;

  const Avatar({super.key, required this.card, this.size = 56, this.ring});

  @override
  Widget build(BuildContext context) {
    final url = avatarFor(card);
    final source = card.label.isNotEmpty
        ? card.label
        : card.platform.clean(card.value).isNotEmpty
            ? card.platform.clean(card.value)
            : card.platform.name;
    final letter =
        source.isEmpty ? '?' : source.substring(0, 1).toUpperCase();

    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            card.platform.color.withOpacity(0.85),
            card.platform.color.withOpacity(0.55),
          ],
        ),
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    final inner = url == null
        ? fallback
        : ClipOval(
            child: Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              // any network / 404 / offline problem quietly falls back
              errorBuilder: (_, __, ___) => fallback,
              loadingBuilder: (c, child, p) =>
                  p == null ? child : fallback,
            ),
          );

    if (ring == null) return inner;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ring!.withOpacity(0.35), width: 2),
      ),
      child: inner,
    );
  }
}

/// Row item shown on the home screen.
class CardTile extends StatelessWidget {
  final SocialCard card;
  final VoidCallback onTap;

  const CardTile({super.key, required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = card.platform;
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: AppTheme.cardShape,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: p.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: FaIcon(p.icon, color: p.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.label.isEmpty ? p.name : card.label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15.5,
                          color: AppTheme.ink),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      card.handle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppTheme.sub, fontSize: 13.5),
                    ),
                  ],
                ),
              ),
              Avatar(card: card, size: 38),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.sub),
            ],
          ),
        ),
      ),
    );
  }
}

/// Big hero card shown on the detail screen.
class ProfileHeroCard extends StatelessWidget {
  final SocialCard card;
  const ProfileHeroCard({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final p = card.platform;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.color, Color.lerp(p.color, Colors.black, 0.35)!],
        ),
        boxShadow: [
          BoxShadow(
            color: p.color.withOpacity(0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              FaIcon(p.icon, color: Colors.white.withOpacity(0.9), size: 20),
              const SizedBox(width: 8),
              Text(
                p.name,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('NexTap',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Avatar(card: card, size: 88, ring: Colors.white),
          const SizedBox(height: 14),
          Text(
            card.label.isEmpty ? card.handle : card.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            card.handle,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withOpacity(0.85), fontSize: 14.5),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              card.url.replaceFirst(RegExp(r'^https?://'), ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.95), fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
