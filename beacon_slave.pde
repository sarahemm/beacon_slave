#include <EEPROM.h>
#include <Wire.h>
#include <avr/wdt.h>

#define WDT_TIMEOUT 9   // ~8 seconds
//#define DEBUG 1

#define DARK   0x00
#define RED    0x01
#define GREEN  0x02
#define YELLOW 0x03
#define BLUE   0x04
#define PURPLE 0x05
#define TEAL   0x06
#define WHITE  0x07

#define L0R 31
#define L0G 30
#define L0B 29
#define L1R 28
#define L1G 27
#define L1B 26
#define L2R 25
#define L2G 24
#define L2B 0 


#define L3R 1
#define L3G 2
#define L3B 3
#define L4R 4
#define L4G 5
#define L4B 6
#define L5R 7
#define L5G 18
#define L5B 19
#define L6R 20
#define L6G 21
#define L6B 22
#define L7R 23
#define L7G 8
#define L7B 9
#define L8R 10
#define L8G 11
#define L8B 12
#define L9R 13
#define L9G 14
#define L9B 15

struct led {
  byte r_pin_addr;       /* Layer-local pin address */
  byte g_pin_addr;       /* Layer-local pin address */
  byte b_pin_addr;       /* Layer-local pin address */
};

struct led leds[10]; /* all LEDs on this board */
volatile int bytesToReceive = 0;

void setup() {
  wdt_disable();
  wdt_enable(WDT_TIMEOUT);
  wdt_reset();
  
  leds[0].r_pin_addr = L0R;  
  leds[0].g_pin_addr = L0G;
  leds[0].b_pin_addr = L0B;

  leds[1].r_pin_addr = L1R;
  leds[1].g_pin_addr = L1G;
  leds[1].b_pin_addr = L1B;

  leds[2].r_pin_addr = L2R;
  leds[2].g_pin_addr = L2G;
  leds[2].b_pin_addr = L2B;

  leds[3].r_pin_addr = L3R;
  leds[3].g_pin_addr = L3G;
  leds[3].b_pin_addr = L3B;

  leds[4].r_pin_addr = L4R;
  leds[4].g_pin_addr = L4G;
  leds[4].b_pin_addr = L4B;

  leds[5].r_pin_addr = L5R;
  leds[5].g_pin_addr = L5G;
  leds[5].b_pin_addr = L5B;

  leds[6].r_pin_addr = L6R;
  leds[6].g_pin_addr = L6G;
  leds[6].b_pin_addr = L6B;

  leds[7].r_pin_addr = L7R;
  leds[7].g_pin_addr = L7G;
  leds[7].b_pin_addr = L7B;

  leds[8].r_pin_addr = L8R;
  leds[8].g_pin_addr = L8G;
  leds[8].b_pin_addr = L8B;
  
  leds[9].r_pin_addr = L9R;
  leds[9].g_pin_addr = L9G;
  leds[9].b_pin_addr = L9B;
  
  // Set all pins to outputs (Wire.begin will reset the I2C pins for us)
  int i;
  for(i=0; i<=31; i++) {
    pinMode(i, OUTPUT);
  }
  
  #ifdef DEBUG
    // Flash each LED quickly to show that we're alive
    for(i=0; i<=9; i++) {
      wdt_reset();
      digitalWrite(leds[i].r_pin_addr, HIGH);
      delay(75);
      digitalWrite(leds[i].r_pin_addr, LOW);
      digitalWrite(leds[i].g_pin_addr, HIGH);
      delay(75);
      digitalWrite(leds[i].g_pin_addr, LOW);
      digitalWrite(leds[i].b_pin_addr, HIGH);
      delay(75);
      digitalWrite(leds[i].b_pin_addr, LOW);
    }
  #endif
  
  // Fetch our address (first EEPROM byte)
  byte slave_addr;
  slave_addr = EEPROM.read(0);
  
  // Now flash a specific LED X times to show what our I2C address is
  for(i=0; i<slave_addr; i++) {
    digitalWrite(leds[0].r_pin_addr, HIGH);
    delay(100);
    digitalWrite(leds[0].r_pin_addr, LOW);
    delay(125);
    wdt_reset();
  }
  
  // Start talking on the I2C bus
  Wire.begin(slave_addr);
  
  // For some reason Wire.begin() turns on pins PD0 and PD1, so we need to turn them off
  digitalWrite(leds[7].g_pin_addr, LOW);
  digitalWrite(leds[7].b_pin_addr, LOW);
  
  // Set up to receive I2C data from the master
  Wire.onReceive(handleReceivedData);
  #ifdef DEBUG
    Serial.begin(9600);
    Serial.println("Waiting for I2C commands...");
  #endif
}

void loop() {
  //delay(100);
  wdt_reset();
  if(bytesToReceive > 0) {
    //while(0 < Wire.available()) {
      //Serial.println(Wire.receive(), HEX);
      handleWireCommands();
    //}
  }
}

void setLedColour(byte ledNumber, byte colour) {
  #ifdef DEBUG
    wdt_reset();
    Serial.print("Setting LED ");
    Serial.print(ledNumber, DEC);
    Serial.print(" to colour ");
    Serial.println(colour, DEC);
  
    Serial.print(" R (pin ");
    Serial.print(leds[ledNumber].r_pin_addr, DEC);
    Serial.print(") = ");
    Serial.println((colour & RED) == RED, DEC);
    
    Serial.print(" G (pin ");
    Serial.print(leds[ledNumber].g_pin_addr, DEC);
    Serial.print(") = ");
    Serial.println((colour & GREEN) == GREEN, DEC);
    
    Serial.print(" B (pin ");
    Serial.print(leds[ledNumber].b_pin_addr, DEC);
    Serial.print(") = ");
    Serial.println((colour & BLUE) == BLUE, DEC);
  #endif
  
  digitalWrite(leds[ledNumber].r_pin_addr, (colour & RED)   == RED  );
  digitalWrite(leds[ledNumber].g_pin_addr, (colour & GREEN) == GREEN);
  digitalWrite(leds[ledNumber].b_pin_addr, (colour & BLUE)  == BLUE );
}

byte readLedColour(byte ledNumber) {
  byte colour;
  colour = digitalRead(leds[ledNumber].r_pin_addr);
  colour = digitalRead(leds[ledNumber].g_pin_addr) << 1;
  colour = digitalRead(leds[ledNumber].b_pin_addr) << 2;

  return colour;
}

void handleWireCommands(void) {
  byte i, cmd, arg;
  
  #ifdef DEBUG
    Serial.print(Wire.available(), DEC);
    Serial.println(" bytes of pending I2C data to receive.");
  #endif
  
  while(bytesToReceive > 0) {
    if(Wire.available() % 2 == 0) {
      // even bytes (we start at zero) contain a command 
      cmd = Wire.receive();
      bytesToReceive--;
      #ifdef DEBUG
        Serial.print(" Received command: 0x");
        Serial.println(cmd, HEX);
      #endif
    } else {
      // even bytes contain an argument
      arg = Wire.receive();
      bytesToReceive--;
      #ifdef DEBUG
        Serial.print(" Received argument: 0x");
        Serial.println(arg, HEX);
        // remote wants us to set an LED colour
        Serial.println("Setting LED colour.");
      #endif
      setLedColour(cmd, arg);
    }
  }
  #ifdef DEBUG
    Serial.println("Processing complete.  Idling...");
  #endif
}

void handleReceivedData(int numBytes) {
  bytesToReceive += numBytes;
  return;
}
