# Arithmetic and dataflow

The stable reference is `p_i = exp(x_i - max(x)) / sum_j exp(x_j - max(x))`,
excluding masked entries from the maximum and sum.

## Fixed-point implementation

Inputs have eight fractional bits. For each active input, `d = max_raw - score_raw`
is a nonnegative 16-bit difference (formed first in 17 bits).

```
t = (d * 94548) >> 8
k = t >> 16
f = t & 65535
```

`94548` approximates `log2(e) * 2^16`. The exponential uses
`exp(-d/256) ~= 2^(-k) * P(f/65536)`. This range reduction approximates the
original natural exponential; it is not a direct replacement of exp(x) by 2^x.

Cubic coefficients with 24 fractional bits are:
`16776255, -11598197, 3872139, -662425`.
They interpolate `2^-u` at four Chebyshev nodes on [0,1]. They are not a newly
optimized minimax solution; the Python generator reconstructs them.

- Horner: `((c3*u+c2)*u+c1)*u+c0`, three registered polynomial stages.
- Estrin: `(c0+c1*u)+(c2+c3*u)*u^2`, two registered polynomial stages.
- Products truncate as specified in `softmax_pkg.sv`; Estrin also truncates its square to Q16.
- `d=0` explicitly returns 1. Outputs are clamped to [0,1] and shifted by `k`.
- The sum has `25 + clog2(MAX_LEN)` bits (39 at 16,384 entries).
- A shared restoring shift/subtract unit computes `floor(2^48 / sum_raw)`.
- Final output: `floor(exp_raw * reciprocal_raw / 2^24)`.

Zero denominator returns zero. Rounding means output probabilities need not sum
exactly to one; very small values may underflow.

## Storage and scheduling

The XPM simple dual-port memory has 25-bit words and one-cycle synchronous reads.
It stores scores/masks during loading, then each consumed location is overwritten
with its exponential. During output, it is read again for reciprocal scaling.
The default logical capacity is 409,600 bits (50 KiB). BRAM allocation includes
physical packing overhead: the measured build uses 12 RAMB36 plus one RAMB18.

One polynomial lane is reused across the row and one reciprocal is calculated
per nonzero row sum. Approximate no-stall complete row cost is `3*N + 49 + overhead`
clock cycles, with the zero-denominator case shorter. The testbench's reported
row totals include intentional gaps/stalls and must not be advertised as peak throughput.
Polynomial pipeline depth alone does not determine full-row latency.

## Portability

The arithmetic and controller are SystemVerilog. The explicit row memory uses
AMD XPM and requires a vendor-memory replacement for another FPGA family or ASIC.
No AMD library implementation is redistributed here.
