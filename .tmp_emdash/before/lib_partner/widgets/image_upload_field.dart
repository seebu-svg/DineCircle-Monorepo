import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_exception.dart';
import '../providers/app_providers.dart';
import '../repositories/image_repository.dart';
import '../services/image_picker_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';
import 'media_image.dart';

/// Uploads [bytes] and returns the stored path. Shared by every photo field so
/// the size check, the error sentences and the superseded-photo cleanup can
/// never drift between the profile, a dish and a deal.
Future<String> uploadVenuePhoto(
  WidgetRef ref, {
  required String venueId,
  required Uint8List bytes,
  required String kind,
  void Function(double progress)? onProgress,
}) {
  return ref.read(imageRepositoryProvider).upload(
    venueId,
    bytes,
    kind: kind,
    onProgress: onProgress,
  );
}

/// Retires the photo a replacement superseded. Best effort by design: a failure
/// here leaves one orphaned row and never fails the upload the partner just
/// completed.
void retireSupersededPhoto(WidgetRef ref, String venueId, String? previous) {
  final id = venueImageId(previous);
  if (id == null) return;
  ref.read(imageRepositoryProvider).delete(venueId, id).catchError((_) {});
}

/// One photo with its own upload, replace and remove controls.
///
/// Controlled: it renders [value] and reports the new stored path through
/// [onChanged]; it does not hold the value. That keeps the surrounding form the
/// single source of truth, so an unsaved form and an unsaved photo cannot
/// disagree — and a screen that saves on every edit never needs to re-read.
class ImageUploadField extends ConsumerStatefulWidget {
  const ImageUploadField({
    super.key,
    required this.venueId,
    required this.label,
    required this.value,
    required this.onChanged,
    this.kind = 'general',
    this.aspectRatio = 16 / 9,
    this.helperText,
    this.enabled = true,
    this.previewKey,
  });

  final String venueId;
  final String label;

  /// Current stored value; empty when there is no photo yet.
  final String value;

  /// Called with the uploaded path, or with '' when the photo is removed.
  final ValueChanged<String> onChanged;

  /// Upload metadata: `logo`, `cover`, `menu_item`, `deal`, `gallery`, …
  final String kind;
  final double aspectRatio;
  final String? helperText;

  /// False while the surrounding form is read-only or saving.
  final bool enabled;

  /// Lets a test or screenshot target the preview specifically.
  final Key? previewKey;

  @override
  ConsumerState<ImageUploadField> createState() => _ImageUploadFieldState();
}

class _ImageUploadFieldState extends ConsumerState<ImageUploadField> {
  bool _busy = false;
  String? _error;
  double? _progress;

  Future<void> _pick(ImageSourceChoice source) async {
    if (_busy || !widget.enabled) return;
    final Uint8List? bytes;
    try {
      bytes = await ref.read(venueImagePickerProvider)(source);
    } on PlatformException catch (error) {
      if (mounted) setState(() => _error = imagePickerError(error, source));
      return;
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open that photo. Try another one.');
      }
      return;
    }
    if (bytes == null || !mounted) return; // cancelled
    if (bytes.isEmpty) {
      setState(() => _error = 'Could not open that photo. Try another one.');
      return;
    }
    if (bytes.length > kMaxVenueImageBytes) {
      setState(
        () => _error = 'That photo is too large. Keep it under 512 KB.',
      );
      return;
    }
    await _upload(bytes);
  }

  Future<void> _upload(Uint8List bytes) async {
    final previous = widget.value;
    setState(() {
      _busy = true;
      _error = null;
      _progress = null;
    });
    try {
      final url = await uploadVenuePhoto(
        ref,
        venueId: widget.venueId,
        bytes: bytes,
        kind: widget.kind,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _progress = null;
      });
      widget.onChanged(url);
      retireSupersededPhoto(ref, widget.venueId, previous);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _progress = null;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _progress = null;
        _error = 'Could not upload that photo. Please try again.';
      });
    }
  }

  void _remove() {
    if (_busy || !widget.enabled) return;
    widget.onChanged('');
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = widget.value.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AppTextStyles.titleSmall),
        if (widget.helperText != null) ...[
          const SizedBox(height: 2),
          Text(
            widget.helperText!,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Stack(
              key: widget.previewKey,
              fit: StackFit.expand,
              children: [
                MediaImage(
                  source: widget.value,
                  fallbackIcon: Icons.add_photo_alternate_outlined,
                ),
                if (_busy)
                  ColoredBox(
                    color: AppColors.scrim,
                    child: Center(
                      child: SizedBox(
                        width: 140,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusPill,
                              ),
                              child: LinearProgressIndicator(
                                key: const Key('imageUploadProgress'),
                                value: _progress,
                                minHeight: 6,
                                backgroundColor: AppColors.surfaceHigh,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              _progress == null
                                  ? 'Uploading photo…'
                                  : 'Uploading… '
                                      '${(_progress! * 100).round()}%',
                              style: AppTextStyles.caption,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.tonalIcon(
              key: const Key('imageUploadChoose'),
              onPressed: widget.enabled && !_busy
                  ? () => _pick(ImageSourceChoice.gallery)
                  : null,
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: Text(hasPhoto ? 'Change photo' : 'Choose photo'),
            ),
            IconButton.outlined(
              key: const Key('imageUploadCamera'),
              tooltip: 'Take a photo',
              onPressed: widget.enabled && !_busy
                  ? () => _pick(ImageSourceChoice.camera)
                  : null,
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
            ),
            if (hasPhoto)
              TextButton(
                key: const Key('imageUploadRemove'),
                onPressed: widget.enabled && !_busy ? _remove : null,
                child: Text(
                  'Remove',
                  style: TextStyle(color: AppColors.danger),
                ),
              ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            _error!,
            key: const Key('imageUploadError'),
            style: AppTextStyles.caption.copyWith(color: AppColors.danger),
          ),
        ],
      ],
    );
  }
}

/// The venue gallery: existing photos plus an add tile.
///
/// One widget rather than a list of [ImageUploadField]s because a gallery is a
/// `text[]` — adding and removing shift the array, so each tile cannot own a
/// slot the way a single-value field owns its value.
class VenueGalleryField extends ConsumerStatefulWidget {
  const VenueGalleryField({
    super.key,
    required this.venueId,
    required this.images,
    required this.onChanged,
    this.maxImages = 8,
    this.enabled = true,
  });

  final String venueId;
  final List<String> images;
  final ValueChanged<List<String>> onChanged;
  final int maxImages;
  final bool enabled;

  @override
  ConsumerState<VenueGalleryField> createState() => _VenueGalleryFieldState();
}

class _VenueGalleryFieldState extends ConsumerState<VenueGalleryField> {
  bool _busy = false;
  String? _error;

  Future<void> _add() async {
    if (_busy || !widget.enabled) return;
    final Uint8List? bytes;
    try {
      bytes = await ref.read(venueImagePickerProvider)(
        ImageSourceChoice.gallery,
      );
    } on PlatformException catch (error) {
      if (mounted) {
        setState(
          () => _error = imagePickerError(error, ImageSourceChoice.gallery),
        );
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open that photo. Try another one.');
      }
      return;
    }
    if (bytes == null || !mounted) return;
    if (bytes.length > kMaxVenueImageBytes) {
      setState(
        () => _error = 'That photo is too large. Keep it under 512 KB.',
      );
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final url = await uploadVenuePhoto(
        ref,
        venueId: widget.venueId,
        bytes: bytes,
        kind: 'gallery',
      );
      if (!mounted) return;
      setState(() => _busy = false);
      widget.onChanged([...widget.images, url]);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not upload that photo. Please try again.';
      });
    }
  }

  void _removeAt(int index) {
    if (!widget.enabled) return;
    final next = [...widget.images]..removeAt(index);
    widget.onChanged(next);
    final removed = widget.images[index];
    retireSupersededPhoto(ref, widget.venueId, removed);
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = widget.enabled && !_busy && widget.images.length < widget.maxImages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gallery', style: AppTextStyles.titleSmall),
        const SizedBox(height: 2),
        Text(
          'Photos guests see on your profile: up to ${widget.maxImages}.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (var i = 0; i < widget.images.length; i++)
              _GalleryTile(
                key: ValueKey('galleryTile$i'),
                source: widget.images[i],
                onRemove: widget.enabled ? () => _removeAt(i) : null,
              ),
            if (widget.images.length < widget.maxImages)
              _AddTile(busy: _busy, onTap: canAdd ? _add : null),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            _error!,
            key: const Key('galleryUploadError'),
            style: AppTextStyles.caption.copyWith(color: AppColors.danger),
          ),
        ],
      ],
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({super.key, required this.source, this.onRemove});

  final String source;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: MediaImage(source: source),
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: 2,
              right: 2,
              child: Material(
                color: AppColors.scrim,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Remove photo',
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  onPressed: onRemove,
                  icon: const Icon(Icons.close, color: AppColors.textPrimary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.busy, this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Material(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          key: const Key('galleryAddTile'),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          onTap: onTap,
          child: Center(
            child: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.add_a_photo_outlined,
                    color: AppColors.textTertiary,
                  ),
          ),
        ),
      ),
    );
  }
}
