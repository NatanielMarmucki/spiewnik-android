import 'package:objectbox/objectbox.dart';

@Entity()
class Song {
  @Id()
  int id;

  @Index()
  int number;

  String content;
  bool favorite;
  String title;

  Song({
    this.id = 0,
    required this.content,
    required this.favorite,
    required this.number,
    required this.title,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      number: json['number'] as int,
      title: json['title'] as String,
      content: json['content'] as String,
      favorite: json['favorite'] as bool? ?? false,
    );
  }
}
