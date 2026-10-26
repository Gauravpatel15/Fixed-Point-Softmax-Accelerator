# Results and evidence

## Provenance

The included report snapshots were produced in the user's Vivado 2024.2 run on
2026-10-26, using the Estrin core at capacity 16,384 and a 5 ns clock.
Host names and local project/tool paths were redacted; numeric report data was retained.
The XSim text is an excerpt from the supplied console log, not a new simulation run.
The RTL in this package is byte-identical to the working Desktop RTL at packaging time.
See `rtl_sha256.json` for file hashes.

The packaged Tcl scripts include release fixes: explicit XPM library setup,
fresh-log test-pass validation, and a reusable route/report script. These script
changes were checked separately; the historical reports predate their packaging.
Python numerical checks were rerun while creating this release. A new Vivado
simulation/implementation was not run during packaging.

## Main results

- Post-route: 483 LUTs, 325 FFs, 7 DSPs, 12 RAMB36 and 1 RAMB18.
- Timing: setup WNS +0.438 ns, hold WHS +0.028 ns, TNS/THS zero.
- Testbench: both modes passed 22 rows / 67,587 outputs each, including long rows,
  masks, backpressure and reset during loading.
- Historical post-route LUTRAM build: 10,801 LUTs, 581 FFs, no BRAM, 7 DSPs.
- LUT reduction: `(10801-483)/10801 = 95.53%`. Dedicated memory replaced LUT storage;
  this is not a claim of equivalent total silicon-area or energy reduction.
- Historical long-row test: length 16,384 took 16,444 or 16,445 cycles from last
  accepted input to first output in the supplied stalled tests. Both schedules
  show similar long-row results; no complete-Softmax speedup is established.

## Timing and DRC limitations

The clocked internal paths meet the stated constraint. The timing report explicitly
lists **21 input ports and 29 output ports without I/O delay constraints** (50 TIMING-18
warnings). Those boundaries require constraints from the eventual system integration.

DRC also lists NSTD-1 and UCIO-1 critical warnings because board I/O standards and
pin locations are not specified, plus DSP input/output pipeline warnings. Do not
suppress these to claim board readiness. The scripts stop at routing and do not
create a board bitstream. Actual FPGA board validation is outstanding.

The displayed Vivado power estimate is not used as an energy-efficiency result:
no workload activity-based power study or physical power measurement is included.

## Numerical limitations

`python_reference.json` evaluates floating-point Softmax on the same quantized
input scores. Its maxima are test-set observations, not formal worst-case guarantees.
No trained BERT/Qwen model integration, downstream accuracy evaluation, exact
unit-sum normalization guarantee, or published-baseline superiority is claimed.

## Evidence files

- `results/utilization.rpt`: routed BRAM build.
- `results/timing.rpt`: timing coverage, slacks and paths.
- `results/drc.rpt`: outstanding design-rule checks.
- `results/baseline_lutram_utilization.rpt`: earlier routed LUTRAM build.
- `results/xsim_test_excerpt.txt`: actual testbench console results.
- `results/python_reference.json`: freshly regenerated software numerical checks.
