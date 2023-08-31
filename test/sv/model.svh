localparam N_BUNDLES = 6;

Bundle_t bundles [N_BUNDLES] = '{
  '{ w_wpt:2304,  w_wpt_p0:2304,  x_wpt:416,  x_wpt_p0:416,  y_wpt:16,  y_wpt_last:96,  y_nl:4,  y_w:3,  n_it:8,  n_p:3 },
  '{ w_wpt:2160,  w_wpt_p0:2160,  x_wpt:832,  x_wpt_p0:832,  y_wpt:24,  y_wpt_last:96,  y_nl:4,  y_w:5,  n_it:6,  n_p:8 },
  '{ w_wpt:1536,  w_wpt_p0:576,  x_wpt:1248,  x_wpt_p0:416,  y_wpt:32,  y_wpt_last:96,  y_nl:4,  y_w:6,  n_it:4,  n_p:6 },
  '{ w_wpt:1152,  w_wpt_p0:288,  x_wpt:2080,  x_wpt_p0:416,  y_wpt:64,  y_wpt_last:128,  y_nl:4,  y_w:7,  n_it:3,  n_p:4 },
  '{ w_wpt:1152,  w_wpt_p0:720,  x_wpt:6240,  x_wpt_p0:3744,  y_wpt:192,  y_wpt_last:192,  y_nl:4,  y_w:8,  n_it:3,  n_p:2 },
  '{ w_wpt:384,  w_wpt_p0:264,  x_wpt:390,  x_wpt_p0:260,  y_wpt:192,  y_wpt_last:192,  y_nl:2,  y_w:1,  n_it:1,  n_p:427 }
};