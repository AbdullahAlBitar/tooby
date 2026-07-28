import 'package:flutter_riverpod/flutter_riverpod.dart';

class NetworkState {
  final bool isClient;
  final String? serverUrl;

  const NetworkState({this.isClient = false, this.serverUrl});
}

class NetworkStateNotifier extends StateNotifier<NetworkState> {
  NetworkStateNotifier() : super(const NetworkState());

  void setClientMode(String url) {
    state = NetworkState(isClient: true, serverUrl: url);
  }

  void setLocalMode() {
    state = const NetworkState(isClient: false);
  }
}

final networkStateProvider = StateNotifierProvider<NetworkStateNotifier, NetworkState>((ref) {
  return NetworkStateNotifier();
});
