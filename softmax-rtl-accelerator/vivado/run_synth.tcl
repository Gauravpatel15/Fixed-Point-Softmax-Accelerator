if {![info exists sm_root]} {error "Source create_project.tcl first"}
if {![info exists SM_SIM_OK] || !$SM_SIM_OK} {error "Run run_sim.tcl successfully before synthesis."}
catch {close_sim}
catch {close_design}
# Rerunning intentionally replaces this project's previous synthesis run.
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%" ||
    [string match -nocase "*error*" [get_property STATUS [get_runs synth_1]]]} {
    error "Synthesis failed; inspect the Vivado run log."
}
open_run synth_1
set report_dir [file join $sm_root reports [format "mode%d_n%d" $SM_MODE $SM_MAX_LEN]]
file mkdir $report_dir
report_utilization -hierarchical -file [file join $report_dir utilization.rpt]
report_timing_summary -report_unconstrained -file [file join $report_dir synthesis_timing.rpt]
report_drc -file [file join $report_dir synthesis_drc.rpt]
write_checkpoint -force [file join $report_dir synthesized.dcp]
puts "Reports saved in $report_dir"
puts "Timing is a post-synthesis estimate; no routed timing or power claim is made."
