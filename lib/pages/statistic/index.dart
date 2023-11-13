import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sleep_tracker/components/charts/bar_chart.dart';
// import 'package:sleep_tracker/components/charts/line_chart.dart';
import 'package:sleep_tracker/components/period_pickers.dart';
import 'package:sleep_tracker/components/sleep_period_tab_bar.dart';
import 'package:sleep_tracker/models/sleep_record.dart';
import 'package:sleep_tracker/providers/sleep_records_provider.dart';
import 'package:sleep_tracker/routers/app_router.dart';
import 'package:sleep_tracker/utils/date_time.dart';
import 'package:sleep_tracker/utils/style.dart';

const double _tabRowHeight = 50.0;
const double _appBarHeight = _tabRowHeight + Style.spacingMd * 2;

@RoutePage()
class StatisticPage extends ConsumerStatefulWidget {
  const StatisticPage({super.key});

  @override
  ConsumerState<StatisticPage> createState() => _StatisticPageState();
}

class _StatisticPageState extends ConsumerState<StatisticPage> {
  late final ButtonStyle? _elevationButtonStyle = Theme.of(context).elevatedButtonTheme.style?.copyWith(
      backgroundColor: MaterialStateProperty.resolveWith<Color>(
        (states) {
          if (states.contains(MaterialState.selected)) {
            return Theme.of(context).colorScheme.background;
          }
          return Theme.of(context).colorScheme.tertiary;
        },
      ),
      foregroundColor: MaterialStatePropertyAll(Theme.of(context).primaryColor),
      side: MaterialStatePropertyAll(BorderSide(color: Theme.of(context).colorScheme.tertiary, width: 2)),
      padding:
          const MaterialStatePropertyAll(EdgeInsets.symmetric(vertical: Style.spacingXs, horizontal: Style.spacingSm)),
      minimumSize: const MaterialStatePropertyAll(Size(72.0, 32.0)));

  final List<String> _tabs = ['Days', 'Weeks', 'Months'];
  final List<PeriodPickerMode> _pickerModes = [PeriodPickerMode.weeks, PeriodPickerMode.weeks, PeriodPickerMode.months];
  final List<bool> _inRange = [false, true, true];

  int _tabIndex = 0;
  static const int _chartLength = 6;

  /// Initially, set Friday of this week as the last date.
  late final DateTime lastDate;
  late final DateTime firstDate;

  bool get _isDisplayingFirstDate => !selectedRange.start.isAfter(firstDate);
  bool get _isDisplayingLastDate => !selectedRange.end.isBefore(lastDate);

  late DateTimeRange selectedRange =
      DateTimeRange(start: DateTimeUtils.mostRecentWeekday(DateTime.now(), 0), end: lastDate);

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    firstDate = DateUtils.dateOnly(now.subtract(const Duration(days: 365)).copyWith(day: 1));
    lastDate = DateUtils.dateOnly(DateTimeUtils.mostNearestWeekday(now, 6));
  }

  void _handleTabChanged(int index) {
    final DateTime end = selectedRange.end;
    DateTime start;
    setState(() {
      _tabIndex = index;
      if (_tabIndex == 0) {
        start = DateUtils.addDaysToDate(end, -_chartLength);
      } else if (_tabIndex == 1) {
        start = DateUtils.addDaysToDate(end, -(DateTime.daysPerWeek * _chartLength) + 1);
      } else {
        start = DateUtils.addMonthsToMonthDate(end, -_chartLength);
      }
      selectedRange = DateTimeRange(start: start, end: end);
    });
  }

  /// Shift [selectedRange] to previous intervals based on [_tabIndex]
  void _handlePreviousPeriod() {
    DateTimeRange range;
    if (_tabIndex == 0) {
      // According to the PeriodPickerMode. 0 index refers to the "DAYS"
      // selection, which has constant 7-day per week as range.
      range = DateTimeUtils.shiftDaysToRange(selectedRange, -DateTime.daysPerWeek);
    } else if (_tabIndex == 1) {
      range = DateTimeUtils.shiftDaysToRange(selectedRange, -(_chartLength * DateTime.daysPerWeek));
    } else {
      range = DateTimeUtils.shiftMonthsToRange(selectedRange, -_chartLength);
    }

    if (range.start.isBefore(firstDate)) {
      return;
    }
    setState(() => selectedRange = range);
  }

  void _handleNextPeriod() {
    DateTimeRange range;
    if (_tabIndex == 0) {
      // According to the PeriodPickerMode. 0 index refers to the "DAYS"
      // selection, which has constant 7-day per week as range.
      range = DateTimeUtils.shiftDaysToRange(selectedRange, DateTime.daysPerWeek);
    } else if (_tabIndex == 1) {
      range = DateTimeUtils.shiftDaysToRange(selectedRange, (_chartLength * DateTime.daysPerWeek));
    } else {
      range = DateTimeUtils.shiftMonthsToRange(selectedRange, _chartLength);
    }

    if (range.end.isAfter(lastDate)) {
      return;
    }
    setState(() => selectedRange = range);
  }

  Widget _buildChart(
    BuildContext context, {
    required String title,
    bool hasMore = false,
    required Widget chart,
  }) {
    final moreButton = ElevatedButton(
        onPressed: () {
          // dev. Since there is only one more button among all statistic chart.
          // It is assumed the [onPressed] only handle the [SleepHealth] case.

          context.pushRoute(const SleepHealthRoute());
        },
        style: _elevationButtonStyle,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('More'),
            SvgPicture.asset('assets/icons/chevron-right.svg', color: Theme.of(context).primaryColor)
          ],
        ));

    final periodHeader = Row(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
          onTap: _handlePreviousPeriod,
          child: SvgPicture.asset('assets/icons/chevron-left.svg',
              color: _isDisplayingFirstDate ? Style.grey3 : Style.grey1)),
      PeriodPicker(
        maxWidth: 100,
        mode: _pickerModes[_tabIndex],
        selectedDate: selectedRange.start,
        selectedRange: selectedRange,
        lastDate: lastDate,
        firstDate: firstDate,
        rangeSelected: _inRange[_tabIndex],
        onDateChanged: (value) {
          if (value != null && value != selectedRange.start) {
            setState(() {
              selectedRange =
                  DateTimeRange(start: value, end: value.add(const Duration(days: DateTime.daysPerWeek - 1)));
            });
          }
        },
      ),
      GestureDetector(
          onTap: _handleNextPeriod,
          child: SvgPicture.asset('assets/icons/chevron-right.svg',
              color: _isDisplayingLastDate ? Style.grey3 : Style.grey1)),
    ]);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Style.spacingMd),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatisticHeader(title: title, topBarRightWidget: hasMore ? moreButton : periodHeader),
          const SizedBox(height: Style.spacingXl),
          chart,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<double> meanDurations = [];
    DateTime start = DateUtils.dateOnly(selectedRange.start);
    final DateTime end = DateUtils.dateOnly(selectedRange.end);
    int interval;
    if (_tabIndex == 0) {
      //  interval as single day
      interval = 1;
    } else if (_tabIndex == 1) {
      //  interval as single week
      interval = DateTime.daysPerWeek;
    } else {
      interval = DateUtils.getDaysInMonth(start.year, start.month);
    }
    while (!start.isAfter(end)) {
      // update interval if [_tabIndex] == 2
      if (_tabIndex == 2) interval = DateUtils.getDaysInMonth(start.year, start.month);
      final DateTime next = start.add(Duration(days: interval));
      final Iterable<SleepRecord> sleepRecords =
          ref.watch(rangeSleepRecordsProvider(DateTimeRange(start: start, end: next)));
      final double meanDuration = (sleepRecords.fold(0.0, (previousValue, record) {
            final wakeUpAt = record.wakeUpAt;
            return previousValue + (wakeUpAt == null ? 0 : wakeUpAt.difference(record.start).inMinutes);
          })) /
          interval;
      meanDurations.add(meanDuration);
      start = next;
    }

    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    List<Widget> charts = [
      // _buildChart(context, title: 'Sleep Health',hasMore: true, chart: LineChart(data: data),)
      _buildChart(context,
          title: 'Sleep Duration',
          chart: BarChart(
            data: meanDurations,
            gradientColors: [colorScheme.primary, colorScheme.tertiary],
            getYTitles: (value) {
              final double hour = value / 60;
              if (hour == hour.roundToDouble()) {
                return hour.toInt().toString();
              } else {
                return hour.toStringAsFixed(1);
              }
            },
            getXTitles: (value) {
              // if is integrate
              if (value == value.roundToDouble()) {
                final start = selectedRange.start;
                final int index = value.round();
                int interval;
                DateFormat format;
                if (_tabIndex == 0) {
                  interval = 1;
                  format = DateFormat.Md();
                } else if (_tabIndex == 1) {
                  interval = DateTime.daysPerWeek;
                  format = DateFormat.Md();
                } else {
                  interval = DateUtils.getDaysInMonth(start.year, start.month);
                  format = DateFormat.MMM();
                }
                final dayToAdd = index * interval;
                final date = DateUtils.addDaysToDate(start, dayToAdd);
                return format.format(date);
              }
              return "";
            },
          ))
    ];
    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(_appBarHeight),
          child: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Theme.of(context).colorScheme.background.withOpacity(0.75),
            elevation: 0,
            flexibleSpace: Padding(
                padding: const EdgeInsets.all(Style.spacingMd),
                child: SleepPeriodTabBar(
                  labels: _tabs,
                  initialIndex: _tabIndex,
                  onChanged: _handleTabChanged,
                )),
          ),
        ),
        body: ListView(
          physics: const BouncingScrollPhysics(),
          children: charts
              .mapIndexed((index, child) =>
                  <Widget>[child, if (index != charts.length - 1) const SizedBox(height: Style.spacingXxl)])
              .expand((child) => child)
              .toList(),
        ));
  }
}

class _StatisticHeader extends StatelessWidget {
  const _StatisticHeader({required this.title, this.topBarRightWidget});
  final String title;
  final Widget? topBarRightWidget;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        if (topBarRightWidget != null) topBarRightWidget!
      ],
    );
  }
}
