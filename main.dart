import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_size/window_size.dart';
import 'package:bonsoir/bonsoir.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initial window position and size
  if (Platform.isMacOS) {
    setWindowMinSize(const Size(450, 850)); // Minimum size
    setWindowMaxSize(Size.infinite);
    setWindowFrame(const Rect.fromLTWH(100, 100, 450, 850));
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SoundTouch App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade100,
            foregroundColor: Colors.blue[900],
          ),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey[900],
            foregroundColor: Colors.blue.shade100,
          ),
        ),
      ),
      themeMode: ThemeMode.system,
      home: const MyHomePage(title: 'SoundTouch App'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // State variables to hold the dynamic text label
  String _trackLabel = 'Track Name';
  String _artistLabel = 'Artist Name';
  String _albumLabel = 'Album Name';
  String _trackNumberLabel = '';
  String _repeatLabel = 'Repeat: Off';
  String _repeatMode = 'Off'; // or All or One
  String _shuffleLabel = 'Shuffle: Off';
  String _shuffleMode = 'Off'; // or Off
  String _playStatus =
      'PLAY_STATE'; // or PAUSE_STATE or STOP_STATE or BUFFERING_STATE
  // TODO: something to the correct icon on the button
  String _skipEnabled = '';
  String _skipPreviousEnabled = '';
  Map<String, String> _nowPlaying = {};
  double _volume = 0;
  double _maxVolume = 50; // originally 100 but we never want that loud
  String _volumeLabel = 'Volume';
  String _statusLabel = 'Discovering device...';
  String _ipAddress = '';
  String _source = 'STORED_MUSIC'; // or TUNEIN
  String _sourceAccount = '';

  // Initialization
  @override
  void initState() {
    super.initState();
    _initAsync();
  }

  // Initialization
  Future<void> _initAsync() async {
    await discoverDevice();
    await sendXmlNowPlaying();
    updateLabelsFromNowPlaying();
  }

  // ****************************************************************************************************
  // Discover Device
  // ****************************************************************************************************
  Future<void> discoverDevice() async {
    // check if we have a stored IP from last time
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? lastip = prefs.getString('last_ip');
    if (lastip != null) {
      print('⚠️ Last stored IP was: $lastip');
      // test connection
      try {
        final socket = await Socket.connect(
          lastip,
          8090,
          timeout: Duration(seconds: 2),
        );
        socket.destroy();
        print('⚠️ Device found at: $lastip');
        _ipAddress = lastip;
        setState(() {
          _statusLabel = 'Device IP: $_ipAddress';
        });
        return;
      } catch (e) {
        print('⚠️ Device not found at: $lastip');
      }
    }
    // start discovery
    print('⚠️ Discovering device...');
    var discovery = BonsoirDiscovery(type: '_soundtouch._tcp');
    await discovery.initialize();
    discovery.eventStream?.listen((event) async {
      if (event is BonsoirDiscoveryServiceFoundEvent) {
        await event.service?.resolve(discovery.serviceResolver);
      } else if (event is BonsoirDiscoveryServiceResolvedEvent) {
        var host = event.service?.host;
        if (host != null && host.isNotEmpty) {
          var addresses = await InternetAddress.lookup(host);
          if (addresses.isNotEmpty) {
            String foundip = addresses.first.address;
            print('⚠️ Device discovered at: ' + foundip);
            _ipAddress = foundip;
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setString('last_ip', foundip);
            discovery.stop();
            setState(() {
              _statusLabel = 'Device IP: $_ipAddress';
            });
          }
        }
      }
    });
    await discovery.start();
  }

  // ****************************************************************************************************
  // Send command and receive XML for "Now Playing"
  // ****************************************************************************************************
  Future<void> sendXmlNowPlaying() async {
    final url = Uri.parse('http://$_ipAddress:8090/now_playing');
    try {
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/xml',
        }, // optional, hints server to send XML
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
          // this is the location of the containing folder, not the actual track !
        }
        print('⚠️ Now Playing: $_nowPlaying');
      } else {
        print('HTTP error, code: ${response.statusCode}');
        print('Body: ${response.body}');
      }
    } catch (e) {
      print('Get XML now_playing HTTP error: $e');
    }
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

  // pressed Play button
  void _pressPlayPause() async {
    print('⚠️ Pressing Play/Pause...');
    await sendXmlKey('PLAY_PAUSE');
  }

  // pressed Previous button
  void _pressPreviousTrack() async {
    print('⚠️ Skipping to Previous track...');
    await sendXmlKey('PREV_TRACK');
  }

  // pressed Next button
  void _pressNextTrack() async {
    print('⚠️ Skipping to Next track...');
    await sendXmlKey('NEXT_TRACK');
  }

  // pressed Repeat button
  void _pressRepeat() async {
    if (_repeatMode == 'Off') {
      print('⚠️ Setting Repeat all...');
      await sendXmlKey('REPEAT_ALL');
      _repeatMode = 'All';
    } else if (_repeatMode == 'All') {
      print('⚠️ Setting Repeat one...');
      await sendXmlKey('REPEAT_ONE');
      _repeatMode = 'One';
    } else if (_repeatMode == 'One') {
      print('⚠️ Setting Repeat off...');
      await sendXmlKey('REPEAT_OFF');
      _repeatMode = 'Off';
    } // set repeat mode here or wait for status-info ?
  }

  // pressed Shuffle button
  void _pressShuffle() async {
    if (_shuffleMode == 'Off') {
      print('⚠️ Setting Shuffle on...');
      await sendXmlKey('SHUFFLE_ON');
      _shuffleMode = 'On';
    } else {
      print('⚠️ Setting Shuffle off...');
      await sendXmlKey('SHUFFLE_OFF');
      _shuffleMode = 'Off';
    }
    // set shuffle mode here or wait for status-info ?
  }

  // pressed Volume down
  void _pressVolumeDown() async {
    print('⚠️ Setting Volume down...');
    await sendXmlKey('VOLUME_DOWN');
  }

  // pressed Volume down
  void _pressVolumeUp() async {
    print('⚠️ Setting Volume up...');
    await sendXmlKey('VOLUME_UP');
  }

  // pressed Preset button
  void _pressPreset(int number) async {
    print('⚠️ Selecting Preset $number...');
    await sendXmlKey('PRESET_$number');
  }

  // changed Volume slider
  void _changedVolume(double value) async {
    setState(() {
      _volume = value;
      // set volume here or wait for status-info ?
    });
    await sendXmlVolume(value.toInt());
  }

  // pressed MediaBrowser button
  void _pressMediaBrowser() async {
    setState(() {
      _statusLabel = 'Media Browser...';
    });
    await sendXmlNowPlaying();
    updateLabelsFromNowPlaying();
  }

  // ****************************************************************************************************
  // Update Labels with new data from "Now Playing"
  // ****************************************************************************************************
  void updateLabelsFromNowPlaying() {
    //_nowPlaying['track'] = nowPlaying.getElement('track')?.text ?? '';
    setState(() {
      _trackLabel = _nowPlaying['track'].toString();
      _artistLabel = _nowPlaying['artist'].toString();
      _albumLabel = _nowPlaying['album'].toString();
      _playStatus = _nowPlaying['playStatus'].toString();
      _trackNumberLabel = _nowPlaying['offset'].toString();
      if (_trackNumberLabel != '') {
        _trackNumberLabel = 'Track ' + _trackNumberLabel;
      }
      _shuffleLabel = _nowPlaying['shuffleSetting'].toString();
      if (_shuffleLabel != '') {
        _shuffleLabel = _shuffleLabel
            .toString()
            .split('_')
            .map((w) => '${w[0]}${w.substring(1).toLowerCase()}')
            .join(': ');
      } else {
        _shuffleLabel = 'Shuffle';
      }
      _repeatLabel = _nowPlaying['repeatSetting'].toString();
      if (_repeatLabel != '') {
        _repeatLabel = _shuffleLabel
            .toString()
            .split('_')
            .map((w) => '${w[0]}${w.substring(1).toLowerCase()}')
            .join(': ');
      } else {
        _repeatLabel = 'Repeat';
      }
      // play status sets button icon
      if (_playStatus == 'PLAY_STATE') {
        // set icon to play
      } else if (_playStatus == 'PAUSE_STATE') {
        // set icon to pause
      }
    });
  }

  // ****************************************************************************************************
  // GUI Design
  // ****************************************************************************************************
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Track name
            Text(
              _trackLabel,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            // Artist label
            Text(
              _artistLabel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(height: 4),
            // Album label
            Text(
              _albumLabel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(height: 4),
            // Tracknumber label
            Text(
              _trackNumberLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Colors.blueGrey.shade500,
              ),
            ),
            SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 20, top: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Previous button
                  ElevatedButton(
                    onPressed: _pressPreviousTrack,

                    style: ElevatedButton.styleFrom(
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      minimumSize: const Size(48, 48),
                    ),
                    child: const Icon(Icons.skip_previous, size: 28),
                  ),
                  const SizedBox(width: 10),
                  // Play/Pause button
                  ElevatedButton(
                    onPressed: _pressPlayPause,
                    style: ElevatedButton.styleFrom(
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 18,
                      ),
                      minimumSize: const Size(72, 64),
                    ),
                    // TODO: set the icon some other way
                    child: (_playStatus == 'PLAY_STATE'
                        ? const Icon(Icons.pause, size: 38)
                        : const Icon(Icons.play_arrow, size: 38)),
                  ),
                  const SizedBox(width: 10),
                  // Next button
                  ElevatedButton(
                    onPressed: _pressNextTrack,
                    style: ElevatedButton.styleFrom(
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      minimumSize: const Size(48, 48),
                    ),
                    child: const Icon(Icons.skip_next, size: 28),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 20, top: 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Repeat button
                  ElevatedButton(
                    onPressed: _pressRepeat,
                    style: ElevatedButton.styleFrom(
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      minimumSize: const Size(48, 48),
                    ),
                    child: Text(_repeatLabel, style: TextStyle(fontSize: 14)),
                  ),
                  const SizedBox(width: 10),
                  // Shuffle button
                  ElevatedButton(
                    onPressed: _pressShuffle,
                    style: ElevatedButton.styleFrom(
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      minimumSize: const Size(48, 48),
                    ),
                    child: Text(_shuffleLabel, style: TextStyle(fontSize: 14)),
                  ),
                ],
              ),
            ),
            // Volume slider
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20),
              child: Slider(
                value: _volume,
                max: _maxVolume,
                divisions: _maxVolume.toInt(),
                label: _volume.toStringAsFixed(0),
                onChanged: (double value) {
                  _changedVolume(value);
                },
              ),
            ),
            // Volume buttons and label
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Volume down
                ElevatedButton(
                  onPressed: _pressVolumeDown,
                  style: ElevatedButton.styleFrom(
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    minimumSize: const Size(40, 40),
                  ),
                  child: const Icon(Icons.remove, size: 24),
                ),
                const SizedBox(width: 28),
                // Volume label
                const Text(
                  'Volume',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 28),
                // Volume up
                ElevatedButton(
                  onPressed: _pressVolumeUp,
                  style: ElevatedButton.styleFrom(
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    minimumSize: const Size(40, 40),
                  ),
                  child: const Icon(Icons.add, size: 24),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Presets
            Padding(
              padding: const EdgeInsets.only(bottom: 20, top: 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () => _pressPreset(1),
                        style: ElevatedButton.styleFrom(
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 16,
                          ),
                          minimumSize: const Size(64, 48),
                        ),
                        child: Text('1', style: TextStyle(fontSize: 18)),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _pressPreset(2),
                        style: ElevatedButton.styleFrom(
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 16,
                          ),
                          minimumSize: const Size(64, 48),
                        ),
                        child: Text('2', style: TextStyle(fontSize: 18)),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _pressPreset(3),
                        style: ElevatedButton.styleFrom(
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 16,
                          ),
                          minimumSize: const Size(64, 48),
                        ),
                        child: Text('3', style: TextStyle(fontSize: 18)),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () => _pressPreset(4),
                        style: ElevatedButton.styleFrom(
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 16,
                          ),
                          minimumSize: const Size(64, 48),
                        ),
                        child: Text('4', style: TextStyle(fontSize: 18)),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _pressPreset(5),
                        style: ElevatedButton.styleFrom(
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 16,
                          ),
                          minimumSize: const Size(64, 48),
                        ),
                        child: Text('5', style: TextStyle(fontSize: 18)),
                      ),
                      SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _pressPreset(6),
                        style: ElevatedButton.styleFrom(
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 16,
                          ),
                          minimumSize: const Size(64, 48),
                        ),
                        child: Text('6', style: TextStyle(fontSize: 18)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Media Browser button
            ElevatedButton(
              onPressed: _pressMediaBrowser,
              style: ElevatedButton.styleFrom(
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                minimumSize: const Size(64, 48),
              ),
              child: Text('Media Browser', style: TextStyle(fontSize: 14)),
            ),
            SizedBox(height: 48),

            // Status label
            Text(
              _statusLabel,
              style: TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
          ],
        ),
      ),
    );
  }
}
