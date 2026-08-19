import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../models/parking_spot.dart';
import '../services/firestore_service.dart';

class BookingPage extends StatefulWidget {
  final ParkingLot lot;
  const BookingPage({super.key, required this.lot});

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  final _firestoreService = FirestoreService();

  DateTime? _date;
  TimeOfDay? _startTime;
  int _durationHours = 1;
  int? _selectedSpot;
  Set<int> _occupiedSpots = {};
  bool _loadingSpots = false;
  bool _isSubmitting = false;
  String? _error;

  int get _totalPrice => _durationHours * widget.lot.pricePerHour;

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String get _endTimeString {
    if (_startTime == null) return '';
    final start = DateTime(2000, 1, 1, _startTime!.hour, _startTime!.minute);
    final end = start.add(Duration(hours: _durationHours));
    return '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _selectedSpot = null;
      });
      _reloadOccupiedSpots();
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        _selectedSpot = null;
      });
      _reloadOccupiedSpots();
    }
  }

  Future<void> _reloadOccupiedSpots() async {
    if (_date == null || _startTime == null) return;
    setState(() => _loadingSpots = true);
    try {
      final occupied = await _firestoreService.getOccupiedSpotNumbers(
        parkingId: widget.lot.id,
        date: _date!,
        startTime: _formatTime(_startTime!),
        endTime: _endTimeString,
      );
      setState(() => _occupiedSpots = occupied);
    } catch (_) {
      setState(() => _error = 'Не удалось проверить занятость мест');
    } finally {
      setState(() => _loadingSpots = false);
    }
  }

  Future<void> _confirmBooking() async {
    if (_date == null || _startTime == null || _selectedSpot == null) {
      setState(() => _error = 'Заполните дату, время и выберите место');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final occupied = await _firestoreService.getOccupiedSpotNumbers(
        parkingId: widget.lot.id,
        date: _date!,
        startTime: _formatTime(_startTime!),
        endTime: _endTimeString,
      );
      if (occupied.contains(_selectedSpot)) {
        setState(() {
          _error = 'Это место уже заняли, выберите другое';
          _occupiedSpots = occupied;
          _selectedSpot = null;
        });
        return;
      }

      await _firestoreService.createBookingAndCharge(
        userId: user.uid,
        userName: user.displayName ?? user.email ?? 'Клиент',
        parkingId: widget.lot.id,
        parkingName: widget.lot.name,
        date: _date!,
        startTime: _formatTime(_startTime!),
        endTime: _endTimeString,
        spotNumber: _selectedSpot!,
        totalPrice: _totalPrice,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Бронирование подтверждено и оплачено')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Бронирование — ${widget.lot.name}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Дата'),
              subtitle: Text(_date == null
                  ? 'Не выбрана'
                  : DateFormat('d MMMM yyyy', 'ru').format(_date!)),
              trailing: TextButton(onPressed: _pickDate, child: const Text('Выбрать')),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time),
              title: const Text('Начало'),
              subtitle: Text(_startTime == null
                  ? 'Не выбрано'
                  : _formatTime(_startTime!)),
              trailing:
                  TextButton(onPressed: _pickStartTime, child: const Text('Выбрать')),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.timelapse),
              title: const Text('Продолжительность'),
              subtitle: Text('$_durationHours ч'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _durationHours > 1
                        ? () {
                            setState(() {
                              _durationHours--;
                              _selectedSpot = null;
                            });
                            _reloadOccupiedSpots();
                          }
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _durationHours < 12
                        ? () {
                            setState(() {
                              _durationHours++;
                              _selectedSpot = null;
                            });
                            _reloadOccupiedSpots();
                          }
                        : null,
                  ),
                ],
              ),
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Итого:', style: TextStyle(fontSize: 16)),
                Text('$_totalPrice ₸',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Парковочные места',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_date == null || _startTime == null)
              const Text('Сначала выберите дату и время начала',
                  style: TextStyle(color: Colors.grey))
            else if (_loadingSpots)
              const Center(child: CircularProgressIndicator())
            else
              _SpotsGrid(
                totalSpots: widget.lot.totalSpots,
                occupied: _occupiedSpots,
                selected: _selectedSpot,
                onSelect: (n) => setState(() => _selectedSpot = n),
              ),
            const SizedBox(height: 12),
            if (_selectedSpot != null)
              Text('Выбрано место №$_selectedSpot',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _confirmBooking,
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 50)),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Подтвердить бронирование'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotsGrid extends StatelessWidget {
  final int totalSpots;
  final Set<int> occupied;
  final int? selected;
  final void Function(int) onSelect;

  const _SpotsGrid({
    required this.totalSpots,
    required this.occupied,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: totalSpots,
      itemBuilder: (context, index) {
        final number = index + 1;
        final isOccupied = occupied.contains(number);
        final isSelected = selected == number;
        return GestureDetector(
          onTap: isOccupied ? null : () => onSelect(number),
          child: Container(
            decoration: BoxDecoration(
              color: isOccupied
                  ? Colors.red[200]
                  : (isSelected ? Colors.green : Colors.green[100]),
              borderRadius: BorderRadius.circular(8),
              border: isSelected ? Border.all(color: Colors.green[900]!, width: 2) : null,
            ),
            alignment: Alignment.center,
            child: Text(
              number.toString().padLeft(2, '0'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isOccupied
                    ? Colors.red[900]
                    : (isSelected ? Colors.white : Colors.green[900]),
              ),
            ),
          ),
        );
      },
    );
  }
}
