import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:bluetooth_enable_fork/bluetooth_enable_fork.dart';
import 'connect.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter React Bluetooth'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _ble = FlutterReactiveBle();
  List<DiscoveredDevice> scanResults = [];
  StreamSubscription? _scanSubscription;

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  Future<void> scanDevices() async{
    // Request to turn on Bluetooth within an app
    BluetoothEnable.enableBluetooth.then((result) {
      if (result == "true") {
        // Bluetooth has been enabled
      }
      else if (result == "false") {
        // Bluetooth has not been enabled
      }
    });
    // Request Bluetooth permissions
    var bluetoothScanPermission = await Permission.bluetoothScan.request();
    var locationPermission = await Permission.location.request();
    var bluetoothConnectPermission = await Permission.bluetoothConnect.request();

    if (bluetoothScanPermission.isGranted && locationPermission.isGranted && bluetoothConnectPermission.isGranted) {
      // Permission granted, start scanning for devices
      _scanSubscription?.cancel();
      _scanSubscription = _ble.scanForDevices(
        withServices: [],
      ).listen((device) {
        setState(() {
          if (scanResults.every((element) => element.id != device.id)) {
            scanResults.add(device);
          }
          //scanResults.add(device);
        });
      });

      // Stop scanning after 4 seconds
      await Future.delayed(Duration(seconds: 4));
      _scanSubscription?.cancel();
    }
    else{
      // Permission denied, handle accordingly
      print('Bluetooth permission denied');
    }
  }

  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: Text('BLE Scanner'),
        ),
        body: Column(
          children: <Widget>[
            ElevatedButton(
              onPressed: scanDevices,
              child: Text('Scan for Devices'),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: scanResults.length,
                itemBuilder: (context, index) {
                  DiscoveredDevice device = scanResults[index];
                  return ListTile(
                    title: Text(device.name ?? 'Unknown'),
                    subtitle: Text(device.id.toString()),
                    onTap: (){
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ConnectPage(device: device), // Pass the device as an argument
                        ),
                      ); // Navigator
                      // print('Number : $uniqueFileNumber');
                      // connectToDevice(device,uniqueFileNumber);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

}
