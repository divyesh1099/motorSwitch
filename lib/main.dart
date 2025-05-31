import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const SwitchApp());
}

class SwitchApp extends StatelessWidget {
  const SwitchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Switch',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const SwitchHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SwitchHomePage extends StatefulWidget {
  const SwitchHomePage({super.key});

  @override
  State<SwitchHomePage> createState() => _SwitchHomePageState();
}

class _SwitchHomePageState extends State<SwitchHomePage> {
  bool isOn = false;
  bool loading = true;

  final String apiUrl = 'https://motorswitch.pythonanywhere.com/switch';


  @override
  void initState() {
    super.initState();
    fetchSwitchStatus();
  }

  Future<void> fetchSwitchStatus() async {
    setState(() => loading = true);
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          isOn = data['isOn'] ?? false;
        });
      }
    } catch (e) {
      // Handle error: show Snackbar or dialog if needed
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> toggleSwitch(bool value) async {
    setState(() => loading = true);
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'isOn': value}),
      );
      if (response.statusCode == 200) {
        setState(() {
          isOn = value;
        });
      } else {
        // Optionally handle API error
      }
    } catch (e) {
      // Optionally handle error
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Switch Controller',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        elevation: 0.5,
      ),
      body: Center(
        child: loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Switch(
                      key: ValueKey(isOn),
                      value: isOn,
                      activeColor: Colors.green,
                      inactiveThumbColor: Colors.red,
                      onChanged: (val) {
                        toggleSwitch(val);
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    isOn ? 'Switch is ON' : 'Switch is OFF',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: fetchSwitchStatus,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh Status'),
                    style: ElevatedButton.styleFrom(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
