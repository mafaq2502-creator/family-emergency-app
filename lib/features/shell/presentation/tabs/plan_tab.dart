import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Plans'),
    ),
    body: const PlanSelectionContent(showHeader: false),
  );
}

class PlanSelectionContent extends StatelessWidget {
  const PlanSelectionContent({super.key, this.action, this.showHeader = true});

  final Widget? action;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : kLightNavy;
    final mutedColor = isDark ? Colors.white60 : kLightMuted;
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader)
          Row(
            children: [
              Expanded(
                child: Text(
                  'Choose Your Plan',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
              ),
              ?action,
            ],
          ),
        if (showHeader) const SizedBox(height: 4),
        Text(
          'Get more features to keep your family\nextra safe.',
          style: TextStyle(fontSize: 14, color: mutedColor),
        ),
      ],
    );
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
            child: header,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, viewport) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 2, 24, 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: viewport.maxHeight > 28
                        ? viewport.maxHeight - 28
                        : 0,
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: _planCard(
                            context: context,
                            title: 'Free',
                            subtitle: 'Basic features for\nsmall families.',
                            price: '\$0',
                            features: const [
                              '1 owned Circle',
                              '1 joined Circle',
                              'Owner + 2 members',
                              'Emergency/SOS alerts',
                              'Emergency recipient selection',
                              'Basic Circle management',
                            ],
                            selected: true,
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: _planCard(
                            context: context,
                            title: 'Premium',
                            subtitle: 'Advanced features\nfor complete safety.',
                            price: '\$2.99',
                            features: const [
                              'Owner + 10 members',
                              'Yearly: \$28.70 (20% off)',
                              'Approved device access',
                              'Battery/offline alerts',
                              'Emergency history',
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _planCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String price,
    required List<String> features,
    bool selected = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 11, 10, 10),
      decoration: BoxDecoration(
        color: isDark ? kDarkCard : kLightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : kLightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isDark
                  ? kDarkCardElevated
                  : selected
                  ? const Color(0xFFEAF4FF)
                  : const Color(0xFFFFF4D9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              selected ? Icons.send_rounded : Icons.workspace_premium_rounded,
              color: selected
                  ? const Color(0xFF2586F6)
                  : const Color(0xFFFFAE00),
              size: 23,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$title Plan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : kLightNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              height: 1.12,
              color: isDark ? Colors.white60 : kLightMuted,
            ),
          ),
          const SizedBox(height: 10),
          RichText(
            textScaler: MediaQuery.textScalerOf(context),
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: [
                TextSpan(
                  text: price,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : kLightNavy,
                  ),
                ),
                TextSpan(
                  text: ' / month',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : kLightMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          for (final feature in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check, size: 15, color: kEmerald),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      feature,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.1,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF314761),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const Spacer(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: selected
                  ? null
                  : () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Premium upgrade will be available soon.',
                        ),
                      ),
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: selected
                    ? context.appSurfaceMuted
                    : kLightPrimary,
                foregroundColor: selected
                    ? const Color(0xFF64748B)
                    : Colors.white,
                disabledBackgroundColor: context.appSurfaceMuted,
                disabledForegroundColor: context.appMuted,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: Text(
                selected ? 'Current Plan' : 'Upgrade Now',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          if (!selected) ...[
            const SizedBox(height: 5),
            Center(
              child: TextButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Subscription management is not connected yet.',
                    ),
                  ),
                ),
                child: const Text(
                  'Manage Subscription',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
