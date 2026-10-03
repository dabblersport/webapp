import 'package:dabbler_design_system/dabbler_design_system.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart' as core;
import 'package:dabbler/data/models/venue_submission_model.dart';
import 'package:dabbler/features/venue_submissions/presentation/controllers/venue_submission_controller.dart';
import 'package:dabbler/features/venue_submissions/providers.dart';
import 'package:dabbler/utils/constants/route_constants.dart';

typedef Result<T> = core.Result<T, Failure>;

/// No design frame: design-system defaults in the same structure.
class CreateVenueSubmissionScreen extends ConsumerStatefulWidget {
  final VenueSubmissionModel? initial;

  const CreateVenueSubmissionScreen({super.key, this.initial});

  @override
  ConsumerState<CreateVenueSubmissionScreen> createState() =>
      _CreateVenueSubmissionScreenState();
}

class _CreateVenueSubmissionScreenState
    extends ConsumerState<CreateVenueSubmissionScreen> {
  late final TextEditingController _nameEn;
  late final TextEditingController _nameAr;
  late final TextEditingController _descriptionEn;
  late final TextEditingController _descriptionAr;
  late final TextEditingController _city;
  late final TextEditingController _district;
  late final TextEditingController _area;
  late final TextEditingController _addressLine1;
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  late final TextEditingController _phone;
  late final TextEditingController _website;
  late final TextEditingController _instagram;
  late final TextEditingController _surfaceType;
  late final TextEditingController _amenities;

  bool _isIndoor = false;

  @override
  void initState() {
    super.initState();

    final initial = widget.initial;

    _nameEn = TextEditingController(text: initial?.nameEn ?? '');
    _nameAr = TextEditingController(text: initial?.nameAr ?? '');
    _descriptionEn = TextEditingController(text: initial?.descriptionEn ?? '');
    _descriptionAr = TextEditingController(text: initial?.descriptionAr ?? '');
    _city = TextEditingController(text: initial?.city ?? '');
    _district = TextEditingController(text: initial?.district ?? '');
    _area = TextEditingController(text: initial?.area ?? '');
    _addressLine1 = TextEditingController(text: initial?.addressLine1 ?? '');
    _lat = TextEditingController(text: initial?.lat?.toString() ?? '');
    _lng = TextEditingController(text: initial?.lng?.toString() ?? '');
    _phone = TextEditingController(text: initial?.phone ?? '');
    _website = TextEditingController(text: initial?.website ?? '');
    _instagram = TextEditingController(text: initial?.instagram ?? '');
    _surfaceType = TextEditingController(text: initial?.surfaceType ?? '');
    _amenities = TextEditingController(
      text: (initial?.amenities ?? const []).join(', '),
    );

    _isIndoor = initial?.isIndoor ?? false;
  }

  @override
  void dispose() {
    _nameEn.dispose();
    _nameAr.dispose();
    _descriptionEn.dispose();
    _descriptionAr.dispose();
    _city.dispose();
    _district.dispose();
    _area.dispose();
    _addressLine1.dispose();
    _lat.dispose();
    _lng.dispose();
    _phone.dispose();
    _website.dispose();
    _instagram.dispose();
    _surfaceType.dispose();
    _amenities.dispose();
    super.dispose();
  }

  /// The SnackBar messages, now DS toasts (same text).
  void _toast(String message) {
    if (!mounted) return;
    DabblerToastProvider.of(context).show(DabblerToastSpec(message: message));
  }

  Widget _field(
    String label,
    TextEditingController controller,
    bool enabled, {
    TextInputType? keyboardType,
  }) => DabblerTextField(
    label: label,
    controller: controller,
    enabled: enabled,
    keyboardType: keyboardType,
  );

  Widget _textArea(
    String label,
    TextEditingController controller,
    bool enabled,
  ) => DabblerTextField(
    variant: DabblerTextFieldVariant.multiline,
    label: label,
    controller: controller,
    enabled: enabled,
    rows: 3,
  );

  Future<void> _saveDraft(
    VenueSubmissionModel? initial,
    VenueSubmissionController notifier,
  ) async {
    final organiserIdRes = await ref.read(organiserProfileIdProvider.future);
    final organiserId = organiserIdRes.fold((_) => null, (id) => id);
    if (organiserId == null) {
      _toast(organiserIdRes.requireError.message);
      return;
    }

    final draft = _buildDraft(initialId: initial?.id);
    final saveRes = await notifier.saveDraft(
      organiserProfileId: organiserId,
      draft: draft,
      existing: initial,
    );

    saveRes.match((failure) => _toast(failure.message), (saved) {
      ref.invalidate(myVenueSubmissionsProvider);
      ref.invalidate(venueSubmissionByIdProvider(saved.id));
      _toast('Draft saved.');
      if (!mounted) return;
      context.go(RoutePaths.venueSubmissionDetail(saved.id));
    });
  }

  Future<void> _submitForReview(
    VenueSubmissionModel? initial,
    VenueSubmissionController notifier,
  ) async {
    final id = initial?.id;
    if (id == null || id.isEmpty) {
      _toast('Save the draft first.');
      return;
    }

    if (!(initial?.canSubmitForReview ?? true)) {
      _toast('You can only submit drafts or returned submissions.');
      return;
    }

    final res = await notifier.submitForReview(
      submissionId: id,
      existing: initial,
    );

    res.match((failure) => _toast(failure.message), (_) {
      ref.invalidate(myVenueSubmissionsProvider);
      ref.invalidate(venueSubmissionByIdProvider(id));
      _toast('Submitted for review.');
      if (!mounted) return;
      context.go(RoutePaths.venueSubmissionDetail(id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(venueSubmissionControllerProvider);
    final notifier = ref.read(venueSubmissionControllerProvider.notifier);

    final initial = widget.initial;
    final isEditing = initial != null;
    final isEditable = initial?.isEditable ?? true; // new draft is editable
    final colors = DabblerColors.of(context);

    const gap = SizedBox(height: DabblerSpacing.space3);

    // One layout at every width (AdaptiveScaffold is not a DS component).
    return DabblerPage(
      topBar: DabblerNavigationTopBar.titled(
        title: isEditing ? 'Edit submission' : 'Create submission',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsetsDirectional.fromSTEB(
          DabblerSpacing.space6,
          DabblerSpacing.space3,
          DabblerSpacing.space6,
          DabblerSpacing.space6,
        ),
        children: [
          if (isEditing) ...[
            DabblerBanner(
              icon: const DabblerIcon('info-circle'),
              message: isEditable
                  ? 'You can edit this submission and save as draft.'
                  : 'This submission is read-only while ${initial.status.name}.',
            ),
            gap,
          ],
          DabblerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Venue details',
                  style: DabblerType.headline
                      .resolveForDirection(Directionality.of(context))
                      .copyWith(color: colors.textPrimary),
                ),
                gap,
                _field('Name (English)', _nameEn, isEditable),
                gap,
                _field('Name (Arabic)', _nameAr, isEditable),
                gap,
                _textArea('Description (English)', _descriptionEn, isEditable),
                gap,
                _textArea('Description (Arabic)', _descriptionAr, isEditable),
                gap,
                _field('City', _city, isEditable),
                gap,
                _field('District', _district, isEditable),
                gap,
                _field('Area', _area, isEditable),
                gap,
                _field('Address line 1', _addressLine1, isEditable),
                gap,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _field(
                        'Latitude',
                        _lat,
                        isEditable,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: DabblerSpacing.space3),
                    Expanded(
                      child: _field(
                        'Longitude',
                        _lng,
                        isEditable,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                gap,
                _field(
                  'Phone',
                  _phone,
                  isEditable,
                  keyboardType: TextInputType.phone,
                ),
                gap,
                _field(
                  'Website',
                  _website,
                  isEditable,
                  keyboardType: TextInputType.url,
                ),
                gap,
                _field('Instagram', _instagram, isEditable),
                gap,
                DabblerInputRow(
                  title: 'Indoor venue',
                  enabled: isEditable,
                  trailing: DabblerToggle(
                    checked: _isIndoor,
                    disabled: !isEditable,
                    semanticLabel: 'Indoor venue',
                    onChanged: isEditable
                        ? (v) => setState(() => _isIndoor = v)
                        : null,
                  ),
                ),
                const SizedBox(height: DabblerSpacing.space2),
                _field('Surface type', _surfaceType, isEditable),
                gap,
                _field('Amenities (comma separated)', _amenities, isEditable),
              ],
            ),
          ),
          gap,
          DabblerCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DabblerButton(
                  label: 'Save as draft',
                  icon: 'save-2',
                  fullWidth: true,
                  disabled: !isEditable || controller.isSaving,
                  onPressed: () => _saveDraft(initial, notifier),
                ),
                gap,
                DabblerButton(
                  label: 'Submit for review',
                  icon: 'send-2',
                  tone: DabblerButtonTone.outlined,
                  fullWidth: true,
                  disabled: !isEditable || controller.isSaving,
                  onPressed: () => _submitForReview(initial, notifier),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  VenueSubmissionDraft _buildDraft({String? initialId}) {
    final amenities = _amenities.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);

    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());

    return VenueSubmissionDraft(
      id: initialId,
      nameEn: _nameEn.text,
      nameAr: _nameAr.text,
      descriptionEn: _descriptionEn.text,
      descriptionAr: _descriptionAr.text,
      city: _city.text,
      district: _district.text,
      area: _area.text,
      addressLine1: _addressLine1.text,
      lat: lat,
      lng: lng,
      phone: _phone.text,
      website: _website.text,
      instagram: _instagram.text,
      isIndoor: _isIndoor,
      surfaceType: _surfaceType.text,
      amenities: amenities,
    );
  }
}
