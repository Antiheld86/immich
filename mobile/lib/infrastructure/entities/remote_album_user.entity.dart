import 'package:drift/drift.dart';
import 'package:immich_mobile/domain/models/album/album.model.dart';
import 'package:immich_mobile/infrastructure/entities/remote_album.entity.dart';
import 'package:immich_mobile/infrastructure/entities/user.entity.dart';
import 'package:immich_mobile/infrastructure/utils/drift_default.mixin.dart';

class RemoteAlbumUserEntity extends Table with DriftDefaultsMixin {
  const RemoteAlbumUserEntity();

  TextColumn get albumId => text().references(RemoteAlbumEntity, #id, onDelete: KeyAction.cascade)();

  TextColumn get userId => text().references(UserEntity, #id, onDelete: KeyAction.cascade)();

  IntColumn get role => intEnum<AlbumUserRole>()();

  /// Controls whether this album's assets appear in the user's timeline
  /// - null: inherit from global "show shared albums" setting (default)
  /// - true: explicitly show this album in timeline
  /// - false: explicitly hide this album from timeline
  BoolColumn get showInTimeline => boolean().nullable()();

  @override
  Set<Column> get primaryKey => {albumId, userId};
}
