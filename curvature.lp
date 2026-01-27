% opposite cardinal directions
opp(n, s). opp(w, e).
opp(D0, D1) :- opp(D1, D0).

% curves (valid parts)
% use on nextdirt: nextdirt(X, Y, D1, D2) :- cell((X, Y), Tr), curve(C, D3, D2), Tr & C = C, opp(D1, D3).
curve(4608, w, s). % 4096 + 512:  1001000000000
curve(16386, e, s). % 16384  2: 100000000000010
curve(2064, w, n). % 2048 + 16:    100000010000
curve(72, e, n). % 64 + 8:               101000
curve(C, D0, D1) :- curve(C, D1, D0).

% straights (valid parts)
straight(32800, n, s).
straight(1025, e, w).
straight(S, D0, D1) :- straight(S, D1, D0). % fixed typo; retry old?

% single recursion movement step
step(DX, DY) :- DX=-1..1, DY=-1..1, |DX|+|DY|=1.

% Entire section: FIXME doesn't check track connectivity (will travel up stacked horizontals)
% extensions ext(Part, X, Y, Dir, DX, DY): curve Part, pos X,Y, startdir Dir, end DX,DY
% parts: use max to get ext
extpart(Part, X, Y, Dir, Dir1', 0, 0) :- curve(Part, Dir, Dir1), opp(Dir1, Dir1'), cell((X, Y), Tr), Tr & Part = Part.
% --- old curvature calculation ---
% main error: DX+DDX needs to be X+DX+DDX
% follow straights (works?)
%extpartm(Part, X, Y, Dir, DX+DDX, DY+DDY) :- extpartm(Part, X, Y, Dir, DX, DY), step(DDX, DDY), cell((X+DX+DDX, Y+DY+DDY), Tr), straight(S, Dir, _), Tr & S = S.
% follow different curves (broken; connect to previous, not first!)
%extpartm(Part, X, Y, Dir, DX+DDX, DY+DDY) :- extpartm(Part, X, Y, Dir, DX, DY), step(DDX, DDY), cell((X+DX+DDX, Y+DY+DDY), Tr), curve(C, Dir', _), opp(Dir, Dir'), Tr & C = C, C != Part.
% take final step to similar curve (broken?)
%extpartf(Part, X, Y, Dir, DX+DDX, DY+DDY) :- extpartm(Part, X, Y, Dir, DX, DY), step(DDX, DDY), cell((X+DX+DDX, Y+DY+DDY), Tr), Tr & Part = Part.
% --- old curvature calc end ---
% new approach: travel along until hitting same
% only restriction: don't travel back or hit same (not current!)
% probably doesn't distinguish between 
extpart(Part, X, Y, Dir0, Dir1, DX+DDX, DY+DDY) :- 
    extpart(Part, X, Y, Dir0, Dir, DX, DY), truenext(X+DX, Y+DY, _, Dir, Dir1), dir(Dir1, DDX, DDY), % connected
    DX * DX + DY * DY <= 25, % prevent too long curves (and overflows)
    not opp(Dir0, Dir1), % no going back
    1 {Dir != Dir1; Dir = Dir0} 2, % not going straight away: Dir = Dir1 != Dir0, negated: D != D1 | D = D0 FIXME: still goes 1 too far
    cell((X+DX, Y+DY), Tr), (Tr & Part) * (1 - 0 ** (|DX|+|DY|)) != Part. % until similar, not same
% combine extpart types
%extpart(Part, X, Y, Dir, DX, DY) :- extpartm(Part, X, Y, Dir0, Dir, DX, DY).
%extpart(Part, X, Y, Dir, DX, DY) :- extpartf(Part, X, Y, Dir, DX, DY).
% extension with intervals [DXn, DXp] and [DYn, DYp]
extint(Part, X, Y, Dir, DXn, DXp, DYn, DYp) :- extpart(Part, X, Y, Dir, _, _, _), 
    DXp = #max{DX' : extpart(Part, X, Y, Dir, _, DX', _)}, DXn = #min{DX' : extpart(Part, X, Y, Dir, _, DX', _)},
    DYp = #max{DY' : extpart(Part, X, Y, Dir, _, _, DY')}, DYn = #min{DY' : extpart(Part, X, Y, Dir, _, _, DY')}.
% get abs-max coords
ext(Part, X, Y, Dir, DXn, DYn) :- extint(Part, X, Y, Dir, DXn, DXp, DYn, DYp), -DXn >= DXp, -DYn >= DYp.
ext(Part, X, Y, Dir, DXn, DYp) :- extint(Part, X, Y, Dir, DXn, DXp, DYn, DYp), -DXn >= DXp, -DYn <= DYp.
ext(Part, X, Y, Dir, DXp, DYn) :- extint(Part, X, Y, Dir, DXn, DXp, DYn, DYp), -DXn <= DXp, -DYn >= DYp.
ext(Part, X, Y, Dir, DXp, DYp) :- extint(Part, X, Y, Dir, DXn, DXp, DYn, DYp), -DXn <= DXp, -DYn <= DYp.

% curvature
% continuous: κ = ||g"(s)|| = d²g/ds²
% as discrete: dg/ds → Δg/Δs from ext
% Δ²g/Δs²: add normalized extensions (creates vector pointing into curve)
curvaturedir(X, Y, Part, DX, DY) :- curve(Part, Dir0, Dir1), ext(Part, X, Y, Dir0, DX1, DY1), ext(Part, X, Y, Dir1, DX2, DY2),
    D1 = |DX1| + |DY1|, D2 = |DX2| + |DY2|,
    DX = DX1 / D1 + DX2 / D2, DY = DY1 / D1 + DY2 / D2. % FIXME: switch to fixed point or rationals
% curvature: get length
curvature(X, Y, Part, C) :- curvaturedir(X, Y, Part, DX, DY), C = |DX| + |DY|. % using manhattan distance for simplicity

% mu: friction coefficient (change to suit weather, will be affected by noise?)
%hash(X, Y, T, H) :- cell((X, Y), Tr), Tr != 0, time(T), H = |X + (Y * 16) + (T * 256) * 2654435761| / 128. % hash, leave 8 bits for addition
%mu(X, Y, T, MUn, MUd) :- hash(X, Y, T, _),
%    M = #sum {N : hash(X', Y', T, H), D = |X'-X|+|Y'-Y|, D < 5, N = H / (D+1)}, 
%    MUn = M / 200000, MUd = 1000. % max: 0x00ffffff * (1 + 4/2 + 8/3 + 12/4 + 16/5) ≈ 2·10⁸
%mu(1, 1).
% g: fit to tile size
g(1000, 1).

% allowed speed
allowed(X, Y, Part, V) :- ext(Part, X, Y, Dir0, DX0, DY0), ext(Part, X, Y, Dir1, DX1, DY1), curve(Part, Dir0, Dir1),
    V=1..40, mu(X, Y, 1, MUn, MUd), g(Gn, Gd), % n: numerator, d: denominator
    (DX0**2+DY0**2) * (DX1**2+DY1**2) * (4*V**4*MUn*Gn - 2*MUd*Gd) ** 2 >= MUd**2 * Gd**2 * 4 * (DX0*DX1 + DY0*DY1) ** 2,
    (V**4 * MUn * Gn - 2 * MUd * Gd) > 0, % derivative; ensure V is on rising part
    DX0*DX1 + DY0+DY1 > 0. % fix square
allowed(X, Y, Part, V) :- ext(Part, X, Y, Dir0, DX0, DY0), ext(Part, X, Y, Dir1, DX1, DY1), curve(Part, Dir0, Dir1),
    V=1..40, mu(X, Y, 1, MUn, MUd), g(Gn, Gd), % n: numerator, d: denominator
    (DX0**2+DY0**2) * (DX1**2+DY1**2) * (4*V**4*MUn*Gn - 2*MUd*Gd) ** 2 <= MUd**2 * Gd**2 * 4 * (DX0*DX1 + DY0*DY1) ** 2,
    (V**4 * MUn * Gn - 2 * MUd * Gd) < 0, % derivative; ensure V is on rising part
    DX0*DX1 + DY0+DY1 < 0.
allowed(X, Y, Part, 4..5) :- cell((X, Y), Tr), curve(Part, _, _), Tr & Part = Part.
allowed(X, Y, Part, N..5) :- allowed(X, Y, Part, N).

highnum(N) :- ext(Part, X, Y, Dir0, DX0, DY0), ext(Part, X, Y, Dir1, DX1, DY1), curve(Part, Dir0, Dir1),
    V=1..4, mu(X, Y, 1, MUn, MUd), g(Gn, Gd), % n: numerator, d: denominator
    N = (DX0**2+DY0**2) * (DX1**2+DY1**2) * (4*V**4*MUn*Gn - 2*MUd*Gd) ** 2.

highnum2(N) :- ext(Part, X, Y, Dir0, DX0, DY0), ext(Part, X, Y, Dir1, DX1, DY1), curve(Part, Dir0, Dir1),
    V=1..4, mu(X, Y, 1, MUn, MUd), g(Gn, Gd), % n: numerator, d: denominator
    N = MUd**2 * Gd**2 * 4 * (DX0*DX1 + DY0*DY1) ** 2.

:- at(ID, T, X, Y, _), speed(ID, T, V), allowed(X, Y, _, _), not allowed(X, Y, _, V).

% debug
limit(X, Y, Part, V) :- allowed(X, Y, Part, _), V = #min{V' : allowed(X, Y, Part, V')}.

overflow(2147483647).
overflow(4294967295).
%overflow(9223372036854775807).

#show overflow/1.
#show highnum/1.
#show highnum2/1.
%#show extpart0/7.
%#show truenext/5.
%#show step/2.
%#show extpart/7.
#show ext/6.
%#show curvaturedir/5.
%#show curvature/4.
#show limit/4.