import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/daily_log.dart';
import '../models/food_entry.dart';
import '../providers/nutrition_provider.dart';

class MonthlyProgramScreen extends StatefulWidget {
  const MonthlyProgramScreen({super.key});

  @override
  State<MonthlyProgramScreen> createState() => _MonthlyProgramScreenState();
}

class _MonthlyProgramScreenState extends State<MonthlyProgramScreen> {
  late DateTime _currentMonth;

  static const _weekdays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  static const _monthNames = [
    '',
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
  }

  void _prevMonth() {
    setState(() {
      _currentMonth =
          DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth =
          DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  int get _daysInMonth =>
      DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;

  int get _firstDayOffset =>
      DateTime(_currentMonth.year, _currentMonth.month, 1).weekday - 1;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isToday(DateTime date) => _isSameDay(date, DateTime.now());

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NutritionProvider>();
    final datesWithData = provider.getDatesWithData();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aylık Program'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildMonthHeader(context),
          _buildWeekdayRow(context),
          Expanded(
            child: _buildCalendarGrid(context, datesWithData, provider),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _prevMonth,
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            '${_monthNames[_currentMonth.month]} ${_currentMonth.year}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          IconButton(
            onPressed: _nextMonth,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayRow(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: _weekdays
            .map(
              (day) => Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      day,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildCalendarGrid(
    BuildContext context,
    List<DateTime> datesWithData,
    NutritionProvider provider,
  ) {
    final totalCells = _firstDayOffset + _daysInMonth;
    final rows = (totalCells / 7).ceil();

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: rows * 7,
      itemBuilder: (context, index) {
        final dayNumber = index - _firstDayOffset + 1;
        if (dayNumber < 1 || dayNumber > _daysInMonth) {
          return const SizedBox.shrink();
        }

        final date = DateTime(
          _currentMonth.year,
          _currentMonth.month,
          dayNumber,
        );
        final hasData =
            datesWithData.any((d) => _isSameDay(d, date));
        final isToday = _isToday(date);

        return _buildDayCell(context, date, dayNumber, hasData, isToday, provider);
      },
    );
  }

  Widget _buildDayCell(
    BuildContext context,
    DateTime date,
    int dayNumber,
    bool hasData,
    bool isToday,
    NutritionProvider provider,
  ) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => _showDayDetail(context, date, provider),
      child: Container(
        decoration: BoxDecoration(
          color: isToday
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
          border: isToday
              ? Border.all(color: theme.colorScheme.primary, width: 1.5)
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              dayNumber.toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isToday
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurface,
              ),
            ),
            if (hasData)
              Positioned(
                bottom: 3,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDayDetail(
    BuildContext context,
    DateTime date,
    NutritionProvider provider,
  ) {
    final log = provider.getLogForDate(date);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => _DayDetailSheet(
          date: date,
          log: log,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

class _DayDetailSheet extends StatelessWidget {
  final DateTime date;
  final DailyLog? log;
  final ScrollController scrollController;

  const _DayDetailSheet({
    required this.date,
    required this.log,
    required this.scrollController,
  });

  static const _monthNames = [
    '',
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  static const _mealLabels = {
    'kahvaltı': 'Kahvaltı',
    'öğle': 'Öğle Yemeği',
    'akşam': 'Akşam Yemeği',
    'ara öğün': 'Ara Öğün',
  };

  Future<List<String>> _loadCompletedSuggestions() async {
    final prefs = await SharedPreferences.getInstance();
    final key = '${date.year}_${date.month}_${date.day}';
    return prefs.getStringList('completed_titles_$key') ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr =
        '${date.day} ${_monthNames[date.month]} ${date.year}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            dateStr,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: (log == null || log!.entries.isEmpty)
              ? Center(
                  child: Text(
                    'Bu gün için kayıtlı veri yok',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : _buildContent(context),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final mealGroups = log!.entriesByMeal;
    final total = log!.totalNutrition;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Card(
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Günlük Toplam',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${total.calories.toStringAsFixed(0)} kcal',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ..._mealLabels.entries.map((meal) {
          final entries = mealGroups[meal.key] ?? [];
          if (entries.isEmpty) return const SizedBox.shrink();
          return _buildMealSection(context, meal.value, entries);
        }),
        FutureBuilder<List<String>>(
          future: _loadCompletedSuggestions(),
          builder: (ctx, snapshot) {
            final suggestions = snapshot.data ?? [];
            if (suggestions.isEmpty) return const SizedBox.shrink();
            return _buildSuggestionsSection(context, suggestions);
          },
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildMealSection(
    BuildContext context,
    String label,
    List<FoodEntry> entries,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ...entries.map((entry) {
          final cal =
              entry.nutritionData.scaleBy(entry.portionSize / 100).calories;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(entry.name),
            subtitle: Text('${entry.portionSize.toStringAsFixed(0)}g'),
            trailing: Text(
              '${cal.toStringAsFixed(0)} kcal',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            dense: true,
          );
        }),
        const Divider(height: 16),
      ],
    );
  }

  Widget _buildSuggestionsSection(
    BuildContext context,
    List<String> suggestions,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Tamamlanan Öneriler',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ...suggestions.map(
          (s) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.check_circle, color: Colors.green, size: 20),
            title: Text(s),
            dense: true,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
