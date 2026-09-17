import 'package:flutter/material.dart';

import '../models/social_card.dart';
import '../services/card_store.dart';
import '../theme.dart';
import '../widgets/cards.dart';

class EditCardScreen extends StatefulWidget {
  final SocialPlatform platform;
  final SocialCard? existing;

  const EditCardScreen({super.key, required this.platform, this.existing});

  @override
  State<EditCardScreen> createState() => _EditCardScreenState();
}

class _EditCardScreenState extends State<EditCardScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _value;
  late final TextEditingController _label;
  late final TextEditingController _avatar;

  @override
  void initState() {
    super.initState();
    _value = TextEditingController(text: widget.existing?.value ?? '');
    _label = TextEditingController(
        text: widget.existing?.label ?? CardStore.instance.ownerName);
    _avatar = TextEditingController(text: widget.existing?.avatarUrl ?? '');
  }

  @override
  void dispose() {
    _value.dispose();
    _label.dispose();
    _avatar.dispose();
    super.dispose();
  }

  SocialCard get _preview => SocialCard(
        id: widget.existing?.id ?? 'preview',
        platformId: widget.platform.id,
        value: _value.text.isEmpty ? 'username' : _value.text,
        label: _label.text,
        avatarUrl: _avatar.text,
      );

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final card = SocialCard(
      id: widget.existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      platformId: widget.platform.id,
      value: _value.text.trim(),
      label: _label.text.trim(),
      avatarUrl: _avatar.text.trim().isEmpty ? null : _avatar.text.trim(),
    );

    if (widget.existing == null) {
      await CardStore.instance.add(card);
    } else {
      await CardStore.instance.update(card);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.platform;
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.existing == null
              ? 'Add ${p.name}'
              : 'Edit ${p.name}')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            ProfileHeroCard(card: _preview),
            const SizedBox(height: 24),
            Text('${p.name} ID',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: AppTheme.ink)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _value,
              autofocus: true,
              keyboardType: switch (p.mode) {
                ValueMode.phone => TextInputType.phone,
                ValueMode.email => TextInputType.emailAddress,
                ValueMode.url => TextInputType.url,
                _ => TextInputType.text,
              },
              decoration: InputDecoration(hintText: p.hint),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'Please enter your ${p.name} ID';
                if (p.mode == ValueMode.email && !t.contains('@')) {
                  return 'That does not look like an email';
                }
                if (p.mode == ValueMode.phone &&
                    p.clean(t).replaceAll('+', '').length < 8) {
                  return 'Add the full number with country code';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            const Text('Display name',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppTheme.ink)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _label,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: 'e.g. Pranav'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 18),
            const Text('Profile picture URL (optional)',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppTheme.ink)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _avatar,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: p.id == 'github'
                    ? 'auto-loaded from GitHub'
                    : 'paste an image link',
                prefixIcon: const Icon(Icons.image_outlined),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            const Text(
              'Instagram, LinkedIn and others do not allow reading a profile '
              'photo without login, so paste a link if you want one. GitHub '
              'loads automatically.',
              style: TextStyle(color: AppTheme.sub, fontSize: 12.5,
                  height: 1.4),
            ),
            const SizedBox(height: 26),
            FilledButton(
              onPressed: _save,
              child: Text(widget.existing == null ? 'Save card' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }
}
