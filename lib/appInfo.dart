class AppInfo {
  int id;
  String title;
  String genre;
  String description;
  String img_url;

  AppInfo(this.id, this.title, this.genre, this.description, this.img_url);

  factory AppInfo.fromJson(dynamic json) {
    return AppInfo(
        json['id'] as int,
        json['title'] as String,
        json['genre'] as String,
        json['description'] as String,
        json['img_url'] as String);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['id'] = id;
    data['title'] = title;
    data['genre'] = genre;
    data['description'] = description;
    data['img_url'] = img_url;
    return data;
  }

  @override
  String toString() {
    return '{ ${id}, ${title}, ${genre}, ${description}, ${img_url} }';
  }
}
