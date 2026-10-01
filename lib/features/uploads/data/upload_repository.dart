// Mirrors openapi/api.yaml -> UploadRead, UploadPurpose. Guide: sdk-contract/docs/media-uploads-api.md.
//
// Upload first, attach second: send the returned `key` where the file belongs (for
// buyers: `evidence_keys` of a refund request). Never store or send `url`.

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/endpoints.dart';
import '../../../core/api/providers.dart';
import '../../catalog/data/common.dart';

enum UploadPurpose {
  shopLogo('shop_logo'),
  shopBanner('shop_banner'),
  productImage('product_image'),
  sellerDocument('seller_document'),
  refundEvidence('refund_evidence');

  const UploadPurpose(this.wire);

  final String wire;
}

class UploadRead {
  const UploadRead({
    required this.id,
    required this.key,
    required this.url,
    required this.contentType,
    required this.sizeBytes,
    this.width,
    this.height,
  });

  factory UploadRead.fromJson(Json json) => UploadRead(
    id: json['id'] as int,
    key: json['key'] as String,
    url: json['url'] as String,
    contentType: json['content_type'] as String,
    sizeBytes: json['size_bytes'] as int,
    width: json['width'] as int?,
    height: json['height'] as int?,
  );

  final int id;

  /// Send this when attaching the file.
  final String key;

  /// For an immediate preview only. Private purposes (refund evidence) get a signed
  /// 15-minute link.
  final String url;
  final String contentType;
  final int sizeBytes;
  final int? width;
  final int? height;
}

/// Login required. Limits (docs/media-uploads-api.md): max 10 MB, JPEG/PNG/WebP only,
/// **HEIC is not accepted** (convert to JPEG first), and buyers get 30 refund-evidence
/// uploads a day (`400 "Too many uploads today - try again tomorrow"`).
class UploadRepository {
  const UploadRepository(this._dio);

  final Dio _dio;

  Future<UploadRead> upload({
    required UploadPurpose purpose,
    required Uint8List bytes,
    required String filename,
  }) async {
    final response = await _dio.post<Json>(
      UploadEndpoints.uploads,
      queryParameters: {'purpose': purpose.wire},
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      }),
    );
    return UploadRead.fromJson(response.data!);
  }

  Future<UploadRead> uploadRefundEvidence(
    Uint8List bytes, {
    required String filename,
  }) => upload(
    purpose: UploadPurpose.refundEvidence,
    bytes: bytes,
    filename: filename,
  );
}

final uploadRepositoryProvider = Provider<UploadRepository>(
  (ref) => UploadRepository(ref.watch(dioProvider)),
);
