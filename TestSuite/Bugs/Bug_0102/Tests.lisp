(test-directories ".")

(test 

 ("Bug 0102 : Extra variable in gnerated proof obligation"
  :show   "ObligationsOfInteger.sw" 
  :output '(";;; Elaborating obligator at $TESTDIR/ObligationsOfInteger"
	    ";;; Elaborating spec at $SPECWARE/Library/Base/WFO"
	    ""
	    "spec  "
	    " import /Library/Base/WFO"
	    " import Nat"
	    " import Compare"
	    " import Functions"
	    " type Integer"
	    " "
	    " op  natural? : Integer -> Boolean"
	    " type Nat = (Integer | natural?)"
	    " "
	    " op  - : Integer -> Integer"
	    " op  ~ : Integer -> Integer"
	    " axiom Integer.backward_compatible_unary_minus_def is "
	    "    fa(i : Integer) ~ i = - i"
	    " axiom Integer.negative_integers is "
	    "    fa(i : Integer) ~(natural? i) => (ex(n : PosNat) i = - n)"
	    " axiom Integer.negative is fa(n : PosNat) ~(natural?(- n))"
	    " axiom Integer.unary_minus_injective_on_positives is "
	    "    fa(n1 : PosNat, n2 : PosNat) n1 ~= n2 => - n1 ~= - n2"
	    " axiom Integer.minus_negative is fa(n : PosNat) -(- n) = n"
	    " axiom Integer.minus_zero is -(0) = 0"
	    " theorem Integer.unary_minus_involution is fa(i : Integer) -(- i) = i"
	    " theorem Integer.unary_minus_bijective is Functions.bijective?(-)"
	    " type NonZeroInteger = {i : Integer | i ~= 0}"
	    " "
	    " op  + infixl 25 : Integer * Integer -> Integer"
	    " op  - infixl 25 : Integer * Integer -> Integer"
	    " op  * infixl 27 : Integer * Integer -> Integer"
	    " op  div infixl 26 : Integer * NonZeroInteger -> Integer"
	    " op  rem infixl 26 : Integer * NonZeroInteger -> Integer"
	    " op  <= infixl 20 : Integer * Integer -> Boolean"
	    " op  < infixl 20 : Integer * Integer -> Boolean"
	    " op  >= infixl 20 : Integer * Integer -> Boolean"
	    " op  > infixl 20 : Integer * Integer -> Boolean"
	    " op  abs : Integer -> Nat"
	    " op  min : Integer * Integer -> Integer"
	    " op  max : Integer * Integer -> Integer"
	    " op  compare : Integer * Integer -> Compare.Comparison"
	    " op  pred : Nat -> Integer"
	    " op  gcd : Integer * Integer -> PosNat"
	    " op  lcm : Integer * Integer -> Nat"
	    " axiom Integer.addition_def1 is fa(i : Integer) i + 0 = i && 0 + i = i"
	    " conjecture Integer.addition_def2_Obligation is "
	    "    fa(n1 : PosNat, n2 : PosNat) "
	    "     n1 + n2 = plus(n1, n2) "
	    "     && - n1 + - n2 = -(plus(n1, n2)) && ~(lte(n1, n2)) => lte(n2, n1)"
	    " conjecture Integer.addition_def2_Obligation0 is "
	    "    fa(n1 : PosNat, n2 : PosNat) "
	    "     n1 + n2 = plus(n1, n2) "
	    "     && - n1 + - n2 = -(plus(n1, n2)) "
	    "        && n1 + - n2 "
	    "           = (if lte(n1, n2) then -(minus(n2, n1)) else minus(n1, n2)) "
	    "           && ~(lte(n1, n2)) => lte(n2, n1)"
	    " axiom Integer.addition_def2 is "
	    "    fa(n1 : PosNat, n2 : PosNat) "
	    "     n1 + n2 = plus(n1, n2) "
	    "     && - n1 + - n2 = -(plus(n1, n2)) "
	    "        && n1 + - n2 "
	    "           = (if lte(n1, n2) then -(minus(n2, n1)) else minus(n1, n2)) "
	    "           && - n1 + n2 "
	    "              = (if lte(n1, n2)"
	    "                  then minus(n2, n1) "
	    "                 else -(minus(n1, n2)))"
	    " axiom Integer.subtraction_def is "
	    "    fa(x : Integer, y : Integer) x - y = x + - y"
	    " axiom Integer.multiplication_def is "
	    "    fa(x : Integer, y : Integer) "
	    "     0 * y = 0 && (x + 1) * y = x * y + y && (x - 1) * y = x * y - y"
	    " conjecture Integer.division_def_Obligation is "
	    "    fa(y : NonZeroInteger) natural?(abs y) => abs y ~= 0"
	    " conjecture Integer.division_def_Obligation0 is "
	    "    fa(x : Integer, y : NonZeroInteger) natural?(abs x div abs y)"
	    " axiom Integer.division_def is "
	    "    fa(x : Integer, y : NonZeroInteger, z : Integer) "
	    "     x div y = z "
	    "     <=> abs z = abs x div abs y "
	    "         && (x * y >= 0 => z >= 0) && (x * y <= 0 => z <= 0)"
	    " axiom Integer.remainder_def is "
	    "    fa(x : Integer, y : NonZeroInteger) x rem y = x - y * (x div y)"
	    " axiom Integer.less_than_equal_def is "
	    "    fa(x : Integer, y : Integer) x <= y <=> natural?(y - x)"
	    " theorem Integer.natural?_and_less_than_equal is "
	    "    fa(i : Integer) natural? i <=> 0 <= i"
	    " axiom Integer.less_than_def is "
	    "    fa(x : Integer, y : Integer) x < y <=> x <= y && x ~= y"
	    " "
	    " def >= (x, y) = y <= x"
	    " "
	    " def > (x, y) = y < x"
	    " conjecture Integer.abs_Obligation is fa(x : Integer) x >= 0 => natural? x"
	    " conjecture Integer.abs_Obligation0 is "
	    "    fa(x : Integer) ~(x >= 0) => natural?(- x)"
	    " "
	    " def abs x = if x >= 0 then x else - x"
	    " "
	    " def min (x, y) = if x < y then x else y"
	    " "
	    " def max (x, y) = if x > y then x else y"
	    " "
	    " def compare (x, y) = "
	    "   if x < y then Less else if x > y then Greater else Equal"
	    " "
	    " def pred x = x - 1"
	    "endspec"
	    ""
	    "")
  )
 )
