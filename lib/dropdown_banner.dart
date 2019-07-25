library dropdown_banner;

import 'dart:collection';
import 'dart:async';
import 'package:dart_notification_center/dart_notification_center.dart';
import 'package:flutter/material.dart';

/// Channel name to communicate menu updates on
const String _BANNERCHANNEL = 'createDropdownBanner';

/// Container to track various aspects of the appearance and life of a dropdown banner object
class _BannerInstanceObject {
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

  /// Position of the banner in the UI
  double bannerTop;

  /// Timers associated with dismissing the banner
  Timer timer;

  /// Action to perform on tap
  VoidCallback tapAction;

  _BannerInstanceObject(this.id, this.duration, this.text, this.color,
      this.textStyle, this.tapAction);
}

/// DropdownBanner manages the creation and animation of banner elements
/// that are useful for displaying warnings and updates to users.
class DropdownBanner extends StatefulWidget {
  /// Builder in which to construct the app content that you are wrapping
  final Widget child;

  DropdownBanner({@required this.child}) {
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
      options: _BannerInstanceObject(
        _idCounter + 1,
        duration ?? Duration(seconds: 3),
        text,
        color,
        textStyle,
        tapCallback,
      ),
    );
    ++_idCounter;
  }

  @override
  State<StatefulWidget> createState() => _DropdownBannerState();
}

class _DropdownBannerState extends State<DropdownBanner> {
  double deviceWidth;
  double bannerHeight;
  double bannerTop;

  LinkedHashMap<int, _BannerInstanceObject> bannerHolder = LinkedHashMap();

  @override
  void initState() {
    DartNotificationCenter.subscribe(
      channel: _BANNERCHANNEL,
      observer: this,
      onNotification: createBanner,
    );

    super.initState();
  }

  @override
  void dispose() {
    DartNotificationCenter.unsubscribe(observer: this);

    bannerHolder.values.forEach((item) {
      item.timer?.cancel();
      item.timer = null;
    });

    super.dispose();
  }

  void createBanner(dynamic bannerInst) {
    checkDimsIfUnset();

    assert(
      bannerInst is _BannerInstanceObject,
      'Do not post to $_BANNERCHANNEL using DartNotificationCenter, as this is reserved for internal use for DropdownBanner to work properly',
    );

    final _BannerInstanceObject banner = bannerInst;
    banner.bannerTop = -bannerHeight;

    int id = banner.id;

    setState(() {
      bannerHolder[id] = banner;
    });

    Timer(
      Duration(milliseconds: 20),
      () => setState(() => banner.bannerTop = 0),
    );

    banner.timer = Timer(
      banner.duration,
      () => setState(() {
        banner.bannerTop = -bannerHeight;
        removeAfterAnimation(id);
        banner.timer = null;
      }),
    );
  }

  void removeAfterAnimation(int id) {
    Timer(
      Duration(milliseconds: 200),
      () => setState(() => bannerHolder.remove(id)),
    );
  }

  void checkDimsIfUnset() {
    if (deviceWidth == null) {
      deviceWidth = MediaQuery.of(context).size.width;
      bannerHeight = MediaQuery.of(context).padding.top + 56;
      bannerTop = -bannerHeight;
    }
  }

  @override
  Widget build(BuildContext context) {
    checkDimsIfUnset();

    List<Widget> banners = bannerHolder.values.map(createBannerWidget).toList();

    return Stack(
      children: <Widget>[
        Align(
          alignment: Alignment.center,
          child: Navigator(
            key: GlobalKey<NavigatorState>(),
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

  Widget createBannerWidget(_BannerInstanceObject inst) {
    return AnimatedPositioned(
      key: inst.key,
      width: deviceWidth,
      left: 0,
      top: inst.bannerTop,
      height: bannerHeight,
      duration: Duration(milliseconds: 180),
      child: GestureDetector(
        onTapUp: (details) => setState(() {
          inst.bannerTop = -bannerHeight;

          // If there is a tap action, perform it
          if (inst.tapAction != null) inst.tapAction();

          // Cancel delayed timer
          inst.timer?.cancel();
          inst.timer = null;

          // Remove as soon as animation is done
          removeAfterAnimation(inst.id);
        }),
        child: Material(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: inst.color, boxShadow: [
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
                inst.text,
                style: TextStyle(
                        color: Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.normal,
                        inherit: true)
                    .merge(inst.textStyle),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
