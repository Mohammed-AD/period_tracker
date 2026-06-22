import 'package:flutter/material.dart';
import '../calendar/calendar_screen.dart';
import '../insights/insights_screen.dart';
import '../yearly_pattern/yearly_pattern_screen.dart';
import '../chatbot/chatbot_screen.dart';
import '../home/profile_screen.dart';
import '../../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // Needed so switching to the Insights tab can force it to reload data —
  // it lives inside an IndexedStack below, which keeps tabs alive instead
  // of recreating them, so its own initState() only runs once per app
  // session and won't see entries logged afterwards on the Calendar tab.
  final GlobalKey<InsightsScreenState> _insightsKey = GlobalKey<InsightsScreenState>();
  final GlobalKey<YearlyPatternScreenState> _yearlyKey = GlobalKey<YearlyPatternScreenState>();

  late final List<Widget> _screens = [
    const CalendarScreen(),
    InsightsScreen(key: _insightsKey),
    YearlyPatternScreen(key: _yearlyKey),
    const ChatbotScreen(),
    const ProfileScreen(),
  ];

  void _selectTab(int index) {
    setState(() => _currentIndex = index);
    if (index == 1) {
      // Refresh insights every time the tab is opened, so newly logged
      // entries (added while on another tab) are reflected immediately.
      _insightsKey.currentState?.reload();
    } else if (index == 2) {
      _yearlyKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    // HomeScreen (and the tabs inside it) stay mounted for the whole
    // session via IndexedStack, so without this they wouldn't repaint
    // when the user picks a new theme from the Profile tab — AppColors
    // would have new values, but nothing would trigger a rebuild to read
    // them. ThemeController.select() calls notifyListeners(), which this
    // catches.
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(color: AppColors.shadow, blurRadius: 16, offset: const Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.calendar_month_rounded,
                  label: 'Calendar',
                  selected: _currentIndex == 0,
                  onTap: () => _selectTab(0),
                ),
                _NavItem(
                  icon: Icons.insights_rounded,
                  label: 'Insights',
                  selected: _currentIndex == 1,
                  onTap: () => _selectTab(1),
                ),
                _NavItem(
                  icon: Icons.bar_chart_rounded,
                  label: 'Yearly',
                  selected: _currentIndex == 2,
                  onTap: () => _selectTab(2),
                ),
                _NavItem(
                  icon: Icons.chat_bubble_rounded,
                  label: 'Chat',
                  selected: _currentIndex == 3,
                  onTap: () => _selectTab(3),
                ),
                _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  selected: _currentIndex == 4,
                  onTap: () => _selectTab(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}
