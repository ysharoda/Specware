(test-directories ".")

(test 

 ("Bug 0030 : system crashes with seg. fault when compiling the following specs"
  :sw "WasCausingSegFault"
  :output '(";;; Elaborating spec at $TESTDIR/WasCausingSegFault#BinaryRel"
	    ";;; Elaborating spec at $TESTDIR/WasCausingSegFault#BinaryOp"
	    ";;; Generating lisp file $TESTDIR/lisp/WasCausingSegFault.lisp"
	    (:optional ";; ensure-directories-exist: creating $TESTDIR/lisp/WasCausingSegFault.lisp")
	    (:optional ";; ensure-directories-exist: creating")
	    (:optional ";;   $TESTDIR/lisp/WasCausingSegFault.lisp")
	    (:optional "creating directory: $TESTDIR/lisp/")
	    (:optional ";; Directory $TESTDIR/lisp/ does not exist, will create.")
	    (:optional "WARNING: Non-constructive def for String-Spec::explode")
	    (:optional "WARNING: Non-constructive def for Function-Spec::injective?")
	    (:optional "WARNING: Non-constructive def for Function-Spec::surjective?")
	    (:optional "WARNING: Non-constructive def for Function-Spec::inverse-1-1")
	    (:optional "WARNING: Non-constructive def for Integer-Spec::pred")
	    (:optional "WARNING: Non-constructive def for Integer-Spec::positive?")
	    (:optional "WARNING: Non-constructive def for IntegerAux::|!-|")
	    (:optional "WARNING: Non-constructive def for Integer-Spec::+-2")
	    (:optional "WARNING: Non-constructive def for Integer-Spec::*-2")
	    (:optional "WARNING: Non-constructive def for Integer-Spec::div-2")
	    (:optional "WARNING: Non-constructive def for Integer-Spec::divides-2")
	    (:optional "WARNING: Non-constructive def for Integer-Spec::gcd-2")
	    (:optional "WARNING: Non-constructive def for Integer-Spec::lcm-2")
	    (:optional "WARNING: Non-constructive def for Char-Spec::ord")
	    (:optional ";;; Suppressing generated def for Boolean-Spec::show")
	    (:optional ";;; Suppressing generated def for Char-Spec::ord")
	    (:optional ";;; Suppressing generated def for IntegerAux::|!-|")
	    (:optional ";;; Suppressing generated def for Integer-Spec::+-2")
	    (:optional ";;; Suppressing generated def for Integer-Spec::--2")
	    (:optional ";;; Suppressing generated def for Integer-Spec::positive?")
	    (:optional ";;; Suppressing generated def for Integer-Spec::<-2")
	    (:optional ";;; Suppressing generated def for Integer-Spec::<=-2")
	    (:optional ";;; Suppressing generated def for Char-Spec::isLowerCase")
	    (:optional ";;; Suppressing generated def for Char-Spec::isUpperCase")
	    (:optional ";;; Suppressing generated def for Char-Spec::isAlpha")
	    (:optional ";;; Suppressing generated def for Char-Spec::isNum")
	    (:optional ";;; Suppressing generated def for Char-Spec::isAlphaNum")
	    (:optional ";;; Suppressing generated def for Char-Spec::isAscii")
	    (:optional ";;; Suppressing generated def for Char-Spec::show")
	    (:optional ";;; Suppressing generated def for Char-Spec::toLowerCase")
	    (:optional ";;; Suppressing generated def for Char-Spec::toString")
	    (:optional ";;; Suppressing generated def for Char-Spec::toUpperCase")
	    (:optional ";;; Suppressing generated def for Integer-Spec::*-2")
	    (:optional ";;; Suppressing generated def for Integer-Spec::div-2")
	    (:optional ";;; Suppressing generated def for Integer-Spec::div")
	    (:optional ";;; Suppressing generated def for Integer-Spec::divides-2")
	    (:optional ";;; Suppressing generated def for Integer-Spec::divides")
	    (:optional ";;; Suppressing generated def for Integer-Spec::gcd-2")
	    (:optional ";;; Suppressing generated def for String-Spec::explode")
	    (:optional ";;; Suppressing generated def for Integer-Spec::rem-2")
	    (:optional ";;; Suppressing generated def for String-Spec::concat-2")
	    (:optional ";;; Suppressing generated def for String-Spec::^-2")
	    (:optional ";;; Suppressing generated def for Nat-Spec::natToString")
	    (:optional ";;; Suppressing generated def for Integer-Spec::intToString")
	    (:optional ";;; Suppressing generated def for Integer-Spec::lcm-2")
	    (:optional ";;; Suppressing generated def for Integer-Spec::multipleOf-2")
	    (:optional ";;; Suppressing generated def for Integer-Spec::multipleOf")
	    (:optional ";;; Suppressing generated def for Integer-Spec::pred")
	    (:optional ";;; Suppressing generated def for String-Spec::|!length|")
	    (:optional ";;; Suppressing generated def for String-Spec::substring-3")
	    (:optional ";;; Suppressing generated def for Nat-Spec::stringToNat")
	    (:optional ";;; Suppressing generated def for Integer-Spec::stringToInt")
	    (:optional ";;; Suppressing generated def for Integer-Spec::toString")
	    (:optional ";;; Suppressing generated def for Integer-Spec::|!*|")
	    (:optional ";;; Suppressing generated def for Integer-Spec::|!+|")
	    (:optional ";;; Suppressing generated def for Integer-Spec::|!-|")
	    (:optional ";;; Suppressing generated def for Integer-Spec::|!<=|")
	    (:optional ";;; Suppressing generated def for Integer-Spec::|!<|")
	    (:optional ";;; Suppressing generated def for Integer-Spec::|!gcd|")
	    (:optional ";;; Suppressing generated def for Integer-Spec::|!lcm|")
	    (:optional ";;; Suppressing generated def for Integer-Spec::|!rem|")
	    (:optional ";;; Suppressing generated def for Nat-Spec::toString")
	    (:optional ";;; Suppressing generated def for String-Spec::++-2")
	    (:optional ";;; Suppressing generated def for String-Spec::compare-2")
	    (:optional ";;; Suppressing generated def for String-Spec::<-2")
	    (:optional ";;; Suppressing generated def for String-Spec::<=-2")
	    (:optional ";;; Suppressing generated def for String-Spec::^")
	    (:optional ";;; Suppressing generated def for String-Spec::all-1-1")
	    (:optional ";;; Suppressing generated def for String-Spec::all")
	    (:optional ";;; Suppressing generated def for String-Spec::compare")
	    (:optional ";;; Suppressing generated def for String-Spec::concat")
	    (:optional ";;; Suppressing generated def for String-Spec::concatList")
	    (:optional ";;; Suppressing generated def for String-Spec::exists-1-1")
	    (:optional ";;; Suppressing generated def for String-Spec::leq-2")
	    (:optional ";;; Suppressing generated def for String-Spec::leq")
	    (:optional ";;; Suppressing generated def for String-Spec::lt-2")
	    (:optional ";;; Suppressing generated def for String-Spec::lt")
	    (:optional ";;; Suppressing generated def for String-Spec::map-1-1")
	    (:optional ";;; Suppressing generated def for String-Spec::newline")
	    (:optional ";;; Suppressing generated def for String-Spec::sub-2")
	    (:optional ";;; Suppressing generated def for String-Spec::sub")
	    (:optional ";;; Suppressing generated def for String-Spec::substring")
	    (:optional ";;; Suppressing generated def for String-Spec::toScreen")
	    (:optional ";;; Suppressing generated def for String-Spec::translate-1-1")
	    (:optional ";;; Suppressing generated def for String-Spec::translate")
	    (:optional ";;; Suppressing generated def for String-Spec::writeLine")
	    (:optional ";;; Suppressing generated def for String-Spec::|!<=|")
	    (:optional ";;; Suppressing generated def for String-Spec::|!<|")
	    (:optional ";;; Suppressing generated def for String-Spec::|!exists|")
	    (:optional ";;; Suppressing generated def for String-Spec::|!map|")
	    (:optional "WARNING: Non-constructive def for List-Spec::lengthOfListFunction")
	    (:optional "WARNING: Non-constructive def for List-Spec::definedOnInitialSegmentOfLength-2")
	    (:optional "WARNING: Non-constructive def for Function-Spec::wellFounded?")
	    (:optional "WARNING: Non-constructive def for Function-Spec::inverse-1-1")
	    (:optional "WARNING: Non-constructive def for Function-Spec::surjective?")
	    (:optional "WARNING: Non-constructive def for Function-Spec::injective?")
	    (:optional ";;; Generating lisp file $TESTDIR/lisp/WasCausingSegFault.lisp")
	    (:optional "WARNING: Non-constructive def for List-Spec::lengthOfListFunction")
	    (:optional "WARNING: Non-constructive def for List-Spec::definedOnInitialSegmentOfLength-2")
	    (:optional "WARNING: Non-constructive def for Function-Spec::wellFounded?")
	    (:optional "WARNING: Non-constructive def for Function-Spec::inverse-1-1")
	    (:optional "WARNING: Non-constructive def for Function-Spec::surjective?")
	    (:optional "WARNING: Non-constructive def for String-Spec::explode")
	    (:optional "WARNING: Non-constructive def for Function-Spec::injective?")
	    (:optional "WARNING: Non-constructive def for Function-Spec::surjective?")
	    (:optional "WARNING: Non-constructive def for Function-Spec::inverse-1-1")
	    (:optional "WARNING: Non-constructive def for Integer-Spec::pred")
	    (:optional "WARNING: Non-constructive def for Integer-Spec::positive?")
	    (:optional "WARNING: Non-constructive def for IntegerAux::|!-|")
	    (:optional "WARNING: Non-constructive def for Integer-Spec::+-2")
	    (:optional "WARNING: Non-constructive def for Integer-Spec::*-2")
	    (:optional "WARNING: Non-constructive def for Integer-Spec::div-2")
	    (:optional "WARNING: Non-constructive def for Integer-Spec::divides-2")
	    (:optional "WARNING: Non-constructive def for Integer-Spec::gcd-2")
	    (:optional "WARNING: Non-constructive def for Integer-Spec::lcm-2")
	    (:optional "WARNING: Non-constructive def for Char-Spec::ord")
	    (:optional ";;; Suppressing generated def for Boolean-Spec::show")
	    (:optional ";;; Suppressing generated def for Char-Spec::ord")
	    (:optional ";;; Suppressing generated def for IntegerAux::|!-|")
	    (:optional ";;; Suppressing generated def for Integer-Spec::+-2")
	    (:optional ";;; Suppressing generated def for Integer-Spec::--2")
	    (:optional ";;; Suppressing generated def for Integer-Spec::positive?")
	    (:optional ";;; Suppressing generated def for Integer-Spec::<-2")
	    (:optional ";;; Suppressing generated def for Integer-Spec::<=-2")
	    (:optional ";;; Suppressing generated def for Char-Spec::isLowerCase")
	    (:optional ";;; Suppressing generated def for Char-Spec::isUpperCase")
	    (:optional ";;; Suppressing generated def for Char-Spec::isAlpha")
	    (:optional ";;; Suppressing generated def for Char-Spec::isNum")
	    (:optional ";;; Suppressing generated def for Char-Spec::isAlphaNum")
	    (:optional ";;; Suppressing generated def for Char-Spec::isAscii")
	    (:optional ";;; Suppressing generated def for Char-Spec::show")
	    (:optional ";;; Suppressing generated def for Char-Spec::toLowerCase")
	    (:optional ";;; Suppressing generated def for Char-Spec::toString")
	    (:optional ";;; Suppressing generated def for Char-Spec::toUpperCase")
	    (:optional ";;; Suppressing generated def for Integer-Spec::*-2")
	    (:optional ";;; Suppressing generated def for Integer-Spec::div-2")
	    (:optional ";;; Suppressing generated def for Integer-Spec::div")
	    (:optional ";;; Suppressing generated def for Integer-Spec::divides-2")
	    (:optional ";;; Suppressing generated def for Integer-Spec::divides")
	    (:optional ";;; Suppressing generated def for Integer-Spec::gcd-2")
	    (:optional ";;; Suppressing generated def for String-Spec::explode")
	    (:optional ";;; Suppressing generated def for Integer-Spec::rem-2")
	    (:optional ";;; Suppressing generated def for String-Spec::concat-2")
	    (:optional ";;; Suppressing generated def for String-Spec::^-2")
	    (:optional ";;; Suppressing generated def for Nat-Spec::natToString")
	    (:optional ";;; Suppressing generated def for Integer-Spec::intToString")
	    (:optional ";;; Suppressing generated def for Integer-Spec::lcm-2")
	    (:optional ";;; Suppressing generated def for Integer-Spec::multipleOf-2")
	    (:optional ";;; Suppressing generated def for Integer-Spec::multipleOf")
	    (:optional ";;; Suppressing generated def for Integer-Spec::pred")
	    (:optional ";;; Suppressing generated def for String-Spec::|!length|")
	    (:optional ";;; Suppressing generated def for String-Spec::substring-3")
	    (:optional ";;; Suppressing generated def for Nat-Spec::stringToNat")
	    (:optional ";;; Suppressing generated def for Integer-Spec::stringToInt")
	    (:optional ";;; Suppressing generated def for Integer-Spec::toString")
	    (:optional ";;; Suppressing generated def for Integer-Spec::|!*|")
	    (:optional ";;; Suppressing generated def for Integer-Spec::|!+|")
	    (:optional ";;; Suppressing generated def for Integer-Spec::|!-|")
	    (:optional ";;; Suppressing generated def for Integer-Spec::|!<=|")
	    (:optional ";;; Suppressing generated def for Integer-Spec::|!<|")
	    (:optional ";;; Suppressing generated def for Integer-Spec::|!gcd|")
	    (:optional ";;; Suppressing generated def for Integer-Spec::|!lcm|")
	    (:optional ";;; Suppressing generated def for Integer-Spec::|!rem|")
	    (:optional ";;; Suppressing generated def for Nat-Spec::toString")
	    (:optional ";;; Suppressing generated def for String-Spec::++-2")
	    (:optional ";;; Suppressing generated def for String-Spec::compare-2")
	    (:optional ";;; Suppressing generated def for String-Spec::<-2")
	    (:optional ";;; Suppressing generated def for String-Spec::<=-2")
	    (:optional ";;; Suppressing generated def for String-Spec::^")
	    (:optional ";;; Suppressing generated def for String-Spec::all-1-1")
	    (:optional ";;; Suppressing generated def for String-Spec::all")
	    (:optional ";;; Suppressing generated def for String-Spec::compare")
	    (:optional ";;; Suppressing generated def for String-Spec::concat")
	    (:optional ";;; Suppressing generated def for String-Spec::concatList")
	    (:optional ";;; Suppressing generated def for String-Spec::exists-1-1")
	    (:optional ";;; Suppressing generated def for String-Spec::leq-2")
	    (:optional ";;; Suppressing generated def for String-Spec::leq")
	    (:optional ";;; Suppressing generated def for String-Spec::lt-2")
	    (:optional ";;; Suppressing generated def for String-Spec::lt")
	    (:optional ";;; Suppressing generated def for String-Spec::map-1-1")
	    (:optional ";;; Suppressing generated def for String-Spec::newline")
	    (:optional ";;; Suppressing generated def for String-Spec::sub-2")
	    (:optional ";;; Suppressing generated def for String-Spec::sub")
	    (:optional ";;; Suppressing generated def for String-Spec::substring")
	    (:optional ";;; Suppressing generated def for String-Spec::toScreen")
	    (:optional ";;; Suppressing generated def for String-Spec::translate-1-1")
	    (:optional ";;; Suppressing generated def for String-Spec::translate")
	    (:optional ";;; Suppressing generated def for String-Spec::writeLine")
	    (:optional ";;; Suppressing generated def for String-Spec::|!<=|")
	    (:optional ";;; Suppressing generated def for String-Spec::|!<|")
	    (:optional ";;; Suppressing generated def for String-Spec::|!exists|")
	    (:optional ";;; Suppressing generated def for String-Spec::|!map|")
	    ""))

 )
