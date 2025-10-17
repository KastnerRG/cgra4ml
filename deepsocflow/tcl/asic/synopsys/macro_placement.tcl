
#relative floorplan

delete_relative_floorplan -all
create_relative_floorplan  -ref_type core_boundary -horizontal_edge_separate {1 -350 1} -vertical_edge_separate {1 80 1} -place PIXELS_RAM_genblk1_0__RAME -orient {R180}
#create_relative_floorplan  -ref_type object -horizontal_edge_separate {3 250 1} -vertical_edge_separate {3 200 3} -place PIXELS_RAM_genblk1_1__RAME -ref PIXELS_RAM_genblk1_0__RAME
#create_relative_floorplan  -ref_type object -horizontal_edge_separate {3 250 1} -vertical_edge_separate {3 200 3} -place PIXELS_RAM_genblk1_2__RAME -ref PIXELS_RAM_genblk1_1__RAME

create_relative_floorplan  -ref_type core_boundary -horizontal_edge_separate {1 -50 1} -vertical_edge_separate {1 60 1} -place WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_0__RAMW -orient {R90}
create_relative_floorplan  -ref_type object -horizontal_edge_separate {3 85 1} -vertical_edge_separate {1 120 1} -place WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_1__RAMW -ref WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_0__RAMW -orient {R90}
create_relative_floorplan  -ref_type object -horizontal_edge_separate {3 85 1} -vertical_edge_separate {1 120 1} -place WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_2__RAMW -ref WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_1__RAMW -orient {R90}
create_relative_floorplan  -ref_type object -horizontal_edge_separate {3 85 1} -vertical_edge_separate {1 120 1} -place WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_3__RAMW -ref WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_2__RAMW -orient {R90}
create_relative_floorplan  -ref_type object -horizontal_edge_separate {3 85 1} -vertical_edge_separate {1 120 1} -place WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_4__RAMW -ref WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_3__RAMW -orient {R90}
create_relative_floorplan  -ref_type object -horizontal_edge_separate {3 85 1} -vertical_edge_separate {1 120 1} -place WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_5__RAMW -ref WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_4__RAMW -orient {R90}
create_relative_floorplan  -ref_type object -horizontal_edge_separate {3 85 1} -vertical_edge_separate {1 120 1} -place WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_6__RAMW -ref WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_5__RAMW -orient {R90}
create_relative_floorplan  -ref_type object -horizontal_edge_separate {3 85 1} -vertical_edge_separate {1 120 1} -place WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_7__RAMW -ref WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_6__RAMW -orient {R90}
create_relative_floorplan  -ref_type object -horizontal_edge_separate {3 85 1} -vertical_edge_separate {1 120 1} -place WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_8__RAMW -ref WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_7__RAMW -orient {R90}
create_relative_floorplan  -ref_type object -horizontal_edge_separate {3 85 1} -vertical_edge_separate {1 120 1} -place WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_9__RAMW -ref WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_8__RAMW -orient {R90}
create_relative_floorplan  -ref_type object -horizontal_edge_separate {3 85 1} -vertical_edge_separate {1 120 1} -place WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_10__RAMW -ref WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_9__RAMW -orient {R90}
create_relative_floorplan  -ref_type object -horizontal_edge_separate {3 85 1} -vertical_edge_separate {1 120 1} -place WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_11__RAMW -ref WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_10__RAMW -orient {R90}

#create_relative_floorplan  -ref_type object -horizontal_edge_separate {3 85 1} -vertical_edge_separate {1 100 1} -place WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_4__RAMW -ref WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_4__RAMW
#create_relative_floorplan  -ref_type object -horizontal_edge_separate {3 85 1} -vertical_edge_separate {1 100 1} -place WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_5__RAMW -ref WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_4__RAMW
#create_relative_floorplan  -ref_type object -horizontal_edge_separate {3 85 1} -vertical_edge_separate {1 100 1} -place WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_5__RAMW -ref WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_5__RAMW


create_relative_floorplan  -ref_type core_boundary -horizontal_edge_separate {1 -200 1} -vertical_edge_separate {1 60 1} -place WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_0__RAMW -orient {R90}
create_relative_floorplan  -ref_type object -horizontal_edge_separate {3 85 1} -vertical_edge_separate {1 120 1} -place WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_1__RAMW -ref WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_0__RAMW -orient {R90}
create_relative_floorplan  -ref_type object -horizontal_edge_separate {3 85 1} -vertical_edge_separate {1 120 1} -place WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_2__RAMW -ref WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_1__RAMW -orient {R90}
create_relative_floorplan  -ref_type object -horizontal_edge_separate {3 85 1} -vertical_edge_separate {1 120 1} -place WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_3__RAMW -ref WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_2__RAMW -orient {R90}
create_relative_floorplan  -ref_type object -horizontal_edge_separate {3 85 1} -vertical_edge_separate {1 120 1} -place WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_4__RAMW -ref WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_3__RAMW -orient {R90}
create_relative_floorplan  -ref_type object -horizontal_edge_separate {3 85 1} -vertical_edge_separate {1 120 1} -place WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_5__RAMW -ref WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_4__RAMW -orient {R90}
create_relative_floorplan  -ref_type object -horizontal_edge_separate {3 85 1} -vertical_edge_separate {1 120 1} -place WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_6__RAMW -ref WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_5__RAMW -orient {R90}
create_relative_floorplan  -ref_type object -horizontal_edge_separate {3 85 1} -vertical_edge_separate {1 120 1} -place WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_7__RAMW -ref WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_6__RAMW -orient {R90}
create_relative_floorplan  -ref_type object -horizontal_edge_separate {3 85 1} -vertical_edge_separate {1 120 1} -place WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_8__RAMW -ref WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_7__RAMW -orient {R90}
create_relative_floorplan  -ref_type object -horizontal_edge_separate {3 85 1} -vertical_edge_separate {1 120 1} -place WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_9__RAMW -ref WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_8__RAMW -orient {R90}
create_relative_floorplan  -ref_type object -horizontal_edge_separate {3 85 1} -vertical_edge_separate {1 120 1} -place WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_10__RAMW -ref WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_9__RAMW -orient {R90}
create_relative_floorplan  -ref_type object -horizontal_edge_separate {3 85 1} -vertical_edge_separate {1 120 1} -place WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_11__RAMW -ref WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_10__RAMW -orient {R90}

#create_place_halo -halo_delatas {5 5 5 5} -insts PIXELS_RAM_genblk1_0__RAME
#create_place_halo -halo_delatas {5 5 5 5} -insts PIXELS_RAM_genblk1_1__RAME
#create_place_halo -halo_delatas {5 5 5 5} -insts PIXELS_RAM_genblk1_2__RAME

#create_place_halo -halo_delatas {5 5 5 5} -insts WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_0__RAMW
#create_place_halo -halo_delatas {5 5 5 5} -insts WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_1__RAMW
#create_place_halo -halo_delatas {5 5 5 5} -insts WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_2__RAMW
#create_place_halo -halo_delatas {5 5 5 5} -insts WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_3__RAMW
#create_place_halo -halo_delatas {5 5 5 5} -insts WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_4__RAMW
#create_place_halo -halo_delatas {5 5 5 5} -insts WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_5__RAMW
#create_place_halo -halo_delatas {5 5 5 5} -insts WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_6__RAMW
#create_place_halo -halo_delatas {5 5 5 5} -insts WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_7__RAMW
#create_place_halo -halo_delatas {5 5 5 5} -insts WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_8__RAMW
#create_place_halo -halo_delatas {5 5 5 5} -insts WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_9__RAMW
#create_place_halo -halo_delatas {5 5 5 5} -insts WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_10__RAMW
#create_place_halo -halo_delatas {5 5 5 5} -insts WEIGHTS_ROTATOR_genblk1_0__BRAM_BRAM_genblk1_11__RAMW

#create_place_halo -halo_delatas {5 5 5 5} -insts WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_0__RAMW
#create_place_halo -halo_delatas {5 5 5 5} -insts WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_1__RAMW
#create_place_halo -halo_delatas {5 5 5 5} -insts WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_2__RAMW
#create_place_halo -halo_delatas {5 5 5 5} -insts WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_3__RAMW
#create_place_halo -halo_delatas {5 5 5 5} -insts WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_4__RAMW
#create_place_halo -halo_delatas {5 5 5 5} -insts WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_5__RAMW
#create_place_halo -halo_delatas {5 5 5 5} -insts WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_6__RAMW
#create_place_halo -halo_delatas {5 5 5 5} -insts WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_7__RAMW
#create_place_halo -halo_delatas {5 5 5 5} -insts WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_8__RAMW
#create_place_halo -halo_delatas {5 5 5 5} -insts WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_9__RAMW
#create_place_halo -halo_delatas {5 5 5 5} -insts WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_10__RAMW
#create_place_halo -halo_delatas {5 5 5 5} -insts WEIGHTS_ROTATOR_genblk1_1__BRAM_BRAM_genblk1_11__RAMW

