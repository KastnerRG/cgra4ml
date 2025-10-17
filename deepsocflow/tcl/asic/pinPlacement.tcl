getPinAssignMode -pinEditInBatch -quiet
setPinAssignMode -pinEditInBatch true

editPin -fixOverlap 1 -unit MICRON -spreadDirection        clockwise -side Top    -layer 3 -spreadType center -spacing 1 -pin {aclk aresetn s_axis_weights_*}
editPin -fixOverlap 1 -unit MICRON -spreadDirection        clockwise -side Left   -layer 3 -spreadType center -spacing 1 -pin {s_axis_pixels_*}
editPin -fixOverlap 1 -unit MICRON -spreadDirection counterclockwise -side Right  -layer 3 -spreadType center -spacing 1 -pin {m_axis_*}

#-pinWidth 0.2 -pinDepth 0.6 

setPinAssignMode -pinEditInBatch false
getPinAssignMode -pinEditInBatch -quiet
setPinAssignMode -pinEditInBatch true


setPinAssignMode -pinEditInBatch false


legalizePin
checkPinAssignment
