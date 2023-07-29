import 'dart:async';
import 'package:csv/csv.dart';
import 'dart:io';
import 'dart:convert' show utf8;
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:path_provider/path_provider.dart';

class ConnectPage extends StatefulWidget {
  final DiscoveredDevice device;

  ConnectPage({required this.device});

  @override
  _ConnectPageState createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  bool isDeviceConnected = false;
  final _ble = FlutterReactiveBle();
  bool isHeadingAdded = false; // Flag to track if headings are added

  Future<void> connectToDevice(DiscoveredDevice device, int fileNumber) async {
    try {
      final deviceConnection = _ble.connectToDevice(
        id: device.id,
        connectionTimeout: Duration(seconds: 10),
      );
      await deviceConnection;
      print('Connected to ${device.name}');

      // Set the isDeviceConnected state to true after successful connection
      setState(() {
        isDeviceConnected = true;
      });

      final services = await _ble.discoverServices(device.id);
      for (var service in services) {
        if (service.serviceId == Uuid.parse("0000181a-0000-1000-8000-00805f9b34fb")) {
          final characteristics = service.characteristics;

          for (var characteristic in characteristics) {
            //print('Characs are : $characteristic');

            if (characteristic.characteristicId == Uuid.parse("00002a6e-0000-1000-8000-00805f9b34fb")) {
              final qualifiedCharacteristic = QualifiedCharacteristic(
                deviceId: device.id,
                serviceId: service.serviceId,
                characteristicId: characteristic.characteristicId,
              );
              // Read from the characteristic
              for (var i = 0; i<3; i++) {

                final response = await _ble.readCharacteristic(
                    qualifiedCharacteristic);
                if (response.isNotEmpty) {
                  final value = response[0];
                  print('Characteristic Value: ${value}');
                  // Write value to CSV file
                  await writeToCSV(value,fileNumber);
                  sleep(const Duration(seconds: 4)); // Notify
                  //await readCSVData();
                } else {
                  print('Error reading characteristic value');
                }
              }
              await readCSVData(fileNumber);
            } //
          }
        }
      }
    }catch (error) {
      print('Error connecting or reading characteristic: $error');
    }
  }

  Future<void> writeToCSV(int value, int fileNumber) async {
    final List<List<dynamic>> rows = [];

    // Check if headings are already added
    if (!isHeadingAdded) {
      rows.add(['Timestamp', 'Temp Value']); // Adding the headings
      isHeadingAdded = true; // Set the flag to true
    }

    print('Adding temp');
    rows.add([10, value]); // Adding the characteristic value under the columns

    String csv = ListToCsvConverter().convert(rows);

    final String dir = (await getExternalStorageDirectory())!.path;
    final String path = '$dir/$fileNumber.csv';

    final File file = File(path);

    // Check if the file exists
    bool fileExists = await file.exists();

    // If the file doesn't exist, create it and write the headings
    if (!fileExists) {
      await file.writeAsString(csv);
      print('CSV file created: $path');
    } else {
      // Read the existing content of the file
      String existingContent = await file.readAsString();
      // Append the new content to the existing content
      String updatedContent = existingContent + '\n' + csv;
      // Write the updated content back to the file
      await file.writeAsString(updatedContent);
      print('CSV file updated: $path');
    }
  }

  Future<void> readCSVData(int fileNumber) async {
    try {
      final String dir = (await getExternalStorageDirectory())!.path;
      final String path = "$dir/$fileNumber.csv";
      final File file = File(path);

      if (await file.exists()) {
        List<List<dynamic>> csvData = await file
            .openRead()
            .transform(utf8.decoder)
            .transform(CsvToListConverter())
            .toList();

        // Process the CSV data as needed
        print('CSV File Data:');
        for (var row in csvData) {
          print(row.join(', '));
        }
      } else {
        print('CSV File does not exist.');
      }
    } catch (e) {
      print('Error reading CSV File: $e');
    }
  }

  int generateUniqueNumber() {
    // Get the current date and time
    DateTime now = DateTime.now();
    // Convert the current date and time to seconds since the epoch
    int secondsSinceEpoch = now.second;
    //Use the secondsSinceEpoch as a unique number
    return secondsSinceEpoch;
  }

  @override
  Widget build(BuildContext context) {
    int uniqueFileNumber = generateUniqueNumber();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: Text('Second Page'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context); // Go back to the previous page
            },
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: isDeviceConnected
                    ? null
                    : () {
                  connectToDevice(widget.device, uniqueFileNumber);
                },
                child: Text('Connect to BLE Device'),
              ),
              ElevatedButton(
                onPressed: (){
                  print('Start recording');
                },
                child: Text('Start recording'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}