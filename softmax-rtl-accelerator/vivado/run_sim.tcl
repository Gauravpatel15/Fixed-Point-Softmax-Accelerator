# A completed XSim process is not sufficient: require the testbench pass marker.
if {![info exists sm_root]} {error "Source create_project.tcl first"}
set SM_SIM_OK 0
catch {close_sim}
set sim_dir [file join [get_property DIRECTORY [current_project]] \
    "[get_property NAME [current_project]].sim" sim_1 behav xsim]
set sim_log [file join $sim_dir simulate.log]
# Preserve the old log and prevent it being mistaken for this run's result.
if {[file exists $sim_log]} {
    file rename $sim_log "${sim_log}.previous_[clock clicks]"
}
set_property xsim.simulate.runtime all [get_filesets sim_1]
launch_simulation -simset sim_1 -mode behavioral
if {![file exists $sim_log]} {error "Fresh simulation log not found: $sim_log"}
set fh [open $sim_log r]
set contents [read $fh]
close $fh
if {[regexp -nocase -line {^[ \t]*(fatal:|error:)} $contents]} {
    error "Simulation reported a failure. Inspect $sim_log"
}
if {![regexp -line {^ALL SOFTMAX RTL TESTS PASSED[ \t\r]*$} $contents]} {
    error "Testbench pass marker missing. Inspect $sim_log"
}
file mkdir [file join $sm_root reports]
file copy -force $sim_log [file join $sm_root reports rtl_simulation.log]
set SM_SIM_OK 1
puts "PASS: Testbench success verified in the fresh simulation log."
