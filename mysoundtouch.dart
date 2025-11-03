import 'dart:io';
import 'dart:async';
import 'package:bonsoir/bonsoir.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

class MySoundTouch {
  String? _ipAddress;
  String? get ipAddress => _ipAddress;
  //Map<String, String> _nowPlaying = {};

  // ****************************************************************************************************
  // Discover device
  // ****************************************************************************************************
  Future<String?> discoverDevice() async {
    // Check if we have a stored IP from last time
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? lastip = prefs.getString('last_ip');

    if (lastip != null) {
      print('⚠️ Last stored IP was: $lastip');
      // Test connection
      try {
        final socket = await Socket.connect(
          lastip,
          8090,
          timeout: Duration(seconds: 2),
        );
        socket.destroy();
        print('⚠️ Device found at: $lastip');
        _ipAddress = lastip;
        return _ipAddress;
      } catch (e) {
        print('⚠️ Device not found at: $lastip');
      }
    }

    // Start discovery
    print('⚠️ Discovering device...');
    var discovery = BonsoirDiscovery(type: '_soundtouch._tcp');
    await discovery.initialize();

    // Create a completer to wait for discovery to finish
    final completer = Completer<String?>();

    // Use Bonsoir for discovery
    discovery.eventStream?.listen((event) async {
      if (event is BonsoirDiscoveryServiceFoundEvent) {
        await event.service?.resolve(discovery.serviceResolver);
      } else if (event is BonsoirDiscoveryServiceResolvedEvent) {
        var host = event.service?.host;
        if (host != null && host.isNotEmpty) {
          var addresses = await InternetAddress.lookup(host);
          if (addresses.isNotEmpty) {
            String foundip = addresses.first.address;
            print('⚠️ Device discovered at: $foundip');
            _ipAddress = foundip;
            // Store IP for next time
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setString('last_ip', foundip);
            await discovery.stop();
            // Complete the future with the found IP
            if (!completer.isCompleted) {
              completer.complete(_ipAddress);
            }
          }
        }
      }
    });
    await discovery.start();

    // Wait for discovery to complete or timeout after 10 seconds
    return completer.future.timeout(
      Duration(seconds: 10),
      onTimeout: () {
        print('⚠️ Discovery timeout');
        discovery.stop();
        return null;
      },
    );
  }

  // ****************************************************************************************************
  // Send XML Command - Key Press and Release
  // ****************************************************************************************************
  Future<void> sendXmlKey(String command) async {
    final url = Uri.parse('http://$_ipAddress:8090/key');
    final pressXml =
        '<?xml version="1.0" ?>'
        '<key state="press" sender="Gabbo">$command</key>';

    final releaseXml =
        '<?xml version="1.0" ?>'
        '<key state="release" sender="Gabbo">$command</key>';
    try {
      await http.post(
        url,
        headers: {'Content-Type': 'application/xml; charset=utf-8'},
        body: pressXml,
      );
      await Future.delayed(Duration(milliseconds: 100));
      await http.post(
        url,
        headers: {'Content-Type': 'application/xml; charset=utf-8'},
        body: releaseXml,
      );
      print('⚠️ Sent XML command Key: $command');
    } catch (e) {
      print('⚠️ XML command HTTP error: $e');
    }
  }

  // ****************************************************************************************************
  // Send XML Command - Volume
  // ****************************************************************************************************
  Future<void> sendXmlVolume(int volume) async {
    final url = Uri.parse('http://$_ipAddress:8090/volume');
    final xml =
        '<?xml version="1.0" ?>'
        '<volume>$volume</volume>';
    try {
      await http.post(
        url,
        headers: {'Content-Type': 'application/xml; charset=utf-8'},
        body: xml,
      );
      print('⚠️ Sent XML command Volume: $volume');
    } catch (e) {
      print('⚠️ XML command HTTP error: $e');
    }
  }

  // ****************************************************************************************************
  // Send command and receive XML for "Now Playing"
  // ****************************************************************************************************
  Future<void> getXmlNowPlaying(Map _nowPlaying) async {
    Uri url = Uri.parse('http://$_ipAddress:8090/now_playing');
    try {
      final response = await http.get(
        url,
        headers: {'Accept': 'application/xml'},
        // This is optional, hints server to send XML
      );
      if (response.statusCode == 200) {
        String xmlString = response.body;
        //print('XML Response: $xmlString');
        final document = XmlDocument.parse(xmlString);
        final nowPlaying = document.rootElement;
        _nowPlaying['track'] = nowPlaying.getElement('track')?.text ?? '';
        _nowPlaying['artist'] = nowPlaying.getElement('artist')?.text ?? '';
        _nowPlaying['album'] = nowPlaying.getElement('album')?.text ?? '';
        _nowPlaying['offset'] = nowPlaying.getElement('offset')?.text ?? '';
        _nowPlaying['playStatus'] =
            nowPlaying.getElement('playStatus')?.text ?? '';
        _nowPlaying['repeatSetting'] =
            nowPlaying.getElement('repeatSetting')?.text ?? '';
        _nowPlaying['shuffleSetting'] =
            nowPlaying.getElement('shuffleSetting')?.text ?? '';
        final contentItem = document.rootElement.getElement('ContentItem');
        if (contentItem != null) {
          _nowPlaying['location'] =
              contentItem.getAttribute('location')?.toString() ?? '';
          // This is the location of the containing folder, not the actual track !
        }
      } else {
        print('HTTP error, code: ${response.statusCode}');
        print('Body: ${response.body}');
      }
    } catch (e) {
      print('Get XML now_playing HTTP error: $e');
    }

    // Also get the volume
    url = Uri.parse('http://$_ipAddress:8090/volume');
    try {
      final response = await http.get(
        url,
        headers: {'Accept': 'application/xml'},
      );
      if (response.statusCode == 200) {
        String xmlString = response.body;
        //print('⚠️ Volume XML Response: $xmlString');
        final document = XmlDocument.parse(xmlString);
        final actualvolume = document.rootElement.getElement('actualvolume');
        //print('⚠️ actualvolume = $volume');
        _nowPlaying['volume'] = actualvolume?.text ?? '';
      }
    } catch (e) {
      print('Get XML now_playing HTTP error: $e');
    }
    print('⚠️ Now Playing: $_nowPlaying');
  }

  // ****************************************************************************************************
  // Class end
  // ****************************************************************************************************
}
