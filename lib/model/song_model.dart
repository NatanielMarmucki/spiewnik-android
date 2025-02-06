import 'package:objectbox/objectbox.dart';

@Entity()
class Song {
  @Id()
  int id;

  String content;
  bool favorite;
  int number;
  String title;

  Song({
    this.id = 0,
    required this.content,
    required this.favorite,
    required this.number,
    required this.title,
  });
}