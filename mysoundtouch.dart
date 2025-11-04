import 'dart:io';
import 'dart:async';
import 'package:bonsoir/bonsoir.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

class MySoundTouch {
  String? _ipAddress;
  String? get ipAddress => _ipAddress;
  String _source = 'STORED_MUSIC';
  String _sourceAccount = '';
  //String _sourceAccount = '10809696-105a-3721-e8b8-f4b5aa96c210/0';
  // Array to hold media items, i.e. ['0$4$215', 'Foldername']

  // ****************************************************************************************************
  // Discover Device
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
  // Send XML Command (POST) for Key Press and Release
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
      print('⚠️ Sent XML command key: $command');
    } catch (e) {
      print('⚠️ XML command HTTP error: $e');
    }
  }

  // ****************************************************************************************************
  // Send XML Command (POST) to Set Volume
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
      print('⚠️ Sent XML command volume: $volume');
    } catch (e) {
      print('⚠️ XML volume HTTP error: $e');
    }
  }

  // ****************************************************************************************************
  // Get XML from Command "Now Playing"
  // ****************************************************************************************************
  Future<void> getXmlNowPlaying(Map nowPlaying) async {
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
        final np = document.rootElement;
        // The following transfers the XML data into the Map "_nowPlaying" from the Main class
        nowPlaying['track'] = np.getElement('track')?.text ?? '';
        nowPlaying['artist'] = np.getElement('artist')?.text ?? '';
        nowPlaying['album'] = np.getElement('album')?.text ?? '';
        nowPlaying['offset'] = np.getElement('offset')?.text ?? '';
        nowPlaying['playStatus'] = np.getElement('playStatus')?.text ?? '';
        nowPlaying['repeatSetting'] =
            np.getElement('repeatSetting')?.text ?? '';
        nowPlaying['shuffleSetting'] =
            np.getElement('shuffleSetting')?.text ?? '';
        final contentItem = document.rootElement.getElement('ContentItem');
        if (contentItem != null) {
          nowPlaying['location'] =
              contentItem.getAttribute('location')?.toString() ?? '';
          // This is the location of the containing folder, not the actual track !
        }
      } else {
        print('HTTP error, code: ${response.statusCode}');
        print('Body: ${response.body}');
      }
    } catch (e) {
      print('XML now_playing HTTP error: $e');
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
        nowPlaying['volume'] = actualvolume?.text ?? '';
      } else {
        print('HTTP error, code: ${response.statusCode}');
        print('Body: ${response.body}');
      }
    } catch (e) {
      print('XML volume HTTP error: $e');
    }
    print('⚠️ Now Playing: $nowPlaying');
  }

  // ****************************************************************************************************
  // Get XML from Command "Sources" and Determine SourceAccount
  // ****************************************************************************************************
  Future<void> getXmlSources() async {
    if (_sourceAccount != '') {
      print('⚠️ SourceAccount known: $_sourceAccount');
      return;
    }
    Uri url = Uri.parse('http://$_ipAddress:8090/sources');
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
        print('⚠️ Getting source account for: $_source');
        final sourceItems = document
            .findAllElements('sourceItem')
            .where((element) => element.getAttribute('source') == _source);
        final sourceItem = sourceItems.isNotEmpty ? sourceItems.first : null;
        if (sourceItem != null) {
          _sourceAccount =
              sourceItem.getAttribute('sourceAccount')?.toString() ?? '';
        }
      } else {
        print('HTTP error, code: ${response.statusCode}');
        print('Body: ${response.body}');
      }
    } catch (e) {
      print('XML sources HTTP error: $e');
    }
    if (_sourceAccount == '') {
      print('⚠️ No Sources found');
      return;
    }
    print('⚠️ SourceAccount: $_sourceAccount');
  }

  // ****************************************************************************************************
  // Send XML Command (POST) "Navigate" and Receive XML
  // ****************************************************************************************************
  Future<String> sendXmlNavigate({String location = ''}) async {
    String xmlString = ''; // future response
    if (location == '') {
      location = r'0$4$215'; // root -> /mnt/usb1_1 -> Folder
      // TODO: This location must not be hardcoded
    }
    final url = Uri.parse('http://$_ipAddress:8090/navigate');
    final xml =
        '<?xml version="1.0"?>'
        '<navigate source="$_source" sourceAccount="$_sourceAccount">'
        '<item>'
        '<name></name>'
        '<type>dir</type>'
        '<ContentItem location="$location"></ContentItem>'
        '</item>'
        '</navigate>';
    //print('⚠️ Request XML: $xml');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/xml; charset=utf-8'},
        body: xml,
      );
      if (response.statusCode == 200) {
        xmlString = response.body;
        //print('XML Response: $xmlString');
      } else {
        print('HTTP error, code: ${response.statusCode}');
        print('Body: ${response.body}');
      }
      print('⚠️ Sent XML command navigate');
    } catch (e) {
      print('⚠️ XML navigate HTTP error: $e');
    }
    return xmlString;
  }

  // ****************************************************************************************************
  // Get Media Browser Items
  // ****************************************************************************************************
  Future<void> getMediaBrowserItems(Map mediaItemList, String location) async {
    await getXmlSources();
    if (_sourceAccount == '') return;
    mediaItemList.clear();
    String xmlString = await sendXmlNavigate();
    final document = XmlDocument.parse(xmlString);
    final allItems = document.findAllElements('item');
    final allContentItems = allItems.expand(
      (item) => item.findAllElements('ContentItem'),
    );
    final contentItems = allContentItems.where((contentItem) {
      // The parent element's name must be 'item' for it to be included.
      return contentItem.parentElement?.name.local == 'item';
      // We check parent?.name.local to safely access the parent's name.
    });

    for (final contentItem in contentItems) {
      final itemName = contentItem
          .findElements('itemName')
          .firstOrNull
          ?.innerText;
      final location = contentItem.getAttribute('location');

      // Store the data only if both are present
      if (itemName != null && location != null) {
        // The key is 'location', the value is 'itemName'
        mediaItemList[location] = itemName;
      }
    }
    print('⚠️ Found itemlist: $mediaItemList');
  }

  // ****************************************************************************************************
  // Class end
  // ****************************************************************************************************
}
