/// SınıfCepte - MEB Okul Veri Modeli (kanonik shard şeması)
class SchoolModel {
  final String id;
  final String name;
  final String city;
  final String cityCode;
  final String district;
  final String type;
  final bool isCustom;
  final String? mebKurumKodu;
  final String status;
  final String source;
  final String? mergedIntoId;

  const SchoolModel({
    required this.id,
    required this.name,
    required this.city,
    this.cityCode = '',
    required this.district,
    required this.type,
    this.isCustom = false,
    this.mebKurumKodu,
    this.status = 'active',
    this.source = 'resmi_liste',
    this.mergedIntoId,
  });

  bool get isCanonicalBindable =>
      (id.startsWith('meb_') || id.startsWith('man_') || id.startsWith('pending_')) &&
      status != 'closed' &&
      status != 'merged';

  String get fullLocation => '$district / $city';
  String get displayName => '$name ($district, $city)';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'city': city,
      'cityCode': cityCode,
      'city_code': cityCode,
      'district': district,
      'type': type,
      'isCustom': isCustom ? 1 : 0,
      'meb_kurum_kodu': mebKurumKodu,
      'status': status,
      'source': source,
      'merged_into_id': mergedIntoId,
    };
  }

  Map<String, dynamic> toShardMap() {
    return {
      'id': id,
      'meb_kurum_kodu': mebKurumKodu,
      'name': name,
      'city': city,
      'city_code': cityCode,
      'district': district,
      'type': type,
      'status': status,
      'source': source,
    };
  }

  factory SchoolModel.fromShardMap(Map<String, dynamic> map) {
    return SchoolModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      city: map['city'] as String? ?? '',
      cityCode: map['city_code'] as String? ?? map['cityCode'] as String? ?? '',
      district: map['district'] as String? ?? '',
      type: map['type'] as String? ?? 'Diğer',
      isCustom: (map['source']?.toString() ?? '') == 'manuel_onayli',
      mebKurumKodu: map['meb_kurum_kodu'] as String?,
      status: map['status'] as String? ?? 'active',
      source: map['source'] as String? ?? 'resmi_liste',
      mergedIntoId: map['merged_into_id'] as String?,
    );
  }

  factory SchoolModel.fromMap(Map<String, dynamic> map) {
    final cityCode = map['city_code'] as String? ?? map['cityCode'] as String? ?? '';
    return SchoolModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      city: map['city'] as String? ?? '',
      cityCode: cityCode,
      district: map['district'] as String? ?? '',
      type: map['type'] as String? ?? 'Diğer',
      isCustom: map['isCustom'] == 1 || map['isCustom'] == true,
      mebKurumKodu: map['meb_kurum_kodu'] as String? ?? map['mebKurumKodu'] as String?,
      status: map['status'] as String? ?? 'active',
      source: map['source'] as String? ?? (map['isCustom'] == true || map['isCustom'] == 1 ? 'manuel_onayli' : 'resmi_liste'),
      mergedIntoId: map['merged_into_id'] as String?,
    );
  }

  SchoolModel copyWith({
    String? id,
    String? name,
    String? city,
    String? cityCode,
    String? district,
    String? type,
    bool? isCustom,
    String? mebKurumKodu,
    String? status,
    String? source,
    String? mergedIntoId,
  }) {
    return SchoolModel(
      id: id ?? this.id,
      name: name ?? this.name,
      city: city ?? this.city,
      cityCode: cityCode ?? this.cityCode,
      district: district ?? this.district,
      type: type ?? this.type,
      isCustom: isCustom ?? this.isCustom,
      mebKurumKodu: mebKurumKodu ?? this.mebKurumKodu,
      status: status ?? this.status,
      source: source ?? this.source,
      mergedIntoId: mergedIntoId ?? this.mergedIntoId,
    );
  }
}
