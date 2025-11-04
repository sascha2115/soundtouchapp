import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_size/window_size.dart';
import 'package:flutter/services.dart';
import 'mysoundtouch.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initial window position and size
  if (Platform.isMacOS) {
    const windowWidth = 450.0;
    const windowHeight = 850.0;
    final screenRect = await getScreenList().then(
      (screens) => screens.first.visibleFrame,
    );
    final screenWidth = screenRect.width;
    final screenHeight = screenRect.height;
    final rightX = screenRect.left + screenWidth - windowWidth;
    final topY = screenRect.top;
    setWindowFrame(Rect.fromLTWH(rightX, topY, windowWidth, windowHeight));
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

  // State Variables for Text Labels
  String _trackNameLabelText = 'Track Name';
  String _artistLabelText = 'Artist Name';
  String _albumLabelText = 'Album Name';
  String _trackNumberLabelText = '';
  String _volumeLabelText = 'Volume';
  String _statusLabelText = 'Discovering Device...';

  // More State Variables
  bool _showMediaBrowserState = false;
  bool _showLoadingSpinnerState = false;

  // More Global variables
  String _playStatus = 'PLAY_STATE';
  // Play state can be: or PLAY_STATE or PAUSE_STATE or STOP_STATE or BUFFERING_STATE
  String _repeatMode = 'REPEAT_OFF';
  // Repeat can be: REPEAT_ALL or REPEAT_ONE or REPEAT_OFF
  String _shuffleMode = 'SHUFFLE_OFF';
  // Shuffle can be: SHUFFLE_ON or SHUFFLE_OFF
  double _volume = 0;
  double _maxVolume = 50; // originally 100 but we never want that loud
  String _ipAddress = '';
  // Source can be: STORED_MUSIC or TUNEIN or some others...

  // TODO: get source account on filebrowser open

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
        _statusLabelText = 'Device: $_ipAddress';
      });
      await mySoundTouch.getXmlNowPlaying(_nowPlaying);
      updateLabelsFromNowPlaying();
    } else {
      setState(() {
        _statusLabelText = 'Device Not Found';
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
    if (_repeatMode == 'REPEAT_OFF') {
      print('⚠️ Setting Repeat all...');
      await mySoundTouch.sendXmlKey('REPEAT_ALL');
      _repeatMode = 'REPEAT_ALL';
    } else if (_repeatMode == 'REPEAT_ALL') {
      print('⚠️ Setting Repeat one...');
      await mySoundTouch.sendXmlKey('REPEAT_ONE');
      _repeatMode = 'REPEAT_ONE';
    } else if (_repeatMode == 'REPEAT_ONE') {
      print('⚠️ Setting Repeat off...');
      await mySoundTouch.sendXmlKey('REPEAT_OFF');
      _repeatMode = 'REPEAT_OFF';
    }
    // TODO: maybe dont set mode here but wait for status-info
  }

  // Pressed Shuffle button
  void _pressShuffle() async {
    if (_shuffleMode == 'SHUFFLE_OFF') {
      print('⚠️ Setting Shuffle on...');
      await mySoundTouch.sendXmlKey('SHUFFLE_ON');
      _shuffleMode = 'SHUFFLE_ON';
    } else if (_shuffleMode == 'SHUFFLE_ON') {
      print('⚠️ Setting Shuffle off...');
      await mySoundTouch.sendXmlKey('SHUFFLE_OFF');
      _shuffleMode = 'SHUFFLE_OFF';
    }
    // TODO: maybe dont set mode here but wait for status-info
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
      _showMediaBrowserState = true;
      _showLoadingSpinnerState = true;
    });
    await mySoundTouch.getMediaBrowserItems(_mediaItemList, '');
    setState(() {
      _showLoadingSpinnerState = false;
    });
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
      _trackNameLabelText = _nowPlaying['track'].toString();
      _artistLabelText = _nowPlaying['artist'].toString();
      _albumLabelText = _nowPlaying['album'].toString();
      _playStatus = _nowPlaying['playStatus'].toString();
      _trackNumberLabelText = _nowPlaying['offset'].toString();
      if (_trackNumberLabelText != '') {
        _trackNumberLabelText = 'Track $_trackNumberLabelText';
      }
      _shuffleMode = _nowPlaying['shuffleSetting'].toString();
      _repeatMode = _nowPlaying['repeatSetting'].toString();
      // Volume
      String volumeStr = _nowPlaying['volume'].toString();
      _volume = double.parse(volumeStr);
      _volumeLabelText = 'Volume: $volumeStr';
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
      setState(() => _showMediaBrowserState = false);
    }
  }

  // ****************************************************************************************************
  // GUI Design
  // ****************************************************************************************************
  @override
  Widget build(BuildContext context) {
    // Track Name Label
    Widget trackNameLabel = Text(
      _trackNameLabelText,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.primary,
        //color: Colors.white,
      ),
    );
    // Artist Label
    Widget artistLabel = Text(
      _artistLabelText,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Theme.of(context).colorScheme.secondary,
      ),
    );
    // Album Label
    Widget albumLabel = Text(
      _albumLabelText,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Theme.of(context).colorScheme.secondary,
      ),
    );
    // Track Number Label
    Widget trackNumberLabel = Text(
      _trackNumberLabelText,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: Colors.blueGrey.shade500,
      ),
    );

    // Previous Button
    Widget previousButton = ElevatedButton(
      onPressed: _pressPreviousTrack,
      style: ElevatedButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      ),
      child: const Icon(Icons.skip_previous, size: 28),
    );
    // Play/Pause Button
    Widget playPauseButton = ElevatedButton(
      onPressed: _pressPlayPause,
      style: ElevatedButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 28),
      ),
      child: Icon(
        (_playStatus == 'PLAY_STATE') ? Icons.pause : Icons.play_arrow,
        size: 38,
      ),
    );
    // Next Button
    Widget nextButton = ElevatedButton(
      onPressed: _pressNextTrack,
      style: ElevatedButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      ),
      child: const Icon(Icons.skip_next, size: 28),
    );
    // Repeat Button
    Widget repeatButton = ElevatedButton(
      onPressed: _pressRepeat,
      style: ElevatedButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      child: Text(
        (_repeatMode == 'REPEAT_ALL')
            ? 'Repeat is All'
            : (_repeatMode == 'REPEAT_ONE')
            ? 'Repeat is One'
            : 'Repeat is Off',
        style: TextStyle(fontSize: 13),
      ),
      //child: Text(_repeatLabelText, style: TextStyle(fontSize: 13)),
    );
    // Shuffle Button
    Widget shuffleButton = ElevatedButton(
      onPressed: _pressShuffle,
      style: ElevatedButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      child: Text(
        (_shuffleMode == 'SHUFFLE_ON') ? 'Shuffle is On' : 'Shuffle is Off',
        style: TextStyle(fontSize: 13),
      ),
      //child: Text(_shuffleLabelText, style: TextStyle(fontSize: 14)),
    );
    // Volume Slider
    Widget volumeSlider = Slider(
      value: _volume,
      max: _maxVolume,
      divisions: _maxVolume.toInt(),
      label: _volume.toStringAsFixed(0),
      onChanged: (double value) {
        _changedVolume(value);
      },
    );
    // Volume Down Button
    Widget volumeDownButton = ElevatedButton(
      onPressed: _pressVolumeDown,
      style: ElevatedButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      child: const Icon(Icons.remove, size: 24),
    );
    // Volume Label
    Widget volumeLabel = Text(
      _volumeLabelText,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
    // Volume Up Button
    Widget volumeUpButton = ElevatedButton(
      onPressed: _pressVolumeUp,
      style: ElevatedButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      child: const Icon(Icons.add, size: 24),
    );
    // Preset Button(s)
    Widget buildPresetButton(int n) => ElevatedButton(
      onPressed: () => _pressPreset(n),
      style: ElevatedButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      ),
      child: Text('$n', style: const TextStyle(fontSize: 18)),
    );
    // Media Browser Button
    Widget mediaBrowserButton = ElevatedButton(
      onPressed: _pressMediaBrowser,
      style: ElevatedButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
      child: Text('Media Browser', style: TextStyle(fontSize: 14)),
    );
    // Status Label
    Widget statusLabel = Text(
      _statusLabelText,
      style: TextStyle(fontSize: 12, color: Colors.blueGrey),
    );

    // Back Button
    Widget backButton = ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      ),
      child: Text('← Back ', style: TextStyle(fontSize: 14)),
    );
    // Loading Spinner
    Widget loadingSpinner = _showLoadingSpinnerState
        ? CircularProgressIndicator()
        : Container();

    // Close Button
    Widget closeButton = ElevatedButton(
      onPressed: () => setState(() => _showMediaBrowserState = false),
      style: ElevatedButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      ),
      child: Text('Close', style: TextStyle(fontSize: 14)),
    );
    // Media List View
    List mediaItemLocations = _mediaItemList.keys.toList();
    List mediaItemNames = _mediaItemList.values.toList();

    Widget mediaListView = ListView.builder(
      itemCount: _mediaItemList.length,
      itemBuilder: (context, index) {
        final itemLocation = mediaItemLocations[index];
        final itemName = mediaItemNames[index];
        return ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          leading: Icon(Icons.folder, size: 28, color: Colors.blue),
          title: Text(itemName, style: TextStyle(fontSize: 14)),
          trailing: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          onTap: () {
            print('⚠️ Tapped item: $itemLocation -> $itemName');
          },
          contentPadding: EdgeInsets.symmetric(horizontal: 8),
        );
      },
    );

    // ****************************************************************************************************
    // Scaffold Layout
    // ****************************************************************************************************
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
                  // Playing Labels
                  trackNameLabel,
                  const SizedBox(height: 8),
                  artistLabel,
                  const SizedBox(height: 4),
                  albumLabel,
                  const SizedBox(height: 4),
                  trackNumberLabel,
                  const SizedBox(height: 12),
                  // Buttons Row
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20, top: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        previousButton,
                        const SizedBox(width: 10),
                        playPauseButton,
                        const SizedBox(width: 10),
                        nextButton,
                      ],
                    ),
                  ),
                  // Buttons Row
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20, top: 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        repeatButton,
                        const SizedBox(width: 10),
                        shuffleButton,
                      ],
                    ),
                  ),
                  // Volume Slider
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20),
                    child: volumeSlider,
                  ),
                  // Volume Row
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      volumeDownButton,
                      const SizedBox(width: 28),
                      volumeLabel,
                      const SizedBox(width: 28),
                      volumeUpButton,
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Presets
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20, top: 20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            buildPresetButton(1),
                            const SizedBox(width: 8),
                            buildPresetButton(2),
                            const SizedBox(width: 8),
                            buildPresetButton(3),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            buildPresetButton(4),
                            const SizedBox(width: 8),
                            buildPresetButton(5),
                            const SizedBox(width: 8),
                            buildPresetButton(6),
                          ],
                        ),
                      ],
                    ),
                  ),
                  mediaBrowserButton,
                  const SizedBox(height: 48),
                  statusLabel,
                ],
              ),
            ),
            // Second Layer: Media Browser
            if (_showMediaBrowserState)
              Positioned.fill(
                child: Container(
                  color: const Color.fromRGBO(0, 0, 0, 0.5),
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Buttons Row
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 16,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  backButton,
                                  Center(child: loadingSpinner),
                                  closeButton,
                                ],
                              ),
                            ),
                            Expanded(child: mediaListView),
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
