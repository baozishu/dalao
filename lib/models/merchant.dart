/// 商家模型
class Merchant {
  final int id;
  final String name;
  final String logo; // 商家 logo 图片
  final String? website;
  final String? description;

  Merchant({
    required this.id,
    required this.name,
    this.logo = '',
    this.website,
    this.description,
  });

  @override
  String toString() {
    return 'Merchant(id: $id, name: $name, logo: $logo)';
  }
}
