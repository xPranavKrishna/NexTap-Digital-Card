import 'package:flutter/material.dart';

/// Slide-to-confirm button. Drag the knob to the right to fire [onConfirm].
class SwipeToSend extends StatefulWidget {
  final String label;
  final String confirmedLabel;
  final Color color;
  final bool busy;
  final Future<void> Function() onConfirm;

  const SwipeToSend({
    super.key,
    required this.onConfirm,
    this.label = 'Swipe to send',
    this.confirmedLabel = 'Sending...',
    this.color = const Color(0xFF3B5BFE),
    this.busy = false,
  });

  @override
  State<SwipeToSend> createState() => _SwipeToSendState();
}

class _SwipeToSendState extends State<SwipeToSend> {
  double _dx = 0;
  bool _fired = false;

  static const _h = 62.0;
  static const _pad = 6.0;

  @override
  void didUpdateWidget(covariant SwipeToSend old) {
    super.didUpdateWidget(old);
    if (old.busy && !widget.busy) {
      setState(() {
        _dx = 0;
        _fired = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final maxDx = c.maxWidth - _h - _pad * 2;
      final progress = maxDx <= 0 ? 0.0 : (_dx / maxDx).clamp(0.0, 1.0);

      return Container(
        height: _h + _pad * 2,
        padding: const EdgeInsets.all(_pad),
        decoration: BoxDecoration(
          color: widget.color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: widget.color.withOpacity(0.25)),
        ),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Center(
              child: AnimatedOpacity(
                opacity: 1 - progress,
                duration: const Duration(milliseconds: 120),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.busy ? widget.confirmedLabel : widget.label,
                      style: TextStyle(
                        color: widget.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.keyboard_double_arrow_right_rounded,
                        color: widget.color.withOpacity(0.7), size: 20),
                  ],
                ),
              ),
            ),
            AnimatedPositioned(
              duration: Duration(milliseconds: _fired ? 0 : 150),
              curve: Curves.easeOut,
              left: _dx,
              child: GestureDetector(
                onHorizontalDragUpdate: widget.busy
                    ? null
                    : (d) => setState(
                        () => _dx = (_dx + d.delta.dx).clamp(0.0, maxDx)),
                onHorizontalDragEnd: widget.busy
                    ? null
                    : (_) async {
                        if (progress > 0.85) {
                          setState(() {
                            _dx = maxDx;
                            _fired = true;
                          });
                          await widget.onConfirm();
                          if (mounted && !widget.busy) {
                            setState(() {
                              _dx = 0;
                              _fired = false;
                            });
                          }
                        } else {
                          setState(() => _dx = 0);
                        }
                      },
                child: Container(
                  width: _h,
                  height: _h,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withOpacity(0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: widget.busy
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white),
                        )
                      : const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 26),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}
