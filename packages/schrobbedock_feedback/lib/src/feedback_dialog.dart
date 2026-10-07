import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'environment_service.dart';
import 'feedback_portal_view.dart';

/// Representeert een bijlage (automatische schermopname of door de gebruiker gekozen afbeelding)
class FeedbackAttachment {
  final String id;
  final String name;
  final Uint8List bytes;
  final bool isAutoScreenshot;

  const FeedbackAttachment({
    required this.id,
    required this.name,
    required this.bytes,
    this.isAutoScreenshot = false,
  });
}

class FeedbackDialog extends StatefulWidget {
  final String appSlug;
  final Uint8List? initialScreenshot;
  final String initialCategory;
  final String initialSeverity;
  final String? initialTitle;
  final String? initialDescription;
  final StackTrace? stackTrace;
  final bool showGitHubLink;

  const FeedbackDialog({
    super.key,
    required this.appSlug,
    this.initialScreenshot,
    this.initialCategory = 'bug',
    this.initialSeverity = 'medium',
    this.initialTitle,
    this.initialDescription,
    this.stackTrace,
    this.showGitHubLink = false,
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
  final List<FeedbackAttachment> _attachments = [];
  bool _isSubmitting = false;
  String? _errorMessage;
  Map<String, dynamic>? _successResult;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    _severity = widget.initialSeverity;
    if (widget.initialScreenshot != null) {
      _attachments.add(
        FeedbackAttachment(
          id: 'auto_screenshot',
          name: 'Schermopname',
          bytes: widget.initialScreenshot!,
          isAutoScreenshot: true,
        ),
      );
    }
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

  Future<void> _pickImages() async {
    const maxAttachments = 5;
    if (_attachments.length >= maxAttachments) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Je kunt maximaal 5 afbeeldingen toevoegen.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final picker = ImagePicker();
      final List<XFile> picked = await picker.pickMultiImage();
      if (picked.isEmpty) return;

      for (final file in picked) {
        if (_attachments.length >= maxAttachments) break;
        final bytes = await file.readAsBytes();
        _attachments.add(
          FeedbackAttachment(
            id: 'att_${DateTime.now().microsecondsSinceEpoch}',
            name: file.name.isNotEmpty ? file.name : 'Bijlage ${_attachments.length + 1}',
            bytes: bytes,
            isAutoScreenshot: false,
          ),
        );
      }
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kon afbeelding(en) niet selecteren: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showImagePreview(FeedbackAttachment att) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              clipBehavior: Clip.none,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  att.bytes,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.65),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

      // 1. Upload alle bijlagen naar Supabase Storage (indien aanwezig)
      for (int i = 0; i < _attachments.length; i++) {
        final att = _attachments[i];
        final fileName =
            '${user.id}/${DateTime.now().millisecondsSinceEpoch}_${i + 1}.png';
        await client.storage.from('feedback_attachments').uploadBinary(
              fileName,
              att.bytes,
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
        if (widget.showGitHubLink && issueUrl != null) ...[
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
                  onPressed: () async {
                    final uri = Uri.tryParse(issueUrl);
                    if (uri != null) {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                        webOnlyWindowName: '_blank',
                      );
                    }
                  },
                  child: const Text('Bekijken'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                final isMobile = MediaQuery.of(context).size.width < 700;
                if (isMobile) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (ctx) => FeedbackPortalView(
                        appSlug: widget.appSlug,
                        onClose: () => Navigator.of(ctx).pop(),
                      ),
                    ),
                  );
                } else {
                  showDialog(
                    context: context,
                    builder: (ctx) => Dialog(
                      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: SizedBox(
                        width: 1000,
                        height: 700,
                        child: FeedbackPortalView(
                          appSlug: widget.appSlug,
                          onClose: () => Navigator.of(ctx).pop(),
                        ),
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.support_agent_outlined, size: 18),
              label: const Text('Volg in Mijn Meldingen'),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Sluiten'),
            ),
          ],
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

                  // Screenshot & Bijlagen sectie (0 tot 5 bijlagen)
                  _buildAttachmentsSection(theme),

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

  Widget _buildAttachmentsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'BIJLAGEN (${_attachments.length}/5)',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: theme.colorScheme.primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_attachments.length < 5)
              TextButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
                label: const Text('Toevoegen', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_attachments.isNotEmpty)
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _attachments.length + (_attachments.length < 5 ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                if (index == _attachments.length) {
                  return _buildAddTile(theme);
                }
                final att = _attachments[index];
                return _buildAttachmentThumbnail(theme, att, index);
              },
            ),
          )
        else
          InkWell(
            onTap: _pickImages,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add_photo_alternate_outlined,
                        size: 20, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Geen bijlagen (optioneel)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Klik hier om zelf afbeeldingen of foto\'s toe te voegen (max 5)',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      size: 20, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAttachmentThumbnail(ThemeData theme, FeedbackAttachment att, int index) {
    return Container(
      width: 90,
      height: 96,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Stack(
          fit: StackFit.expand,
          children: [
            InkWell(
              onTap: () => _showImagePreview(att),
              child: Image.memory(
                att.bytes,
                fit: BoxFit.cover,
              ),
            ),
            // Bottom label
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                color: Colors.black.withValues(alpha: 0.65),
                child: Text(
                  att.isAutoScreenshot ? 'Schermopname' : att.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            // Delete button top right
            Positioned(
              top: 4,
              right: 4,
              child: InkWell(
                key: Key('delete_attachment_$index'),
                onTap: () {
                  setState(() {
                    _attachments.removeAt(index);
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddTile(ThemeData theme) {
    return InkWell(
      onTap: _pickImages,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 80,
        height: 96,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 24, color: theme.colorScheme.primary),
            const SizedBox(height: 4),
            Text(
              'Toevoegen',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
