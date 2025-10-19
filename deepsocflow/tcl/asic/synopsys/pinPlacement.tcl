set_individual_pin_constraints -nets {aclk aresetn} -pin_spacing_distance 2 -side 2 -offset {250 750}
set_individual_pin_constraints -nets {s_axis_weights_*} -pin_spacing_distance 2 -side 3 -offset {250 750}
set_individual_pin_constraints -nets {s_axis_pixels_*} -pin_spacing_distance 2 -side 2 -offset {150 350}
set_individual_pin_constraints -nets {m_axis_*}  -pin_spacing_distance 2 -side 1 -offset {350 550}

place_pins -self
