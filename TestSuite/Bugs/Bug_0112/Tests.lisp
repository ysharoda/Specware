(test-directories ".")

(test 

 ("Bug 0112 : Failure to translate when rule uses unqualified ref [Winner]"
  :show   "Capture#Winner"
  :output '(";;; Elaborating spec-translation at $TESTDIR/Capture#Winner"
	    ";;; Elaborating spec at $TESTDIR/Capture#S"
	    ""
	    "spec  "
	    " type AA"
	    " axiom foo1 is fa(x : AA) x = x"
	    " type BB"
	    " axiom foo2 is fa(x : BB) x = x"
	    " axiom foo3 is fa(x : BB) x = x"
	    " type CC"
	    " type Q.C"
	    " axiom foo4 is fa(x : CC) x = x"
	    " axiom foo5 is fa(x : Q.C) x = x"
	    " type DD"
	    " type Q2.D"
	    " axiom foo6 is fa(x : DD) x = x"
	    " axiom foo7 is fa(x : Q2.D) x = x"
	    "endspec"
	    ""
	    ""))

 ("Bug 0112 : Failure to translate when rule uses unqualified ref [Loser]"
  :show   "Capture#Loser"
  :output '(";;; Elaborating spec-translation at $TESTDIR/Capture#Loser"
	    "Errors in $TESTDIR/Capture.sw"
	    "26.24-26.31	: Error in translation: Ambiguous source type D"
	    ""))
 
 )