import 'package:app_incontri/features/profile/domain/entities/user_profile.dart';

abstract class UserProfileRepository {
  Future<UserProfile?> getCurrentUserProfile(String userId);

  Stream<UserProfile?> watchCurrentUserProfile(String userId);

  Future<void> createUserProfile(UserProfile profile);

  Future<void> updateUserProfile(UserProfile profile);
}
