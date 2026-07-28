import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../providers/network_provider.dart';
import '../../../providers/video_provider.dart';
import '../../../services/local_network_server.dart';

final localServerProvider = Provider<LocalNetworkServer>((ref) {
  final videoRepo = ref.watch(videoRepositoryProvider); // For server, this is usually local
  final tagRepo = ref.watch(tagRepositoryProvider);
  return LocalNetworkServer(videoRepository: videoRepo, tagRepository: tagRepo);
});

class NetworkSettingsPage extends ConsumerStatefulWidget {
  const NetworkSettingsPage({super.key});

  @override
  ConsumerState<NetworkSettingsPage> createState() => _NetworkSettingsPageState();
}

class _NetworkSettingsPageState extends ConsumerState<NetworkSettingsPage> {
  bool _isServerRunning = false;
  String? _serverUrl;
  final TextEditingController _clientIpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkServerState();
  }

  void _checkServerState() {
    final server = ref.read(localServerProvider);
    _isServerRunning = server.isRunning;
    if (_isServerRunning) {
      // Need a way to retrieve the active URL if it's running. For now, assume it's stored or we can just show it's running.
      // A full implementation might store the active URL in a provider.
    }
  }

  Future<void> _toggleServer() async {
    final server = ref.read(localServerProvider);
    if (server.isRunning) {
      await server.stop();
      setState(() {
        _isServerRunning = false;
        _serverUrl = null;
      });
    } else {
      final url = await server.start();
      setState(() {
        _isServerRunning = true;
        _serverUrl = url;
      });
    }
  }

  void _connectAsClient() {
    final ip = _clientIpController.text.trim();
    if (ip.isEmpty) return;
    
    final url = ip.startsWith('http') ? ip : 'http://$ip';
    ref.read(networkStateProvider.notifier).setClientMode(url);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Connected to $url as Client')),
    );
  }

  void _disconnectClient() {
    ref.read(networkStateProvider.notifier).setLocalMode();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Disconnected. Returned to Local Mode.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final networkState = ref.watch(networkStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Network Streaming')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Server Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Host as Server', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text('Host your local videos and database to another device on the same Wi-Fi network.'),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Start Server'),
                      value: _isServerRunning,
                      onChanged: networkState.isClient ? null : (val) => _toggleServer(),
                    ),
                    if (_isServerRunning && _serverUrl != null) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: QrImageView(
                          data: _serverUrl!,
                          version: QrVersions.auto,
                          size: 200.0,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(child: Text('Scan QR Code or connect to: $_serverUrl', style: const TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    if (networkState.isClient)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text('Cannot host a server while connected as a client.', style: TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Client Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Connect as Client', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text('Connect to another device running Tooby to browse and stream its videos.'),
                    const SizedBox(height: 16),
                    if (networkState.isClient) ...[
                      Text('Currently connected to: ${networkState.serverUrl}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _disconnectClient,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        child: const Text('Disconnect'),
                      ),
                    ] else ...[
                      TextField(
                        controller: _clientIpController,
                        decoration: const InputDecoration(
                          labelText: 'Server IP Address (e.g., 192.168.1.5:8080)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isServerRunning ? null : _connectAsClient,
                        child: const Text('Connect'),
                      ),
                      if (_isServerRunning)
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Text('Cannot connect as a client while hosting a server.', style: TextStyle(color: Colors.red)),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
