if {![info exists sm_root]} {error "Source create_project.tcl first"}
if {![info exists SM_SIM_OK] || !$SM_SIM_OK} {error "Run run_sim.tcl successfully first"}
if {[get_property PROGRESS [get_runs synth_1]] ne "100%" ||
    ![string match "*synth_design Complete*" [get_property STATUS [get_runs synth_1]]]} {
    error "Run run_synth.tcl successfully first"
}
if {[get_property NEEDS_REFRESH [get_runs synth_1]]} {
    error "Synthesis is stale. Rerun simulation and synthesis."
}
catch {close_design}
reset_run impl_1
launch_runs impl_1 -to_step route_design -jobs 2
wait_on_run impl_1
if {![string match "*route_design Complete*" [get_property STATUS [get_runs impl_1]]]} {
    error "Routing did not complete. Inspect the implementation log."
}
open_run impl_1
set report_dir [file join $sm_root reports [format "mode%d_n%d" $SM_MODE $SM_MAX_LEN] routed]
file mkdir $report_dir
report_utilization -hierarchical -file [file join $report_dir utilization.rpt]
report_timing_summary -delay_type min_max -report_unconstrained -max_paths 10 \
    -file [file join $report_dir timing.rpt]
report_drc -file [file join $report_dir drc.rpt]
report_methodology -file [file join $report_dir methodology.rpt]
write_checkpoint -force [file join $report_dir routed.dcp]
puts "Routed reports saved in $report_dir"
puts "Internal timing only: this project has no board pin or I/O delay constraints."
