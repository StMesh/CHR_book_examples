%% 9.2 Lexicographic order global constraint

%% N.B. For non-gound list, we need to simulate some sort of abstract semantics.
%% See 2.2.1 Minimum, Abstract semantics

%% We assuming with the same length.

%% N.B.
%% Because clpr constraints can not waken chr constraints, and the workaround of trig solution doesn't work 
%% (see 2_add_constraint_propagation_l4.pl). This directory simulates inequalities constraints. However this
%% simulation is not complete, and it is only for demonstrating idea of lexicographic order global constraint.

%% 1. Not support entailed/1.
%% Using kept constraints in head to simulate entailed in guard. It usually causes problems, for example,
%% if there is a bi(X=<5) in store, it imply X=<6, so you can use entailed(X=<6) in guard, but in this
%% simulation you can not match bi(X=<6) in head, because there is no bi(X=<6) in the store.
%% TODO: see Extending Arbitrary Solvers with Constraint Handling Rules by Gregory J. Duck.

%% 2. Not support transitivity
%% Therefore [R1,R2,R3] lex [T1,T2,T3], bi(R2=T2), bi(R3>T4), bi(R4>T3). doesn't work as expected

%% TODO:
%% 1. Find a way to let clpr constraints waken chr constraints
%% e.g. is there any chr predicate can reactive a chr constraint manually?
%% 2. Implement partial order relation that supports entailed check? (still require a wake-up mechanism)
%% 3. Is it possible to implement the non-ground list version, but only allow = in query?
%% i.e. not allow bi(X>=Y), but allow X=Y.

:- use_module(library(chr)).

%% :- set_prolog_flag(double_quotes, codes).

:- op(700, xfx, lex).

:- chr_constraint lex/2, bi/1.

bi(A) \ bi(A) <=> true.
bi(X=Y) <=> X=Y.
bi(X=\=X) <=> fail.
bi(X>=X) <=> true.
bi(X=<X) <=> true.
bi(X>X) <=> fail.
bi(X<X) <=> fail.

%% ground
bi(X=<Y) <=> ground(X), ground(Y) | X =< Y.
bi(X>=Y) <=> ground(X), ground(Y) | X >= Y.
bi(X<Y) <=> ground(X), ground(Y) | X < Y.
bi(X>Y) <=> ground(X), ground(Y) | X > Y.
bi(X=Y) <=> ground(X), ground(Y) | X =:= Y.

bi(X>=Y), bi(X=<Y) <=> X=Y.
bi(X>=Y), bi(Y>=X) <=> X=Y.
bi(X>=Y), bi(Y>X) <=> fail.
bi(X=<Y), bi(Y<X) <=> fail.

% for lexicographic constraint
% so that guard checking works
bi(X>Y) ==> bi(X>=Y),bi(X=\=Y).
bi(X<Y) ==> bi(X=<Y),bi(X=\=Y).
bi(X=Y) ==> bi(X>=Y),bi(X=<Y).

bi(X>=Y),bi(X=\=Y) ==> bi(X>Y).
bi(X=<Y),bi(X=\=Y) ==> bi(X<Y).
bi(X>=Y),bi(X=<Y) ==> bi(X=Y).


l1  @ [] lex [] <=> true.
l2g @ [X|L1] lex [Y|L2] <=> ground(X), ground(Y), X<Y | true.
l2  @ bi(X<Y) \ [X|L1] lex [Y|L2] <=> true.

l3  @ [X|L1] lex [Y|L2] <=>  X==Y | L1 lex L2.
l4  @ [X|L1] lex [Y|L2] ==> bi(X=<Y).

l5  @ bi(U>V) \ [X,U|L1] lex [Y,V|L2] <=> bi(X<Y) .
l6  @ [X,U|L1] lex [Y,V|L2] <=> U==V | [X|L1] lex [Y|L2].
l6p @ bi(U>=V), [X,U|L1] lex [Y,V|L2] ==> [X|L1] lex [Y|L2].

%% ?- [2] lex [1].
%@ false.

%% ?- [1] lex [2].
%@ true.

%% ?- [X] lex [X].
%@ true.

%% ?- [X] lex [Y], bi(X<Y).
%@ bi($VAR(X)\== $VAR(Y)),
%@ bi($VAR(X)< $VAR(Y)),
%@ bi($VAR(X)=< $VAR(Y)).

%% Fix the previous problem by l4
%% ?- [X] lex [Y].
%@ [$VAR(X)]lex[$VAR(Y)],
%@ bi($VAR(X)=< $VAR(Y)).

%% Fix the previous problem by l4
%% ?- [X] lex [Y], bi(X>=Y). 
%@ X = $VAR(Y).

%% Fix the previous problem by l4
%% ?- [X] lex [Y], bi(X>Y). 
%@ false.

%% ?- [R|Rs] lex [T|Ts], bi(R=\=T).
%@ bi($VAR(R)< $VAR(T)),
%@ bi($VAR(R)=\= $VAR(T)),
%@ bi($VAR(R)=< $VAR(T)).

%% Fix the previous problem by l5 l6.
%% ?- [R1,R2,R3] lex [T1,T2,T3], bi(R2=T2), bi(R3>T3).
%@ R2 = $VAR(T2),
%@ bi($VAR(R1)=\= $VAR(T1)),
%@ bi($VAR(R1)< $VAR(T1)),
%@ bi($VAR(R3)=\= $VAR(T3)),
%@ bi($VAR(R3)>= $VAR(T3)),
%@ bi($VAR(R3)> $VAR(T3)),
%@ bi($VAR(R1)=< $VAR(T1)).

%% Fix the previous problem by l6p.
%% ?- [R1,R2,R3] lex [T1,T2,T3], bi(R2>=T2), bi(R3>T3).
%@ bi($VAR(R1)=\= $VAR(T1)),
%@ bi($VAR(R1)< $VAR(T1)),
%@ bi($VAR(R3)=\= $VAR(T3)),
%@ bi($VAR(R3)>= $VAR(T3)),
%@ bi($VAR(R3)> $VAR(T3)),
%@ bi($VAR(R2)>= $VAR(T2)),
%@ bi($VAR(R1)=< $VAR(T1)).

%% The six rules (l1 to l5 and l6’) implement a complete constraint solver
%% for the nonstrict lexicographic order constraint for comparing sequences of
%% the same, given length.

%% A cascade of propagation rule applications together with the subsequent simplification of
%% the constraints produced can lead to a quadratic time behavior with simple CHR implementations.

%% This happens if, after exhaustive propagation with rule l6’, the resulting O(n2) variable pairs are
%% removed one by one by rule l3.
