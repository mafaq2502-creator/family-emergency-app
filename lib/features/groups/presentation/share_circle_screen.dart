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
  CircleInviteResult? _invite;
  bool _busy = false;
  int _tab = 0;

  Future<void> _generate() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final invite = await CircleJoinService().createInvite(widget.group.id);
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
    final code = _invite?.code;
    return LightPage(
      title: 'Share Circle',
      subtitle: widget.group.name,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: context.appSurfaceMuted,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: ['QR Code', 'Invite Code', 'Invite Link'].indexed
                  .map(
                    (entry) => Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setState(() => _tab = entry.$1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            gradient: _tab == entry.$1
                                ? kPrimaryGradient
                                : null,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            entry.$2,
                            style: TextStyle(
                              color: _tab == entry.$1
                                  ? Colors.white
                                  : context.appMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 18),
          _tabContent(code),
          if (_invite != null) ...[
            const SizedBox(height: 10),
            Text(
              'Expires ${MaterialLocalizations.of(context).formatMediumDate(_invite!.expiresAt)}',
              style: TextStyle(color: context.appMuted, fontSize: 11),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _invite == null
                  ? _generate
                  : () => _copy(code!, 'Invitation code'),
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

  Widget _tabContent(String? code) {
    if (_tab == 0) {
      return const LightStateView(
        icon: Icons.qr_code_scanner_rounded,
        title: 'QR sharing unavailable',
        message: 'A scannable QR renderer is not connected. Use the real invitation code tab instead.',
      );
    }
    if (_tab == 2) {
      return const LightStateView(
        icon: Icons.link_off_rounded,
        title: 'Joining link unavailable',
        message: 'Deep-link configuration is required before a safe joining link can be shared.',
      );
    }
    return LightCard(
      child: code == null
          ? const LightStateView(
              icon: Icons.key_rounded,
              title: 'Generate an invitation code',
              message: 'The code will be created by the existing secure invitation service and will expire.',
            )
          : Row(
              children: [
                Expanded(
                  child: SelectableText(
                    code,
                    style: TextStyle(
                      color: context.appHeading,
                      fontSize: 20,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _copy(code, 'Code'),
                  child: const Text('Copy'),
                ),
              ],
            ),
    );
  }
}
