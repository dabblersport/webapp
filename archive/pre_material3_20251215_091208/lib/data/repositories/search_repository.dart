import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';
import '../models/profile.dart';
import '../models/venue.dart';
import '../models/post.dart';

abstract class SearchRepository {
  Future<Result<List<Profile>, Failure>> searchProfiles({
    required String query,
    int limit = 20,
    int offset = 0,
  });

  Future<Result<List<Venue>, Failure>> searchVenues({
    required String query,
    int limit = 20,
    int offset = 0,
  });

  Future<Result<List<Post>, Failure>> searchPosts({
    required String query,
    int limit = 20,
    int offset = 0,
  });
}
