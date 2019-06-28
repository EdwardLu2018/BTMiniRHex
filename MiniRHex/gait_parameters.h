#ifndef gait_parameters
#define gait_parameters

#define NUM_GAITS 6

typedef struct gait_container Gait;

struct gait_container{
  int id;
  float theta_s[7];
  float theta_d[7];
  int leg_dir[7];
  int t_cc[7];
  float duty_f[7];
  float phases[7];
  float kp;
  float kd;
};

extern Gait all_gaits[NUM_GAITS];
extern Gait stand_gait;
extern Gait walk_gait;
extern Gait backward_gait;
extern Gait right_gait;
extern Gait left_gait;
extern Gait pronk_gait;

#endif
