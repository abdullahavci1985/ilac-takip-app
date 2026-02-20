import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/home/home_screen.dart';
import 'features/medications/medications_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(useMaterial3: true);

    return MaterialApp(
      title: 'İlaç Takip',
      theme: base.copyWith(
        textTheme: base.textTheme.apply(fontSizeFactor: 1.25),
        visualDensity: VisualDensity.standard,
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(64),
            textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      home: const _SimpleShell(),
    );
  }
}

class _SimpleShell extends ConsumerStatefulWidget {
  const _SimpleShell();

  @override
  ConsumerState<_SimpleShell> createState() => _SimpleShellState();
}

class _SimpleShellState extends ConsumerState<_SimpleShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = const [
      HomeScreen(),
      MedicationsScreen(),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today), label: 'Bugün'),
          NavigationDestination(icon: Icon(Icons.medication_outlined), label: 'İlaçlar'),
        ],
      ),
    );
  }
}
