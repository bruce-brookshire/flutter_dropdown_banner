library dropdown_banner;

import 'dart:collection';
import 'dart:async';
import 'package:dart_notification_center/dart_notification_center.dart';
import 'package:flutter/material.dart';

/// Channel name to communicate menu updates on
const String _BANNERCHANNEL = 'createDropdownBanner';

typedef void _IntCallback(int id);

/// DropdownBanner manages the creation and animation of banner elements
/// that are useful for displaying warnings and updates to users.
class DropdownBanner extends StatefulWidget {
  /// Builder in which to construct the app content that you are wrapping
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  DropdownBanner({@required this.child, @required this.navigatorKey}) {
    DartNotificationCenter.registerChannel(channel: _BANNERCHANNEL);
  }

  static int _idCounter = 0;

  /// Display a banner with the desired [text] and [textStyle] on a [color] background
  /// for the [duration] specified. If the banner is tapped and [tapCallback] != null,
  /// the callback will be executed and the banner dismissed.
  static showBanner({
    @required String text,
    Duration duration,
    Color color = Colors.white,
    TextStyle textStyle,
    VoidCallback tapCallback,
  }) {
    DartNotificationCenter.post(
      channel: _BANNERCHANNEL,
      options: {
        'id': _idCounter + 1,
        'duration': duration ?? Duration(seconds: 3),
        'text': text,
        'color': color,
        'textStyle': textStyle,
        'tapCallback': tapCallback,
      },
    );
    ++_idCounter;
  }

  @override
  State<StatefulWidget> createState() => _DropdownBannerState();
}

class _DropdownBannerState extends State<DropdownBanner> {
  List<_BannerInstanceObject> banners = [];

  @override
  void initState() {
    super.initState();

    DartNotificationCenter.subscribe(
      channel: _BANNERCHANNEL,
      observer: this,
      onNotification: createBanner,
    );
  }

  @override
  void dispose() {
    DartNotificationCenter.unsubscribe(observer: this);

    banners = [];

    super.dispose();
  }

  void createBanner(dynamic bannerDetails) {
    assert(
      bannerDetails is Map<String, dynamic> &&
          bannerDetails['id'] is int &&
          bannerDetails['duration'] is Duration &&
          bannerDetails['color'] is Color,
      'Do not post to $_BANNERCHANNEL using DartNotificationCenter, as this is reserved for internal use for DropdownBanner to work properly',
    );

    final _BannerInstanceObject banner = _BannerInstanceObject(
      bannerDetails['id'],
      bannerDetails['duration'],
      bannerDetails['text'],
      bannerDetails['color'],
      bannerDetails['textStyle'],
      bannerDetails['tapCallback'],
      onAnimationCompletion,
    );

    setState(() => banners.add(banner));
  }

  void onAnimationCompletion(int id) =>
      setState(() => banners.removeWhere((b) => b.id == id));

  @override
  Widget build(BuildContext context) => Stack(
        children: <Widget>[
          Align(
            alignment: Alignment.center,
            child: Navigator(
              key: widget.navigatorKey,
              onGenerateRoute: (settings) => MaterialPageRoute(
                settings: settings,
                builder: (_) => widget.child,
              ),
            ),
          ),
          ...banners
        ],
      );
}

/// Container to track various aspects of the appearance and life of a dropdown banner object
class _BannerInstanceObject extends StatefulWidget {
  /// Identify unique state between rebuilds
  final Key key = UniqueKey();

  /// Unique id for referencing
  final int id;

  /// Length of time the banner stays visible for
  final Duration duration;

  /// Text to display in the banner
  final String text;

  /// Color of the banner
  final Color color;

  /// Style for the text displayed
  final TextStyle textStyle;

  /// Action to perform on tap
  final VoidCallback tapAction;

  /// Callback to remove from parent render tree
  final _IntCallback onCompletion;

  _BannerInstanceObject(this.id, this.duration, this.text, this.color,
      this.textStyle, this.tapAction, this.onCompletion);

  @override
  createState() => _BannerInstanceObjectState();
}

class _BannerInstanceObjectState extends State<_BannerInstanceObject> {
  /// Whether the banner is being presented or removed
  bool isActive = true;
  Timer timer;
  double bannerHeight;

  @override
  void initState() {
    super.initState();

    timer = Timer(
      widget.duration,
      () {
        if (isActive) dismissAndDispose();
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((duration) {
      final deviceHeight = context.size.height;

      print(deviceHeight);
      setState(() => this.bannerHeight = deviceHeight);
    });
  }

  void dismissAndDispose([_]) {
    print('retiring ${widget.id}');
    // Cancel delayed timer
    timer.cancel();

    setState(() => isActive = false);

    if (widget.tapAction != null) widget.tapAction();

    // Remove as soon as animation is done
    Timer(
      Duration(milliseconds: 200),
      () => widget.onCompletion(widget.id),
    );
  }

  @override
  build(BuildContext context) {
    final top = bannerHeight == null ? -120.0 : (isActive ? 0.0 : -bannerHeight);

    return AnimatedPositioned(
      key: widget.key,
      left: 0,
      right: 0,
      top: top,
      duration: Duration(milliseconds: 180),
      child: GestureDetector(
        onTapUp: dismissAndDispose,
        child: Material(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: widget.color, boxShadow: [
              BoxShadow(
                color: Color(0x1F000000),
                offset: Offset(0, 1.75),
                blurRadius: 3.5,
              )
            ]),
            alignment: Alignment.center,
            child: SafeArea(
              bottom: false,
              child: Text(
                widget.text,
                style: TextStyle(
                        color: Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.normal,
                        inherit: true)
                    .merge(widget.textStyle),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
