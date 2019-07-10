library dropdown_banner;

import 'dart:collection';
import 'dart:async';
import 'package:dart_notification_center/dart_notification_center.dart';
import 'package:flutter/material.dart';

const String _BANNERCHANNEL = 'createDropdownBanner';

class _BannerInstanceObject {
  final Key key = UniqueKey();
  final int id;

  final Duration duration;
  final String text;
  final Color color;
  final TextStyle textStyle;

  double bannerTop;

  Timer timer;

  VoidCallback tapAction;

  _BannerInstanceObject(this.id, this.duration, this.text, this.color,
      this.textStyle, this.tapAction);
}

class DropdownBanner extends StatefulWidget {
  final WidgetBuilder builder;
  final navigatorKey = GlobalKey<NavigatorState>();

  DropdownBanner({@required this.builder}) {
    DartNotificationCenter.registerChannel(channel: _BANNERCHANNEL);
  }

  static int _idCounter = 0;

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
            key: widget.navigatorKey,
            onGenerateRoute: (settings) => MaterialPageRoute(
              settings: settings,
              builder: widget.builder,
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

          //If there is a tap action, perform it
          if (inst.tapAction != null) inst.tapAction();

          //Cancel delayed timer
          inst.timer?.cancel();
          inst.timer = null;

          //Remove as soon as animation is done
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
