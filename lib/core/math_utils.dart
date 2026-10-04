/// Typed clamps (num.clamp returns `num`, which needs casts at call sites).
double clampD(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);
int clampI(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);
