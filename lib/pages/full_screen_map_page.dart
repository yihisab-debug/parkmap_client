import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/parking_spot.dart';
import '../services/firestore_service.dart';
import '../services/geocoding_service.dart';
import 'parking_details_page.dart';

class FullScreenMapPage extends StatefulWidget {
  const FullScreenMapPage({super.key});

  @override
  State<FullScreenMapPage> createState() => _FullScreenMapPageState();
}

class _FullScreenMapPageState extends State<FullScreenMapPage> {
  final _firestoreService = FirestoreService();
  final _geocodingService = GeocodingService();
  final _mapController = MapController();
  final _searchController = TextEditingController();

  LatLng? _searchTarget;
  String? _searchLabel;
  bool _isSearching = false;
  String? _searchError;
  bool _didInitialFit = false;

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    final result = await _geocodingService.forward(query);
    if (!mounted) return;
    setState(() => _isSearching = false);

    if (result == null) {
      setState(() => _searchError = 'Адрес не найден');
      return;
    }

    _mapController.move(result.point, 16);
    setState(() {
      _searchTarget = result.point;
      _searchLabel = result.label;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Карта парковок')),
      body: Stack(
        children: [
          StreamBuilder<List<ParkingLot>>(
            stream: _firestoreService.watchParkingLots(),
            builder: (context, snapshot) {
              final lots = snapshot.data ?? [];

              if (!_didInitialFit && lots.isNotEmpty) {
                _didInitialFit = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (lots.length == 1) {
                    _mapController.move(
                      LatLng(lots.first.latitude, lots.first.longitude),
                      14,
                    );
                  } else {
                    final bounds = LatLngBounds.fromPoints(
                      lots.map((l) => LatLng(l.latitude, l.longitude)).toList(),
                    );
                    _mapController.fitCamera(
                      CameraFit.bounds(
                        bounds: bounds,
                        padding: const EdgeInsets.all(60),
                      ),
                    );
                  }
                });
              }

              return FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: LatLng(43.2389, 76.8897),
                  initialZoom: 12,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.parkmap_client',
                  ),
                  MarkerLayer(
                    markers: [
                      ...lots.map((lot) => Marker(
                            point: LatLng(lot.latitude, lot.longitude),
                            width: 42,
                            height: 42,
                            child: GestureDetector(
                              onTap: () => showModalBottomSheet(
                                context: context,
                                builder: (_) => _LotPreviewSheet(lot: lot),
                              ),
                              child: const Icon(Icons.location_on,
                                  color: Colors.red, size: 38),
                            ),
                          )),
                      if (_searchTarget != null)
                        Marker(
                          point: _searchTarget!,
                          width: 46,
                          height: 46,
                          child: GestureDetector(
                            onTap: _searchLabel == null
                                ? null
                                : () => ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(_searchLabel!)),
                                    ),
                            child: const Icon(Icons.place,
                                color: Colors.purple, size: 42),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Найти адрес на карте...',
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                    _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: _search,
                          ),
                  ],
                ),
              ),
            ),
          ),
          if (_searchError != null)
            Positioned(
              top: 68,
              left: 12,
              right: 12,
              child: Card(
                color: Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_searchError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LotPreviewSheet extends StatelessWidget {
  final ParkingLot lot;
  const _LotPreviewSheet({required this.lot});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lot.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(lot.address, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 10),
          Text('${lot.pricePerHour} ₸ / час'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ParkingDetailsPage(lot: lot)));
              },
              child: const Text('Подробнее'),
            ),
          ),
        ],
      ),
    );
  }
}
