#include <WiFi.h>  // Include WiFi library for network connectivity
#include <WiFiClientSecure.h>  // Include WiFiClientSecure for secure connections
#include <PubSubClient.h>  // Include PubSubClient for MQTT communication
#include <ESP32Servo.h>  // Include ESP32Servo for controlling servos
#include <Adafruit_Sensor.h>  // Include Adafruit_Sensor for sensor management
#include <DHT.h>  // Include DHT library for temperature and humidity sensing

#define DHTPIN 33  // Define the pin for the DHT11 sensor
#define DHTTYPE DHT11  // Define the type of DHT sensor

DHT dht(DHTPIN, DHTTYPE);  // Initialize the DHT sensor

// WiFi credentials
const char* ssid = "Abdo's laptop";  // SSID of the WiFi network
const char* password = "12345678";  // Password for the WiFi network

// MQTT server details
const char* mqtt_server = "d422ba0605d740a194a4513751bc4030.s1.eu.hivemq.cloud";  // MQTT server address
const int mqtt_port = 8883;  // MQTT server port
const char* mqtt_user = "abdoo1";  // MQTT username
const char* mqtt_pass = "Abdo1234";  // MQTT password

// MQTT topics
const char* ledTopic = "esp32/led";  // MQTT topic for LED control
const char* led2Topic = "esp32/led2";  // MQTT topic for second LED control
const char* servoTopic = "esp32/servo";  // MQTT topic for servo control
const char* servo2Topic = "esp32/servo2";  // MQTT topic for second servo control
const char* ldrTopic = "esp32/ldr";  // MQTT topic for LDR sensor data
const char* pirTopic = "esp32/pir";  // MQTT topic for PIR sensor data
const char* irTopic = "esp32/ir";  // MQTT topic for IR sensor data
const char* tempTopic = "esp32/temp";  // MQTT topic for temperature data
const char* motorTopic = "esp32/motor";  // MQTT topic for motor control
const char* motor2Topic = "esp32/motor2";  // MQTT topic for second motor control
const char* alarmTopic= "esp32/alarm";  // MQTT topic for alarm notifications

// Pin definitions
const int ledPin = 2;  // GPIO pin for LED
const int led2Pin = 4;  // GPIO pin for second LED
const int buzzerPin = 5;  // GPIO pin for buzzer
const int servoPin = 23;  // GPIO pin for servo control
const int servo2Pin = 15;  // GPIO pin for second servo control
const int ldrPin = 27;  // GPIO pin for LDR sensor
const int gasPin = 34;  // GPIO pin for gas sensor
const int irPin = 32;  // GPIO pin for IR sensor
const int irPin2 = 25;  // GPIO pin for second IR sensor
const int flamePin=35;  // GPIO pin for flame sensor
#define ENA_PIN2 14  // PWM pin to control speed of motor 2
#define IN3_PIN 12  // Direction pin 1 for motor 2
#define IN4_PIN 13  // Direction pin 2 for motor 2
#define ENA_PIN 26  // PWM pin to control speed of motor 1
#define IN1_PIN 19  // Direction pin 1 for motor 1
#define IN2_PIN 18  // Direction pin 2 for motor 1

// Create instances
WiFiClientSecure espClient;  // Secure WiFi client instance
PubSubClient client(espClient);  // MQTT client instance
Servo myServo;  // Servo instance
Servo myServo2;  // Second servo instance

// Global state variables
enum Mode { OFF, ON, AUTO ,MANUAL,VENTILATION,PUMP};  // Define modes for different operations
Mode ledMode = OFF;  // Initial mode for LED
Mode led2Mode = OFF;  // Initial mode for second LED
Mode servoMode = OFF;  // Initial mode for servo
Mode motorMode= OFF;  // Initial mode for motor
Mode motor2Mode= OFF;  // Initial mode for second motor
Mode servo2Mode = OFF;  // Initial mode for second servo

// Sensor values
int ldrValue = 0;  // LDR sensor value
int gasValue = 0;  // Gas sensor value
int flameValue=0;  // Flame sensor value
int irValue = 0;  // IR sensor value
int irValue2 = 0;  // Second IR sensor value
int motorSpeed=0;  // Motor speed value

void setup_wifi() {
  delay(10);  // Small delay before connecting to WiFi
  Serial.println();
  Serial.print("Connecting to ");
  Serial.println(ssid);  // Print SSID

  WiFi.begin(ssid, password);  // Start WiFi connection

  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");  // Print dots while connecting
  }

  Serial.println("");
  Serial.println("WiFi connected");  // WiFi connected message
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());  // Print local IP address
}

void connectMQTT() {
  while (!client.connected()) {
    Serial.print("Attempting MQTT connection...");
    if (client.connect("ESP32Client2", mqtt_user, mqtt_pass)) {
      Serial.println("connected");  // MQTT connected message
      client.subscribe(ledTopic);  // Subscribe to LED topic
      client.subscribe(led2Topic);  // Subscribe to second LED topic
      client.subscribe(servoTopic);  // Subscribe to servo topic
      client.subscribe(motorTopic);  // Subscribe to motor topic
      client.subscribe(motor2Topic);  // Subscribe to second motor topic
      client.subscribe(servo2Topic);  // Subscribe to second servo topic
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());  // Print reason for connection failure
      Serial.println(" try again in 5 seconds");
      delay(5000);  // Wait before retrying
    }
  }
}

void reconnectMQTT() {
  while (!client.connected()) {
    Serial.print("Attempting MQTT connection...");
    if (client.connect("ESP32Client", mqtt_user, mqtt_pass)) {
      Serial.println("connected");  // MQTT reconnected message
      client.subscribe(ledTopic);  // Subscribe to LED topic
      client.subscribe(led2Topic);  // Subscribe to second LED topic
      client.subscribe(servoTopic);  // Subscribe to servo topic
      client.subscribe(motorTopic);  // Subscribe to motor topic
      client.subscribe(motor2Topic);  // Subscribe to second motor topic
      client.subscribe(servo2Topic);  // Subscribe to second servo topic
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());  // Print reason for reconnection failure
      Serial.println(" try again in 5 seconds");
      delay(5000);  // Wait before retrying
    }
  }
}

void callback(char* topic, byte* payload, unsigned int length) {
  String topicStr = String(topic);  // Convert topic to String
  String message;

  for (int i = 0; i < length; i++) {
    message += (char)payload[i];  // Convert payload to message String
  }

  Serial.print("Message arrived [");
  Serial.print(topicStr);  // Print topic of the received message
  Serial.print("] ");
  Serial.println(message);  // Print received message

  if (topicStr == ledTopic) {  // Check if topic is LED control
    if (message == "on") {
      ledMode = ON;  // Set LED mode to ON
    } else if (message == "off") {
      ledMode = OFF;  // Set LED mode to OFF
    } else if (message == "auto") {
      ledMode = AUTO;  // Set LED mode to AUTO
    }
  } else if (topicStr == led2Topic) {  // Check if topic is second LED control
    if (message == "on") {
      led2Mode = ON;  // Set second LED mode to ON
    } else if (message == "off") {
      led2Mode = OFF;  // Set second LED mode to OFF
    } 
  } else if (topicStr == servoTopic) {  // Check if topic is servo control
    if (message == "on") {
      servoMode = ON;  // Set servo mode to ON
    } else if (message == "off") {
      servoMode = OFF;  // Set servo mode to OFF
    } else if (message == "auto") {
      servoMode = AUTO;  // Set servo mode to AUTO
    }
  } else if (topicStr == servo2Topic) {  // Check if topic is second servo control
    if (message == "on") {
      servo2Mode = ON;  // Set second servo mode to ON
    } else if (message == "off") {
      servo2Mode = OFF;  // Set second servo mode to OFF
    } else if (message == "auto") {
      servo2Mode = AUTO;  // Set second servo mode to AUTO
    }
  } else if(topicStr == motorTopic) {  // Check if topic is motor control
    if (message == "auto") {
      motorMode = AUTO;  // Set motor mode to AUTO
      Serial.println("auto fan");  // Print motor mode
    } else {
      motorMode = MANUAL;  // Set motor mode to MANUAL
      motorSpeed = message.toInt();  // Convert message to motor speed
      Serial.print("setting fan speed to ");
      Serial.println(motorSpeed);  // Print motor speed
    }
  } else if(topicStr == motor2Topic) {  // Check if topic is second motor control
    if (message == "auto") {
      motor2Mode = AUTO;  // Set second motor mode to AUTO
    } else if (message == "off") {
      motor2Mode = OFF;  // Set second motor mode to OFF
    } else if (message == "ventilation") {
      motor2Mode = VENTILATION;  // Set second motor mode to VENTILATION
    } else if (message == "pump air") {
      motor2Mode = PUMP;  // Set second motor mode to PUMP
    }
  }
}

void setup() {
  ledcAttachPin(buzzerPin, 0);
  Serial.begin(115200);  // Start serial communication at 115200 baud
  setup_wifi();  // Connect to WiFi
  espClient.setInsecure();  // Set client to insecure mode
  client.setServer(mqtt_server, mqtt_port);  // Set MQTT server and port
  client.setCallback(callback);  // Set MQTT callback function

  pinMode(ledPin, OUTPUT);  // Set LED pin as output
  pinMode(led2Pin, OUTPUT);  // Set second LED pin as output
  pinMode(buzzerPin, OUTPUT);  // Set buzzer pin as output
  pinMode(ENA_PIN, OUTPUT);  // Set motor 1 PWM pin as output
  pinMode(IN1_PIN, OUTPUT);  // Set motor 1 direction pin 1 as output
  pinMode(IN2_PIN, OUTPUT);  // Set motor 1 direction pin 2 as output
  pinMode(ENA_PIN2, OUTPUT);  // Set motor 2 PWM pin as output
  pinMode(IN3_PIN, OUTPUT);  // Set motor 2 direction pin 1 as output
  pinMode(IN4_PIN, OUTPUT);  // Set motor 2 direction pin 2 as output
  myServo.attach(servoPin);  // Attach servo to servo pin
  myServo2.attach(servo2Pin);  // Attach second servo to second servo pin

  // Initialize sensors
  pinMode(ldrPin, INPUT);  // Set LDR sensor pin as input
  pinMode(gasPin, INPUT);  // Set gas sensor pin as input
  pinMode(flamePin, INPUT);  // Set flame sensor pin as input
  pinMode(irPin, INPUT);  // Set IR sensor pin as input
  pinMode(irPin2, INPUT);  // Set second IR sensor pin as input

  dht.begin();  // Start DHT sensor
  connectMQTT();  // Connect to MQTT server
}

void loop() {
  if (!client.connected()) {
    reconnectMQTT();  // Reconnect to MQTT if disconnected
  }
  client.loop();  // Process MQTT messages

  // Read sensor values
  ldrValue = digitalRead(ldrPin);  // Read LDR sensor value
  gasValue = analogRead(gasPin);  // Read gas sensor value
  flameValue = analogRead(flamePin);  // Read flame sensor value
  irValue = digitalRead(irPin);  // Read IR sensor value
  irValue2 = digitalRead(irPin2);  // Read second IR sensor value


  if (motor2Mode == OFF) {
    digitalWrite(ENA_PIN2, LOW);  // Turn off motor 2
  }
  if (motor2Mode == PUMP) {
    digitalWrite(ENA_PIN2, HIGH);  // Turn on motor 2
    digitalWrite(IN3_PIN, HIGH);  // Set motor 2 direction
    digitalWrite(IN4_PIN, LOW);
  }
  if (motor2Mode == VENTILATION) {
    digitalWrite(ENA_PIN2, HIGH);  // Turn on motor 2
    digitalWrite(IN3_PIN, LOW);  // Set motor 2 direction
    digitalWrite(IN4_PIN, HIGH);
  }
  if (flameValue < 2500) {
  digitalWrite(buzzerPin,HIGH); // Sound the buzzer
   // Sound the buzzer

    if (motor2Mode == AUTO) {
      digitalWrite(ENA_PIN2, HIGH);  // Turn on motor 2
      digitalWrite(IN3_PIN, HIGH);  // Set motor 2 direction
      digitalWrite(IN4_PIN, LOW);
    }
    if (gasValue > 2500) {
      client.publish(alarmTopic, "fire,leakage");  // Send fire and leakage alert
    } else {
      client.publish(alarmTopic, "fire,normal");  // Send fire and normal alert
    }
  } else {
    if (gasValue > 2500) {
      client.publish(alarmTopic, "normal,leakage");  // Send normal and leakage alert
        digitalWrite(buzzerPin,HIGH); // Sound the buzzer// Sound the buzzer
      
      if (motor2Mode == AUTO) {
        digitalWrite(ENA_PIN2, HIGH);  // Turn on motor 2
        digitalWrite(IN3_PIN, LOW);  // Set motor 2 direction
        digitalWrite(IN4_PIN, HIGH);
      }
    } else {
        digitalWrite(buzzerPin,LOW); // Sound the buzzer // stop the buzzer
   
      client.publish(alarmTopic, "normal,normal");  // Send normal alert
      digitalWrite(buzzerPin, LOW);  // Turn off the buzzer
      if (motor2Mode == AUTO) {
        digitalWrite(ENA_PIN2, LOW);  // Turn off motor 2
      }
    }
  }

  float temperature = dht.readTemperature();  // Read temperature
  float humidity = dht.readHumidity();  // Read humidity

  // Publish temperature and humidity data
  if (!isnan(temperature) && !isnan(humidity)) {
    String tempMsg = String(temperature) + " " + String(humidity);  // Create temperature and humidity message
    client.publish(tempTopic, tempMsg.c_str());  // Publish temperature and humidity
  }

  // Update LED1 based on mode
  if (ledMode == ON) {
    digitalWrite(ledPin, HIGH);  // Turn on LED
  } else if (ledMode == OFF) {
    digitalWrite(ledPin, LOW);  // Turn off LED
  } else if (ledMode == AUTO) {
    if (ldrValue == HIGH) {  // If LDR sensor detects light
      digitalWrite(ledPin, HIGH);  // Turn on LED
    } else {
      digitalWrite(ledPin, LOW);  // Turn off LED
    }
  }

  // Update LED2 based on mode
  if (led2Mode == ON) {
    digitalWrite(led2Pin, HIGH);  // Turn on second LED
  } else if (led2Mode == OFF) {
    digitalWrite(led2Pin, LOW);  // Turn off second LED
  }

  // Update Servo based on mode
  if (servoMode == ON) {
    myServo.write(95);  // Set servo to position 95
  } else if (servoMode == OFF) {
    myServo.write(180);  // Set servo to position 180
  } else if (servoMode == AUTO) {
    if (irValue == HIGH) {  // If IR sensor detects object
      myServo.write(180);  // Set servo to position 180
    } else {
      myServo.write(95);  // Set servo to position 95
    }
  }

  if (servo2Mode == ON) {
    myServo2.write(90);  // Set second servo to position 90
  } else if (servo2Mode == OFF) {
    myServo2.write(0);  // Set second servo to position 0
  } else if (servo2Mode == AUTO) {
    if (irValue2 == HIGH) {  // If second IR sensor detects object
      myServo2.write(0);  // Set second servo to position 0
    } else {
      myServo2.write(90);  // Set second servo to position 90
    }
  }

  if (motorMode == AUTO) {
    motorSpeed = map(humidity, 60, 100, 0, 255);  // Map humidity to motor speed
    analogWrite(ENA_PIN, motorSpeed);  // Set motor speed
    digitalWrite(IN1_PIN, HIGH);  // Set motor direction
    digitalWrite(IN2_PIN, LOW);
  } else if (motorMode == MANUAL) {
    analogWrite(ENA_PIN, motorSpeed);  // Set motor speed
    digitalWrite(IN1_PIN, HIGH);  // Set motor direction
    digitalWrite(IN2_PIN, LOW);
  }

  delay(100);  // Small delay to prevent excessive looping
}
