#!/usr/bin/env python3
"""Compute 96 kHz re-voiced constants for Audio-Lab-PYNQ DSP.

Strategy: every fs-normalised constant is recomputed so the AUDIBLE voicing
(corner Hz, biquad centre Hz, time constants) is preserved when fs doubles
48k -> 96k. Validates the RBJ + one-pole formulas against the existing 48k
coefficients first, then re-emits at 96k.
"""
import math

FS48 = 48000.0
FS96 = 96000.0

def rbj_peak(f0, Q, dB, fs):
    """RBJ peaking EQ, a0-normalised, scaled by 2^14, rounded.
    Returns (b0,b1,b2,a1,a2) as ints (a1,a2 are the normalised RBJ values,
    matching the code convention `y = (b0x+b1x1+b2x2 - a1y1 - a2y2)>>14`)."""
    A = 10**(dB/40.0)
    w0 = 2*math.pi*f0/fs
    cw = math.cos(w0); sw = math.sin(w0)
    alpha = sw/(2*Q)
    b0 = 1 + alpha*A
    b1 = -2*cw
    b2 = 1 - alpha*A
    a0 = 1 + alpha/A
    a1 = -2*cw
    a2 = 1 - alpha/A
    s = 16384.0
    r = lambda v: int(round(v/a0*s))
    return r(b0), r(b1), r(b2), r(a1), r(a2)

def show_biquad(name, f0, Q, dB):
    c48 = rbj_peak(f0,Q,dB,FS48)
    c96 = rbj_peak(f0,Q,dB,FS96)
    print(f"--- {name}: f0={f0} Q={Q} {dB:+}dB")
    print(f"    48k b0,b1,b2,a1,a2 = {c48}")
    print(f"    96k b0,b1,b2,a1,a2 = {c96}")
    return c96

print("="*70)
print("BIQUADS (RBJ peaking, Q14, a0-normalised)")
print("="*70)
show_biquad("tubeScreamerMid / odMid TS9", 720, 0.8, +6)
show_biquad("bigMuffScoop", 700, 0.8, -10)
show_biquad("ampScoop Fender (idx0/1)", 400, 0.7, -5)
show_biquad("ampScoop AC30 (idx2)", 2200, 1.0, +4)
show_biquad("ampScoop JCM800 (idx4)", 650, 0.8, +4)
show_biquad("ampXfmrRes", 110, 0.8, +2)
show_biquad("odMid BD-2 (idx2)", 1500, 0.7, +3)

print()
print("="*70)
print("ONE-POLE (onePoleU8 alpha, Q8) bilinear: a2 = 1 - sqrt(1-a)")
print("="*70)
def a2(alpha48):
    a = alpha48/256.0
    if a >= 1: a = 0.999999
    return 256.0*(1-math.sqrt(1-a))

def fit_var(name, base, shift, expr=""):
    """alpha = base + (byte>>shift) over byte in 0..255.
    Refit new base' + (byte>>shift') so corner Hz preserved at both ends."""
    amin = base
    amax = base + (255>>shift)
    nmin = a2(amin)
    nmax = a2(amax)
    base2 = int(round(nmin))
    span = nmax - nmin
    # choose shift' so 255>>shift' ~= span
    best=None
    for s in range(0,9):
        got = 255>>s
        err = abs(got-span)
        if best is None or err<best[0]:
            best=(err,s,got)
    s2=best[1]
    print(f"  {name}: alpha48 = {base}+(b>>{shift})  range[{amin}..{amax}]Hz-equiv")
    print(f"     corner Hz @48k: min {fc(amin,FS48):.0f}..max {fc(amax,FS48):.0f}")
    print(f"     target alpha96 min {nmin:.1f} max {nmax:.1f} (span {span:.1f})")
    print(f"     -> base96={base2} shift96={s2} (gives {base2}..{base2+(255>>s2)})")
    print(f"     check corner Hz @96k: min {fc(base2,FS96):.0f}..max {fc(base2+(255>>s2),FS96):.0f}")
    return base2, s2

def fc(alpha, fs):
    a=alpha/256.0
    if a<=0: return 0
    if a>=1: a=0.999999
    return -fs/(2*math.pi)*math.log(1-a)

def show_const_alpha(name, alpha):
    n=a2(alpha)
    print(f"  {name}: alpha48={alpha} (fc {fc(alpha,FS48):.0f}Hz) -> alpha96={int(round(n))} (fc {fc(int(round(n)),FS96):.0f}Hz @96k)")

print("# variable-alpha LPF/HPF (base + byte>>shift):")
fit_var("tubeScreamerHpf", 4, 4)
fit_var("tubeScreamerPostLpf", 56, 1)
fit_var("metalHpf", 8, 3)
fit_var("metalPostLpf", 40, 1)
fit_var("ds1Hpf", 5, 4)
fit_var("ds1Tone", 104, 1)
fit_var("bigMuffTone", 48, 1)
fit_var("fuzzFaceTone", 80, 1)
print("# const / special:")
show_const_alpha("ratPostLowpass", 168)
# ratOpAmp alpha = 184 - (drive>>1): decreasing. handle endpoints.
print("  ratOpAmpLowpass alpha48 = 184-(drive>>1) range[57..184]")
print(f"     -> alpha96 endpoints: drive0 184->{int(round(a2(184)))}, drive255 57->{int(round(a2(57)))}")
print("  ratTone alpha48 = 192-dark, dark up to ~191 -> alpha96 endpoints:")
print(f"     192->{int(round(a2(192)))}, 1->{int(round(a2(1)))}")
print("  ampPreLowpass baseAlpha=128+(char>>2) minus darken; per-model, endpoints:")
for ch,nm in [(18,'JC120'),(78,'Twin'),(166,'AC30'),(208,'Rock'),(220,'JCM'),(246,'Tri')]:
    base=128+(ch>>2)
    print(f"     {nm}: baseAlpha48={base} -> {int(round(a2(base)))}")

print()
print("="*70)
print("HP one-pole coeff (a*prevOut>>8): widen to >>9 for lower corner at 96k")
print("="*70)
def hp_corner(coef, shiftbits, fs):
    a = coef/(2**shiftbits)
    return fs*(1-a)/(2*math.pi)
for coef,nm in [(253,'ampHighpass'),(255,'ratHighpass')]:
    c48 = hp_corner(coef,8,FS48)
    # want same corner at 96k with >>9 coeff: a' = 1 - 2*pi*fc/fs96
    target = c48
    a9 = 1 - 2*math.pi*target/FS96
    coef9 = int(round(a9*512))
    print(f"  {nm}: {coef}/256 -> corner {c48:.1f}Hz @48k; "
          f"96k >>9 coeff={coef9}/512 -> {hp_corner(coef9,9,FS96):.1f}Hz")

print()
print("="*70)
print("WAH SVF f-byte map (f_coef ~ 2*sin(pi*f0/fs)); halve for 2x fs")
print("="*70)
# basePositionToFByte anchors 15/24/37/53/73 at 48k; f_coef = byte/256
# f0 from f_coef = 2 sin(pi f0/fs) -> f0 = fs/pi * asin(fcoef/2)
for byte in [15,24,37,53,73]:
    fcoef=byte/256.0
    f0_48 = FS48/math.pi*math.asin(min(0.999,fcoef/2))
    # new byte to keep f0 at 96k:
    newcoef = 2*math.sin(math.pi*f0_48/FS96)
    nb=newcoef*256
    print(f"  byte48={byte} -> f0 {f0_48:.0f}Hz -> byte96={nb:.1f} (~{int(round(nb))})")

print()
print("="*70)
print("ampPreLowpass tables (recompute baseAlpha/modelDarken/driveDarken @96k)")
print("="*70)
# model: (char, modelDarken48, driveDarken48)
models = [
 (0,'JC120',18,0,6),(1,'Twin',78,3,8),(2,'AC30',166,3,12),
 (3,'Rock',208,18,20),(4,'JCM',220,10,20),(5,'Tri',246,26,30)]
# choose a base formula baseAlpha96 = B0 + (char>>2); pick B0 so all darken>=0
def a2(alpha48):
    a=alpha48/256.0
    if a>=1:a=0.999999
    return 256.0*(1-math.sqrt(1-a))
clean96={}; drive96={}
for idx,nm,char,md,dd in models:
    base48=128+(char>>2)
    ca48=base48-md
    da48=ca48-dd
    clean96[idx]=a2(ca48)
    drive96[idx]=a2(da48)
B0=80
print(f"baseAlpha96 = {B0} + (char>>2)")
print("idx name  base96  clean96  drive96  ->  modelDarken96  driveDarken96")
for idx,nm,char,md,dd in models:
    base96=B0+(char>>2)
    mdk=base96-round(clean96[idx])
    ddk=round(clean96[idx])-round(drive96[idx])
    print(f" {idx}  {nm:5} {base96:4d}   {clean96[idx]:5.1f}   {drive96[idx]:5.1f}  ->  {mdk:4d}          {ddk:4d}")
