import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'environment_service.dart';

class FeedbackDialog extends StatefulWidget {
  final String appSlug;
  final Uint8List? initialScreenshot;
  final String initialCategory;
  final String initialSeverity;
  final String? initialTitle;
  final String? initialDescription;
  final StackTrace? stackTrace;

  const FeedbackDialog({
    super.key,
    required this.appSlug,
    this.initialScreenshot,
    this.initialCategory = 'bug',
    this.initialSeverity = 'medium',
    this.initialTitle,
    this.initialDescription,
    this.stackTrace,
  });

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;

  late String _category;
  late String _severity;
  Uint8List? _screenshotBytes;
  bool _isSubmitting = false;
  String? _errorMessage;
  Map<String, dynamic>? _successResult;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    _severity = widget.initialSeverity;
    _screenshotBytes = widget.initialScreenshot;
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _descriptionController =
        TextEditingController(text: widget.initialDescription ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;

    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      setState(() {
        _errorMessage = 'Je moet ingelogd zijn om feedback te kunnen verzenden.';
      });
      return;
    }

    final envInfo = EnvironmentService.collect(context);

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final List<String> attachmentUrls = [];

      // 1. Upload screenshot als deze aanwezig is
      if (_screenshotBytes != null) {
        final fileName =
            '${user.id}/${DateTime.now().millisecondsSinceEpoch}_screenshot.png';
        await client.storage.from('feedback_attachments').uploadBinary(
              fileName,
              _screenshotBytes!,
              fileOptions: const FileOptions(contentType: 'image/png'),
            );
        final publicUrl =
            client.storage.from('feedback_attachments').getPublicUrl(fileName);
        attachmentUrls.add(publicUrl);
      }

      final payload = {
        'app_slug': widget.appSlug,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _category,
        'severity': _severity,
        'environment_info': envInfo,
        'attachment_urls': attachmentUrls,
        if (widget.stackTrace != null)
          'stack_trace': widget.stackTrace.toString(),
      };

      // 3. Probeer de Edge Function submit-feedback aan te roepen
      Map<String, dynamic>? resultData;
      try {
        final FunctionResponse res =
            await client.functions.invoke('submit-feedback', body: payload);
        if (res.status == 200 && res.data is Map<String, dynamic>) {
          resultData = res.data as Map<String, dynamic>;
        }
      } catch (fnErr) {
        debugPrint('[SchrobbeDockFeedback] Edge Function fallback: $fnErr');
      }

      // 4. Fallback: directe Postgres insert als de Edge Function niet draait
      if (resultData == null) {
        final appData = await client
            .from('apps')
            .select('id')
            .eq('slug', widget.appSlug)
            .maybeSingle();

        if (appData == null) {
          throw Exception('Applicatie ${widget.appSlug} niet gevonden.');
        }

        final insertRes = await client
            .from('feedback_reports')
            .insert({
              'user_id': user.id,
              'app_id': appData['id'],
              'title': payload['title'],
              'description': payload['description'],
              'category': payload['category'],
              'severity': payload['severity'],
              'environment_info': payload['environment_info'],
              'attachment_urls': payload['attachment_urls'],
              'stack_trace': payload['stack_trace'],
              'status': 'open',
            })
            .select()
            .single();

        resultData = {
          'success': true,
          'report_id': insertRes['id'],
          'github_issue_url': null,
          'github_issue_number': null,
        };
      }

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _successResult = resultData;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Fout bij verzenden: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _successResult != null
              ? _buildSuccessView(theme)
              : _buildFormView(theme),
        ),
      ),
    );
  }

  Widget _buildSuccessView(ThemeData theme) {
    final issueUrl = _successResult?['github_issue_url'] as String?;
    final issueNum = _successResult?['github_issue_number'];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_outline,
              size: 56, color: Colors.green),
        ),
        const SizedBox(height: 18),
        Text(
          'Melding Succesvol Verzonden!',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'Bedankt voor je terugkoppeling. Jouw melding is opgeslagen in het centrale systeem en helpt ons het platform te verbeteren.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        if (issueUrl != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.link, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Gekoppeld aan GitHub Issue #${issueNum ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Open URL kan via url_launcher of browser link
                  },
                  child: const Text('Bekijken'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Sluiten'),
        ),
      ],
    );
  }

  Widget _buildFormView(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.feedback_outlined,
                    color: theme.colorScheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Probleem Melden of Feedback',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'App: ${widget.appSlug}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Scrollbare Formulier Inhoud
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type Keuze
                  Text(
                    'CATEGORIE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'bug',
                          icon: Icon(Icons.bug_report_outlined, size: 16),
                          label: Text('Bug / Fout'),
                        ),
                        ButtonSegment(
                          value: 'enhancement',
                          icon: Icon(Icons.lightbulb_outline, size: 16),
                          label: Text('Verbetering'),
                        ),
                        ButtonSegment(
                          value: 'question',
                          icon: Icon(Icons.help_outline, size: 16),
                          label: Text('Vraag'),
                        ),
                      ],
                      selected: {_category},
                      onSelectionChanged: (val) {
                        setState(() => _category = val.first);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Ernst Keuze
                  Text(
                    'PRIORITEIT / ERNST',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _buildSeverityChip('low', 'Laag', Colors.green),
                      const SizedBox(width: 8),
                      _buildSeverityChip('medium', 'Normaal', Colors.orange),
                      const SizedBox(width: 8),
                      _buildSeverityChip('high', 'Dringend', Colors.red),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Titel
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Korte samenvatting *',
                      hintText: 'Wat gebeurde er of wat stel je voor?',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Vul een samenvatting in'
                        : null,
                  ),
                  const SizedBox(height: 12),

                  // Omschrijving
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Gedetailleerde toelichting *',
                      hintText:
                          'Beschrijf de stappen om het te reproduceren of jouw idee...',
                      alignLabelWithHint: true,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Vul een toelichting in'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Screenshot sectie
                  Text(
                    'SCHERMAFBEELDING & BIJLAGEN',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_screenshotBytes != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              theme.colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.memory(
                              _screenshotBytes!,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Automatische schermopname',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600)),
                                Text('Gemaakt bij het openen van dit dialoog',
                                    style: TextStyle(fontSize: 11)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            tooltip: 'Verwijder schermafbeelding',
                            onPressed: () {
                              setState(() => _screenshotBytes = null);
                            },
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              theme.colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.image_not_supported_outlined,
                              size: 20,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Geen schermafbeelding gekoppeld',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (widget.stackTrace != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Foutdetails & Crash Stacktrace worden automatisch meegezonden.',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                child: const Text('Annuleren'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _submitFeedback,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, size: 16),
                label: Text(_isSubmitting ? 'Verzenden...' : 'Melding Versturen'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeverityChip(String value, String label, Color color) {
    final isSelected = _severity == value;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : color,
      ),
      selectedColor: color,
      backgroundColor: color.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? color : color.withValues(alpha: 0.4),
        ),
      ),
      onSelected: (selected) {
        if (selected) setState(() => _severity = value);
      },
    );
  }
}
