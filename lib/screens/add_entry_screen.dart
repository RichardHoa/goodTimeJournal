import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/entry_model.dart';
import '../providers/journal_provider.dart';
import '../widgets/gauge_chart.dart';
import '../widgets/activity_hint_widget.dart';
import '../theme/app_theme.dart';

class AddEntryScreen extends StatefulWidget {
  final JournalEntry? entryToEdit;

  const AddEntryScreen({super.key, this.entryToEdit});

  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _activityController;

  double _engagement = 5.0;
  double _goodness = 5.0;
  bool _isFlow = false;
  late DateTime _timestamp;
  bool _isSaving = false;

  bool get _isEditing => widget.entryToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final entry = widget.entryToEdit!;
      _activityController = TextEditingController(text: entry.activity);
      _engagement = entry.engagement;
      _goodness = entry.goodness;
      _isFlow = entry.isFlow;
      _timestamp = entry.timestamp;
    } else {
      _activityController = TextEditingController();
      _timestamp = DateTime.now();
    }
  }

  @override
  void dispose() {
    _activityController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final provider = context.read<JournalProvider>();

    if (_isEditing) {
      final updated = widget.entryToEdit!.copyWith(
        activity: _activityController.text.trim(),
        engagement: _engagement,
        goodness: _goodness,
        isFlow: _isFlow,
        timestamp: _timestamp,
      );
      await provider.updateEntry(updated);
    } else {
      await provider.addEntry(
        activity: _activityController.text.trim(),
        engagement: _engagement,
        goodness: _goodness,
        isFlow: _isFlow,
        timestamp: _timestamp,
      );
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              _isEditing ? 'Journal entry updated!' : 'Journal entry saved!',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatted = DateFormat('EEEE, MMM dd, yyyy • hh:mm a').format(_timestamp);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Journal Entry' : 'Add Journal Entry'),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Timestamp Info Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkPrimaryContainer
                      : AppTheme.lightPrimaryContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Log Timestamp',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateFormatted,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Unobtrusive AEIOU Activity Guidance Hint Widget
              const ActivityHintWidget(),

              const SizedBox(height: 20),

              // Activity Field
              const Text(
                'What activity did you do?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _activityController,
                minLines: 3,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Describe your activity...\ne.g. UI/UX design session, team alignment sync, reading research paper',
                  alignLabelWithHint: true,
                  contentPadding: const EdgeInsets.all(16),
                  suffixIcon: _activityController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _activityController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your activity';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Flow State Checkbox
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isFlow
                        ? Theme.of(context).colorScheme.primary
                        : (isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                    width: _isFlow ? 1.5 : 1,
                  ),
                ),
                child: CheckboxListTile(
                  title: Row(
                    children: [
                      Text(
                        'Flow State',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _isFlow ? Theme.of(context).colorScheme.primary : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '⚡ Deep Focus',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8B5CF6),
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    'Were you fully immersed, lost sense of time, and deeply engaged?',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                    ),
                  ),
                  value: _isFlow,
                  activeColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onChanged: (val) {
                    setState(() {
                      _isFlow = val ?? false;
                    });
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Engagement Gauge
              GaugeChartWidget(
                title: 'Engagement Rating (0 - 10)',
                value: _engagement,
                type: GaugeType.engagement,
                isInteractive: true,
                onChanged: (val) {
                  setState(() {
                    _engagement = val;
                  });
                },
              ),

              const SizedBox(height: 20),

              // Goodness Gauge
              GaugeChartWidget(
                title: 'Energy & Goodness (0 - 10)',
                value: _goodness,
                type: GaugeType.goodness,
                isInteractive: true,
                onChanged: (val) {
                  setState(() {
                    _goodness = val;
                  });
                },
              ),

              const SizedBox(height: 28),

              // Submit Button
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _submitForm,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.check_circle_rounded, size: 22),
                label: Text(
                  _isSaving
                      ? (_isEditing ? 'Saving Changes...' : 'Saving Entry...')
                      : (_isEditing ? 'Update Journal Entry' : 'Save Journal Entry'),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
