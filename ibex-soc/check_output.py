
from pathlib import Path

here = Path(__file__).resolve().parent
root = here.parent

log_path = here / "ibex_simple_system.log"
exp_path = root / "run" / "work" / "vectors" / "y_exp.txt"

# Parse lines like: y[2]: 1000/1000
nums = []  # list of (num, den, val)
with log_path.open() as f:
    for line in f:
        line = line.strip()
        if not line.startswith("y["):
            continue

        # line is like "y[2]: 1000/1000"
        # split by ':' to get the fraction part, then by '/'
        parts = line.split(":", 1)
        frac_part = parts[1].strip()          # "1000/1000"
        num_str, den_str = frac_part.split("/", 1)

        num = int(num_str.strip())
        den = int(den_str.strip())
        val = num // den                      # integer scaling
        nums.append((num, den, val))

# Expected outputs: one int per line
with exp_path.open() as f:
    exp_vals = [int(l.strip()) for l in f if l.strip()]

print("idx y_exp ibex_out")

n = min(len(nums), len(exp_vals))
all_match = True

for i in range(n):
    num, den, val = nums[i]
    exp_v = exp_vals[i]
    # zero-pad numerator to 4 digits (like 0000/1000, 1000/1000, -0006/1000)
    num_fmt = f"{num:04d}"
    print(f"{i}: {exp_v} --- {val} ({num_fmt}/{den})")
    if val != exp_v:
        all_match = False

# if lengths differ, treat as mismatch
if len(nums) != len(exp_vals):
    all_match = False

if all_match:
    print("ALL OUTPUTS MATCH!")
else:
    print("OUTPUTS DONT MATCH")
    raise RuntimeError("OUTPUTS DONT MATCH")
