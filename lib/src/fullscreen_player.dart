library vimeoplayer;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import 'package:wakelock/wakelock.dart';
import 'dart:async';

import '../vimeoplayer.dart';
import 'meedu_player_status.dart';

/// Full screen video player class
class FullscreenPlayer extends StatefulWidget {
  final String id;
  final bool autoPlay;
  final bool looping;
  final VideoPlayerController controller;
  final position;
  final Future<void> initFuture;
  final String qualityValue;
  final Color backgroundColor;

  ///[overlayTimeOut] in seconds: decide after how much second overlay should vanishes
  ///minimum 3 seconds of timeout is stacked
  final int overlayTimeOut;

  final Color loadingIndicatorColor;
  final Color controlsColor;

  //contains the resolution qualities of vimeo video
  final List<MapEntry> qualityValues;
  final String qualityKey;

  FullscreenPlayer({
    @required this.id,
    @required this.overlayTimeOut,
    @required this.qualityValues,
    @required this.qualityKey,
    this.autoPlay = false,
    this.looping,
    this.controller,
    this.position,
    this.initFuture,
    this.qualityValue,
    this.backgroundColor,
    this.loadingIndicatorColor,
    this.controlsColor,
    Key key,
  }) : super(key: key);

  @override
  _FullscreenPlayerState createState() => _FullscreenPlayerState(
        id,
        autoPlay,
        looping,
        controller,
        position,
        initFuture,
        qualityValue,
        qualityKey,
      );
}

class _FullscreenPlayerState extends State<FullscreenPlayer> {
  String _id;
  bool autoPlay = false;
  bool looping = false;
  bool _overlay = true;
  bool fullScreen = true;

  VideoPlayerController controller;
  VideoPlayerController _controller;

  int position;

  Future<void> initFuture;
  var qualityValue;
  String qualityKey;

  _FullscreenPlayerState(
    this._id,
    this.autoPlay,
    this.looping,
    this.controller,
    this.position,
    this.initFuture,
    this.qualityValue,
    this.qualityKey,
  );

  //// Quality Class
  //QualityLinks _quality;
  //Map _qualityValues;

  // Rewind variable
  bool _seek = true;

  // Video variables
  double videoHeight;
  double videoWidth;
  double videoMargin;

  // Variables for double-tap zones
  double doubleTapRMarginFS = 36;
  double doubleTapRWidthFS = 700;
  double doubleTapRHeightFS = 300;
  double doubleTapLMarginFS = 10;
  double doubleTapLWidthFS = 700;
  double doubleTapLHeightFS = 400;

  //overlay timeout handler
  Timer overlayTimer;
  //indicate if overlay to be display on commencing video or not
  bool initialOverlay = true;

  double volumeBeforeMute = 0;
  bool mute = false;

  Timer _timer;
  bool _showControls = true;

  // OBSERVABLES
  Duration positionVideo = Duration.zero;
  Duration sliderPosition = Duration.zero;
  Duration duration = Duration.zero;

  @override
  void initState() {
    // Initialize video controllers when receiving data from Vimeo
    _controller = controller;
    if (autoPlay) _controller.play();

    // // Load the list of video qualities
    // _quality = QualityLinks(_id); //Create class
    // _quality.getQualitiesSync().then((value) {
    //   _qualityValues = value;
    // });

    setState(() {
      SystemChrome.setPreferredOrientations(
          [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      SystemChrome.setEnabledSystemUIOverlays([SystemUiOverlay.bottom]);
    });

    //Keep screen active till video plays
    Wakelock.enable();

    super.initState();
  }

  // Track the user's click back and translate
  // the screen with the player is not in fullscreen mode, return the orientation
  Future<bool> _onWillPop() {
    final playing = _controller.value.isPlaying;
    overlayTimer?.cancel();
    setState(() {
      _controller.pause();
      SystemChrome.setPreferredOrientations(
          [DeviceOrientation.portraitDown, DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIOverlays(
          [SystemUiOverlay.top, SystemUiOverlay.bottom]);
    });
    Navigator.pop(
      context,
      ControllerDetails(
        playingStatus: playing,
        position: _controller.value.position.inSeconds,
        resolutionQuality: MapEntry(qualityKey, qualityValue),
      ),
    );
    return Future.value(true);
  }

  ///display or vanishes the overlay i.e playing controls, etc.
  void _toogleOverlay() {
    //Inorder to avoid descrepancy in overlay popping up & vanishing out
    overlayTimer?.cancel();
    if (!_overlay) {
      overlayTimer = Timer(Duration(seconds: widget.overlayTimeOut), () {
        setState(() {
          _overlay = false;
          doubleTapRHeightFS = videoHeight + 36;
          doubleTapLHeightFS = videoHeight;
          doubleTapRMarginFS = 0;
          doubleTapLMarginFS = 0;
        });
      });
    }
    // Edit the size of the double tap area when showing the overlay.
    // Made to open the "Full Screen" and "Quality" buttons
    setState(() {
      _overlay = !_overlay;
      if (_overlay) {
        doubleTapRHeightFS = videoHeight - 36;
        doubleTapLHeightFS = videoHeight - 10;
        doubleTapRMarginFS = 36;
        doubleTapLMarginFS = 10;
      } else if (!_overlay) {
        doubleTapRHeightFS = videoHeight + 36;
        doubleTapLHeightFS = videoHeight;
        doubleTapRMarginFS = 0;
        doubleTapLMarginFS = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: _onWillPop,
        child: Scaffold(
            backgroundColor: widget.backgroundColor,
            body: Center(
                child: Stack(
              alignment: AlignmentDirectional.center,
              children: <Widget>[
                GestureDetector(
                  child: FutureBuilder(
                      future: initFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done) {
                          // Control the width and height of the video
                          double delta = MediaQuery.of(context).size.width -
                              MediaQuery.of(context).size.height *
                                  _controller.value.aspectRatio;
                          if (MediaQuery.of(context).orientation ==
                                  Orientation.portrait ||
                              delta < 0) {
                            videoHeight = MediaQuery.of(context).size.width /
                                _controller.value.aspectRatio;
                            videoWidth = MediaQuery.of(context).size.width;
                            videoMargin = 0;
                          } else {
                            videoHeight = MediaQuery.of(context).size.height;
                            videoWidth =
                                videoHeight * _controller.value.aspectRatio;
                            videoMargin = (MediaQuery.of(context).size.width -
                                    videoWidth) /
                                2;
                          }
                          // Variables double tap, depending on the size of the video
                          doubleTapRWidthFS = videoWidth;
                          doubleTapRHeightFS = videoHeight - 36;
                          doubleTapLWidthFS = videoWidth;
                          doubleTapLHeightFS = videoHeight;

                          // Immediately upon entering the fullscreen mode, rewind
                          // to the right place
                          if (_seek && fullScreen) {
                            _controller.seekTo(Duration(seconds: position));
                            _seek = false;
                          }

                          // Go to the right place when changing quality
                          if (_seek &&
                              _controller.value.duration.inSeconds > 2) {
                            _controller.seekTo(Duration(seconds: position));
                            _seek = false;
                          }
                          SystemChrome.setEnabledSystemUIOverlays(
                              [SystemUiOverlay.bottom]);

                          //vanish overlayer if so.
                          if (initialOverlay) {
                            overlayTimer = Timer(
                                Duration(seconds: widget.overlayTimeOut), () {
                              setState(() {
                                _overlay = false;
                                doubleTapRHeightFS = videoHeight + 36;
                                doubleTapLHeightFS = videoHeight;
                                doubleTapRMarginFS = 0;
                                doubleTapLMarginFS = 0;
                              });
                            });
                            initialOverlay = false;
                          }

                          // Rendering player elements
                          return Stack(
                            children: <Widget>[
                              Container(
                                height: videoHeight,
                                width: videoWidth,
                                margin: EdgeInsets.only(left: videoMargin),
                                child: VideoPlayer(_controller),
                              ),
                              _videoOverlay(),
                            ],
                          );
                        } else {
                          return Center(
                              heightFactor: 6,
                              child: CircularProgressIndicator(
                                strokeWidth: 4,
                                valueColor: widget.loadingIndicatorColor != null
                                    ? AlwaysStoppedAnimation<Color>(
                                        widget.loadingIndicatorColor)
                                    : null,
                              ));
                        }
                      }),
                  // Edit the size of the double tap area when showing the overlay.
                  // Made to open the "Full Screen" and "Quality" buttons
                  onTap: _toogleOverlay,
                ),
                GestureDetector(
                    child: Container(
                      width: doubleTapLWidthFS / 2 - 30,
                      height: doubleTapLHeightFS - 44,
                      margin: EdgeInsets.fromLTRB(
                          0, 0, doubleTapLWidthFS / 2 + 30, 40),
                      decoration: BoxDecoration(
                          //color: Colors.red,
                          ),
                    ),
                    // Edit the size of the double tap area when showing the overlay.
                    // Made to open the "Full Screen" and "Quality" buttons
                    onTap: _toogleOverlay,
                    onDoubleTap: () {
                      setState(() {
                        _controller.seekTo(Duration(
                            seconds:
                                _controller.value.position.inSeconds - 10));
                      });
                    }),
                GestureDetector(
                    child: Container(
                      width: doubleTapRWidthFS / 2 - 45,
                      height: doubleTapRHeightFS - 80,
                      margin: EdgeInsets.fromLTRB(doubleTapRWidthFS / 2 + 45, 0,
                          0, doubleTapLMarginFS + 20),
                      decoration: BoxDecoration(
                          //color: Colors.red,
                          ),
                    ),
                    // Edit the size of the double tap area when showing the overlay.
                    // Made to open the "Full Screen" and "Quality" buttons
                    onTap: _toogleOverlay,
                    onDoubleTap: () {
                      setState(() {
                        _controller.seekTo(Duration(
                            seconds:
                                _controller.value.position.inSeconds + 10));
                      });
                    }),
              ],
            ))));
  }

  //================================ Quality ================================//
  void _settingModalBottomSheet(context) {
    showModalBottomSheet(
        context: context,
        builder: (BuildContext bc) {
          final children = <Widget>[];
          //_qualityValues.forEach((elem, value) => (children.add(new ListTile(
          widget.qualityValues.forEach((quality) => (children.add(new ListTile(
              title: new Text(" ${quality.key.toString()}"),
              trailing: qualityKey == quality.key ? Icon(Icons.check) : null,
              onTap: () => {
                    // Update application state and redraw
                    setState(() {
                      _controller.pause();
                      qualityKey = quality.key;
                      _controller =
                          VideoPlayerController.network(quality.value);
                      _controller.setLooping(looping);
                      _seek = true;
                      initFuture = _controller.initialize();
                      _controller.play();
                      Navigator.pop(context); //close sheets
                    }),
                  }))));

          return Container(
            height: videoHeight,
            child: ListView(
              children: children,
            ),
          );
        });
  }

  //================================ OVERLAY ================================//
  Widget _videoOverlay() {
    return _overlay
        ? Stack(
            children: <Widget>[
              GestureDetector(
                child: Center(
                  child: Container(
                    width: videoWidth,
                    height: videoHeight,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [
                          const Color(0x662F2C47),
                          const Color(0x662F2C47)
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: IconButton(
                    padding: EdgeInsets.only(
                      top: videoHeight / 2 - 50,
                      bottom: videoHeight / 2 - 30,
                    ),
                    icon:
                        _controller.value.duration == _controller.value.position
                            ? Icon(
                                Icons.replay,
                                size: 80.0,
                                color: widget.controlsColor,
                              )
                            : _controller.value.isPlaying
                                ? Icon(
                                    Icons.pause,
                                    size: 80.0,
                                    color: widget.controlsColor,
                                  )
                                : Icon(
                                    Icons.play_arrow,
                                    size: 80.0,
                                    color: widget.controlsColor,
                                  ),
                    onPressed: () {
                      setState(() {
                        //replay video
                        if (_controller.value.position ==
                            _controller.value.duration) {
                          setState(() {
                            _controller.seekTo(Duration());
                            _controller.play();
                          });
                        }
                        //vanish the overlay if play button is pressed
                        else if (!_controller.value.isPlaying) {
                          overlayTimer?.cancel();
                          _controller.play();
                          _overlay = !_overlay;
                        } else {
                          _controller.pause();
                        }
                      });
                    }),
              ),
              // Mute Button
              Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    // decoration: BoxDecoration(color: Colors.grey),
                    margin: EdgeInsets.only(
                        top: videoHeight - 60,
                        left: videoWidth + videoMargin - 120),
                    child: _muteButton(),
                  )),
              Container(
                margin: EdgeInsets.only(
                    top: videoHeight - 55, left: videoWidth + videoMargin - 60),
                child: IconButton(
                    alignment: AlignmentDirectional.center,
                    icon: Icon(Icons.fullscreen,
                        size: 50.0, color: widget.controlsColor),
                    onPressed: () {
                      final playing = _controller.value.isPlaying;
                      overlayTimer?.cancel();
                      setState(() {
                        _controller.pause();
                        SystemChrome.setPreferredOrientations([
                          DeviceOrientation.portraitDown,
                          DeviceOrientation.portraitUp
                        ]);
                        SystemChrome.setEnabledSystemUIOverlays(
                            [SystemUiOverlay.top, SystemUiOverlay.bottom]);
                      });
                      Navigator.pop(
                        context,
                        ControllerDetails(
                          playingStatus: playing,
                          position: _controller.value.position.inSeconds,
                          resolutionQuality: MapEntry(qualityKey, qualityValue),
                        ),
                      );
                      // Navigator.pop(context, {
                      //   'position': _controller.value.position.inSeconds,
                      //   'status': playing
                      // });
                    }),
              ),
              Container(
                margin: EdgeInsets.only(left: videoWidth + videoMargin - 48),
                child: IconButton(
                    icon: Icon(
                      Icons.settings_applications,
                      size: 40.0,
                      color: widget.controlsColor,
                    ),
                    onPressed: () {
                      position = _controller.value.position.inSeconds;
                      _seek = true;
                      _settingModalBottomSheet(context);
                      setState(() {});
                    }),
              ),
              Container(
                // ===== Slider ===== //
                margin: EdgeInsets.only(
                    top: videoHeight - 40, left: videoMargin), //CHECK IT
                child: _videoOverlaySlider(),
              )
            ],
          )
        : Center();
  }

  // ==================== SLIDER =================== //
  Widget _videoOverlaySlider() {
    return ValueListenableBuilder(
      valueListenable: _controller,
      builder: (context, VideoPlayerValue value, child) {
        if (!value.hasError && value.isInitialized) {
          return Row(
            children: <Widget>[
              Container(
                width: 46,
                alignment: Alignment(0, 0),
                child: Text(
                  '${_twoDigits(value.position.inMinutes)}:${_twoDigits(value.position.inSeconds - value.position.inMinutes * 60)}',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              Container(
                height: 30,
                width: videoWidth - 92 - 120,
                child: VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  colors: VideoProgressColors(
                    playedColor: Color(0xffE50B15),
                    backgroundColor: Color(0x5515162B),
                    bufferedColor: Color(0x5583D8F7),
                  ),
                  padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
                ),
              ),
              Container(
                width: 46,
                alignment: Alignment(0, 0),
                child: Text(
                  '${_twoDigits(value.duration.inMinutes)}:${_twoDigits(value.duration.inSeconds - value.duration.inMinutes * 60)}',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        } else {
          //Screen can resume it's active status from System Configurations
          Wakelock.disable();
          return Container();
        }
      },
    );
  }

  Widget _muteButton() {
    return IconButton(
        alignment: AlignmentDirectional.center,
        icon: Icon(
          mute ? Icons.volume_off : Icons.volume_up,
          size: 40.0,
          color: widget.controlsColor,
        ),
        onPressed: () async {
          final playing = _controller.value.isPlaying;
          setState(() {
            // _controller;
            // overlayTimer?.cancel();
            mute = !mute;
            setMute(mute);
          });
        });
  }

  Future<void> setVolume(double volume) async {
    assert(volume >= 0.0 && volume <= 1.0); // validate the param
    volumeBeforeMute = _controller.value.volume;
    await _controller?.setVolume(volume);
  }

  /// set the video player to mute or sound
  ///
  /// [enabled] if is true the video player is muted
  Future<void> setMute(bool enabled) async {
    if (enabled) {
      volumeBeforeMute = _controller.value.volume;
    }
    mute = enabled;
    await this.setVolume(enabled ? 0 : volumeBeforeMute);
  }

  /// fast Forward (10 seconds)
  Future<void> fastForward() async {
    final to = positionVideo.inSeconds + 10;
    if (duration.inSeconds > to) {
      await seekTo(Duration(seconds: to));
    }
  }

  /// rewind (10 seconds)
  Future<void> rewind() async {
    final to = positionVideo.inSeconds - 10;
    await seekTo(Duration(seconds: to < 0 ? 0 : to));
  }

  /// seek the current video position
  Future<void> seekTo(Duration position) async {
    await _controller?.seekTo(Duration(seconds: position.inSeconds));

    if (playerStatus.stopped) {
      await play();
    }
  }

  /// play the current video
  ///
  /// [repeat] if is true the player go to Duration.zero before play
  Future<void> play({bool repeat = false}) async {
    if (repeat) {
      await seekTo(Duration.zero);
    }
    await _controller?.play();
    playerStatus.status.value = PlayerStatus.playing;

    _hideTaskControls();
  }

  /// pause the current video
  ///
  /// [notify] if is true and the events is not null we notifiy the event
  Future<void> pause({bool notify = true}) async {
    await _controller?.pause();
    playerStatus.status.value = PlayerStatus.paused;
  }

  /// create a taks to hide controls after certain time
  void _hideTaskControls() {
    _timer = Timer(Duration(seconds: 5), () {
      this.controls = false;
      _timer = null;
    });
  }

  /// show or hide the player controls
  set controls(bool visible) {
    _showControls = visible;
    _timer?.cancel();
    if (visible) {
      _hideTaskControls();
    }
  }

  /// the playerStatus to notify the player events like paused,playing or stopped
  /// [playerStatus] has a [status] observable
  final MeeduPlayerStatus playerStatus = MeeduPlayerStatus();

  ///Convert the integer number in atleast 2 digit format (i.e appending 0 in front if any)
  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  @override
  void dispose() {
    overlayTimer?.cancel();
    Wakelock.disable();
    super.dispose();
  }
}
