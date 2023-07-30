import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:bluetooth_enable_fork/bluetooth_enable_fork.dart';
import 'connect.dart';
import 'package:location/location.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        scaffoldBackgroundColor: Color(0xFFEEE2D4),
        primarySwatch: Colors.blueGrey,
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
  // void initState() {
  //   super.initState();
  //   scanDevices();
  // }
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  Future<void> scanDevices() async{
    Location location = Location();
    // Request permissions
    var bluetoothScanPermission = await Permission.bluetoothScan.request();
    var locationPermission = await Permission.location.request();
    var bluetoothConnectPermission = await Permission.bluetoothConnect.request();

    if (bluetoothScanPermission.isGranted && locationPermission.isGranted && bluetoothConnectPermission.isGranted) {
      // Permission granted, start scanning for devices

      // Request to turn on Bluetooth within an app
      String bluetoothResult = await BluetoothEnable.enableBluetooth;
      if (bluetoothResult == "true") {
        // Bluetooth has been enabled
        print('Bluetooth has been enabled.');
      } else if (bluetoothResult == "false") {
        // Bluetooth has not been enabled
        print('Bluetooth has not been enabled.');
      }

      // Request to turn on Location within an app
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        // Request to enable location services
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          // Location services are still not enabled
          print('Location services are still not enabled.');
        }
      } else {
        // Location services are already enabled
        print('Location services are already enabled.');
      }

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
    return Scaffold(
        appBar: AppBar(
          title: Text('BLE Scanner'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: Align(
                alignment: Alignment.center,
                child: ElevatedButton(
                  onPressed: scanDevices,
                  style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFEACAA3), foregroundColor: Colors.black),
                  child: Text('Scan Devices'),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              child: ListView.builder(
                itemCount: scanResults.length,
                itemBuilder: (context, index) {
                  DiscoveredDevice device = scanResults[index];
                  //String deviceName = device.name ?? 'Unknown Device';
                  return Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color(0xFFEACAA3),
                        borderRadius: BorderRadius.circular(10.0), 
                      ),
                      child: ListTile(
                        title: Text(device.name ?? 'Unknown Device'),
                        subtitle: Text(device.id.toString()),
                        trailing: ElevatedButton(
                          onPressed: (){
                            print('Dummy Connect');
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFB47A36)),
                          child: Text('Connect'),
                        ),
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
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
    );
  }

}
