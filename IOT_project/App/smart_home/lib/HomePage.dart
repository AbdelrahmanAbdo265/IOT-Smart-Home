import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:io';
import 'login_screen.dart';


class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Actuators'),
      ),
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  _buildElevatedButton(context, 'Room', RoomPage()),
                  SizedBox(height: 20),
                  _buildElevatedButton(context, 'Hall', Room2Page()),
                  SizedBox(height: 20),
                  _buildElevatedButton(context, 'Garage', GaragePage()),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: FloatingActionButton(
                backgroundColor: Colors.red,
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()), // Replace with your home page widget
                  );
                },
                child: Icon(Icons.logout),
                tooltip: 'Logout',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElevatedButton(BuildContext context, String title, Widget page) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 16.0),
          textStyle: TextStyle(fontSize: 18),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => page,
            ),
          );
        },
        child: Text(title),
      ),
    );
  }
}


class RoomPage extends StatefulWidget {
  @override
  _RoomPageState createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  String broker = 'd422ba0605d740a194a4513751bc4030.s1.eu.hivemq.cloud';
  int port = 8883;
  String username = 'flutter';
  String password = 'Flutter1';
  String _selectedLEDMode = 'off';
  String _selectedServoMode = 'off';
  String _motorControlMode = 'manual'; // New variable to manage motor control mode
  double _motorSpeed = 0.0; // New variable to store motor speed
  late MqttServerClient _client;

  List<bool> _ledSelections = List.generate(3, (_) => false);
  List<bool> _servoSelections = List.generate(3, (_) => false);
  String _temperature = 'N/A';
  String _humidity = 'N/A';

  @override
  void initState() {
    super.initState();
    _connectMQTT();
    _updateLEDSelection();
    _updateServoSelection();
  }

  Future<void> _connectMQTT() async {
    _client = MqttServerClient(broker, '');
    _client.port = port;
    _client.secure = true;
    _client.logging(on: true);
    _client.onConnected = () {
      print('Connected');
      _client.subscribe('esp32/temp', MqttQos.atMostOnce);
    };
    _client.onSubscribed = (String topic) {
      print("Subscribed to $topic");
    };
    _client.onDisconnected = () => print('Disconnected');
    _client.securityContext = SecurityContext.defaultContext;
    _client.keepAlivePeriod = 20;
    _client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier('flutter_client')
        .authenticateAs(username, password)
        .withWillQos(MqttQos.atMostOnce)
        .startClean();

    try {
      await _client.connect();
    } catch (e) {
      print('Exception: $e');
      _client.disconnect();
    }
    _client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      final MqttPublishMessage recMessage = messages[0].payload as MqttPublishMessage;
      final String topic = messages[0].topic;
      final String message = MqttPublishPayload.bytesToStringAsString(recMessage.payload.message);

      if (topic == 'esp32/temp') {
        List<String> parts = message.split(' ');

        setState(() {
          _temperature = parts[0];
          _humidity = parts[1];
        });
      }
    });
  }

  void _sendMessage(String topic, String message) {
    final MqttClientPayloadBuilder builder = MqttClientPayloadBuilder();
    builder.addString(message);
    _client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
  }

  void _updateLEDSelection() {
    setState(() {
      switch (_selectedLEDMode) {
        case 'on':
          _ledSelections = [true, false, false];
          break;
        case 'off':
          _ledSelections = [false, true, false];
          break;
        case 'auto':
          _ledSelections = [false, false, true];
          break;
      }
    });
  }

  void _updateServoSelection() {
    setState(() {
      switch (_selectedServoMode) {
        case 'on':
          _servoSelections = [true, false, false];
          break;
        case 'off':
          _servoSelections = [false, true, false];
          break;
        case 'auto':
          _servoSelections = [false, false, true];
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Room 1'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _buildToggleSection('Lights', _ledSelections, (index) {
              setState(() {
                switch (index) {
                  case 0:
                    _selectedLEDMode = 'on';
                    _sendMessage('esp32/led', 'on');
                    break;
                  case 1:
                    _selectedLEDMode = 'off';
                    _sendMessage('esp32/led', 'off');
                    break;
                  case 2:
                    _selectedLEDMode = 'auto';
                    _sendMessage('esp32/led', 'auto');
                    break;
                }
                _updateLEDSelection();
              });
            }),
            SizedBox(height: 20),
            _buildToggleSection('Door', _servoSelections, (index) {
              setState(() {
                switch (index) {
                  case 0:
                    _selectedServoMode = 'on';
                    _sendMessage('esp32/servo', 'on');
                    break;
                  case 1:
                    _selectedServoMode = 'off';
                    _sendMessage('esp32/servo', 'off');
                    break;
                  case 2:
                    _selectedServoMode = 'auto';
                    _sendMessage('esp32/servo', 'auto');
                    break;
                }
                _updateServoSelection();
              });
            }),
            SizedBox(height: 20),
            _buildMotorControlSection(), // New section for motor control
            SizedBox(height: 20),
            _buildInfoCard('Temperature', '$_temperature °C'),
            _buildInfoCard('Humidity', '$_humidity %'),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleSection(String title, List<bool> selections, Function(int) onPressed) {
    return Column(
      children: <Widget>[
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        ToggleButtons(
          borderRadius: BorderRadius.circular(8),
          selectedColor: Colors.white,
          fillColor: Theme.of(context).primaryColor,
          borderColor: Theme.of(context).primaryColor,
          selectedBorderColor: Theme.of(context).primaryColor,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text('On'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text('Off'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text('Auto'),
            ),
          ],
          isSelected: selections,
          onPressed: onPressed,
        ),
      ],
    );
  }

  Widget _buildMotorControlSection() {
    return Column(
      children: <Widget>[
        Text('Fan Control', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        ToggleButtons(
          borderRadius: BorderRadius.circular(8),
          selectedColor: Colors.white,
          fillColor: Theme.of(context).primaryColor,
          borderColor: Theme.of(context).primaryColor,
          selectedBorderColor: Theme.of(context).primaryColor,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text('Manual'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text('Auto'),
            ),
          ],
          isSelected: [_motorControlMode == 'manual', _motorControlMode == 'auto'],
          onPressed: (index) {
            setState(() {
              if (index == 0) {
                _motorControlMode = 'manual';

              } else {
                _motorControlMode = 'auto';
                _sendMessage('esp32/motor', 'auto');
              }
            });
          },
        ),
        SizedBox(height: 20),
        Slider(
          value: _motorSpeed,
          min: 0,
          max: 255,
          divisions: 10,
          label: _motorSpeed.round().toString(),
          onChanged: _motorControlMode == 'manual'
              ? (value) {
            setState(() {
              _motorSpeed = value;
            });
          }
              : null,
          onChangeEnd: _motorControlMode == 'manual'
              ? (value) {
            _sendMessage('esp32/motor', value.toString());
          }
              : null,
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, String value) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(value, style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}



class Room2Page extends StatefulWidget {
  @override
  _Room2PageState createState() => _Room2PageState();
}

class _Room2PageState extends State<Room2Page> {
  // Existing Variables
  String broker = 'd422ba0605d740a194a4513751bc4030.s1.eu.hivemq.cloud';
  int port = 8883;
  String username = 'flutter';
  String password = 'Flutter1';
  String _selectedMode = 'off';
  String _motorMode = 'off';
  String gasStatus = 'NA';
  String flameStatus = 'NA';
  late MqttServerClient _client;

  List<bool> _selections = List.generate(2, (_) => false);
  List<bool> _motorSelections = List.generate(4, (_) => false);

  // New Variables for Servo Control
  String _servoMode = 'off';
  List<bool> _servoSelections = List.generate(3, (_) => false);

  @override
  void initState() {
    super.initState();
    _connectMQTT();
    _updateSelection();
    _updateMotorSelection();
    _updateServoSelection();  // Initialize servo selection
  }

  Future<void> _connectMQTT() async {
    _client = MqttServerClient(broker, '');
    _client.port = port;
    _client.secure = true;
    _client.logging(on: true);
    _client.onConnected = () => print('Connected');
    _client.onDisconnected = () => print('Disconnected');
    _client.securityContext = SecurityContext.defaultContext;
    _client.keepAlivePeriod = 20;
    _client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier('flutter_client')
        .authenticateAs(username, password)
        .withWillQos(MqttQos.atMostOnce)
        .startClean();

    try {
      await _client.connect();
      _subscribeToTopic('esp32/alarm');
    } catch (e) {
      print('Exception: $e');
      _client.disconnect();
    }
  }

  void _subscribeToTopic(String topic) {
    _client.subscribe(topic, MqttQos.atMostOnce);
    _client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage message = c[0].payload as MqttPublishMessage;
      final String payload =
      MqttPublishPayload.bytesToStringAsString(message.payload.message);

      setState(() {
        if (topic == 'esp32/alarm') {
          List<String> parts = payload.split(',');

          setState(() {
            flameStatus = parts[0];
            gasStatus = parts[1];
          });
        }
      });
    });
  }

  void _sendMessage(String topic, String message) {
    final MqttClientPayloadBuilder builder = MqttClientPayloadBuilder();
    builder.addString(message);
    _client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
  }

  void _updateSelection() {
    setState(() {
      switch (_selectedMode) {
        case 'on':
          _selections = [true, false];
          break;
        case 'off':
          _selections = [false, true];
          break;
      }
    });
  }

  void _updateMotorSelection() {
    setState(() {
      switch (_motorMode) {
        case 'off':
          _motorSelections = [true, false, false, false];
          break;
        case 'auto':
          _motorSelections = [false, true, false, false];
          break;
        case 'ventilation':
          _motorSelections = [false, false, true, false];
          break;
        case 'pump air':
          _motorSelections = [false, false, false, true];
          break;
      }
    });
  }
  void _updateServoSelection() {
    setState(() {
      switch (_servoMode) {
        case 'on':
          _servoSelections = [true, false, false];
          break;
        case 'off':
          _servoSelections = [false, true, false];
          break;
        case 'auto':
          _servoSelections = [false, false, true];
          break;
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Room 2'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _buildToggleSection('Lights', _selections, (index) {
                setState(() {
                  switch (index) {
                    case 0:
                      _selectedMode = 'on';
                      _sendMessage('esp32/led2', 'on');
                      break;
                    case 1:
                      _selectedMode = 'off';
                      _sendMessage('esp32/led2', 'off');
                      break;
                  }
                  _updateSelection();
                });
              }),
              SizedBox(height: 20),
              _buildServoControlSection(),  // Add Servo Control Section
              SizedBox(height: 20),
              _buildMotorControlSection(),
              SizedBox(height: 20),
              _buildGasStatusSection(),
              SizedBox(height: 20),
              _buildFlameStatusSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServoControlSection() {
    return Column(
      children: <Widget>[
        Text('Servo Control',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        ToggleButtons(
          borderRadius: BorderRadius.circular(8),
          selectedColor: Colors.white,
          fillColor: Theme.of(context).primaryColor,
          borderColor: Theme.of(context).primaryColor,
          selectedBorderColor: Theme.of(context).primaryColor,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text('On'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text('Off'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text('Auto'),
            ),
          ],
          isSelected: _servoSelections,
          onPressed: (index) {
            setState(() {
              switch (index) {
                case 0:
                  _servoMode = 'on';
                  _sendMessage('esp32/servo2', 'on');
                  break;
                case 1:
                  _servoMode = 'off';
                  _sendMessage('esp32/servo2', 'off');
                  break;
                case 2:
                  _servoMode = 'auto';
                  _sendMessage('esp32/servo2', 'auto');
                  break;
              }
              _updateServoSelection();
            });
          },
        ),
      ],
    );
  }
  Widget _buildToggleSection(
      String title, List<bool> selections, Function(int) onPressed) {
    return Column(
      children: <Widget>[
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        ToggleButtons(
          borderRadius: BorderRadius.circular(8),
          selectedColor: Colors.white,
          fillColor: Theme.of(context).primaryColor,
          borderColor: Theme.of(context).primaryColor,
          selectedBorderColor: Theme.of(context).primaryColor,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text('On'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text('Off'),
            ),
          ],
          isSelected: selections,
          onPressed: onPressed,
        ),
      ],
    );
  }

  Widget _buildMotorControlSection() {
    return Column(
      children: <Widget>[
        Text('Motor Control',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        ToggleButtons(
          borderRadius: BorderRadius.circular(8),
          selectedColor: Colors.white,
          fillColor: Theme.of(context).primaryColor,
          borderColor: Theme.of(context).primaryColor,
          selectedBorderColor: Theme.of(context).primaryColor,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text('Off'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text('Auto'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text('Ventilation'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text('Pump Air'),
            ),
          ],
          isSelected: _motorSelections,
          onPressed: (index) {
            setState(() {
              switch (index) {
                case 0:
                  _motorMode = 'off';
                  _sendMessage('esp32/motor2', 'off');
                  break;
                case 1:
                  _motorMode = 'auto';
                  _sendMessage('esp32/motor2', 'auto');
                  break;
                case 2:
                  _motorMode = 'ventilation';
                  _sendMessage('esp32/motor2', 'ventilation');
                  break;
                case 3:
                  _motorMode = 'pump air';
                  _sendMessage('esp32/motor2', 'pump air');
                  break;
              }
              _updateMotorSelection();
            });
          },
        ),
      ],
    );
  }

  Widget _buildGasStatusSection() {
    Color status1Color;
    String status1Text;

    if (gasStatus == 'normal') {
      status1Color = Colors.green;
      status1Text = 'Gas Level Normal';
    } else if (gasStatus == 'leakage') {
      status1Color = Colors.red;
      status1Text = 'Gas Leakage Detected!';
    } else {
      status1Color = Colors.grey;
      status1Text = 'Unknown Gas Status';
    }

    return Column(
      children: <Widget>[
        Text('Gas Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: status1Color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            status1Text,
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildFlameStatusSection() {
    Color status2Color;
    String status2Text;

    if (flameStatus == 'normal') {
      status2Color = Colors.green;
      status2Text = 'No Flame Detected';
    } else if (flameStatus == 'fire') {
      status2Color = Colors.red;
      status2Text = 'Fire Alert!';
    } else {
      status2Color = Colors.grey;
      status2Text = 'Unknown Flame Status';
    }

    return Column(
      children: <Widget>[
        Text('Flame Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: status2Color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            status2Text,
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ],
    );
  }
}




class GaragePage extends StatefulWidget {
  @override
  _GaragePageState createState() => _GaragePageState();
}

class _GaragePageState extends State<GaragePage> {
  String broker = 'd422ba0605d740a194a4513751bc4030.s1.eu.hivemq.cloud';
  int port = 8883;
  String username = 'flutter';
  String password = 'Flutter1';
  String _selectedLEDMode = 'off';

  late MqttServerClient _client;

  List<bool> _ledSelections = List.generate(3, (_) => false);
  List<bool> _servoSelections = List.generate(3, (_) => false);

  @override
  void initState() {
    super.initState();
    _connectMQTT();
    _updateLEDSelection();

  }

  Future<void> _connectMQTT() async {
    _client = MqttServerClient(broker, '');
    _client.port = port;
    _client.secure = true;
    _client.logging(on: true);
    _client.onConnected = () => print('Connected');
    _client.onDisconnected = () => print('Disconnected');
    _client.securityContext = SecurityContext.defaultContext;
    _client.keepAlivePeriod = 20;
    _client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier('flutter_client')
        .authenticateAs(username, password)
        .withWillQos(MqttQos.atMostOnce)
        .startClean();

    try {
      await _client.connect();
    } catch (e) {
      print('Exception: $e');
      _client.disconnect();
    }
  }

  void _sendMessage(String topic, String message) {
    final MqttClientPayloadBuilder builder = MqttClientPayloadBuilder();
    builder.addString(message);
    _client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
  }

  void _updateLEDSelection() {
    setState(() {
      switch (_selectedLEDMode) {
        case 'on':
          _ledSelections = [true, false, false];
          break;
        case 'off':
          _ledSelections = [false, true, false];
          break;
        case 'auto':
          _ledSelections = [false, false, true];
          break;
      }
    });
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Garage'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _buildToggleSection('Lights', _ledSelections, (index) {
                setState(() {
                  switch (index) {
                    case 0:
                      _selectedLEDMode = 'on';
                      _sendMessage('esp32/led3', 'on');
                      break;
                    case 1:
                      _selectedLEDMode = 'off';
                      _sendMessage('esp32/led3', 'off');
                      break;
                    case 2:
                      _selectedLEDMode = 'auto';
                      _sendMessage('esp32/led3', 'auto');
                      break;
                  }
                  _updateLEDSelection();
                });
              }),
              SizedBox(height: 20),
              _buildServoControlSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleSection(String title, List<bool> selections, Function(int) onPressed) {
    return Column(
      children: <Widget>[
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        ToggleButtons(
          borderRadius: BorderRadius.circular(8),
          selectedColor: Colors.white,
          fillColor: Theme.of(context).primaryColor,
          borderColor: Theme.of(context).primaryColor,
          selectedBorderColor: Theme.of(context).primaryColor,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text('On'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text('Off'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text('Auto'),
            ),
          ],
          isSelected: selections,
          onPressed: onPressed,
        ),
      ],
    );
  }
  Widget _buildServoControlSection() {
    return
      Row(
      children: <Widget>[
        Text('Door', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 10),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            textStyle: TextStyle(fontSize: 18),
          ),
          onPressed: () {
            setState(() {

              _sendMessage('esp32/servo3', 'on');

            });
          },
          child: Text('Open'),
        ),
        SizedBox(height: 10),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            textStyle: TextStyle(fontSize: 18),
          ),
          onPressed: () {
            setState(() {

              _sendMessage('esp32/servo3', 'off');

            });
          },
          child: Text('Close'),
        ),
        SizedBox(height: 10),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            textStyle: TextStyle(fontSize: 18),
          ),
          onPressed: () {
            setState(() {

              _sendMessage('esp32/servo3', 'auto');

            });
          },
          child: Text('Auto'),
        ),
        SizedBox(height: 10),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            textStyle: TextStyle(fontSize: 18),
          ),
          onPressed: () {
            setState(() {

              _sendMessage('esp32/servo3', 'lock');

            });
          },
          child: Text('Lock'),
        ),
      ],
    );
  }
}
