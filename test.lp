% Possible moves
mv(move_forward).
mv(move_left).
mv(move_right).
mv(wait).

% define ticks (replaces global)
maxEnd(Emax) :- Emax = #max { E : end(_,(_, _),E) }.
time(T) :- maxEnd(Emax), T = 0..Emax.

action_candidate(train(ID), M, T) :- mv(M), train(ID), start(ID, _, S, _), end(ID,(_, _),E), time(T).

% use predetermined moves on spawning
% changed actions for testing speeds; possible behavior change!
action(train(ID), wait, 0..S) :- start(ID, _, S, _), train(ID).
action(train(ID), move_forward, S+1..S+1) :- start(ID, _, S, _), train(ID).
% choose all other moves
{ action(train(ID), M, T) : action_candidate(train(ID), M, T) } 1 :- train(ID), not reached(ID,T-1), time(T).
% discard if a train doesn't reach its station (reached defined later)
:- train(ID), not reached(ID).

reached_at_time(ID,T) :- at(ID,T,X,Y,_), end(ID,(X,Y),_).

% direction to vector
dir(n, -1, 0).
dir(e, 0, 1).
dir(s, 1, 0).
dir(w, 0, -1).

% possible turns
left(n, w). left(w, s). left(s, e). left(e, n).
right(n, e). right(e, s). right(s, w). right(w, n).

% direction after moving forward
nextdir(X, Y, n, n) :- cell((X, Y), Tr), Tr & 32800 = 32800.
nextdir(X, Y, s, s) :- cell((X, Y), Tr), Tr & 32800 = 32800.
nextdir(X, Y, e, e) :- cell((X, Y), Tr), Tr & 1025 = 1025.
nextdir(X, Y, w, w) :- cell((X, Y), Tr), Tr & 1025 = 1025.

% direction after turning
nextdirt(X, Y, n, w) :- cell((X, Y), Tr), Tr & 4608 = 4608.
nextdirt(X, Y, e, s) :- cell((X, Y), Tr), Tr & 4608 = 4608.
nextdirt(X, Y, n, e) :- cell((X, Y), Tr), Tr & 16386 = 16386.
nextdirt(X, Y, w, s) :- cell((X, Y), Tr), Tr & 16386 = 16386.
nextdirt(X, Y, s, w) :- cell((X, Y), Tr), Tr & 2064 = 2064.
nextdirt(X, Y, e, n) :- cell((X, Y), Tr), Tr & 2064 = 2064.
nextdirt(X, Y, s, e) :- cell((X, Y), Tr), Tr & 72 = 72.
nextdirt(X, Y, w, n) :- cell((X, Y), Tr), Tr & 72 = 72.

% handle symmetrical fork edge case (don't go forward)
nextdouble(X, Y, D0) :- nextdirt(X, Y, D0, D1), nextdirt(X, Y, D0, D2), D1 != D2.

% get next direction corresponding to move option
truenext(X, Y, M, D, D) :- M = move_forward, nextdir(X, Y, D, D).
truenext(X, Y, M, D0, D1) :- M = move_forward, not nextdir(X, Y, D0, D0), nextdirt(X, Y, D0, D1), not nextdouble(X, Y, D0).
truenext(X, Y, M, D0, D1) :- M = move_left, nextdir(X, Y, D0, D0), nextdirt(X, Y, D0, D1), left(D0, D1).
truenext(X, Y, M, D0, D1) :- M = move_left, nextdirt(X, Y, D0, D2), nextdirt(X, Y, D0, D1), left(D0, D1), right(D0, D2).
truenext(X, Y, M, D0, D1) :- M = move_right, nextdir(X, Y, D0, D0), nextdirt(X, Y, D0, D1), right(D0, D1).
truenext(X, Y, M, D0, D1) :- M = move_right, nextdirt(X, Y, D0, D2), nextdirt(X, Y, D0, D1), right(D0, D1), left(D0, D2).

% calculate position of trains
at(ID, Dep+1, X, Y, D) :- start(ID, (X, Y), Dep, D).
at(ID, T+1, X+DX, Y+DY, Dn) :- at(ID, T, X, Y, D), action(train(ID), M, T), truenext(X, Y, M, D, Dn), dir(Dn, DX, DY).
at(ID, T+1, X, Y, D) :- at(ID, T, X, Y, D), action(train(ID), wait, T).

% discard on train crash (same tile or swapping)
:- at(ID1, T, X, Y, _), at(ID2, T, X, Y, _), train(ID1), train(ID2), ID1 != ID2.
:- at(ID1, T, X, Y, _), at(ID2, T, X1, Y1, _), train(ID1), train(ID2), ID1 != ID2, at(ID1, T+1, X1, Y1, _), at(ID2, T+1, X, Y, _).

% determine which trains reach their goal
reached(ID, T) :- at(ID, T, X, Y, _), end(ID, (X, Y), _).
reached(ID) :- reached(ID, _).

reached_before(ID, E) :- at(ID, T, X, Y, _), end(ID, (X, Y), E), T <= E.

% --- FORCE ACCELERATION ---
% waited for any: move, wait 3
% waited for n: move, wait n-1
% result: wwwwwwwMwwwMwwMwMMMM...MMwMwwMwwwwww
% speed:  -------4444333221111...1223334444444
speedpart(ID, T, 1) :- train(ID), action(train(ID), M1, T), M1 != wait.
% initial speedparts
% wwwwwwwMwwwMwwMwMMMM...MMwMwwMwwwwww; M---
% -------1---1--1-1111...11-1--1------  1
speedpart(ID, T..T+N, N+1) :- speedpart(ID, T, N), action(train(ID), M, T), M != wait, action(train(ID), wait, T+N), N=1..4.
speedpart(ID, T..T+N, N+1) :- speedpart(ID, T, N), action(train(ID), M, T), M != wait, not action(train(ID), _, T+N), N=1..4. % also ensures final speed 4
% speedparts handled by: first line   | second line
% -------22--22-221111...12222-22-----  2
% -------333-333221111...122333333----  3
% -------4444333221111...1223334444---  4
speed2(ID, T, N) :- speedpart(ID, T, _), N = #max{N1: speedpart(ID, T, N1)}.
speed2(ID, T, 5) :- train(ID), time(T), not speedpart(ID, T, _).
% speed: max speedpart or 5
% 55555554444333221111...1223334444555  4

% --- ACCELERATION SPECIFICS ---
% smooth acceleration (speeddiff can't be less/greater than 1)
:- speed2(ID, T, N1), speed2(ID, T+1, N2), N1=1..5, N1 + 1 < N2, time(T+1).
:- speed2(ID, T, N1), speed2(ID, T+1, N2), N1=1..5, N1 - 1 > N2, time(T+1).
% test: drop speed on curves (replace 1 with 1..n in speed for more deceleration)
%:- speed2(ID, T-1, 1), at(ID, T, _, _, D1), at(ID, T+1, _, _, D2), D1 != D2.
% test: reduce max speed (slow train, icy rails, ...; change to 1..n to disable speed >= n)
:- speed2(_, _, 1..0).
:- speed2(ID,T,N),speed(ID,N2),N<N2.

% --- EARLIEST ARRIVAL ---
earliest_arrival(ID, T) :- reached(ID, T), not reached(ID, T1), T1 < T,time(T1).
:- action(train(ID), M, T), mv(M), M != wait, earliest_arrival(ID, T0), T > T0.

% --- MINIMIZATION ---
#minimize { T@1, ID : earliest_arrival(ID, T) }.
#minimize { 1@2, ID, T : action(train(ID), M, T), mv(M), M != wait }.

#show action/3.
%#show earliest_arrival/2.
%
%#show speed2/3.
%#show speedpart/3.
%#show at/5.
