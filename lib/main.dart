import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() => runApp(const MotorSwitchApp());

class MotorSwitchApp extends StatelessWidget {
  const MotorSwitchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Motor Switch',
      themeMode: ThemeMode.system,
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final base = 'https://motorswitch.pythonanywhere.com';
  bool isOn = false, busy = true;
  List dbg = [], notif = [], runs = [];
  bool showDbg = false, nBusy = false, lBusy = false;

  // ── helpers ──
  void log(String m) => setState(() {
    dbg.insert(0, '${DateFormat.Hms().format(DateTime.now())}  $m');
    if (dbg.length > 300) dbg.removeLast();
  });
  String since(String iso) {
    final t = DateTime.parse(iso).toLocal();
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours   < 24) return '${d.inHours} h ${d.inMinutes%60} m ago';
    return DateFormat('MMM d, h:mm a').format(t);
  }
  String dur(int s) {
    final d = Duration(seconds: s);
    if (d.inHours > 0) return '${d.inHours} h ${(d.inMinutes%60)} m';
    if (d.inMinutes > 0) return '${d.inMinutes} min ${(d.inSeconds%60)} s';
    return '${d.inSeconds} s';
  }

  // ── REST ──
  Future<void> _getState() async {
    setState(() => busy = true);
    try {
      final r = await http.get(Uri.parse('$base/switch'));
      if (r.statusCode == 200) isOn = json.decode(r.body)['isOn'] ?? false;
      log('state → ${r.body}');
    } catch (e) { log('ERR $e'); }
    setState(() => busy = false);
  }
  Future<void> _setState(bool v) async {
    setState(() => busy = true);
    try {
      final r = await http.post(Uri.parse('$base/switch'),
        headers:{'Content-Type':'application/json'},
        body: json.encode({'isOn': v}));
      log('toggle → ${r.body}');
      if (r.statusCode == 200) isOn = v;
    } catch (e) { log('ERR $e'); }
    setState(() => busy = false);
    _getNotif(); _getRuns();
  }
  Future<void> _getNotif() async {
    setState(() => nBusy = true);
    try {
      final r = await http.get(Uri.parse('$base/notifications'));
      if (r.statusCode == 200) notif = json.decode(r.body);
    } catch (e) { log('ERR notif'); }
    setState(() => nBusy = false);
  }
  Future<void> _getRuns() async {
    setState(() => lBusy = true);
    try {
      final r = await http.get(Uri.parse('$base/logs'));
      if (r.statusCode == 200) runs = json.decode(r.body);
    } catch (e) { log('ERR runs'); }
    setState(() => lBusy = false);
  }

  // ── life-cycle ──
  @override void initState() {
    super.initState();
    _getState(); _getNotif(); _getRuns();
  }

  // ── permission shortcut ──
  void askNotif() {
    if (kIsWeb) {
      // You can implement web notification request here if needed.
      // No-op for now, or show a SnackBar saying "Not available on web".
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Web notification permission not implemented'))
      );
    } else {
      AppSettings.openAppSettings(type: AppSettingsType.notification);
    }
  }

  // ── UI ──
  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: AppBar(
      title: const Text('Motor Switch', style: TextStyle(fontWeight: FontWeight.w700)),
      actions: [
        PopupMenuButton(
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'console',
              child: Row(children: [
                Icon(showDbg?Icons.visibility_off:Icons.bug_report, size:18),
                const SizedBox(width:8),
                Text(showDbg?'Hide developer console':'Show developer console')
              ]),
            ),
          ],
          onSelected: (v) => setState(() => showDbg = !showDbg),
        )
      ],
    ),
    body: busy
      ? const Center(child: CircularProgressIndicator())
      : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal:12, vertical:8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

          // ── big power button ──
          Center(
            child: GestureDetector(
              onTap: ()=> _setState(!isOn),
              child: Container(
                width:120, height:120,
                decoration: BoxDecoration(
                  color: isOn? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                  boxShadow:[BoxShadow(color: Colors.black26, blurRadius:8)]
                ),
                child: Icon(
                  isOn? Icons.power_settings_new : Icons.power_off,
                  size: 64, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height:14),
          Center(
            child: Chip(
              backgroundColor: isOn? Colors.green.shade100 : Colors.red.shade100,
              label: Text(isOn? 'Motor is ON' : 'Motor is OFF',
                style: TextStyle(fontSize:16,
                  color: isOn? Colors.green.shade800 : Colors.red.shade800)),
            ),
          ),

          const SizedBox(height:20),
          ElevatedButton.icon(
            onPressed: ()=> {_getState(), _getNotif(), _getRuns()},
            icon: const Icon(Icons.refresh), label: const Text('Refresh Everything')),

          const SizedBox(height:12),
          TextButton.icon(
              onPressed: askNotif,
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Enable notifications on this device')),

          // ── Notifications ──
          sectionHeader('Notifications', Icons.notifications),
          nBusy ? const Center(child:CircularProgressIndicator())
                : notif.isEmpty
                  ? const Padding(padding: EdgeInsets.all(12), child: Text('No notifications yet'))
                  : ListView.separated(
                      shrinkWrap:true, physics: const NeverScrollableScrollPhysics(),
                      itemCount: notif.length,
                      separatorBuilder: (_,__)=>const Divider(height:1),
                      itemBuilder: (_, i) {
                        final n = notif[notif.length-1-i];
                        return ListTile(
                          leading: const Icon(Icons.notifications, color: Colors.blue),
                          title: Text(n['msg']??''),
                          subtitle: Text(since(n['time']??'')),
                        );
                      }),

          const SizedBox(height:8),
          // ── Past Runs ──
          sectionHeader('Past Runs', Icons.history),
          lBusy ? const Center(child:CircularProgressIndicator())
                : runs.isEmpty
                  ? const Padding(padding: EdgeInsets.all(12), child: Text('No runs logged yet'))
                  : ListView.separated(
                      shrinkWrap:true, physics: const NeverScrollableScrollPhysics(),
                      itemCount: runs.length,
                      separatorBuilder: (_,__)=>const Divider(height:1),
                      itemBuilder: (_, i) {
                        final r = runs[runs.length-1-i];
                        final on  = DateTime.parse(r['on_time']).toLocal();
                        final off = DateTime.parse(r['off_time']).toLocal();
                        return ListTile(
                          leading: const Icon(Icons.event, color: Colors.orange),
                          title: Text('Started: ${DateFormat('MMM d, h:mm a').format(on)}'),
                          subtitle: Text('Stopped: ${DateFormat('MMM d, h:mm a').format(off)}\n'
                                         'Duration: ${dur(r['duration_sec'])}'),
                          isThreeLine: true,
                        );
                      }),

          // ── Developer console ──
          if (showDbg) ...[
            const SizedBox(height:12),
            sectionHeader('Developer Console', Icons.terminal),
            Container(
              height: 200, padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black, borderRadius: BorderRadius.circular(6)),
              child: ListView(reverse:true, children: dbg
                .map((l)=>Text(l, style: const TextStyle(
                    fontFamily:'monospace', fontSize:11, color: Colors.greenAccent)))
                .toList()),
            ),
          ]
        ]),
      ),
  );

  // helper for section titles
  Widget sectionHeader(String txt, IconData ic) => Padding(
    padding: const EdgeInsets.only(top:18, bottom:6),
    child: Row(children:[
      Icon(ic, size:20),
      const SizedBox(width:6),
      Text(txt, style: const TextStyle(fontSize:16, fontWeight: FontWeight.w600))
    ]),
  );
}
