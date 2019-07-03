#include "robot.h"

// Dynamixel Setup //
#define DXL_BUS_SERIAL1 1  //Dynamixel on Serial1(USART1)  <-OpenCM9.04
Dynamixel dxl(DXL_BUS_SERIAL1);

float mini1zeros[7] = {0, 0, 0, 0, 0, 0};
Robot minirhex(mini1zeros, &dxl);

// Button Setup //
int button_state;
int last_button_state = 0;

void setup() {
    minirhex.setup();
    Serial2.begin(57600); // set up serial usb input
    pinMode(BOARD_BUTTON_PIN, INPUT_PULLDOWN); // setup user button
    pinMode(BOARD_LED_PIN, OUTPUT); // setup LED
}

void user_button_pressed() {
    digitalWrite(BOARD_LED_PIN, LOW); //turn led on
    int new_gait_idx = minirhex.incrementGait(); // change to next gait
    SerialUSB.println(new_gait_idx);
}

void user_button_released() {
    digitalWrite(BOARD_LED_PIN, HIGH);
}

int count = 0;
void loop() {
    SerialUSB.println("working");
    //time count
    count++;

    //Every 100 loop iterations, find max voltage supplied to each leg and compare with nominal
    if (count % 10 == 0) {
      SerialUSB.println(minirhex.checkBattery());
    }

    //button control
    button_state = digitalRead(BOARD_BUTTON_PIN);
    if (button_state > last_button_state) user_button_pressed();
    else if (button_state < last_button_state) user_button_released();
    last_button_state = button_state;

    minirhex.move();
    minirhex.checkForBT();
}
