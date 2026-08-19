import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/app_user.dart';
import '../models/parking_spot.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/parking_lot_card.dart';
import 'parking_details_page.dart';
import 'my_bookings_page.dart';
import 'my_reviews_page.dart';
import 'full_screen_map_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _searchController = TextEditingController();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _authService.watchCurrentAppUser(),
      builder: (context, userSnap) {
        final appUser = userSnap.data;
        return Scaffold(
          appBar: AppBar(
            title: const Text('ParkMap'),
            actions: [
              IconButton(
                icon: const Icon(Icons.map_outlined),
                tooltip: 'Открыть карту на весь экран',
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const FullScreenMapPage())),
              ),
              IconButton(
                icon: const Icon(Icons.receipt_long),
                tooltip: 'Мои бронирования',
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MyBookingsPage())),
              ),
              IconButton(
                icon: const Icon(Icons.reviews_outlined),
                tooltip: 'Отзывы и жалобы',
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MyReviewsPage())),
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Выйти',
                onPressed: () => _authService.signOut(),
              ),
            ],
          ),
          body: Column(
            children: [
              _WalletBar(appUser: appUser, firestoreService: _firestoreService),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '🔍 Найти парковку по названию или адресу...',
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<ParkingLot>>(
                  stream: _firestoreService.watchParkingLots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return _ErrorState(onRetry: () => setState(() {}));
                    }
                    final lots = snapshot.data ?? [];
                    final filtered = _query.isEmpty
                        ? lots
                        : lots
                            .where((l) =>
                                l.name.toLowerCase().contains(_query) ||
                                l.address.toLowerCase().contains(_query))
                            .toList();
                    if (filtered.isEmpty) {
                      return const Center(child: Text('Парковки не найдены'));
                    }
                    return Column(
                      children: [
                        SizedBox(
                          height: 220,
                          child: _ParkingMap(
                            lots: filtered,
                            focusedLot: _query.isNotEmpty && filtered.isNotEmpty
                                ? filtered.first
                                : null,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Парковки рядом',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final lot = filtered[index];
                              return FutureBuilder<int>(
                                future: _firestoreService.getCurrentFreeSpots(lot),
                                builder: (context, freeSnap) {
                                  final free = freeSnap.data ?? lot.totalSpots;
                                  return ParkingLotCard(
                                    lot: lot,
                                    freeSpots: free,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ParkingDetailsPage(lot: lot),
                                      ),
                                    ),
                                    onBookPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ParkingDetailsPage(lot: lot),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WalletBar extends StatelessWidget {
  final AppUser? appUser;
  final FirestoreService firestoreService;

  const _WalletBar({required this.appUser, required this.firestoreService});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet, color: Colors.green),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              appUser == null
                  ? 'Баланс: —'
                  : 'Баланс: ${appUser!.balance} ₸',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          ElevatedButton.icon(
            onPressed: appUser == null
                ? null
                : () async {
                    await firestoreService.topUpBalance(appUser!.uid, 10000);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Баланс пополнен на 10 000 ₸')),
                      );
                    }
                  },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('10 000 ₸'),
          ),
        ],
      ),
    );
  }
}

class _ParkingMap extends StatefulWidget {
  final List<ParkingLot> lots;
  final ParkingLot? focusedLot;
  final LatLng? externalTarget;
  final String? externalLabel;
  const _ParkingMap({
    required this.lots,
    this.focusedLot,
    this.externalTarget,
    this.externalLabel,
  });

  @override
  State<_ParkingMap> createState() => _ParkingMapState();
}

class _ParkingMapState extends State<_ParkingMap> {
  final MapController _mapController = MapController();

  void _focusOnStart() {
    final center = widget.lots.isNotEmpty
        ? LatLng(widget.lots.first.latitude, widget.lots.first.longitude)
        : const LatLng(43.2389, 76.8897);
    _mapController.move(center, 14);
  }

  @override
  void didUpdateWidget(covariant _ParkingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final focused = widget.focusedLot;
    if (focused != null && focused.id != oldWidget.focusedLot?.id) {
      _mapController.move(LatLng(focused.latitude, focused.longitude), 15);
      return;
    }
    final target = widget.externalTarget;
    if (target != null && target != oldWidget.externalTarget) {
      _mapController.move(target, 16);
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.lots.isNotEmpty
        ? LatLng(widget.lots.first.latitude, widget.lots.first.longitude)
        : const LatLng(43.2389, 76.8897);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14,
              onMapReady: _focusOnStart,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.parkmap_client',
              ),
              MarkerLayer(
                markers: [
                  ...widget.lots.map((lot) {
                    final isFocused = widget.focusedLot?.id == lot.id;
                    return Marker(
                      point: LatLng(lot.latitude, lot.longitude),
                      width: isFocused ? 50 : 40,
                      height: isFocused ? 50 : 40,
                      child: GestureDetector(
                        onTap: () => showModalBottomSheet(
                          context: context,
                          builder: (_) => _LotPreviewSheet(lot: lot),
                        ),
                        child: Icon(
                          Icons.location_on,
                          color: isFocused ? Colors.blue : Colors.red,
                          size: isFocused ? 46 : 36,
                        ),
                      ),
                    );
                  }),
                  if (widget.externalTarget != null)
                    Marker(
                      point: widget.externalTarget!,
                      width: 46,
                      height: 46,
                      child: GestureDetector(
                        onTap: widget.externalLabel == null
                            ? null
                            : () => ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(widget.externalLabel!)),
                                ),
                        child: const Icon(Icons.place, color: Colors.purple, size: 42),
                      ),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 2,
              child: IconButton(
                icon: const Icon(Icons.fullscreen, color: Colors.black87),
                tooltip: 'Открыть карту на весь экран',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FullScreenMapPage()),
                ),
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

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Не удалось загрузить парковки'),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: onRetry, child: const Text('Повторить')),
        ],
      ),
    );
  }
}
