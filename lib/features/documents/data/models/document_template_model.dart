/// SınıfCepte - Resmi Evrak Şablon Modeli
class DocumentTemplateModel {
  final String id;
  final String title;
  final String category; // Maarif, Planlar, Tutanaklar
  final String description;
  final DateTime createdAt;
  final bool isAutoPopulated;

  const DocumentTemplateModel({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.createdAt,
    this.isAutoPopulated = true,
  });
}
