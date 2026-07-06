import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/tomodachi.dart';
import '../services/auth_service.dart';
import '../services/friends_service.dart';

part 'friends_providers.g.dart';

@riverpod
class TomodachiNotifier extends _$TomodachiNotifier {
  @override
  Future<List<Tomodachi>> build() async {
    if (!AuthService.isLoggedIn) {
      return [];
    }
    return FriendsService().fetchFriends();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() async {
      if (!AuthService.isLoggedIn) {
        return <Tomodachi>[];
      }
      return FriendsService().fetchFriends();
    });
  }

  Future<Map<String, dynamic>> sendRequest(String username) async {
    final result = await FriendsService().sendRequest(username);
    if (result['success'] == true) {
      await refresh();
    }
    return result;
  }

  Future<Map<String, dynamic>> removeFriend(String username) async {
    final result = await FriendsService().removeFriend(username);
    if (result['success'] == true) {
      await refresh();
    }
    return result;
  }

  Future<Map<String, dynamic>> declineRequest(String username) async {
    final result = await FriendsService().declineRequest(username);
    if (result['success'] == true) {
      await refresh();
    }
    return result;
  }

  Future<Map<String, dynamic>> acceptRequest(String username) async {
    final result = await FriendsService().acceptRequest(username);
    if (result['success'] == true) {
      await refresh();
    }
    return result;
  }
}

@riverpod
int pendingTomodachiRequestsCount(PendingTomodachiRequestsCountRef ref) {
  final tomodachiAsync = ref.watch(tomodachiNotifierProvider);
  return tomodachiAsync.maybeWhen(
    data: (list) =>
        list.where((t) => t.isPending && !t.isSender).length,
    orElse: () => 0,
  );
}
