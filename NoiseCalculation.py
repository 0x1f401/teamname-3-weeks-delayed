import sys
import re
from pathlib import Path

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
    cells = set()
    for m in re.finditer(r"\bcell\s*\(\s*\(\s*(-?\d+)\s*,\s*(-?\d+)\s*\)\s*,\s*(-?\d+)\s*\)\s*\.",text):
        x, y, tr = map(int, m.groups())
        if tr != 0:
            cells.add((x, y))

    if not cells:
        raise RuntimeError("No active cell(X,Y,Tr!=0). facts found")

    return global_t, cells


# -------------------------
# Hash + mu logic (ASP-faithful)
# -------------------------

def asp_hash(x, y, t):
    # H = |X + (Y * 16) + (T * 256) * 2654435761| / 128
    val = abs(x + (y * 16) + (t * 256)) * 2654435761
    return val // 128


def compute_mu(cells, T_max):
    mu_facts = []

    for t in range(T_max + 1):
        for (x, y) in cells:
            M = 0
            for (xp, yp) in cells:
                D = abs(xp - x) + abs(yp - y)
                if D < 5:
                    H = asp_hash(xp, yp, t)
                    M += H // (D + 1)

            MUn = M // 200000
            MUd = 1000
            mu_facts.append((x, y, t, MUn, MUd))

    return mu_facts


# -------------------------
# Main
# -------------------------

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 gen_mu.py env_xx.lp")
        sys.exit(1)

    env_path = sys.argv[1]
    global_t, cells = parse_env_lp(env_path)

    mu_facts = compute_mu(cells, global_t)

    out_path = Path(env_path).with_name(
        Path(env_path).stem + "_mu.lp"
    )

    with out_path.open("w", encoding="utf-8") as f:
        for x, y, t, num, den in mu_facts:
            f.write(f"mu({x},{y},{t},{num},{den}).\n")

    print(f"Wrote {len(mu_facts)} mu-facts to {out_path}")


if __name__ == "__main__":
    main()