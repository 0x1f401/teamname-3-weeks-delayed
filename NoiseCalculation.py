import sys
import re
from pathlib import Path
import opensimplex
import numpy as np

# -------------------------
# Parsing
# -------------------------

def parse_env_lp(path):
    text = Path(path).read_text(encoding="utf-8")
    text = re.sub(r"%.*", "", text)

    # global(T).
    m = re.search(r"\bglobal\s*\(\s*(\d+)\s*\)\s*\.", text)
    global_t = int(m.group(1)) if m else 400

    # cell(X,Y,Tr).
    cells = list()
    for m in re.finditer(r"\bcell\s*\(\s*\(\s*(-?\d+)\s*,\s*(-?\d+)\s*\)\s*,\s*(-?\d+)\s*\)\s*\.",text):
        x, y, tr = map(int, m.groups())
        cells.append((x, y))

    if not cells:
        raise RuntimeError("No active cell(X,Y,Tr!=0). facts found")

    return global_t, cells


# -------------------------
# Hash + mu logic 
# -------------------------


#opensimplex.noise3array(np.array(range(x)/n),np.array(range(x)/n),np.array(range(t)/m)) = matrix
#zusätzlicher eingabewert für Teiler von position (n) and time (m)
#matrix *21 (evtl. Wert bei user) /1 
#Rundung durch die 1 :D
#for t in range(t) for y in range (y) for x in range (x) mu_facts.append((x, y, t, test[t][y][x], MUd)

def compute_mu(cells, T_max,nRaum,tTime):
    mu_facts = []
    x,y=cells[-1]
    muMatrix=opensimplex.noise3array((np.array(range(x))/nRaum),(np.array(range(y))/nRaum),(np.array(range(T_max))/tTime))
    muMatrix=(((muMatrix+1)*10//1)+1)
    print(muMatrix)
    MUd=1000

    for t1 in range(T_max):
        for y1 in range(y):
            for x1 in range (x):
                mu_facts.append((x1, y1, t1, muMatrix[t1][y1][x1], MUd))
    return mu_facts


# -------------------------
# Main
# -------------------------

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 NoiseCalculation.py env.lp")
        sys.exit(1)

    env_path = sys.argv[1]
    try:
        nRaum=int(sys.argv[2])
        tTime=int(sys.argv[3])
    
    except:
        print("the second and third argument must be Integers")
        sys.exit(1)
    
    
    global_t, cells = parse_env_lp(env_path)

    mu_facts = compute_mu(cells, global_t,nRaum,tTime)

    out_path = Path(env_path).with_name(
        Path(env_path).stem + "_mu.lp"
    )

    with out_path.open("w", encoding="utf-8") as f:
        for x, y, t, num, den in mu_facts:
            num=int(num)
            f.write(f"mu({x},{y},{t},{num},{den}).\n")

    print(f"Wrote {len(mu_facts)} mu-facts to {out_path}")


if __name__ == "__main__":
    main()