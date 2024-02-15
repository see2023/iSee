// 控制小车前进、后退、左转、右转、停止的摇杆UI类，接受手指的操作，通过回调函数将操作指令传递给小车

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:see_me_now/data/log.dart';
import 'package:see_me_now/tools/bluetooth_control.dart';

typedef JoystickDirectionCallback = Function(Offset);

class JoystickWidget extends StatefulWidget {
  final double size;

  const JoystickWidget({
    Key? key,
    required this.size,
  }) : super(key: key);

  @override
  _JoystickWidgetState createState() => _JoystickWidgetState();
}

class _JoystickWidgetState extends State<JoystickWidget> {
  Offset _thumbPosition = Offset.zero;
  Timer? _timer;
  final _bluetoothController = Get.find<BlueToothControl>();

  // A method used to calculate the distance to the center and keep the thumb within the area of the joystick
  Offset _calculatePosition(
      Offset localPosition, Offset center, double radius) {
    final Offset offsetFromCenter = localPosition - center;
    if (offsetFromCenter.distance <= radius) {
      return offsetFromCenter;
    } else {
      final double angle = atan2(offsetFromCenter.dy, offsetFromCenter.dx);
      return Offset(cos(angle) * radius, sin(angle) * radius);
    }
  }

  void onDirectionChanged(Offset offset, bool isReset) {
    _bluetoothController.onDirectionChanged(offset.dx, -offset.dy, isReset);
  }

  void _updatePosition(Offset localPosition) {
    // Subtract the top padding of the Container from the localPosition
    double topPadding =
        MediaQuery.of(context).padding.top; // or use a constant value
    topPadding += 130;
    final Offset adjustedPosition = localPosition - Offset(0, topPadding);
    final Offset center = Offset(widget.size / 2, widget.size / 2);
    final double radius = widget.size / 2 * 0;
    final Offset position =
        _calculatePosition(adjustedPosition, center, center.dx - radius);

    setState(() {
      _thumbPosition = position;
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      onDirectionChanged(_thumbPosition / widget.size * 2, false);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _thumbPosition = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double innerCircleSize = widget.size * 0.4;
    Log.log.finest('build JoystickWidget');
    return GestureDetector(
      onPanStart: (details) {
        _startTimer();
        _updatePosition(details.localPosition);
      },
      onPanUpdate: (details) {
        _updatePosition(details.localPosition);
      },
      onPanEnd: (details) {
        onDirectionChanged(Offset.zero, true);
        _stopTimer();
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[300],
        ),
        child: Center(
          child: Transform.translate(
            offset: _thumbPosition,
            child: Container(
              width: innerCircleSize,
              height: innerCircleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
