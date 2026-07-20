import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ActivityHintWidget extends StatefulWidget {
  const ActivityHintWidget({super.key});

  @override
  State<ActivityHintWidget> createState() => _ActivityHintWidgetState();
}

class _ActivityHintWidgetState extends State<ActivityHintWidget> {
  bool _isExpanded = false;

  final List<_HintCategory> _hints = const [
    _HintCategory(
      icon: Icons.checklist_rounded,
      title: 'Activities',
      description:
          'What were you actually doing? Was this a structured or an unstructured activity? Did you have a specific role to play (e.g. team leader) or were you just a participant?',
    ),
    _HintCategory(
      icon: Icons.place_rounded,
      title: 'Environments',
      description:
          'Our environment has a profound effect on our emotional state (e.g. stadium vs cathedral). Notice where you were when involved in the activity. What kind of place was it, and how did it make you feel?',
    ),
    _HintCategory(
      icon: Icons.forum_rounded,
      title: 'Interactions',
      description:
          'What were you interacting with—people or machines? Was it a new kind of interaction or one you are familiar with? Was it formal or informal?',
    ),
    _HintCategory(
      icon: Icons.devices_other_rounded,
      title: 'Objects',
      description:
          'Were you interacting with any objects or devices—smartphones, tools, or physical gear? What objects created or supported your feeling of engagement?',
    ),
    _HintCategory(
      icon: Icons.people_outline_rounded,
      title: 'Users',
      description:
          'Who else was there, and what role did they play in making it either a positive or a negative experience?',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkPrimaryContainer.withValues(alpha: 0.6)
            : AppTheme.lightPrimaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(),
          collapsedShape: const RoundedRectangleBorder(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lightbulb_outline_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          title: Text(
            'Need help describing your activity?',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          subtitle: Text(
            _isExpanded ? 'Tap to collapse AEIOU framework' : 'AEIOU Prompts: Activities, Environments, Interactions...',
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
            ),
          ),
          onExpansionChanged: (expanded) {
            setState(() {
              _isExpanded = expanded;
            });
          },
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: _hints.map((hint) => _buildHintRow(context, hint, isDark)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHintRow(BuildContext context, _HintCategory hint, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hint.icon,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hint.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hint.description,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HintCategory {
  final IconData icon;
  final String title;
  final String description;

  const _HintCategory({
    required this.icon,
    required this.title,
    required this.description,
  });
}
