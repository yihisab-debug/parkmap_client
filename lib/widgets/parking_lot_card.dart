import 'package:flutter/material.dart';
import '../models/parking_spot.dart';

class ParkingLotCard extends StatelessWidget {
  final ParkingLot lot;
  final int freeSpots;
  final VoidCallback onTap;
  final VoidCallback onBookPressed;

  const ParkingLotCard({
    super.key,
    required this.lot,
    required this.freeSpots,
    required this.onTap,
    required this.onBookPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.directions_car, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(lot.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                      child: Text(lot.address,
                          style: const TextStyle(color: Colors.grey))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Свободно: $freeSpots / ${lot.totalSpots}',
                      style: TextStyle(
                        color: freeSpots > 0 ? Colors.green[700] : Colors.red,
                        fontWeight: FontWeight.w600,
                      )),
                  Text('${lot.pricePerHour} ₸ / час',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: freeSpots > 0 ? onBookPressed : null,
                  child: Text(freeSpots > 0 ? 'Забронировать' : 'Нет мест'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
