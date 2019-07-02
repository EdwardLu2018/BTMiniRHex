#include "leg_info.h"
#include "control_parameters.h"
// #include "desired_values.h"
#include "conversions.h"
#include "pd_control.h"
#include "gait_parameters.h"

// Dynamixel Setup //
#define DXL_BUS_SERIAL1 1  //Dynamixel on Serial1(USART1)  <-OpenCM9.04
Dynamixel Dxl(DXL_BUS_SERIAL1);

// Control Table //
#define MOVING_SPEED 32
#define PRESENT_POS 37
#define PRESENT_SPEED 39
#define PRESENT_VOLTAGE 45
#define LED 25

//Rewritable globals
float desired_vel;
float desired_theta;
float actual_vel;
float actual_theta;
float control_signal;
float actual_p;

int gait_idx = 0;

//Deadzone
int dead_buffer = 40;

// Legs setup //
const int legs_active = 6;

// Packet Setup //
const int packet_length = 2*legs_active;
word packet[packet_length];

// Button Setup //
int button_state;
int last_button_state = 0;

// Battery Check //
int low_battery = 1; // 1 = red, 3 = yellow, 2 = green
int prev_low_battery = 0;
int voltage;
int voltage_check;

void setup() {
  Dxl.begin(3); // baudrate set to 1 Mbps (max)
  Serial2.begin(57600); // set up serial usb input
  pinMode(BOARD_BUTTON_PIN, INPUT_PULLDOWN); // setup user button
  pinMode(BOARD_LED_PIN, OUTPUT); // setup LED
  int t_start = millis();
  for (int i = 1; i <= legs_active; i++) { // legs stored at their index
    Dxl.wheelMode(legs[i].id); // change servo to wheel mode
    legs[i].updateGait(gait_idx, t_start); // set initial parameters, initial_gait in gait_parameters
  }
}

void user_button_pressed() {

  digitalWrite(BOARD_LED_PIN, LOW); //turn led on
  //compute new gait
  int t_start = millis();
  gait_idx = (gait_idx + 1) % TOTAL_GAITS;
  SerialUSB.print("gait idx: ");
  SerialUSB.println(gait_idx);
  for(int i = 1; i <= legs_active; i++) {
    legs[i].updateGait(gait_idx, t_start);
  }

}

void user_button_released() {
  digitalWrite(BOARD_LED_PIN, HIGH);
}

int count = 0;
void loop() {
  //time count
  count++;

  prev_low_battery = low_battery;
  //Every 100 loop iterations, find max voltage supplied to each leg and compare with nominal
  if (count%10 == 0) {
    voltage = 0;
    for (int i = 1; i <= legs_active; i++) {
      voltage_check = Dxl.readByte(legs[1].id, PRESENT_VOLTAGE);
      if (voltage_check > voltage) voltage = voltage_check;
    }
    SerialUSB.println(voltage);

    if (voltage > 73) { //green
      low_battery = 2;
    }
    else if (voltage < 71) { //red
      low_battery = 1;
    }
    else{
      low_battery = 3; //yellow
    }
  }

  if (prev_low_battery != low_battery) {
    SerialUSB.println("Should switch led color here");
    for (int i = 1; i <= legs_active; i++) {
      Dxl.writeByte(legs[i].id, LED, low_battery);
    }
  }

  // bluetooth control
  if (Serial2.available()) {
    char a = (char)(Serial2.read());
    SerialUSB.println(a);
    int bt_gait_idx = -1;
    switch (a) {
    case 'q':
      bt_gait_idx = 0;
      break; //stand
    case 'w':
      bt_gait_idx = 1;
      break; //forwards
    case 's':
      bt_gait_idx = 2;
      break; //reverse
    case 'a':
      bt_gait_idx = 3;
      break; //left
    case 'd':
      bt_gait_idx = 4;
      break; //right
    case 'e':
      bt_gait_idx = 5;
      break;
    }

    if (bt_gait_idx != -1) {
      int t_start = millis();
      for (int i = 1; i <= legs_active; i++) {
        legs[i].updateGait(bt_gait_idx, t_start);
      }
    }
  }
  SerialUSB.print("count: ");
  SerialUSB.println(count % 100);
  if (count % 100 == 0) {
    gait_idx++;
    SerialUSB.println(gait_idx);
  }

  //button control
  button_state = digitalRead(BOARD_BUTTON_PIN);
  if (button_state > last_button_state) user_button_pressed();
  else if (button_state < last_button_state) user_button_released();
  last_button_state = button_state;


  //primary for-loop
  for(int i = 1; i <= legs_active; i++) {
    packet[(i-1) * 2] = legs[i].id;
    actual_p = Dxl.readWord(legs[i].id, PRESENT_POS);
    actual_theta = P_to_Theta(actual_p); // converted to degrees, relative to leg
    actual_vel = dynV_to_V(Dxl.readWord(legs[i].id, PRESENT_SPEED)); // converted to degrees/ms, relative to leg
    if (!legs[i].deadzone) {

      if (actual_p == 0 || actual_p == 1023) { //entering deadzone
        legs[i].deadzone = true;
        if (actual_p == 0) legs[i].dead_from_neg = true;
        else legs[i].dead_from_neg = false;
        continue;
      }

      if (legs[i].gait.id == 0) { //standing or sitting
        if (legs[i].right_side) {
          desired_theta = Theta_to_ThetaR(legs[i].desired_theta);
        }
        else{
          desired_theta = legs[i].desired_theta;
        }
        actual_theta = actual_theta - legs[i].zero; //zero out leg thetas, accounts for small servo irregularities
        control_signal = pd_controller(actual_theta, desired_theta, actual_vel, 0, kp_hold, kd_hold);
      }
      else { //walking, turning
        //compute absolute desired values (theta and velocity) from clock time
        legs[i].getDesiredVals(millis());
        //translate theta and v to relative (left and right)
        if (legs[i].right_side) {
          desired_vel = -legs[i].global_velocity; //relative
          desired_theta = Theta_to_ThetaR(legs[i].global_theta); // relative
        }
        else { //left side, relative is same as global
          desired_vel = legs[i].global_velocity;
          desired_theta = legs[i].global_theta;
        }
        actual_theta = actual_theta - legs[i].zero;

        control_signal = pd_controller(actual_theta, desired_theta, actual_vel, desired_vel, legs[i].kp, legs[i].kd);
      }

      int new_vel = V_to_dynV(actual_vel + control_signal);
      packet[(i-1) * 2 + 1] = new_vel;
    }

    else{ //deadzone
      if ((actual_p > 0) & (actual_p < dead_buffer) || (actual_p < 1023) & (actual_p > 1023 -dead_buffer)) { //exiting deadzone
        legs[i].deadzone = false;
      }
      float signed_recovery_speed = legs[i].dead_from_neg == true ? -legs[i].recovery_speed : legs[i].recovery_speed;
      packet[(i-1) * 2 + 1] = V_to_dynV(signed_recovery_speed);
    }

    // SerialUSB.println(packet[0]);
    // SerialUSB.println(packet[1]);
    // SerialUSB.println(packet[2]);
    // SerialUSB.println(packet[3]);
    // SerialUSB.println(packet[4]);
    // SerialUSB.println(packet[5]);
    // SerialUSB.println(packet[6]);
    // SerialUSB.println(packet[7]);
    // SerialUSB.println(packet[8]);
    // SerialUSB.println(packet[9]);
    // SerialUSB.println(packet[10]);
    // SerialUSB.println(packet[11]);
  }

  Dxl.syncWrite(MOVING_SPEED, 1, packet, packet_length); //simultaneously write to each of 6 servoes with updated commands
}
