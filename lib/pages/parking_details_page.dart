import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/parking_spot.dart';
import '../services/firestore_service.dart';
import 'booking_page.dart';

class ParkingDetailsPage extends StatelessWidget {
  final ParkingLot lot;
  const ParkingDetailsPage({super.key, required this.lot});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    return Scaffold(
      appBar: AppBar(title: Text(lot.name)),
      body: FutureBuilder<int>(
        future: firestoreService.getCurrentFreeSpots(lot),
        builder: (context, snapshot) {
          final free = snapshot.data;
          final hasError = snapshot.connectionState == ConnectionState.done &&
              snapshot.hasError;
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 200,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(lot.latitude, lot.longitude),
                      initialZoom: 15,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.parkmap_client',
                      ),
                      MarkerLayer(markers: [
                        Marker(
                          point: LatLng(lot.latitude, lot.longitude),
                          child: const Icon(Icons.location_on,
                              color: Colors.red, size: 36),
                        ),
                      ]),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.grey, size: 18),
                          const SizedBox(width: 4),
                          Expanded(child: Text(lot.address)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('Парковочных мест: ${lot.totalSpots}'),
                      const SizedBox(height: 4),
                      Text(
                        hasError
                            ? 'Не удалось проверить свободные места'
                            : (free == null
                                ? 'Свободных мест: загрузка...'
                                : 'Свободных мест: $free'),
                        style: TextStyle(
                          color: hasError
                              ? Colors.red
                              : ((free ?? 1) > 0 ? Colors.green[700] : Colors.red),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Стоимость:', style: TextStyle(color: Colors.grey)),
                      Text('${lot.pricePerHour} ₸ / час',
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (free ?? 1) > 0
                              ? () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => BookingPage(lot: lot)),
                                  )
                              : null,
                          style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50)),
                          child: const Text('Забронировать'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
