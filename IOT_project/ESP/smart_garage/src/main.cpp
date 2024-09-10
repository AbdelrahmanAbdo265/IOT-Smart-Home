#include <WiFi.h>  // Include the WiFi library for ESP32 WiFi functions
#include <WiFiClientSecure.h>  // Include the WiFiClientSecure library for secure WiFi client
#include <PubSubClient.h>  // Include the PubSubClient library for MQTT client functions
#include <Arduino.h>  // Include the core Arduino functions
#include <Keypad.h>  // Include the Keypad library for matrix keypad support
#include <LiquidCrystal_I2C.h>  // Include the LiquidCrystal_I2C library for I2C LCD control
#include <ESP32Servo.h>  // Include the ESP32Servo library for servo motor control

// Define WiFi credentials
const char* ssid = "Abdo's laptop";  // SSID of the WiFi network
const char* password = "12345678";  // Password for the WiFi network

// Define MQTT server details
const char* mqtt_server = "d422ba0605d740a194a4513751bc4030.s1.eu.hivemq.cloud";  // MQTT server address
const int mqtt_port = 8883;  // MQTT server port number
const char* mqtt_user = "abdoo";  // MQTT username
const char* mqtt_pass = "Abdo1234";  // MQTT password

// Define MQTT topics for LED and servo control
const char* led3Topic = "esp32/led3";  // MQTT topic for LED control
const char* servo3Topic = "esp32/servo3";  // MQTT topic for servo control

// Define GPIO pins for various components
const int pirPin = 34;  // GPIO pin for PIR sensor
const int irPin = 32;  // GPIO pin for IR sensor
const int led3Pin = 13;  // GPIO pin for LED
const int servo3pin = 15;  // GPIO pin for servo motor

// Define modes for LED and servo
enum Mode { OFF, ON, AUTO ,LOCK};  // Enumeration for different modes
Mode led3Mode = OFF;  // Initial mode for LED
Mode servo3Mode=OFF;  // Initial mode for servo

// Define keypad configuration
const int ROWS = 4;  // Number of rows in the keypad
const int COLS = 4;  // Number of columns in the keypad
char keys[ROWS][COLS] = {  // Define the keys on the keypad
  {'1', '2', '3', 'A'},
  {'4', '5', '6', 'B'},
  {'7', '8', '9', 'C'},
  {'*', '0', '#', 'D'}
};
byte rowPins[ROWS] = {4, 5, 18, 19};  // GPIO pins connected to keypad rows
byte colPins[COLS] = {25, 26, 14, 12};  // GPIO pins connected to keypad columns

// Instantiate objects for keypad, WiFi client, MQTT client, servo, and LCD
Keypad keypad = Keypad(makeKeymap(keys), rowPins, colPins, ROWS, COLS);
WiFiClientSecure espClient;
PubSubClient client(espClient);
Servo myservo;
LiquidCrystal_I2C lcd(0x27, 16, 2);  // Initialize LCD with I2C address and dimensions

// Define security password
const String userPass = "1234";  // Password for home security

// Define variables for sensor readings and motor speed
int pirValue = 0;  // Variable to store PIR sensor reading
int irValue = 0;  // Variable to store IR sensor reading
int motorSpeed=0;  // Variable to store motor speed

// Function to connect to WiFi
void setup_wifi() {
  delay(10);
  Serial.println();
  Serial.print("Connecting to ");
  Serial.println(ssid);
  WiFi.begin(ssid, password);  // Begin WiFi connection
  while (WiFi.status() != WL_CONNECTED) {  // Wait for WiFi connection
    delay(500);
    Serial.print(".");
  }
  Serial.println("");
  Serial.println("WiFi connected");
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());  // Print local IP address
}

// Function to connect to the MQTT server
void connectMQTT() {
  while (!client.connected()) {  // Wait until connected to MQTT server
    Serial.print("Attempting MQTT connection...");
    if (client.connect("ESP32Client", mqtt_user, mqtt_pass)) {  // Connect to MQTT server
      Serial.println("connected");
      client.subscribe(led3Topic);  // Subscribe to LED control topic
      client.subscribe(servo3Topic);  // Subscribe to servo control topic
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());  // Print connection failure reason
      Serial.println(" try again in 5 seconds");
      delay(5000);
    }
  }
}

// Function to reconnect to the MQTT server if disconnected
void reconnectMQTT() {
  while (!client.connected()) {  // Wait until connected to MQTT server
    Serial.print("Attempting MQTT connection...");
    if (client.connect("ESP32Client", mqtt_user, mqtt_pass)) {  // Connect to MQTT server
      Serial.println("connected");
      client.subscribe(led3Topic);  // Subscribe to LED control topic
      client.subscribe(servo3Topic);  // Subscribe to servo control topic
    } else {
      Serial.print("failed, rc=");
      Serial.print(client.state());  // Print connection failure reason
      Serial.println(" try again in 5 seconds");
      delay(5000);
    }
  }
}

// Callback function to handle incoming MQTT messages
void callback(char* topic, byte* payload, unsigned int length) {
  String topicStr = String(topic);  // Convert topic to string
  String message;  // Variable to store incoming message
  for (int i = 0; i < length; i++) {
    message += (char)payload[i];  // Convert payload to string
  }
  Serial.print("Message arrived [");
  Serial.print(topicStr);
  Serial.print("] ");
  Serial.println(message);
  if (topicStr == led3Topic) {  // Handle LED control messages
    if (message == "on") {
      led3Mode = ON;
    } else if (message == "off") {
      led3Mode = OFF;
    } else if (message == "auto") {
      led3Mode = AUTO;
    }
  } else if (topicStr == servo3Topic) {  // Handle servo control messages
    if (message == "on") {
      servo3Mode = ON;
    } else if (message == "off") {
      servo3Mode = OFF;
    } else if (message == "auto") {
      servo3Mode = AUTO;
    } else if (message == "lock") {
      servo3Mode = LOCK;
    }
  }
}

// Function declarations for password, house entry, and locking
bool getPassword();  // Function to get password from keypad
void enterHouse();  // Function to open the house after correct password
void lock();  // Function to lock the house

// Setup function to initialize the system
void setup() {
  Serial.begin(115200);  // Initialize serial communication
  setup_wifi();  // Connect to WiFi
  espClient.setInsecure();  // Disable SSL verification (not recommended for production)
  client.setServer(mqtt_server, mqtt_port);  // Set MQTT server
  client.setCallback(callback);  // Set MQTT message callback
  pinMode(led3Pin, OUTPUT);  // Set LED pin as output
  pinMode(irPin, INPUT);  // Set IR pin as input
  pinMode(pirPin, INPUT);  // Set PIR pin as input
  myservo.attach(servo3pin);  // Attach servo motor to pin
  myservo.write(0);  // Initialize servo position
  lcd.init();  // Initialize LCD
  lcd.clear();  // Clear LCD display
  lcd.backlight();  // Turn on LCD backlight
  connectMQTT();  // Connect to MQTT server
}

// Main loop function
void loop() {
  if (!client.connected()) {  // Reconnect to MQTT if disconnected
    reconnectMQTT();
  }
  client.loop();  // Process incoming MQTT messages
  irValue = digitalRead(irPin);  // Read IR sensor value
  pirValue = digitalRead(pirPin);  // Read PIR sensor value
  if (led3Mode == ON) {  // Handle LED on mode
    digitalWrite(led3Pin, HIGH);  // Turn on LED
  } else if (led3Mode == OFF) {  // Handle LED off mode
    digitalWrite(led3Pin, LOW);  // Turn off LED
  } else if (led3Mode == AUTO) {  // Handle LED auto mode
    if (pirValue == HIGH) {  // Turn on LED if motion is detected
      digitalWrite(led3Pin, HIGH);
    } else {
      digitalWrite(led3Pin, LOW);
    }
  }
  if (servo3Mode == ON) {  // Handle servo on mode
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Welcome");  // Display welcome message on LCD
    myservo.write(90);  // Open the door
  } else if (servo3Mode == OFF) {  // Handle servo off mode
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("closed");  // Display closed message on LCD
    myservo.write(0);  // Close the door
  } else if (servo3Mode == AUTO) {  // Handle servo auto mode
    if (irValue == HIGH) {  // Close the door if IR sensor is triggered
      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print("closed");
      myservo.write(0);
    } else {  // Open the door if IR sensor is not triggered
      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print("Welcome");
      myservo.write(90);
    }
  } else if(servo3Mode==LOCK){  // Handle servo lock mode
    lock();
  }
}

// Function to take the password using the keypad
bool getPassword() {
  String password = "";
  lcd.setCursor(0, 1);  // Set cursor to second line on LCD
  while (true) {
    char key = keypad.getKey();  // Get key pressed on keypad
    if (key) {
      if (key == '#') {  // Check if user pressed enter key
        break;
      } else {
        password += key;  // Append pressed key to password string
        lcd.print('*');  // Print asterisk on LCD for each key press
      }
    }
  }
  password == userPass ? "Password correct" : "Incorrect password";  // Compare entered password with correct password
  return password == userPass;  // Return true if password is correct, else false
}

// Function to check if the password is correct and open the door
void enterHouse() {
  bool isCorrect = getPassword();  // Check if password is correct
  lcd.clear();
  while(!isCorrect) {  // Loop until correct password is entered
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("x try again:");  // Prompt user to try again
    isCorrect = getPassword();   
  } 
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Welcome");  // Display welcome message
  myservo.write(90);  // Open the door  
  servo3Mode=ON;  // Set servo mode to ON
}

// Function to lock the house and check password to enter
void lock(){
  myservo.write(0);  // Close the door
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Enter password:");  // Prompt user to enter password
  enterHouse();  // Call enterHouse to check password and open the door
}
