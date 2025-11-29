import 'package:flutter/material.dart';

typedef SliderChangedCallback = void Function(double value);

/// A single, clean vertical slider widget.
/// Keeps a value between [min] and [max] and reports changes via [onChanged].
class VerticalMixerSlider extends StatefulWidget {
  final double initialValue;
  final double min;
  final double max;
  final SliderChangedCallback onChanged;
  final String label;

  const VerticalMixerSlider({
    Key? key,
    this.initialValue = 0,
    this.min = 0,
    this.max = 100,
    required this.onChanged,
    this.label = '',
  }) : super(key: key);

  @override
  State<VerticalMixerSlider> createState() => _VerticalMixerSliderState();
}

class _VerticalMixerSliderState extends State<VerticalMixerSlider> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue.clamp(widget.min, widget.max);
  }

  Color _activeColorForValue(double v) {
    final range = widget.max - widget.min;
    final percent = range <= 0 ? 0.0 : ((v - widget.min) / range) * 100.0;
    if (percent <= 40) return Colors.black.withOpacity(0.5);
    if (percent <= 60) return Colors.green.withOpacity(0.6);
    if (percent <= 80) return Colors.yellow.withOpacity(0.7);
    return Colors.red.withOpacity(0.8);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            if (widget.label.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(widget.label, style: Theme.of(context).textTheme.bodyMedium),
              ),
            // Expand the rotated slider to fill available height instead of
            // using a fixed internal size which caused RenderFlex overflow.
            Expanded(
              child: SizedBox(
                width: 56,
                child: RotatedBox(
                  quarterTurns: -1,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 8,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                      activeTrackColor: _activeColorForValue(_value),
                      inactiveTrackColor: Colors.black12,
                    ),
                    child: Slider(
                      value: _value.clamp(widget.min, widget.max),
                      min: widget.min,
                      max: widget.max,
                      divisions: (widget.max - widget.min).round() > 0 ? (widget.max - widget.min).round() : null,
                      onChanged: (v) {
                        setState(() => _value = v);
                        widget.onChanged(v);
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('${_value.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        );
      },
    );
}
  }
