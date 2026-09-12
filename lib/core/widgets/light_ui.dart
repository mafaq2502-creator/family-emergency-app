import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class LightPage extends StatelessWidget {
  const LightPage({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.subtitle,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 28),
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> actions;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    appBar: AppBar(title: Text(title), actions: actions),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: padding,
        children: [
          if (subtitle != null) ...[
            Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: context.appMuted),
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    ),
  );
}

/// Shared dialog chrome. Closing returns no value, so temporary field edits
/// remain local to the dismissed popup and are never submitted.
class AppAlertDialog extends StatelessWidget {
  const AppAlertDialog({
    super.key,
    this.icon,
    required this.title,
    this.content,
    this.actions,
    this.actionsAlignment,
  });

  final Widget? icon;
  final Widget title;
  final Widget? content;
  final List<Widget>? actions;
  final MainAxisAlignment? actionsAlignment;

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: icon,
    title: Row(
      children: [
        Expanded(child: title),
        const SizedBox(width: 8),
        IconButton(
          key: const Key('dialog-close'),
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
    content: content,
    actions: actions,
    actionsAlignment: actionsAlignment,
  );
}

class LightCard extends StatelessWidget {
  const LightCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? context.appSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C0B715E),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Material(color: Colors.transparent, child: child),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

class LightSectionTitle extends StatelessWidget {
  const LightSectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: context.appHeading,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class LightStatusChip extends StatelessWidget {
  const LightStatusChip({
    super.key,
    required this.label,
    this.color = kEmerald,
    this.icon,
  });
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .11),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class LightAvatar extends StatelessWidget {
  const LightAvatar({
    super.key,
    required this.name,
    this.radius = 24,
    this.online,
  });
  final String name;
  final double radius;
  final bool? online;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      CircleAvatar(
        radius: radius,
        backgroundColor: context.appSuccessSurface,
        child: Text(
          name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
          style: TextStyle(
            color: context.appPrimary,
            fontSize: radius * .7,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      if (online != null)
        Positioned(
          right: 0,
          bottom: 1,
          child: Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: online! ? kEmerald : context.appMuted,
              shape: BoxShape.circle,
              border: Border.all(color: context.appSurface, width: 2),
            ),
          ),
        ),
    ],
  );
}

class LightSettingRow extends StatelessWidget {
  const LightSettingRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) => LightCard(
    padding: EdgeInsets.zero,
    onTap: onTap,
    color: destructive ? context.appDangerSurface : null,
    child: ListTile(
      minLeadingWidth: 30,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: (destructive ? kEmergency : kEmerald).withValues(alpha: .11),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: destructive ? kEmergency : context.appPrimary,
          size: 18,
        ),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: destructive ? kEmergency : context.appHeading,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: context.appMuted),
            ),
      trailing:
          trailing ??
          (onTap == null
              ? null
              : Icon(Icons.chevron_right_rounded, color: context.appMuted)),
    ),
  );
}

class LightStateView extends StatelessWidget {
  const LightStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.busy = false,
  });
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool busy;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: context.appSuccessSurface,
              shape: BoxShape.circle,
            ),
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(22),
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Icon(icon, color: context.appPrimary, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.appHeading,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.appMuted, fontSize: 14),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    ),
  );
}

class LightToggleRow extends StatelessWidget {
  const LightToggleRow({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => LightSettingRow(
    icon: icon,
    title: title,
    subtitle: subtitle,
    trailing: Switch.adaptive(value: value, onChanged: onChanged),
  );
}
