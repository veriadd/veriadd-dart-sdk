/// Request/response types for the Veriadd API. Field-for-field with the
/// REST payloads documented at https://veriadd.tech/docs/api.

/// Lenient map cast: returns null instead of throwing on unexpected shapes.
Map<String, dynamic>? _optMap(dynamic v) =>
    v is Map<String, dynamic> ? v : (v is Map ? v.cast<String, dynamic>() : null);

/// Input for [VeriaddClient.verifyAddress]. Only [postcode] is required.
class VeriaddVerifyInput {
  final String postcode;
  final String? street;
  final String? lga;
  final String? state;
  final String? firstName;
  final String? lastName;

  /// Date of birth, yyyy-mm-dd.
  final String? dob;
  final String? phone;

  /// 11-digit Bank Verification Number.
  final String? bvn;

  /// 11-digit National Identification Number.
  final String? nin;
  final double? lat;
  final double? lng;

  /// NIPOST lookup depth 1–5. Billing: L1 free, L2 ₦30, L3+ ₦50. Defaults to 3.
  final int? level;

  const VeriaddVerifyInput({
    required this.postcode,
    this.street,
    this.lga,
    this.state,
    this.firstName,
    this.lastName,
    this.dob,
    this.phone,
    this.bvn,
    this.nin,
    this.lat,
    this.lng,
    this.level,
  });

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{'postcode': postcode};
    if (street != null) m['street'] = street;
    if (lga != null) m['lga'] = lga;
    if (state != null) m['state'] = state;
    if (firstName != null) m['first_name'] = firstName;
    if (lastName != null) m['last_name'] = lastName;
    if (dob != null) m['dob'] = dob;
    if (phone != null) m['phone'] = phone;
    if (bvn != null) m['bvn'] = bvn;
    if (nin != null) m['nin'] = nin;
    if (lat != null) m['lat'] = lat;
    if (lng != null) m['lng'] = lng;
    if (level != null) m['level'] = level;
    return m;
  }
}

/// NIPOST graded lookup payload (levels are cumulative).
class VeriaddNipostLookup {
  final String postcode;
  final bool valid;
  final Map<String, dynamic>? administrativeAddress;
  final Map<String, dynamic>? recentHouseAddress;
  final String? buildingUseStatus;

  const VeriaddNipostLookup({
    required this.postcode,
    required this.valid,
    this.administrativeAddress,
    this.recentHouseAddress,
    this.buildingUseStatus,
  });

  factory VeriaddNipostLookup.fromJson(Map<String, dynamic> json) {
    return VeriaddNipostLookup(
      postcode: json['postcode'] as String? ?? '',
      valid: json['valid'] as bool? ?? false,
      administrativeAddress: _optMap(json['administrative_address']),
      recentHouseAddress: _optMap(json['recent_house_address']),
      buildingUseStatus: json['building_use_status'] as String?,
    );
  }
}

/// Identity cross-check breakdown (Dojah). Fields appear when checked.
class VeriaddIdentity {
  final String provider;
  final bool? bvnValid;
  final bool? bvnNameMatch;
  final bool? phoneLinked;
  final bool? phoneNameMatch;
  final bool? ninValid;

  const VeriaddIdentity({
    this.provider = '',
    this.bvnValid,
    this.bvnNameMatch,
    this.phoneLinked,
    this.phoneNameMatch,
    this.ninValid,
  });

  factory VeriaddIdentity.fromJson(Map<String, dynamic> json) {
    return VeriaddIdentity(
      provider: json['provider'] as String? ?? '',
      bvnValid: json['bvn_valid'] as bool?,
      bvnNameMatch: json['bvn_name_match'] as bool?,
      phoneLinked: json['phone_linked'] as bool?,
      phoneNameMatch: json['phone_name_match'] as bool?,
      ninValid: json['nin_valid'] as bool?,
    );
  }
}

class VeriaddVerifyResult {
  final String auditId;

  /// One of `verified`, `partial`, `failed`, `invalid`.
  final String status;

  /// 0–100 confidence score. Gate onboarding on status + threshold.
  final int confidence;

  /// Human-readable, auditable scoring trail.
  final List<String> reasons;
  final String postcodeCanonical;
  final VeriaddNipostLookup? nipost;
  final VeriaddIdentity? identity;
  final int billedKobo;
  final double billedNgn;

  const VeriaddVerifyResult({
    required this.auditId,
    required this.status,
    required this.confidence,
    required this.reasons,
    required this.postcodeCanonical,
    this.nipost,
    this.identity,
    required this.billedKobo,
    required this.billedNgn,
  });

  factory VeriaddVerifyResult.fromJson(Map<String, dynamic> json) {
    final nipost = json['nipost'];
    final identity = json['identity'];
    return VeriaddVerifyResult(
      auditId: json['audit_id'] as String? ?? '',
      status: json['status'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toInt() ?? 0,
      reasons: ((json['reasons'] as List?) ?? const []).map((e) => '$e').toList(),
      postcodeCanonical: json['postcode_canonical'] as String? ?? '',
      nipost: nipost is Map<String, dynamic>
          ? VeriaddNipostLookup.fromJson(nipost)
          : null,
      identity: identity is Map<String, dynamic>
          ? VeriaddIdentity.fromJson(identity)
          : null,
    );
  }
}

class VeriaddWallet {
  final String client;
  final String email;
  final int balanceKobo;
  final double balanceNgn;
  final int priceL2Kobo;
  final int priceL3Kobo;
  final List<String> topupProviders;

  const VeriaddWallet({
    required this.client,
    required this.email,
    required this.balanceKobo,
    required this.balanceNgn,
    required this.priceL2Kobo,
    required this.priceL3Kobo,
    required this.topupProviders,
  });

  factory VeriaddWallet.fromJson(Map<String, dynamic> json) {
    return VeriaddWallet(
      client: json['client'] as String? ?? '',
      email: json['email'] as String? ?? '',
      balanceKobo: (json['balance_kobo'] as num?)?.toInt() ?? 0,
      balanceNgn: _toDouble(json['balance_ngn']),
      priceL2Kobo: (json['price_l2_kobo'] as num?)?.toInt() ?? 0,
      priceL3Kobo: (json['price_l3_kobo'] as num?)?.toInt() ?? 0,
      topupProviders:
          ((json['topup_providers'] as List?) ?? const []).map((e) => '$e').toList(),
    );
  }
}

double _toDouble(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;

class VeriaddUsageRow {
  final String endpoint;
  final String status;
  final int billedKobo;
  final int? confidence;
  final String createdAt;

  const VeriaddUsageRow({
    required this.endpoint,
    required this.status,
    required this.billedKobo,
    this.confidence,
    required this.createdAt,
  });

  factory VeriaddUsageRow.fromJson(Map<String, dynamic> json) {
    final c = json['confidence'];
    return VeriaddUsageRow(
      endpoint: json['endpoint'] as String? ?? '',
      status: json['status'] as String? ?? '',
      billedKobo: (json['billed_kobo'] as num?)?.toInt() ?? 0,
      confidence: c == null ? null : (c as num).toInt(),
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class VeriaddTopupInit {
  final String provider;
  final String authorizationUrl;
  final String reference;
  final String? checkoutId;

  const VeriaddTopupInit({
    required this.provider,
    required this.authorizationUrl,
    required this.reference,
    this.checkoutId,
  });

  factory VeriaddTopupInit.fromJson(Map<String, dynamic> json) {
    return VeriaddTopupInit(
      provider: json['provider'] as String? ?? '',
      authorizationUrl: json['authorization_url'] as String? ?? '',
      reference: json['reference'] as String? ?? '',
      checkoutId: json['checkout_id'] as String?,
    );
  }
}

class VeriaddTopupVerify {
  final int creditedKobo;
  final bool alreadyCredited;
  final int balanceKobo;
  final double balanceNgn;

  const VeriaddTopupVerify({
    required this.creditedKobo,
    required this.alreadyCredited,
    required this.balanceKobo,
    required this.balanceNgn,
  });

  factory VeriaddTopupVerify.fromJson(Map<String, dynamic> json) {
    return VeriaddTopupVerify(
      creditedKobo: (json['credited_kobo'] as num?)?.toInt() ?? 0,
      alreadyCredited: json['already_credited'] as bool? ?? false,
      balanceKobo: (json['balance_kobo'] as num?)?.toInt() ?? 0,
      balanceNgn: _toDouble(json['balance_ngn']),
    );
  }
}

class VeriaddKYB {
  final String id;
  final String businessName;
  final String rcNumber;
  final String registeredAddress;
  final String website;
  final String useCase;
  final String companyType;
  final bool cacVerified;
  final String? cacLegalName;
  final String status;
  final String? reviewNote;

  const VeriaddKYB({
    required this.id,
    required this.businessName,
    required this.rcNumber,
    required this.registeredAddress,
    required this.website,
    required this.useCase,
    required this.companyType,
    required this.cacVerified,
    this.cacLegalName,
    required this.status,
    this.reviewNote,
  });

  factory VeriaddKYB.fromJson(Map<String, dynamic> json) {
    return VeriaddKYB(
      id: json['id'] as String? ?? '',
      businessName: json['business_name'] as String? ?? '',
      rcNumber: json['rc_number'] as String? ?? '',
      registeredAddress: json['registered_address'] as String? ?? '',
      website: json['website'] as String? ?? '',
      useCase: json['use_case'] as String? ?? '',
      companyType: json['company_type'] as String? ?? '',
      cacVerified: json['cac_verified'] as bool? ?? false,
      cacLegalName: json['cac_legal_name'] as String?,
      status: json['status'] as String? ?? '',
      reviewNote: json['review_note'] as String?,
    );
  }
}

/// Input for [VeriaddClient.kybSubmit].
class VeriaddKYBInput {
  final String businessName;
  final String rcNumber;

  /// One of BUSINESS_NAME, COMPANY, INCORPORATED_TRUSTEES,
  /// LIMITED_PARTNERSHIP, LIMITED_LIABILITY_PARTNERSHIP.
  final String companyType;
  final String? registeredAddress;
  final String? website;
  final String? useCase;

  const VeriaddKYBInput({
    required this.businessName,
    required this.rcNumber,
    required this.companyType,
    this.registeredAddress,
    this.website,
    this.useCase,
  });

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'business_name': businessName,
      'rc_number': rcNumber,
      'company_type': companyType,
    };
    if (registeredAddress != null) m['registered_address'] = registeredAddress;
    if (website != null) m['website'] = website;
    if (useCase != null) m['use_case'] = useCase;
    return m;
  }
}

class VeriaddKeyInfo {
  final String id;
  final String keyPrefix;
  final String env;
  final String name;
  final bool revoked;
  final String createdAt;

  const VeriaddKeyInfo({
    required this.id,
    required this.keyPrefix,
    required this.env,
    required this.name,
    required this.revoked,
    required this.createdAt,
  });

  factory VeriaddKeyInfo.fromJson(Map<String, dynamic> json) {
    return VeriaddKeyInfo(
      id: json['id'] as String? ?? '',
      keyPrefix: json['key_prefix'] as String? ?? '',
      env: json['env'] as String? ?? '',
      name: json['name'] as String? ?? '',
      revoked: json['revoked'] as bool? ?? false,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class VeriaddCreatedKey {
  /// Shown once — store it immediately, it is never returned again.
  final String apiKey;
  final String keyPrefix;
  final String warning;

  const VeriaddCreatedKey({
    required this.apiKey,
    required this.keyPrefix,
    required this.warning,
  });

  factory VeriaddCreatedKey.fromJson(Map<String, dynamic> json) {
    return VeriaddCreatedKey(
      apiKey: json['api_key'] as String? ?? '',
      keyPrefix: json['key_prefix'] as String? ?? '',
      warning: json['warning'] as String? ?? '',
    );
  }
}

class VeriaddStatus {
  final String service;
  final String version;
  final String time;
  final int uptimeSeconds;

  /// Raw dependency map (postgres, redis, nipost, dojah, bachs).
  final Map<String, dynamic> deps;

  const VeriaddStatus({
    required this.service,
    required this.version,
    required this.time,
    required this.uptimeSeconds,
    required this.deps,
  });

  factory VeriaddStatus.fromJson(Map<String, dynamic> json) {
    return VeriaddStatus(
      service: json['service'] as String? ?? '',
      version: json['version'] as String? ?? '',
      time: json['time'] as String? ?? '',
      uptimeSeconds: (json['uptime_seconds'] as num?)?.toInt() ?? 0,
      deps: _optMap(json['deps']) ?? const {},
    );
  }
}

/// Input for [VeriaddClient.assemble].
class VeriaddAssembleInput {
  final String state;
  final String lga;
  final String district;
  final String area;
  final String unit;

  const VeriaddAssembleInput({
    required this.state,
    required this.lga,
    required this.district,
    required this.area,
    required this.unit,
  });

  Map<String, dynamic> toJson() => {
        'state': state,
        'lga': lga,
        'district': district,
        'area': area,
        'unit': unit,
      };
}
