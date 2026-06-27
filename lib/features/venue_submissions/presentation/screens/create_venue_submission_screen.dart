import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart' as core;
import 'package:dabbler/data/models/venue_submission_model.dart';
import 'package:dabbler/features/venue_submissions/providers.dart';
import 'package:dabbler/utils/constants/route_constants.dart';
import 'package:dabbler/widgets/input_field.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

typedef Result<T> = core.Result<T, Failure>;

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

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(venueSubmissionControllerProvider);
    final notifier = ref.read(venueSubmissionControllerProvider.notifier);

    final initial = widget.initial;
    final isEditing = initial != null;
    final isEditable = initial?.isEditable ?? true; // new draft is editable

    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: isWide ? 16 : MediaQuery.of(context).padding.top + 8,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Iconsax.arrow_left_copy),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      isEditing ? 'Edit submission' : 'Create submission',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isEditing)
                    Card.filled(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Iconsax.info_circle_copy),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isEditable
                                    ? 'You can edit this submission and save as draft.'
                                    : 'This submission is read-only while ${initial.status.name}.',
                                style: textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (isEditing) const SizedBox(height: 12),

                  Card.filled(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Venue details',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          CustomInputField(
                            label: 'Name (English)',
                            controller: _nameEn,
                            enabled: isEditable,
                          ),
                          const SizedBox(height: 12),
                          CustomInputField(
                            label: 'Name (Arabic)',
                            controller: _nameAr,
                            enabled: isEditable,
                          ),
                          const SizedBox(height: 12),
                          CustomTextArea(
                            label: 'Description (English)',
                            controller: _descriptionEn,
                            enabled: isEditable,
                            minLines: 3,
                            maxLines: 6,
                          ),
                          const SizedBox(height: 12),
                          CustomTextArea(
                            label: 'Description (Arabic)',
                            controller: _descriptionAr,
                            enabled: isEditable,
                            minLines: 3,
                            maxLines: 6,
                          ),
                          const SizedBox(height: 12),
                          CustomInputField(
                            label: 'City',
                            controller: _city,
                            enabled: isEditable,
                          ),
                          const SizedBox(height: 12),
                          CustomInputField(
                            label: 'District',
                            controller: _district,
                            enabled: isEditable,
                          ),
                          const SizedBox(height: 12),
                          CustomInputField(
                            label: 'Area',
                            controller: _area,
                            enabled: isEditable,
                          ),
                          const SizedBox(height: 12),
                          CustomInputField(
                            label: 'Address line 1',
                            controller: _addressLine1,
                            enabled: isEditable,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: CustomInputField(
                                  label: 'Latitude',
                                  controller: _lat,
                                  enabled: isEditable,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: CustomInputField(
                                  label: 'Longitude',
                                  controller: _lng,
                                  enabled: isEditable,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          CustomInputField(
                            label: 'Phone',
                            controller: _phone,
                            enabled: isEditable,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 12),
                          CustomInputField(
                            label: 'Website',
                            controller: _website,
                            enabled: isEditable,
                            keyboardType: TextInputType.url,
                          ),
                          const SizedBox(height: 12),
                          CustomInputField(
                            label: 'Instagram',
                            controller: _instagram,
                            enabled: isEditable,
                          ),
                          const SizedBox(height: 12),
                          SwitchListTile.adaptive(
                            value: _isIndoor,
                            onChanged: isEditable
                                ? (v) => setState(() => _isIndoor = v)
                                : null,
                            title: const Text('Indoor venue'),
                          ),
                          const SizedBox(height: 8),
                          CustomInputField(
                            label: 'Surface type',
                            controller: _surfaceType,
                            enabled: isEditable,
                          ),
                          const SizedBox(height: 12),
                          CustomInputField(
                            label: 'Amenities (comma separated)',
                            controller: _amenities,
                            enabled: isEditable,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Card.filled(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton.icon(
                            onPressed: (!isEditable || controller.isSaving)
                                ? null
                                : () async {
                                    final organiserIdRes = await ref.read(
                                      organiserProfileIdProvider.future,
                                    );
                                    final organiserId = organiserIdRes.fold(
                                      (_) => null,
                                      (id) => id,
                                    );
                                    if (organiserId == null) {
                                      final msg =
                                          organiserIdRes.requireError.message;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text(msg)),
                                      );
                                      return;
                                    }

                                    final draft = _buildDraft(
                                      initialId: initial?.id,
                                    );
                                    final saveRes = await notifier.saveDraft(
                                      organiserProfileId: organiserId,
                                      draft: draft,
                                      existing: initial,
                                    );

                                    saveRes.match(
                                      (failure) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(failure.message),
                                          ),
                                        );
                                      },
                                      (saved) {
                                        ref.invalidate(
                                          myVenueSubmissionsProvider,
                                        );
                                        ref.invalidate(
                                          venueSubmissionByIdProvider(saved.id),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Draft saved.'),
                                          ),
                                        );
                                        context.go(
                                          RoutePaths.venueSubmissionDetail(
                                            saved.id,
                                          ),
                                        );
                                      },
                                    );
                                  },
                            icon: const Icon(Iconsax.save_2_copy),
                            label: const Text('Save as draft'),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                            onPressed: (!isEditable || controller.isSaving)
                                ? null
                                : () async {
                                    final id = initial?.id;
                                    if (id == null || id.isEmpty) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Save the draft first.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    if (!(initial?.canSubmitForReview ??
                                        true)) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'You can only submit drafts or returned submissions.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }

                                    final res = await notifier.submitForReview(
                                      submissionId: id,
                                      existing: initial,
                                    );

                                    res.match(
                                      (failure) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(failure.message),
                                          ),
                                        );
                                      },
                                      (_) {
                                        ref.invalidate(
                                          myVenueSubmissionsProvider,
                                        );
                                        ref.invalidate(
                                          venueSubmissionByIdProvider(id),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Submitted for review.',
                                            ),
                                          ),
                                        );
                                        context.go(
                                          RoutePaths.venueSubmissionDetail(id),
                                        );
                                      },
                                    );
                                  },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Iconsax.send_2_copy),
                                const SizedBox(width: 8),
                                const Text('Submit for review'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
