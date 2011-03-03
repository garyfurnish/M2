-- -*- coding: utf-8 -*-
newPackage(
  "NumericalHilbert",
  Version => "0.0", 
  Date => "July 25, 2010",
  Authors => {{Name => "Robert Krone", 
    Email => "krone@math.gatech.edu"}},
  Headline => "some local Hilbert series functions",
  DebuggingMode => true
)

export {dualBasis, dualBasisBM, dualHilbert, hilbertB, hilbertC, Point, UseDZ, STmatrix, DZmatrix, deflation, Size}

--Generators of the dual space with all terms of degree d or less.
--Uses ST algorithm by default, but can use DZ instead if specified.
dualBasis = method(TypicalValue => Matrix, Options => {Point => {}, UseDZ => false})
dualBasis (Matrix, ZZ) := o -> (igens, d) -> (
  R := ring igens;
  epsilon := .001; --error tolerance for kernel
  M := new Matrix;
  if o.UseDZ then M = last DZmatrix(igens, d, Point => o.Point)
             else M = last STmatrix(igens, d, Point => o.Point);
  dmons := apply(1..d, i->dMonomials(R,i)); --nested list of monomials up to order d
  if M != 0 then (
    (svs, U, Vt) := SVD transpose sub(M,coefficientRing R);
    Vt = entries Vt;
    dualGens := new MutableList;
    for i from 0 to #svs-1 do
      if abs svs#i <= epsilon then dualGens#(#dualGens) = apply(Vt#i, conjugate);
    for i from #svs to (numgens target M)-1 do
      dualGens#(#dualGens) = Vt#i;
    dualGens = transpose rowReduce(matrix new List from dualGens, epsilon);
    --print (dualGens, matrix {new List from flatten dmons});
    (matrix {{1_R}}) | ((matrix {new List from flatten dmons})*sub(dualGens,R))
  )
  else (matrix {{1_R}}) | (matrix {new List from flatten dmons})
);

dualBasisBM = method(TypicalValue => Matrix, Options => {Point => {}})
dualBasisBM (Matrix, ZZ) := o -> (igens, d) -> (
     R := ring igens;
     n := #gens R;
     m := #(entries igens)#0;
     epsilon := .001; --error tolerance for kernel
     if o.Point != {} then igens = sub(igens, matrix{gens R + o.Point});
     betas := {};
     newbetas := {1_R};
     npairs := subsets(n,2);
     M := map(R^(m),R^0,0);
     E := map(R^0,R^n,0);
     bvectors := map(R^1,R^0,0);
     buildVBlock := v -> (
 	  Vb := mutableMatrix(R,#npairs,n);
    	  for i from 0 to #npairs-1 do (
      	       Vb_(i,npairs#i#0) =  v#(npairs#i#1);
      	       Vb_(i,npairs#i#1) = -v#(npairs#i#0);
    	       );
    	  new Matrix from Vb
  	  );
     V := {{}};
     
     for e from 1 to d+1 do (
	  --print (m, M, E, bvectors, betas, newbetas);
	  s := #betas;
	  snew := #newbetas;
	  M = bvectors || M;
	  --print M;
    	  for i from 0 to #newbetas-1 do (
	       b := newbetas#i;
      	       --get alpha vector for b
      	       alpha := apply(n, k->(
	       	    subs := matrix{apply(n, l->(if l > k then 0_R else (gens R)#l))};
		    (gens R)#k * sub(b,subs)
	       	    ));
      	       --get new A from new alpha
	       A := matrix apply(m, j->apply(alpha,a->innerProduct(a,igens_(0,j))));
	       --expand E with alpha as next row
	       E = E || matrix{alpha};
	       --expand M with Vs and new A
	       newcol := map(R^(s+snew),R^n,0) || A;
	       for v in V#i do newcol = newcol || v;
	       --print (M,newcol, numgens target M, numgens target newcol);
	       M = M | newcol;
      	       );
    	  --add newbetas to betas
	  betas = betas | newbetas;
	  s := #betas;
    	  --get bvectors from kernel of M
    	  (svs, U, Vt) := SVD sub(M,coefficientRing R);
	  --print (svs,U,Vt);
    	  Vt = entries Vt;
    	  bvectors = new MutableList;
    	  for i from 0 to #svs-1 do
	       if i > #svs-1 or svs#i <= epsilon then bvectors#(#bvectors) = apply(Vt#i, conjugate);
    	  --bvectors = entries transpose rowReduce(matrix new List from bvectors, epsilon);
	  bvectors = new List from bvectors;
    	  --find newbetas from bvectors
	  newbetas = apply(bvectors, bv->sum(#bv, i->(bv#i * E_(i//n,i%n))));
    	  --find Vs from bvectors
	  V = apply(#bvectors, i->(
	       w := apply(s, j-> apply(n,k->((bvectors#i)#(j*n + k))));
	       --print ("w",w);
	       apply(s, j->buildVBlock(w#j))
	       ));
	  if #bvectors > 0 then bvectors = matrix bvectors else break;
	  M = M || map(R^(snew*#npairs),R^(n*s),0);
  	  );
     (mons,bmatrix) := coefficients matrix {betas};
     --print(mons,bmatrix);
     bmatrix = sub(bmatrix,coefficientRing R);
     mons * transpose rowReduce(transpose bmatrix,epsilon)
     );

--List of number of generators of the dual space with lead term of degree k for k from 0 to d.
--Uses ST algorithm by default, but can use DZ instead if specified.
dualHilbert = method(TypicalValue => List, Options => {Point => {}, UseDZ => false})
dualHilbert (Matrix, ZZ) := o -> (igens, d) -> (
  epsilon := .001; --error tolerance for kernel
  mList := new Matrix;
  if o.UseDZ then mList = DZmatrix(igens, d, Point => o.Point)
             else mList = STmatrix(igens, d, Point => o.Point);
  fs := apply(mList, M->(
    svs := {};
    if M != 0 then svs = (SVD sub(M,coefficientRing ring igens))#0;
    --print(M, svs, numgens target M, #select(svs, v->(abs v > epsilon)));
    (numgens target M) - #select(svs, v->(abs v > epsilon)) + 1
  ));
  fs = {0,1}|fs;
  apply(d+1, i->(fs#(i+1) - fs#i))
);

--Dayton-Zeng algorithm to find the matrices corresponding to the dual space
--up to degree d.
DZmatrix = method(TypicalValue => List, Options => {Point => {}})
DZmatrix (Matrix, ZZ) := o -> (igens, d) -> (
  epsilon := .001; --error tolerance for kernel
  R := ring igens;
  if o.Point != {} then igens = sub(igens, matrix{gens R + o.Point});
  dmons := apply(d+1, i->dMonomials(R,i));
  M := k -> ( --# of dual space generators with lead term of deg k or less
    p := igens;
    for m in flatten take(dmons,{1,k-1}) do p = p|(m*igens);
    (coefficients(p, Monomials => flatten take(dmons,{1,k})))#1
  );
  new List from apply(1..d, M)
)

--Stetter-Thallinger algorithm to find the matrices corresponding to the dual space
--up to degree d.
STmatrix = method(TypicalValue => List, Options => {Point => {}})
STmatrix (Matrix, ZZ) := o -> (igens, d) -> (
  epsilon := .001; --error tolerance for kernel
  R := ring igens;
  if o.Point != {} then igens = sub(igens, matrix{gens R + o.Point});
  dmons := apply(d+1, i->dMonomials(R,i));
  Ms := new MutableList;
  M := matrix {{}};
  for i from 1 to d do (
    mons := flatten take(dmons,{1,i});
    N := (coefficients(igens, Monomials => mons))#1;
    for v from 0 to #(gens R)-1 do (
      Mshift := new MutableList; --"antiderivative" of M with respect to variable v
      l := 0;
      for p from 0 to #mons-1 do (
	if (listForm mons#p)#0#0#v >= 1 and first degree mons#p > 1 then (
	  Mshift#p = (entries M)#l;
	  l = l+1;
	)
        else Mshift#p = apply(numgens source M, i->0);
      );
      --print (i,v,N,matrix new List from Mshift);
      N = N | matrix new List from Mshift;
    );
    M = gens gb N;
    Ms#(i-1) = M;
  );
  new List from Ms
)

--checks each monomial of degree d and counts ones in the monomial
--basis of the quotient space.
hilbertB = method(TypicalValue => ZZ, Options => {Point => {}})
hilbertB (Matrix, ZZ) := o -> (igens, d) -> (
  R := ring igens;
  if o.Point != {} then igens = sub(igens, matrix{gens R + o.Point});
  G := (flatten entries gens gb igens) / leadMonomial;
  #select(dMonomials(R,d), m->(#select(G, g->isDivisible(m,g)) == 0))
)

--takes alternating sum of number of all monomials, number that are
--a multiple of the lead term of each Groebner basis element, number
--in each pair-wise intersection, etc.
hilbertC = method(TypicalValue => ZZ, Options => {Point => {}})
hilbertC (Matrix, ZZ) := o -> (igens, d) -> (
  R := ring igens;
  if o.Point != {} then igens = sub(igens, matrix{gens R + o.Point});
  G := apply(flatten entries gens gb igens, g->(listForm g)#0#0); --store lead monomials as n-tuples of integers
  bin := (n,k) -> (if n >= 0 then binomial(n,k) else 0);
  listFormLCM := (a,b) -> apply(#a, i->(max {a#i,b#i}));
  recurC := (m, gIndex, coef) -> ( --for each subset S of G add or subtract # of d monomials that are divisible by lcm of S
    if gIndex == #G then
      coef*bin(d - sum m + #(gens R) - 1, #(gens R) - 1)
    else
      recurC(m, gIndex+1, coef) +
      recurC(listFormLCM(m,G#gIndex), gIndex+1, -1*coef)
  );
  newm := apply(#gens R, i->0);
  recurC(newm, 0, 1)
)

deflation = method(TypicalValue => ZZ, Options => {Point => matrix {{}}, Size => 0})
deflation (Matrix) := o -> (igens) -> (
  R := ring igens;
  n := #(gens R);
  epsilon := .001;
  p := sub(o.Point,CC);
  m := o.Size;
  if p == 0 then p = matrix {apply(n, i->0_CC)};
  if m == 0 then m = n;
  A := jacobian igens;
  Asub := sub(A, p);
  svs := (SVD(Asub))#0;
  r := 0;
  for v in svs do
    if clean(epsilon,v) != 0 then r = r + 1;
  if r == n then return take((entries p)#0,m);
  h := randomVector(r+1);
  Br := matrix apply(n, i->randomVector(r+1));
  Bl := matrix apply(r, i->randomVector(n));
  C := (Bl*Asub*Br) || matrix{h};
  p = p | transpose solve(C, transpose matrix{(apply(r,i->0_CC))|{1_CC}});
  lambda := symbol lambda;
  R = CC[gens R,lambda_n..lambda_(n+r)];
  lvec := transpose matrix{new List from lambda_n..lambda_(n+r)};
  igens = sub(igens,R) | transpose (sub(A,R)*Br*lvec) | transpose (matrix{h}*lvec - 1);
  print transpose igens;
  deflation(igens, Point => p, Size => m)
)

--produces a list of all monomials of degree d in the ring R in lex order
dMonomials = (R, d) -> (
  mons := new MutableHashTable;
  recurm := (m, varIndex, deg) -> (
    if varIndex == #(gens R)-1 then
      mons#(#mons) = m*(((gens R)#varIndex)^deg)
    else for k from 0 to deg do
      recurm(m*(((gens R)#varIndex)^k), varIndex+1, deg-k);
    true
  );
  recurm(1_R, 0, d);
  reverse values mons
)

isDivisible = (a, b) -> (
  dif := (listForm a)#0#0 - (listForm b)#0#0;
  #select(dif, i->(i < 0)) == 0
)

--performs Gaussian reduction on M but starting from the bottom right
rowReduce = (M,epsilon) -> (
  R := ring M;
  n := (numgens source M) - 1;
  m := (numgens target M) - 1;
  rindex := m;
  M = new MutableMatrix from M;
  for k from 0 to n do (
    M = new MutableMatrix from clean(epsilon,new Matrix from M);
    a := -1;
    for l from 0 to rindex do
      if (entries M)#l#(n-k) != 0 then (a = l; break);
    if a == -1 then continue;
    rowSwap(M,a,rindex);
    rowMult(M,rindex,1_R/M_(rindex,(n-k)));
    for l from 0 to m do
      if l != rindex then rowAdd(M,l,-1*(entries M)#l#(n-k),rindex);
    rindex = rindex-1;
    --print new Matrix from M;
  );
  M = new Matrix from M
)

--generates a vector of specified length of random complex numbers with unit modulus
randomVector = (dimension) -> (
  apply(dimension, i -> exp((random 2.*pi)*ii))
)

--build a matrix from a nested list of matrices of uniform size
blockMatrix = (blist) -> (
  R := ring (blist#0#0);
  m := #blist;
  n := #(blist#0);
  a := dim target (blist#0#0);
  b := dim source (blist#0#0); 
  M := map(R^0,R^(n*b),0);
  for i from 0 to m-1 do (
    N := map(R^a,R^0,0);
    for j from 0 to n-1 do
      N = N | (blist#i#j);
    M = M || N;
  );
  M
)

--evaluation of a dual element v on a polynomial w
innerProduct = (v,w) -> (
  c := entries (coefficients matrix{{v,w}})#1;
  sum(#c,i->(c#i#0)*(c#i#1))
)

newtonsMethod = (eqns, p, n) -> (
  elist := (entries eqns)#0;
  A := entries transpose jacobian eqns;
  for i from 1 to n do (
    for j from 0 to #elist-1 do (
      val := sub(elist#j, p);
      grad := sub(A#j, p);
    );
  );
)

beginDocumentation()
document { 
  Key => NumericalHilbert,
  Headline => "some local Hilbert series functions",
  EM "NumericalHilbert", " is a basic package to be used as an example."
}

///
document {
  Key => hilbertA,
  Headline => "local Hilbert series of the dual space of an ideal",
  Usage => "hilbertA(igens,d)",
  Inputs => { "igens", "d" },
  Outputs => {{ "the", TT "d", "th element of the Hilbert series corresponding to the ideal with generators", TT "igens" }},
}
///

document {
  Key => hilbertB,
  Headline => "local Hilbert series of the quotient space of an ideal",
  Usage => "hilbertB(igens,d)",
  Inputs => { "igens", "d" },
  Outputs => {{ "the", TT "d", "th element of the Hilbert series corresponding to the ideal with generators", TT "igens" }},
}
document {
  Key => hilbertC,
  Headline => "local Hilbert series of the quotient space of an ideal",
  Usage => "hilbertC(igens,d)",
  Inputs => { "igens", "d" },
  Outputs => {{ "the", TT "d", "th element of the Hilbert series corresponding to the ideal with generators", TT "igens" }},
}

end

loadPackage "NumericalHilbert"
R = CC[x,y]
M = matrix {{y,x^2-y}}
deflation(M)

loadPackage "NumericalHilbert"
loadPackage ("NumericalHilbert", Reload => true)
R = RR[x,y, MonomialOrder => {Weights=>{-1,-1}}, Global => false]
M = matrix {{x*y,x^2-y^2,y^3}}
M = matrix {{x^2 - y}}
M = matrix {{x + y + x*y}}
dualBasisBM(M,6)
STmatrix(M,4)
DZmatrix(M,4)
dualHilbert(M,4)
dualBasis(M,6)
dualHilbert(M,4, UseDZ=>true)
dualBasis(M,4, UseDZ=>true)
apply(0..4, i->hilbertB(M,i))
apply(0..4, i->hilbertC(M,i))

loadPackage "NumericalHilbert"
R = CC[x,y,z, MonomialOrder => {Weights=>{-1,-1,-1}}, Global => false]
M = matrix {{x*y+z, y*z+x, x^2-z^2}}
dualBasis(M,4)
dualHilbert(M,4)