import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/journal_provider.dart';
import '../models/entry_model.dart';
import '../theme/app_theme.dart';
import 'add_entry_screen.dart';
import 'all_entries_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.menu_book_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'mixApp',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          Selector<JournalProvider, bool>(
            selector: (_, provider) => provider.isDarkMode,
            builder: (context, isDark, _) {
              return IconButton(
                tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: isDark ? const Color(0xFFFBBF24) : Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
                onPressed: () {
                  context.read<JournalProvider>().toggleThemeMode();
                },
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Selector<JournalProvider, bool>(
        selector: (_, provider) => provider.isLoading,
        builder: (context, isLoading, _) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                _HeroHeaderBanner(),
                SizedBox(height: 24),
                _ActionButtonsGroup(),
                SizedBox(height: 28),
                _RecentActivitiesSection(),
                SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Minimalist Hero Header Banner with clean Iris aesthetic
class _HeroHeaderBanner extends StatelessWidget {
  const _HeroHeaderBanner();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightPrimaryContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? AppTheme.darkBorder
              : AppTheme.lightPrimary.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkPrimary.withValues(alpha: 0.15)
                      : AppTheme.lightPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Design Your Life 🌿',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Track Your Daily Energy & Engagement',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              height: 1.25,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Discover activities that energize you and optimize your routines.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Minimalist elevated and outlined buttons group
class _ActionButtonsGroup extends StatelessWidget {
  const _ActionButtonsGroup();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddEntryScreen(),
              ),
            );
          },
          icon: const Icon(Icons.add_rounded, size: 22),
          label: const Text('Add Journal Entry'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AllEntriesScreen(),
              ),
            );
          },
          icon: const Icon(Icons.history_rounded, size: 20),
          label: const Text('View All Entries'),
        ),
      ],
    );
  }
}

/// Recent activities feed section
class _RecentActivitiesSection extends StatelessWidget {
  const _RecentActivitiesSection();

  @override
  Widget build(BuildContext context) {
    return Selector<JournalProvider, List<JournalEntry>>(
      selector: (_, provider) => provider.recentEntries,
      builder: (context, entries, _) {
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Activities',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                if (entries.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AllEntriesScreen(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48), // Touch target
                    ),
                    child: Text(
                      'See All',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              const _EmptyStateWidget()
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: entries.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _ActivityFeedTile(entry: entries[index]);
                },
              ),
          ],
        );
      },
    );
  }
}

class _EmptyStateWidget extends StatelessWidget {
  const _EmptyStateWidget();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.edit_calendar_rounded,
            size: 42,
            color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
          ),
          const SizedBox(height: 12),
          const Text(
            'No journal entries recorded yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap "Add Journal Entry" above to record your first activity.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityFeedTile extends StatelessWidget {
  final JournalEntry entry;

  const _ActivityFeedTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeStr = DateFormat('hh:mm a').format(entry.timestamp);
    final dateStr = DateFormat('MMM dd').format(entry.timestamp);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddEntryScreen(entryToEdit: entry),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkPrimaryContainer
                    : AppTheme.lightPrimaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.edit_note_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.activity,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '$dateStr • $timeStr',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                        ),
                      ),
                      if (entry.isFlow) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '⚡ Flow',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF8B5CF6),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _Badge(
                  label: 'Eng: ${entry.engagement.toInt()}',
                  color: isDark ? AppTheme.darkEngagement : AppTheme.lightEngagement,
                ),
                const SizedBox(height: 4),
                _Badge(
                  label: 'Good: ${entry.goodness.toInt()}',
                  color: isDark ? AppTheme.darkGoodness : AppTheme.lightGoodness,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
