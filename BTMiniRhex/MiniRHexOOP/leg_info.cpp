#include <math.h>
#include <fstream>
#include "leg_info.h"
#include "gait_parameters.h"
#include "control_parameters.h"

Leg::Leg(int set_id,
    float set_desired_theta, Gait set_gait,
    float set_zero, bool set_right_side,
    bool set_deadzone, bool set_dead_from_neg)
{
    id = set_id;
    desired_theta = set_desired_theta;
    gait = set_gait;
    zero = set_zero;
    right_side = set_right_side;
    deadzone = set_deadzone;
    dead_from_neg = set_dead_from_neg;
    updateGait(0, 0);
}

void Leg::updateGait(int gait_idx, int startMillis)
{
    Gait new_gait = all_gaits[gait_idx];
    gait = new_gait;
    theta_slow = new_gait.theta_s[id];
    theta_down = new_gait.theta_d[id];
    t_c = new_gait.t_cc[id];
    duty_factor = new_gait.duty_f[id];
    phase = new_gait.phases[id];
    kp = new_gait.kp;
    kd = new_gait.kd;
    updateGaitInternalParams(startMillis);
}

void Leg::updateGaitInternalParams(int startTime)
{
    float ground_spd;
    float recovery_spd;
    int t_s = round(t_c * duty_factor);

    if (gait.id == 5) {
        ground_speed = theta_slow / t_s;
        recovery_spd = -theta_slow / (t_c - t_s);

        thetas[0] = theta_down;
        ts[0] = 0;

        thetas[1] = theta_down - theta_slow/2;
        ts[1] = ts[0] + (thetas[1] - thetas[0]) / recovery_spd;

        thetas[2] = theta_down;
        ts[2] = ts[1] + (thetas[2] - thetas[1]) / ground_spd;

        thetas[3] = theta_down + theta_slow/2;
        ts[3] = ts[2] + (thetas[3] - thetas[2]) / ground_spd;

        thetas[4] = theta_down;
        ts[4] = t_c;
    }
    else //all walking gaits (and standing technically)
    {
        ground_spd = theta_slow / t_s;
        recovery_spd = (theta_circle - theta_slow) / (t_c - t_s);

        thetas[0] = theta_down - theta_circle + theta_up;
        ts[0] = 0;

        thetas[1] = theta_down - theta_slow/2;
        ts[1] = ts[0] + (thetas[1] - thetas[0]) / recovery_spd;

        thetas[2] = theta_down;
        ts[2] = ts[1] + (thetas[2] - thetas[1]) / ground_spd;

        thetas[3] = theta_down + theta_slow/2;
        ts[3] = ts[2] + (thetas[3] - thetas[2]) / ground_spd;

        thetas[4] = theta_down + theta_up;
        ts[4] = t_c;
    }
    startMillis = startTime;
    ground_speed = ground_spd;
    recovery_speed = recovery_spd;
}

void Leg::setPos(int new_pos) {
    desired_theta = new_pos;
}

void Leg::getDesiredVals(int t) { // handles phasing and start time, user provides get desired vals internal function
  int elapsed_time = t - startMillis;

  t = fmodf(elapsed_time + phase * t_c, t_c);

  getDesiredValsInternal(t);
}


void Leg::getDesiredValsInternal(int t) { // assume t has been adjusted for phasing

  int forward = gait.leg_dir[id];
  float theta;
  float velocity;

  if (t < ts[1]) {
    theta = thetas[0] + t * recovery_speed;
    velocity = recovery_speed;
  }
  else if (t < ts[2]) {
    theta = thetas[1] + (t - ts[1]) * ground_speed;
    velocity = ground_speed;
  }
  else if (t < ts[3]) {
    theta = thetas[2] + (t - ts[2]) * ground_speed;
    velocity = ground_speed;
  }
  else {
    theta = thetas[3] + (t - ts[3]) * recovery_speed;
    velocity = recovery_speed;
  }

  if (theta < theta_up - theta_circle) theta = theta_circle + theta;
  else if (theta >= theta_up) theta = -theta_circle + theta; // wrap thetas
  theta = theta * forward;
  velocity = velocity * forward;
  global_theta = theta;
  global_velocity = velocity;

}


int active_mini = 1;

/*
MODIFY THESE ARRAYS TO CONFIGURE ROBOT
(mini1 and mini2 are our two prototypes, ignore mini2 array if you're only using one robot)
be sure to set active_mini to 1 above
*/
float mini1Zeros[6] = {0, 0, 0, 0, 0, 0};
float mini2Zeros[6] = {0, 0, 0, 0, 0, 0};

int IDS[6] = {1, 2, 3, 4, 5, 6};

//////////////////////////////////////////

float *zeros = (active_mini == 1) ? mini1Zeros : mini2Zeros;

Leg fake_leg0(  0,    0, stand_gait,     0,    false, false, false); // this leg is a spacer in the array, only used to make each leg's index be equal to its number
Leg leg1     (1, 0, stand_gait, zeros[0], false, false, false);
Leg leg2     (2, 0, stand_gait, zeros[1], false, false, false);
Leg leg3     (3, 0, stand_gait, zeros[2], false, false, false);
Leg leg4     (4, 0, stand_gait, zeros[3],  true, false, false);
Leg leg5     (5, 0, stand_gait, zeros[4],  true, false, false);
Leg leg6     (6, 0, stand_gait, zeros[5],  true, false, false);

Leg legs[7] = {fake_leg0, leg1, leg2, leg3, leg4, leg5, leg6};
