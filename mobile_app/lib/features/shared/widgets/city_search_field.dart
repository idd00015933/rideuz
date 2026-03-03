import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// A text field with live city-name autocomplete powered by Nominatim (OSM).
///
/// Suggestions appear inline below the text field (no Overlay positioning bugs).
/// Calls [onSelected] with the display name and [LatLng] when user picks a result.
class CitySearchField extends StatefulWidget {
  const CitySearchField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.prefixIcon,
    this.onSelected,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final Widget? prefixIcon;

  /// Called when the user taps a suggestion.
  final void Function(String city, LatLng coords)? onSelected;
  final String? Function(String?)? validator;

  @override
  State<CitySearchField> createState() => _CitySearchFieldState();
}

class _CitySearchFieldState extends State<CitySearchField> {
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<_Place> _suggestions = [];
  bool _searching = false;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      // Small delay so tap on suggestion registers before dismissing
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) setState(() => _showSuggestions = false);
      });
    }
  }

  void _onTextChanged() {
    _debounce?.cancel();
    final q = widget.controller.text.trim();
    if (q.length < 2) {
      if (mounted) setState(() => _showSuggestions = false);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (mounted) setState(() => _searching = true);
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(q)}'
        '&format=json&limit=5&addressdetails=1',
      );
      final res = await http.get(uri, headers: {
        'Accept': 'application/json',
        'User-Agent': 'RideUzApp/1.0',
      }).timeout(const Duration(seconds: 8));

      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _suggestions = data
              .map((p) => _Place(
                    display: p['display_name'] as String,
                    short: _shortName(p),
                    lat: double.parse(p['lat'] as String),
                    lon: double.parse(p['lon'] as String),
                  ))
              .toList();
          _showSuggestions = _suggestions.isNotEmpty;
        });
      }
    } catch (_) {
      // Silently swallow network errors
    }
    if (mounted) setState(() => _searching = false);
  }

  String _shortName(dynamic p) {
    final addr = p['address'] as Map<String, dynamic>? ?? {};
    return (addr['city'] ??
            addr['town'] ??
            addr['village'] ??
            addr['county'] ??
            p['display_name'])
        .toString();
  }

  void _selectSuggestion(_Place p) {
    widget.controller.text = p.short;
    widget.onSelected?.call(p.short, LatLng(p.lat, p.lon));
    setState(() {
      _showSuggestions = false;
      _suggestions = [];
    });
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Text field ───────────────────────────────────────────────────
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon: widget.prefixIcon,
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (_showSuggestions
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          widget.controller.clear();
                          setState(() {
                            _showSuggestions = false;
                            _suggestions = [];
                          });
                        },
                      )
                    : null),
          ),
          validator: widget.validator,
        ),

        // ── Inline suggestion list ───────────────────────────────────────
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E0FF)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _suggestions.asMap().entries.map((entry) {
                  final i = entry.key;
                  final p = entry.value;
                  return Column(
                    children: [
                      InkWell(
                        onTap: () => _selectSuggestion(p),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on_rounded,
                                  size: 18, color: Color(0xFF3D7EFF)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.short,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF1A1A2E),
                                      ),
                                    ),
                                    Text(
                                      p.display,
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: Colors.grey[500],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (i < _suggestions.length - 1)
                        const Divider(height: 1, indent: 42),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }
}

class _Place {
  const _Place({
    required this.display,
    required this.short,
    required this.lat,
    required this.lon,
  });
  final String display;
  final String short;
  final double lat;
  final double lon;
}
