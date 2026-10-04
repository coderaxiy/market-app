import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/settings/settings.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_widgets.dart';
import '../../uploads/data/upload_repository.dart';
import '../application/photo_picker.dart';
import '../data/order.dart';
import '../data/order_repository.dart';
import '../data/refund.dart';

/// Opens the return form for [line]. Completes with true when a request was sent.
Future<bool> showReturnSheet(BuildContext context, OrderLineRead line) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => ReturnSheet(line: line),
  );
  return sent ?? false;
}

String _reasonKey(RefundReasonCode code) => switch (code) {
  RefundReasonCode.defective => 'return.reasonDefective',
  RefundReasonCode.notAsDescribed => 'return.reasonNotAsDescribed',
  RefundReasonCode.wrongItem => 'return.reasonWrongItem',
  RefundReasonCode.changedMind => 'return.reasonChangedMind',
  RefundReasonCode.neverArrived => 'return.reasonNeverArrived',
  RefundReasonCode.other => 'return.reasonOther',
};

/// Reason, optional text and up to five photos. Refunds are all-or-nothing: the buyer gets
/// the item's full price, so there is no amount to enter. Photos are uploaded first, then
/// their keys go with the request.
class ReturnSheet extends ConsumerStatefulWidget {
  const ReturnSheet({super.key, required this.line});

  final OrderLineRead line;

  @override
  ConsumerState<ReturnSheet> createState() => _ReturnSheetState();
}

class _ReturnSheetState extends ConsumerState<ReturnSheet> {
  var _reason = RefundReasonCode.defective;
  final _details = TextEditingController();
  final _photos = <PickedPhoto>[];
  var _detailsMissing = false;
  String? _error;
  var _busy = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _addPhoto(PhotoSource source) async {
    final photo = await ref.read(photoPickerProvider).pick(source);
    if (photo != null && mounted) setState(() => _photos.add(photo));
  }

  Future<void> _submit() async {
    final t = ref.read(tProvider);
    final text = _details.text.trim();
    setState(() {
      _detailsMissing = _reason == RefundReasonCode.other && text.isEmpty;
      _error = null;
    });
    if (_detailsMissing) return;

    setState(() => _busy = true);
    final uploads = ref.read(uploadRepositoryProvider);
    try {
      final keys = <String>[];
      for (final photo in _photos) {
        try {
          final upload = await uploads.uploadRefundEvidence(
            photo.bytes,
            filename: photo.filename,
          );
          keys.add(upload.key);
        } catch (error) {
          if (!mounted) return;
          // e.g. "Too many uploads today - try again tomorrow" is a string: show it.
          setState(() {
            _busy = false;
            _error = apiErrorMessage(error, t('return.uploadFailed'));
          });
          return;
        }
      }
      await ref
          .read(orderRepositoryProvider)
          .requestRefund(
            widget.line.id,
            reasonCode: _reason,
            reasonText: text,
            evidenceKeys: keys,
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = apiErrorMessage(error, t('return.failed'));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final colors = AppColors.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t('return.title'), style: text.titleLarge),
            const SizedBox(height: 4),
            Text(widget.line.productTitleSnapshot),
            const SizedBox(height: 4),
            Text(
              t('return.refundNote'),
              style: text.bodySmall?.copyWith(color: colors.mutedForeground),
            ),
            const SizedBox(height: 16),
            if (_error != null) FormErrorBanner(_error!),
            Text(t('return.reason'), style: text.titleSmall),
            RadioGroup<RefundReasonCode>(
              groupValue: _reason,
              onChanged: (value) => setState(() => _reason = value ?? _reason),
              child: Column(
                children: [
                  for (final code in RefundReasonCode.values)
                    RadioListTile<RefundReasonCode>(
                      value: code,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(t(_reasonKey(code))),
                    ),
                ],
              ),
            ),
            TextField(
              controller: _details,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: t('return.details'),
                errorText: _detailsMissing ? t('return.detailsRequired') : null,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t('return.photos', {'max': maxRefundEvidence}),
              style: text.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _photos.length; i++)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: Image.memory(
                            _photos[i].bytes,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => ColoredBox(
                              color: colors.muted,
                              child: const Icon(Icons.image_outlined),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: -4,
                        right: -4,
                        child: IconButton(
                          tooltip: t('return.removePhoto'),
                          visualDensity: VisualDensity.compact,
                          onPressed: _busy
                              ? null
                              : () => setState(() => _photos.removeAt(i)),
                          icon: const Icon(Icons.cancel, size: 20),
                        ),
                      ),
                    ],
                  ),
                if (_photos.length < maxRefundEvidence)
                  PopupMenuButton<PhotoSource>(
                    enabled: !_busy,
                    onSelected: _addPhoto,
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: PhotoSource.camera,
                        child: Text(t('return.camera')),
                      ),
                      PopupMenuItem(
                        value: PhotoSource.gallery,
                        child: Text(t('return.gallery')),
                      ),
                    ],
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.input),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Semantics(
                        label: t('return.addPhoto'),
                        child: const Icon(Icons.add_a_photo_outlined),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            SubmitButton(
              label: _busy ? t('return.sending') : t('return.submit'),
              busy: _busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
