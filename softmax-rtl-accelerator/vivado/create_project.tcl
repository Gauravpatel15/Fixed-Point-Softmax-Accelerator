# Run in the Vivado Tcl console. This script never modifies the old project.
set sm_root [file normalize [file join [file dirname [info script]] ..]]
if {![info exists SM_PART]} {set SM_PART xczu7ev-ffvf1517-3-e}
if {![info exists SM_MODE]} {set SM_MODE 1}
if {![info exists SM_MAX_LEN]} {set SM_MAX_LEN 16384}
if {$SM_MODE ni {0 1}} {error "SM_MODE must be 0 (Horner) or 1 (Estrin)"}
if {![string is integer -strict $SM_MAX_LEN] || $SM_MAX_LEN < 1 || $SM_MAX_LEN > 16384} {
    error "Use SM_MAX_LEN from 1 through 16384. Larger sizes require a new precision review."
}
if {[llength [get_parts -quiet $SM_PART]] == 0} {
    error "Part $SM_PART is not installed. Install support for the selected device, or set SM_PART to an installed device."
}
set sm_project_dir [file join $sm_root build vivado]
set sm_xpr [file join $sm_project_dir softmax_research.xpr]
if {[llength [get_projects -quiet]] > 0} {
    if {[file normalize [get_property DIRECTORY [current_project]]] ne $sm_project_dir} {
        error "Another project is open. Save it, run close_project, then source this script again."
    }
} elseif {[file exists $sm_xpr]} {
    open_project $sm_xpr
} else {
    create_project softmax_research $sm_project_dir -part $SM_PART
}
set_property part $SM_PART [current_project]
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property target_simulator XSim [current_project]
set_property XPM_LIBRARIES {XPM_MEMORY} [current_project]
foreach name {softmax_pkg.sv poly_eval.sv exp_approx.sv reciprocal_q24.sv softmax_core.sv} {
    set path [file join $sm_root rtl $name]
    if {[llength [get_files -quiet $path]] == 0} {add_files -norecurse $path}
}
set_property top softmax_core [get_filesets sources_1]
set_property generic [list MAX_LEN=$SM_MAX_LEN MODE=$SM_MODE] [get_filesets sources_1]
set xdc [file join $sm_root constraints softmax.xdc]
if {[llength [get_files -quiet $xdc]] == 0} {add_files -fileset constrs_1 -norecurse $xdc}
foreach name {tb_softmax.sv vectors.svh} {
    set path [file join $sm_root sim $name]
    if {[llength [get_files -quiet $path]] == 0} {add_files -fileset sim_1 -norecurse $path}
}
set_property file_type {Verilog Header} [get_files [file join $sm_root sim vectors.svh]]
set_property include_dirs [list [file join $sm_root sim]] [get_filesets sim_1]
set_property top tb_softmax [get_filesets sim_1]
set_property generic {} [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
# Use standard project synthesis for broad Vivado-version compatibility.
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
set SM_SIM_OK 0
puts "READY: $SM_PART; MODE=$SM_MODE; MAX_LEN=$SM_MAX_LEN; 5 ns target."
puts "Next: source [file join $sm_root vivado run_sim.tcl]"
