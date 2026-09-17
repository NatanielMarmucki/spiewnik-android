import 'package:objectbox/objectbox.dart';

/// Song written by the user. Kept separate from [Song]: songs from the asset
/// are overwritten when the songs data version changes, user songs never are.
@Entity()
class MySong {
  @Id()
  int id;

  String title;
  String content;

  @Property(type: PropertyType.dateNano)
  DateTime createdAt;

  @Property(type: PropertyType.dateNano)
  DateTime updatedAt;

  MySong({
    this.id = 0,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });
}
