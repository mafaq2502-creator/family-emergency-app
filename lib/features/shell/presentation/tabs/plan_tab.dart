part of '../family_shell.dart';

extension _PlanTab on _HomeScreenState {
  Widget _buildPlanTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : kLightNavy;
    final mutedColor = isDark ? Colors.white60 : kLightMuted;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose Your Plan',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Get more features to keep your family\nextra safe.',
              style: TextStyle(fontSize: 12, color: mutedColor),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _planCard(
                      title: 'Free',
                      subtitle: 'Basic features for\nsmall families.',
                      price: '\$0',
                      features: const [
                        'Up to 5 members',
                        'Basic alerts',
                        'Location tracking',
                      ],
                      selected: true,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _planCard(
                      title: 'Premium',
                      subtitle: 'Advanced features\nfor complete safety.',
                      price: '\$4.99',
                      features: const [
                        'Unlimited members',
                        'Real-time alerts',
                        'Location history',
                        'Priority support',
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _planCard({
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
              color: selected
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
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : kLightNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              height: 1.12,
              color: isDark ? Colors.white60 : kLightMuted,
            ),
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
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
                    fontSize: 10,
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
                        fontSize: 9.5,
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
          SizedBox(
            width: double.infinity,
            height: 35,
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
                backgroundColor: selected ? const Color(0xFFF1F3F4) : kEmerald,
                foregroundColor: selected
                    ? const Color(0xFF64748B)
                    : Colors.white,
                disabledBackgroundColor: const Color(0xFFF1F3F4),
                disabledForegroundColor: const Color(0xFF64748B),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: Text(
                selected ? 'Current Plan' : 'Upgrade Now',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
