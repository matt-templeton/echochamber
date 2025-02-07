// Mocks generated by Mockito 5.4.5 from annotations
// in echochamber/test/services/video_feed_service_test.dart.
// Do not manually edit this file.

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i4;

import 'package:cloud_firestore/cloud_firestore.dart' as _i2;
import 'package:echochamber/models/video_model.dart' as _i5;
import 'package:echochamber/repositories/video_repository.dart' as _i3;
import 'package:mockito/mockito.dart' as _i1;
import 'package:mockito/src/dummies.dart' as _i6;

// ignore_for_file: type=lint
// ignore_for_file: avoid_redundant_argument_values
// ignore_for_file: avoid_setters_without_getters
// ignore_for_file: comment_references
// ignore_for_file: deprecated_member_use
// ignore_for_file: deprecated_member_use_from_same_package
// ignore_for_file: implementation_imports
// ignore_for_file: invalid_use_of_visible_for_testing_member
// ignore_for_file: must_be_immutable
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_parenthesis
// ignore_for_file: camel_case_types
// ignore_for_file: subtype_of_sealed_class

class _FakeSnapshotMetadata_0 extends _i1.SmartFake
    implements _i2.SnapshotMetadata {
  _FakeSnapshotMetadata_0(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

class _FakeDocumentReference_1<T1 extends Object?> extends _i1.SmartFake
    implements _i2.DocumentReference<T1> {
  _FakeDocumentReference_1(Object parent, Invocation parentInvocation)
    : super(parent, parentInvocation);
}

/// A class which mocks [VideoRepository].
///
/// See the documentation for Mockito's code generation for more information.
class MockVideoRepository extends _i1.Mock implements _i3.VideoRepository {
  MockVideoRepository() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i4.Future<void> createVideo(_i5.Video? video) =>
      (super.noSuchMethod(
            Invocation.method(#createVideo, [video]),
            returnValue: _i4.Future<void>.value(),
            returnValueForMissingStub: _i4.Future<void>.value(),
          )
          as _i4.Future<void>);

  @override
  _i4.Future<_i5.Video?> getVideoById(String? videoId) =>
      (super.noSuchMethod(
            Invocation.method(#getVideoById, [videoId]),
            returnValue: _i4.Future<_i5.Video?>.value(),
          )
          as _i4.Future<_i5.Video?>);

  @override
  _i4.Stream<_i2.QuerySnapshot<Object?>> getUserVideos(String? userId) =>
      (super.noSuchMethod(
            Invocation.method(#getUserVideos, [userId]),
            returnValue: _i4.Stream<_i2.QuerySnapshot<Object?>>.empty(),
          )
          as _i4.Stream<_i2.QuerySnapshot<Object?>>);

  @override
  _i4.Stream<_i2.QuerySnapshot<Object?>> getVideosByGenre(String? genre) =>
      (super.noSuchMethod(
            Invocation.method(#getVideosByGenre, [genre]),
            returnValue: _i4.Stream<_i2.QuerySnapshot<Object?>>.empty(),
          )
          as _i4.Stream<_i2.QuerySnapshot<Object?>>);

  @override
  _i4.Stream<_i2.QuerySnapshot<Object?>> getVideosByTag(String? tag) =>
      (super.noSuchMethod(
            Invocation.method(#getVideosByTag, [tag]),
            returnValue: _i4.Stream<_i2.QuerySnapshot<Object?>>.empty(),
          )
          as _i4.Stream<_i2.QuerySnapshot<Object?>>);

  @override
  _i4.Future<void> updateVideo(String? videoId, Map<String, dynamic>? data) =>
      (super.noSuchMethod(
            Invocation.method(#updateVideo, [videoId, data]),
            returnValue: _i4.Future<void>.value(),
            returnValueForMissingStub: _i4.Future<void>.value(),
          )
          as _i4.Future<void>);

  @override
  _i4.Future<void> deleteVideo(String? videoId) =>
      (super.noSuchMethod(
            Invocation.method(#deleteVideo, [videoId]),
            returnValue: _i4.Future<void>.value(),
            returnValueForMissingStub: _i4.Future<void>.value(),
          )
          as _i4.Future<void>);

  @override
  _i4.Future<void> incrementViewCount(String? videoId) =>
      (super.noSuchMethod(
            Invocation.method(#incrementViewCount, [videoId]),
            returnValue: _i4.Future<void>.value(),
            returnValueForMissingStub: _i4.Future<void>.value(),
          )
          as _i4.Future<void>);

  @override
  _i4.Future<void> likeVideo(String? videoId, String? userId) =>
      (super.noSuchMethod(
            Invocation.method(#likeVideo, [videoId, userId]),
            returnValue: _i4.Future<void>.value(),
            returnValueForMissingStub: _i4.Future<void>.value(),
          )
          as _i4.Future<void>);

  @override
  _i4.Future<void> unlikeVideo(String? videoId, String? userId) =>
      (super.noSuchMethod(
            Invocation.method(#unlikeVideo, [videoId, userId]),
            returnValue: _i4.Future<void>.value(),
            returnValueForMissingStub: _i4.Future<void>.value(),
          )
          as _i4.Future<void>);

  @override
  _i4.Future<bool> hasUserLikedVideo(String? videoId, String? userId) =>
      (super.noSuchMethod(
            Invocation.method(#hasUserLikedVideo, [videoId, userId]),
            returnValue: _i4.Future<bool>.value(false),
          )
          as _i4.Future<bool>);

  @override
  _i4.Stream<_i2.QuerySnapshot<Object?>> getTrendingVideos({int? limit = 10}) =>
      (super.noSuchMethod(
            Invocation.method(#getTrendingVideos, [], {#limit: limit}),
            returnValue: _i4.Stream<_i2.QuerySnapshot<Object?>>.empty(),
          )
          as _i4.Stream<_i2.QuerySnapshot<Object?>>);

  @override
  _i4.Stream<_i2.QuerySnapshot<Object?>> getFeedVideos({
    int? limit = 10,
    _i2.DocumentSnapshot<Object?>? startAfter,
  }) =>
      (super.noSuchMethod(
            Invocation.method(#getFeedVideos, [], {
              #limit: limit,
              #startAfter: startAfter,
            }),
            returnValue: _i4.Stream<_i2.QuerySnapshot<Object?>>.empty(),
          )
          as _i4.Stream<_i2.QuerySnapshot<Object?>>);

  @override
  _i4.Stream<_i2.QuerySnapshot<Object?>> getUserLikedVideos(String? userId) =>
      (super.noSuchMethod(
            Invocation.method(#getUserLikedVideos, [userId]),
            returnValue: _i4.Stream<_i2.QuerySnapshot<Object?>>.empty(),
          )
          as _i4.Stream<_i2.QuerySnapshot<Object?>>);

  @override
  _i4.Future<void> addComment(
    String? videoId,
    String? userId,
    String? comment,
  ) =>
      (super.noSuchMethod(
            Invocation.method(#addComment, [videoId, userId, comment]),
            returnValue: _i4.Future<void>.value(),
            returnValueForMissingStub: _i4.Future<void>.value(),
          )
          as _i4.Future<void>);

  @override
  _i4.Stream<_i2.QuerySnapshot<Object?>> getVideoComments(String? videoId) =>
      (super.noSuchMethod(
            Invocation.method(#getVideoComments, [videoId]),
            returnValue: _i4.Stream<_i2.QuerySnapshot<Object?>>.empty(),
          )
          as _i4.Stream<_i2.QuerySnapshot<Object?>>);
}

/// A class which mocks [QuerySnapshot].
///
/// See the documentation for Mockito's code generation for more information.
class MockQuerySnapshot<T extends Object?> extends _i1.Mock
    implements _i2.QuerySnapshot<T> {
  MockQuerySnapshot() {
    _i1.throwOnMissingStub(this);
  }

  @override
  List<_i2.QueryDocumentSnapshot<T>> get docs =>
      (super.noSuchMethod(
            Invocation.getter(#docs),
            returnValue: <_i2.QueryDocumentSnapshot<T>>[],
          )
          as List<_i2.QueryDocumentSnapshot<T>>);

  @override
  List<_i2.DocumentChange<T>> get docChanges =>
      (super.noSuchMethod(
            Invocation.getter(#docChanges),
            returnValue: <_i2.DocumentChange<T>>[],
          )
          as List<_i2.DocumentChange<T>>);

  @override
  _i2.SnapshotMetadata get metadata =>
      (super.noSuchMethod(
            Invocation.getter(#metadata),
            returnValue: _FakeSnapshotMetadata_0(
              this,
              Invocation.getter(#metadata),
            ),
          )
          as _i2.SnapshotMetadata);

  @override
  int get size =>
      (super.noSuchMethod(Invocation.getter(#size), returnValue: 0) as int);
}

/// A class which mocks [QueryDocumentSnapshot].
///
/// See the documentation for Mockito's code generation for more information.
class MockQueryDocumentSnapshot<T extends Object?> extends _i1.Mock
    implements _i2.QueryDocumentSnapshot<T> {
  MockQueryDocumentSnapshot() {
    _i1.throwOnMissingStub(this);
  }

  @override
  String get id =>
      (super.noSuchMethod(
            Invocation.getter(#id),
            returnValue: _i6.dummyValue<String>(this, Invocation.getter(#id)),
          )
          as String);

  @override
  _i2.DocumentReference<T> get reference =>
      (super.noSuchMethod(
            Invocation.getter(#reference),
            returnValue: _FakeDocumentReference_1<T>(
              this,
              Invocation.getter(#reference),
            ),
          )
          as _i2.DocumentReference<T>);

  @override
  _i2.SnapshotMetadata get metadata =>
      (super.noSuchMethod(
            Invocation.getter(#metadata),
            returnValue: _FakeSnapshotMetadata_0(
              this,
              Invocation.getter(#metadata),
            ),
          )
          as _i2.SnapshotMetadata);

  @override
  bool get exists =>
      (super.noSuchMethod(Invocation.getter(#exists), returnValue: false)
          as bool);

  @override
  T data() =>
      (super.noSuchMethod(
            Invocation.method(#data, []),
            returnValue: _i6.dummyValue<T>(this, Invocation.method(#data, [])),
          )
          as T);

  @override
  dynamic get(Object? field) =>
      super.noSuchMethod(Invocation.method(#get, [field]));

  @override
  dynamic operator [](Object? field) =>
      super.noSuchMethod(Invocation.method(#[], [field]));
}
