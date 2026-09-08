import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/light_ui.dart';
import '../../../models/family_group.dart';
import '../../../services/circle_join_service.dart';

class ShareCircleScreen extends StatefulWidget {
  const ShareCircleScreen({super.key, required this.group});
  final FamilyGroup group;

  @override
  State<ShareCircleScreen> createState() => _ShareCircleScreenState();
}

class _ShareCircleScreenState extends State<ShareCircleScreen> {
  final _service = CircleJoinService();
  CircleInviteResult? _invite;
  bool _busy = false;

  Future<void> _generate() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final invite = await _service.createInvite(widget.group.id);
      if (mounted) setState(() => _invite = invite);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitation could not be created. Please try again.'),
            backgroundColor: kEmergency,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$label copied.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = _invite?.code ?? 'Generate a code';
    const link = 'Joining link is not configured yet';
    return LightPage(
      title: 'Share Circle',
      subtitle: widget.group.name,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: kLightSurfaceMuted,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: ['QR Code', 'Invite Code', 'Invite Link']
                  .map(
                    (label) => Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          gradient: label == 'QR Code'
                              ? kPrimaryGradient
                              : null,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          label,
                          style: TextStyle(
                            color: label == 'QR Code'
                                ? Colors.white
                                : kLightMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 18),
          LightCard(
            child: Column(
              children: [
                Container(
                  width: 176,
                  height: 176,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kLightBorder),
                  ),
                  child: Icon(
                    _invite == null
                        ? Icons.qr_code_2_rounded
                        : Icons.qr_code_rounded,
                    size: 142,
                    color: _invite == null ? kLightMuted : kLightNavy,
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        code,
                        style: const TextStyle(
                          color: kLightNavy,
                          fontSize: 20,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _invite == null
                          ? null
                          : () => _copy(code, 'Code'),
                      child: const Text('Copy'),
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        link,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: kLightMuted,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: null,
                      icon: const Icon(Icons.copy_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_invite != null) ...[
            const SizedBox(height: 10),
            Text(
              'Expires ${MaterialLocalizations.of(context).formatMediumDate(_invite!.expiresAt)}',
              style: const TextStyle(color: kLightMuted, fontSize: 11),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _invite == null
                  ? _generate
                  : () => _copy(code, 'Invitation code'),
              icon: Icon(
                _invite == null ? Icons.add_link_rounded : Icons.share_rounded,
              ),
              label: Text(
                _invite == null
                    ? 'Generate Invitation'
                    : 'Copy Invitation Code',
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: _busy ? null : _generate,
              child: Text(_busy ? 'Generating…' : 'Generate New Code'),
            ),
          ),
        ],
      ),
    );
  }
}
