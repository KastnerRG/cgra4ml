set_individual_pin_constraints -nets {aclk aresetn s_axis_pixels_*} -pin_spacing_distance 0.1 -side 2 -offset {70 170} -allowed_layers {M5 M7 M9}
set_individual_pin_constraints -nets {s_axis_weights_*} -pin_spacing_distance 0.1 -side 3 -offset {70 170} -allowed_layers {M4 M6 M8}
set_individual_pin_constraints -nets {m_axis_*}         -pin_spacing_distance 0.1 -side 1 -offset {70 170} -allowed_layers {M4 M6 M8}

place_pins -self