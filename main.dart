import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_size/window_size.dart';
import 'package:flutter/services.dart';
import 'mysoundtouch.dart';

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
          primary: Colors.white,
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
  final MySoundTouch mySoundTouch = MySoundTouch();
  FocusNode _keyboardFocusNode = FocusNode();

  // State variables to hold  text labels
  String _trackLabel = 'Track Name';
  String _artistLabel = 'Artist Name';
  String _albumLabel = 'Album Name';
  String _trackNumberLabel = '';
  String _repeatLabel = 'Repeat';
  String _shuffleLabel = 'Shuffle';
  String _volumeLabel = 'Volume';
  String _statusLabel = 'Discovering device...';
  // More global variables
  String _playStatus = 'PLAY_STATE';
  // Play state can be: or PLAY_STATE or PAUSE_STATE or STOP_STATE or BUFFERING_STATE
  String _repeatMode = 'Off';
  // Repeat can be: All or One or Off
  String _shuffleMode = 'Off';
  // Shuffle can be: On or Off
  double _volume = 0;
  double _maxVolume = 50; // originally 100 but we never want that loud
  String _ipAddress = '';
  String _source = 'STORED_MUSIC';
  // Source can be: STORED_MUSIC or TUNEIN or some others...
  String _sourceAccount = '10809696-105a-3721-e8b8-f4b5aa96c210/0';
  // TODO: get source account on filebrowser open
  bool _showMediaBrowser = false;
  // Array to hold media items, i.e. ['0$4$215', 'Foldername']
  Map<String, String> _mediaItemList = {};
  // Array to hold the curent "NowPlaying" info
  Map<String, String> _nowPlaying = {};

  // TODO: maybe later we add _skipEnabled and _skipPreviousEnabled

  // Initialization
  @override
  void initState() {
    super.initState();
    _initAsync();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyboardFocusNode.requestFocus();
    });
  }

  // Initialization
  Future<void> _initAsync() async {
    String? foundIp = await mySoundTouch.discoverDevice();
    _ipAddress = foundIp ?? '';
    if (_ipAddress.isNotEmpty) {
      setState(() {
        _statusLabel = 'Device: $_ipAddress';
      });
      await mySoundTouch.getXmlNowPlaying(_nowPlaying);
      updateLabelsFromNowPlaying();
    } else {
      setState(() {
        _statusLabel = 'Device not found';
      });
    }
  }

  // Pressed Play button
  void _pressPlayPause() async {
    print('⚠️ Pressing Play/Pause...');
    await mySoundTouch.sendXmlKey('PLAY_PAUSE');
  }

  // Pressed Previous button
  void _pressPreviousTrack() async {
    print('⚠️ Skipping to Previous track...');
    await mySoundTouch.sendXmlKey('PREV_TRACK');
  }

  // Pressed Next button
  void _pressNextTrack() async {
    print('⚠️ Skipping to Next track...');
    await mySoundTouch.sendXmlKey('NEXT_TRACK');
  }

  // Pressed Repeat button
  void _pressRepeat() async {
    if (_repeatMode == 'Off') {
      print('⚠️ Setting Repeat all...');
      await mySoundTouch.sendXmlKey('REPEAT_ALL');
      _repeatMode = 'All';
    } else if (_repeatMode == 'All') {
      print('⚠️ Setting Repeat one...');
      await mySoundTouch.sendXmlKey('REPEAT_ONE');
      _repeatMode = 'One';
    } else if (_repeatMode == 'One') {
      print('⚠️ Setting Repeat off...');
      await mySoundTouch.sendXmlKey('REPEAT_OFF');
      _repeatMode = 'Off';
    }
    // TODO: set repeat mode here or wait for status-info ?
  }

  // Pressed Shuffle button
  void _pressShuffle() async {
    if (_shuffleMode == 'Off') {
      print('⚠️ Setting Shuffle on...');
      await mySoundTouch.sendXmlKey('SHUFFLE_ON');
      _shuffleMode = 'On';
    } else {
      print('⚠️ Setting Shuffle off...');
      await mySoundTouch.sendXmlKey('SHUFFLE_OFF');
      _shuffleMode = 'Off';
    }
    // TODO: set shuffle mode here or wait for status-info ?
  }

  // Pressed Volume down
  void _pressVolumeDown() async {
    print('⚠️ Setting Volume down...');
    await mySoundTouch.sendXmlKey('VOLUME_DOWN');
  }

  // Pressed Volume down
  void _pressVolumeUp() async {
    print('⚠️ Setting Volume up...');
    await mySoundTouch.sendXmlKey('VOLUME_UP');
  }

  // Pressed a Preset button
  void _pressPreset(int number) async {
    print('⚠️ Selecting Preset $number...');
    await mySoundTouch.sendXmlKey('PRESET_$number');
  }

  // Changed Volume slider
  void _changedVolume(double value) async {
    setState(() {
      _volume = value;
      // TODO: set volume here or wait for status-info ?
    });
    await mySoundTouch.sendXmlVolume(value.toInt());
  }

  // Pressed MediaBrowser button
  void _pressMediaBrowser() async {
    setState(() {
      _showMediaBrowser = true;
    });
    mySoundTouch.getMediaBrowserItems(_mediaItemList);
  }

  // Pressed Update button
  void _pressUpdate() async {
    await mySoundTouch.getXmlNowPlaying(_nowPlaying);
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
        _trackNumberLabel = 'Track $_trackNumberLabel';
      }
      // Shuffle
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
      // Repeat
      _repeatLabel = _nowPlaying['repeatSetting'].toString();
      if (_repeatLabel != '') {
        _repeatLabel = _repeatLabel
            .toString()
            .split('_')
            .map((w) => '${w[0]}${w.substring(1).toLowerCase()}')
            .join(': ');
      } else {
        _repeatLabel = 'Repeat';
      }
      // Play status sets button icon
      if (_playStatus == 'PLAY_STATE') {
        // Set icon to play
      } else if (_playStatus == 'PAUSE_STATE') {
        // Set icon to pause
      }
      // Volume
      String volumeStr = _nowPlaying['volume'].toString();
      _volume = double.parse(volumeStr);
      _volumeLabel = 'Volume: $volumeStr';
    });
  }

  // ****************************************************************************************************
  // Handle Keyboard Events
  // ****************************************************************************************************
  void _handleKeyPress(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.space) {
      _pressPlayPause();
    }
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _pressPreviousTrack();
    }
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _pressNextTrack();
    }
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.minus) {
      _pressVolumeDown();
    }
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.add) {
      _pressVolumeUp();
    }
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyR) {
      _pressRepeat();
    }
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyS) {
      _pressShuffle();
    }
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.digit1) {
      _pressPreset(1);
    }
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.digit2) {
      _pressPreset(2);
    }
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.digit3) {
      _pressPreset(3);
    }
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.digit4) {
      _pressPreset(4);
    }
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.digit5) {
      _pressPreset(5);
    }
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.digit6) {
      _pressPreset(6);
    }
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyU) {
      _pressUpdate();
    }
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() => _showMediaBrowser = false);
    }
  }

  // ****************************************************************************************************
  // GUI Design
  // ****************************************************************************************************
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //appBar: AppBar(
      //  backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      //  title: Text(widget.title),
      //),
      body: KeyboardListener(
        focusNode: _keyboardFocusNode,
        onKeyEvent: _handleKeyPress,
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // Track name
                  Text(
                    _trackLabel,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      //color: Colors.white,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  SizedBox(height: 8),
                  // Artist label
                  Text(
                    _artistLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  SizedBox(height: 4),
                  // Album label
                  Text(
                    _albumLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Theme.of(context).colorScheme.secondary,
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
                          // TODO: maybe set the icon some other way (?)
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
                          child: Text(
                            _repeatLabel,
                            style: TextStyle(fontSize: 14),
                          ),
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
                          child: Text(
                            _shuffleLabel,
                            style: TextStyle(fontSize: 14),
                          ),
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
                      Text(
                        _volumeLabel,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
                    child: Text(
                      'Media Browser',
                      style: TextStyle(fontSize: 14),
                    ),
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
            // Second Layer: Media Browser
            if (_showMediaBrowser)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 16,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  ElevatedButton(
                                    onPressed: () {},
                                    style: ElevatedButton.styleFrom(
                                      shape: const StadiumBorder(),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 32,
                                        vertical: 16,
                                      ),
                                    ),
                                    child: Text(
                                      '← Back',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => setState(
                                      () => _showMediaBrowser = false,
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      shape: const StadiumBorder(),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 32,
                                        vertical: 16,
                                      ),
                                    ),
                                    child: Text(
                                      'Close',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _mediaItemList.length,
                                itemBuilder: (context, index) {
                                  return ListTile(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    leading: Icon(
                                      Icons.folder,
                                      size: 28,
                                      color: Colors.blue,
                                    ),
                                    title: Text(
                                      _mediaItemList.values.toList()[index],
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    trailing: Icon(
                                      Icons.arrow_forward_ios,
                                      size: 14,
                                      color: Colors.grey,
                                    ),
                                    // Optional: onTap handler
                                    onTap: () {
                                      // Handle tap event here
                                    },
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ), // controls horizontal padding
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  // ****************************************************************************************************
  // Class '_MyHomePageState' end
  // ****************************************************************************************************
}
