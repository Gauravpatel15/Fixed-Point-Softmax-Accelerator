import math, random, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ONE=1<<24
C=(16776255,-11598197,3872139,-662425)

def coefficients():
    # Lagrange interpolation of 2^-f at four Chebyshev nodes on [0,1].
    nodes=[(1+math.cos((2*j+1)*math.pi/8))/2 for j in range(4)]
    result=[0.0]*4
    for j,x in enumerate(nodes):
        basis=[1.0]; den=1.0
        for k,y in enumerate(nodes):
            if k==j: continue
            nxt=[0.0]*(len(basis)+1)
            for n,b in enumerate(basis): nxt[n]-=y*b; nxt[n+1]+=b
            basis=nxt; den*=x-y
        for n,b in enumerate(basis): result[n]+=2**(-x)*b/den
    return tuple(round(x*ONE) for x in result)

def exponential(d,mode):
    if d==0: return ONE
    t=(d*94548)>>8; k=t>>16; f=t&65535
    if mode==0:
        y=C[2]+((C[3]*f)>>16)
        y=C[1]+((y*f)>>16)
        y=C[0]+((y*f)>>16)
    else:
        a=C[0]+((C[1]*f)>>16)
        b=C[2]+((C[3]*f)>>16)
        y=a+((b*((f*f)>>16))>>16)
    return max(0,min(ONE,y))>>k

def serial_reciprocal(den):
    if not den: return 0
    rem=0; q=0
    for step in range(48,-1,-1):
        rem=2*rem+(step==48)
        bit=rem>=den
        if bit: rem-=den
        q=((q<<1)|bit)&((1<<25)-1)
    return q

def softmax(scores,masks,mode):
    active=[x for x,m in zip(scores,masks) if not m]
    if not active: return [0]*len(scores)
    mx=max(active)
    e=[0 if m else exponential(mx-x,mode) for x,m in zip(scores,masks)]
    den=sum(e)
    reciprocal=(1<<48)//den
    assert serial_reciprocal(den)==reciprocal
    return [(x*reciprocal)>>24 for x in e]

def floating(scores,masks):
    a=[x for x,m in zip(scores,masks) if not m]
    if not a: return [0.0]*len(scores)
    mx=max(a); e=[0 if m else math.exp((x-mx)/256) for x,m in zip(scores,masks)]
    total=sum(e)
    return [x/total for x in e]

def main():
    (ROOT/"sim").mkdir(exist_ok=True)
    (ROOT/"reports").mkdir(exist_ok=True)
    assert coefficients()==C
    rng=random.Random(20261026)
    cases=[]
    def add(scores,masks=None,missing=False):
        cases.append((scores,masks if masks is not None else [0]*len(scores),missing))
    add([0]); add([123],[1]); add([0]*8); add([3072,2560,512])
    add([-32768,32767,0]); add([32767,-32768,123],[1,0,0])
    add([10,20,30],[1,1,1])
    for n in [2,3,7,31,64,129,257,512,1024,4096,8192,16384]:
        add([rng.randrange(-2048,2049) for _ in range(n)],
            [int(rng.random()<0.2) for _ in range(n)])
    add([0]*4096)
    add([0]*16384)
    add([0]*16384,missing=True)
    metrics={}
    for mode in [0,1]:
        ee=max(abs(exponential(d,mode)/ONE-math.exp(-d/256)) for d in range(65536))
        max_error=max_norm=0.0
        for scores,masks,missing in cases:
            fixed=softmax(scores,masks,mode); ref=floating(scores,masks)
            assert all(0<=p<=ONE for p in fixed)
            assert all(p==0 for p,m in zip(fixed,masks) if m)
            if not all(masks):
                max_norm=max(max_norm,abs(sum(fixed)/ONE-1))
                max_error=max(max_error,max(abs(p/ONE-q) for p,q in zip(fixed,ref)))
        assert ee<0.0001 and max_error<0.0002 and max_norm<0.002
        metrics["Horner" if mode==0 else "Estrin"]={
          "max_exponential_absolute_error_exhaustive_65536_differences":ee,
          "max_probability_absolute_error_test_rows":max_error,
          "max_sum_error_test_rows":max_norm}
    for den in [ONE,ONE+1,16384*ONE]+[rng.randrange(ONE,16384*ONE+1) for _ in range(10000)]:
        assert serial_reciprocal(den)==(1<<48)//den
    entries=[]
    for scores,masks,missing in cases:
        h=softmax(scores,masks,0); e=softmax(scores,masks,1)
        err=int(all(masks) or missing)
        for i,(s,m,hp,ep) in enumerate(zip(scores,masks,h,e)):
            end=int(i==len(scores)-1); last=end and not missing
            packed=(s&65535)|(m<<16)|(int(last)<<17)|(hp<<18)|(ep<<43)|(err<<68)|(end<<69)
            entries.append(packed)
    text="localparam integer VECTOR_COUNT=%d;\nlogic [69:0] vectors [0:VECTOR_COUNT-1];\ninitial begin\n"%len(entries)
    text+="".join("  vectors[%d]=70'h%018x;\n"%(i,v) for i,v in enumerate(entries))
    text+="end\n"
    (ROOT/"sim/vectors.svh").write_text(text)
    report={"status":"Python reference checks passed; RTL status is evaluated separately",
            "rows":len(cases),"tokens":len(entries),"metrics":metrics,
            "reference":"float Softmax on the same quantized input scores"}
    (ROOT/"reports/python_reference.json").write_text(json.dumps(report,indent=2))
    print(json.dumps(report,indent=2))
if __name__=="__main__": main()
