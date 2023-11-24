#include <Servo.h>


Servo servo;

String command = "OFF";
bool commandComplete = true;
String lastCommand = "";

int currentPos;
int pos;

void setup() {
  Serial.begin(9600);

  pinMode(DD3, OUTPUT);

  command.reserve(20);
}

void moveTo(int newPos) {
  servo.attach(DD4);

  currentPos = servo.read();

  if (currentPos < newPos) {
    for (pos = currentPos; pos <= newPos; pos += 1) {
      servo.write(pos);
      delay(25);
    }
  } else if (currentPos > newPos) {
    for (pos = currentPos; pos >= newPos; pos -= 1) {
      servo.write(pos);
      delay(25);
    }
  }

  servo.detach();
}

void on() {
  moveTo(0);
  digitalWrite(DD3, HIGH);
}


void off() {
  digitalWrite(DD3, LOW);
  moveTo(90);
}

void loop() {
  if (commandComplete) {
    if (lastCommand != command) {
      if (command == "ON") {
        on();
      } else if (command == "OFF") {
        off();
      }
      
      lastCommand = command;
    }

    command = "";
    commandComplete = false;
  }
}

/*
  SerialEvent occurs whenever a new data comes in the hardware serial RX. This
  routine is run between each time loop() runs, so using delay inside loop can
  delay response. Multiple bytes of data may be available.
*/
void serialEvent() {
  while (Serial.available()) {
    char inChar = (char)Serial.read();

    // if the incoming character is a newline, set a flag so the main loop can do something about it
    if (inChar == '\n') {
      commandComplete = true;
    } else {
      command += inChar;
    }
  }
}
