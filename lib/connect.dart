import 'dart:async';
import 'package:csv/csv.dart';
import 'dart:io';
import 'dart:convert' show utf8;
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class ConnectPage extends StatefulWidget {
  final DiscoveredDevice device;

  ConnectPage({required this.device});

  @override
  _ConnectPageState createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  bool isDeviceConnected = false;
  bool isRecordStarted = false;
  bool stopTimer = false;
  final _ble = FlutterReactiveBle();
  bool isHeadingAdded = false; // Flag to track if headings are added
  String selectedEnvironment = 'None';
  String selectedActivity = 'None';

  Future<void> connectToDevice(DiscoveredDevice device) async {
    try {
      final deviceConnection = _ble.connectToDevice(
        id: device.id,
        connectionTimeout: const Duration(seconds: 10),
      );
      await deviceConnection;
      print('Connected to ${device.name}');

      // Set the isDeviceConnected state to true after successful connection
      Timer(Duration(seconds: 1), () {
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text('Connected Successfully'),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      isDeviceConnected = true;
                    });
                    Navigator.pop(context); // Close the dialog
                  },
                  child: Text('OK'),
                ),
              ],
            );
          },
        );
      });
    }catch (error) {
      print('Error connecting or reading characteristic: $error');
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Connection Failed'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close the dialog
                  setState(() {
                    isDeviceConnected = false;
                  });
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  void checkRecording() {
    if (selectedEnvironment == 'None' || selectedActivity == 'None') {
      // Show an alert dialog indicating invalid entry
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Invalid Entry'),
            content: Text('Please select valid attributes from the dropdown lists.'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close the dialog
                },
                child: Text('OK'),
              ),
            ],
          );
        },
      );
    } else {
      setState(() {
        isRecordStarted = true;
      });
      // Create the File Name with current date and time, selectedEnvironment, and selectedActivity
      String fileName = '${DateFormat('yyyy-MM-dd_HH:mm:ss').format(DateTime.now())}_$selectedEnvironment\_$selectedActivity';
      print('CSV FILE NAME: $fileName');
      startRecording(widget.device, fileName);
    }
  }

  Future<void> startRecording(DiscoveredDevice device, String fileName) async {

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
            while (!stopTimer) {
              final response = await _ble.readCharacteristic(
                  qualifiedCharacteristic);
              if (response.isNotEmpty) {
                final value = response[0];
                print('Characteristic Value: ${value}');
                // Write value to CSV file
                await writeToCSV(value,fileName);
                sleep(const Duration(seconds: 4)); // Notify
                //await readCSVData();
              } else {
                print('Error reading characteristic value');
              }
            }
            await readCSVData(fileName);
          } //
        }
      }
    }
  }


  Future<void> writeToCSV(int value, String fileName) async {

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
    final String path = '$dir/$fileName.csv';

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

  Future<void> readCSVData(String fileName) async {
    try {
      final String dir = (await getExternalStorageDirectory())!.path;
      final String path = "$dir/$fileName.csv";
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Data Collection'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context); // Go back to the previous page
            },
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isDeviceConnected
                            ? null
                            : () {
                          connectToDevice(widget.device);
                        },
                        child: Text('Connect to BLE Device'),
                      ),
                    ),
                    IconButton(
                      onPressed: stopTimer ?
                          () {
                        print('Reset Everything');
                        setState(() {
                          isRecordStarted = false;
                          stopTimer = false;
                        });
                        } : null,
                      icon: Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  DropdownButton<String>(
                    value: selectedEnvironment,
                    onChanged: isDeviceConnected && !isRecordStarted
                        ? (String? newValue) {
                      setState(() {
                        selectedEnvironment = newValue ?? 'None';
                      });
                    } : null,
                    items: <String>['None', 'Indoor', 'Outdoor']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                  SizedBox(width: 20),
                  DropdownButton<String>(
                    value: selectedActivity,
                    onChanged: isDeviceConnected && !isRecordStarted
                        ? (String? newValue) {
                      setState(() {
                        selectedActivity = newValue ?? 'None';
                      });
                    } : null,
                    items: <String>['None', 'Running', 'Walking', 'Sitting']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ],
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: isDeviceConnected && !isRecordStarted
                    ? () {
                  checkRecording();
                } : null,
                child: Text('Start Recording'),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: isRecordStarted && !stopTimer
                    ? () {
                  print('Stop Recording function');
                  setState(() {
                    stopTimer = true;
                  });
                } : null,
                child: Text('Stop Recording'),
              ),
            ],
          ),
        ),
    );
  }
}