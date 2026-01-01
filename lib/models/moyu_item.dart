/// 摸鱼 RSS 聚合项目
class MoyuItem {
  final String title;
  final String url;
  final String author;
  final String source;
  final String sourceIcon;
  final DateTime publishedAt;

  MoyuItem({
    required this.title,
    required this.url,
    required this.author,
    required this.source,
    required this.sourceIcon,
    required this.publishedAt,
  });
}
