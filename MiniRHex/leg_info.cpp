#include "leg_info.h"
#include "control_parameters.h"
#include "gait_parameters.h"
// #include "gaits.h"
#include <fstream>

int active_mini = 1;

void update_gait(int leg_index, int gait_idx, int startMillis){
  Gait new_gait = all_gaits[gait_idx];
  legs[leg_index].gait = new_gait;
  legs[leg_index].theta_slow = new_gait.theta_s[leg_index];
  legs[leg_index].theta_down = new_gait.theta_d[leg_index];
  legs[leg_index].t_c = new_gait.t_cc[leg_index];
  legs[leg_index].duty_factor = new_gait.duty_f[leg_index];
  legs[leg_index].phase = new_gait.phases[leg_index];
  legs[leg_index].kp = new_gait.kp;
  legs[leg_index].kd = new_gait.kd;
  update_gait_internal_params(legs[leg_index], startMillis);
}

void update_gait_internal_params(leg& l, int startTime){
  float ground_speed;
  float recovery_speed;
  int t_s = round(l.t_c * l.duty_factor);

  if (l.gait.id == 5){
    ground_speed = l.theta_slow / t_s;
    recovery_speed = -l.theta_slow / (l.t_c - t_s);

    l.thetas[0] = l.theta_down;
    l.ts[0] = 0;

    l.thetas[1] = l.theta_down - l.theta_slow/2;
    l.ts[1] = l.ts[0] + (l.thetas[1] - l.thetas[0]) / recovery_speed;

    l.thetas[2] = l.theta_down;
    l.ts[2] = l.ts[1] + (l.thetas[2] - l.thetas[1]) / ground_speed;

    l.thetas[3] = l.theta_down + l.theta_slow/2;
    l.ts[3] = l.ts[2] + (l.thetas[3] - l.thetas[2]) / ground_speed;

    l.thetas[4] = l.theta_down;
    l.ts[4] = l.t_c;

  }
  else{ //all walking gaits (and standing technically)

    ground_speed = l.theta_slow / t_s;
    recovery_speed = (theta_circle - l.theta_slow) / (l.t_c - t_s);

    l.thetas[0] = l.theta_down - theta_circle + theta_up;
    l.ts[0] = 0;

    l.thetas[1] = l.theta_down - l.theta_slow/2;
    l.ts[1] = l.ts[0] + (l.thetas[1] - l.thetas[0]) / recovery_speed;

    l.thetas[2] = l.theta_down;
    l.ts[2] = l.ts[1] + (l.thetas[2] - l.thetas[1]) / ground_speed;

    l.thetas[3] = l.theta_down + l.theta_slow/2;
    l.ts[3] = l.ts[2] + (l.thetas[3] - l.thetas[2]) / ground_speed;

    l.thetas[4] = l.theta_down + theta_up;
    l.ts[4] = l.t_c;

  }
  l.startMillis = startTime;
  l.ground_speed = ground_speed;
  l.recovery_speed = recovery_speed;

}

/*
MODIFY THESE ARRAYS TO CONFIGURE ROBOT
(mini1 and mini2 are our two prototypes, ignore mini2 array if you're only using one robot)
be sure to set active_mini to 1 in gait_parameters.cpp
*/
float mini1Zeros[6] = {0,0,0,0,0,0};

float mini2Zeros[6] = {0,0,0,0,0,0};
int IDS[6] = {1, 2, 3, 4, 5, 6};

///////////////////////

float *zeros = (active_mini == 1) ? mini1Zeros : mini2Zeros;

leg fake_leg0 = {  0,     0,  stand_gait,    0,      false, false, false}; //this leg is a spacer in the array, only used to make each leg's index be equal to its number
leg leg1 =      {IDS[0],  0,  stand_gait, zeros[0],  false, false, false};
leg leg2 =      {IDS[1],  0,  stand_gait, zeros[1],  false, false, false};
leg leg3 =      {IDS[2],  0,  stand_gait, zeros[2],  false, false, false};
leg leg4 =      {IDS[3],  0,  stand_gait, zeros[3],  true,  false, false};
leg leg5 =      {IDS[4],  0,  stand_gait, zeros[4],  true,  false, false};
leg leg6 =      {IDS[5],  0,  stand_gait, zeros[5],  true,  false, false};

leg legs[] = {fake_leg0, leg1, leg2, leg3, leg4, leg5, leg6};

