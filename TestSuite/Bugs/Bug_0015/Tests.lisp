(test-directories ".")

(test 

 ("Bug 0015 : Substitute and Translate fail to update the localTypes and localOps"
  :show "subsExample#BB"
  :output '(";;; Elaborating spec-substitution at $TESTDIR/subsExample#BB"
	    ";;; Elaborating spec at $TESTDIR/subsExample#AA"
	    ";;; Elaborating spec at $TESTDIR/subsExample#A"
	    ";;; Elaborating spec-morphism at $TESTDIR/subsExample#M"
	    ";;; Elaborating spec at $TESTDIR/subsExample#B"
	    ""
	    "spec  "
	    " import B"
            ""
	    " type Interval = {start : Integer, stop : Integer}"
	    (:optional " ")
	    " op  isEmptyInterval? : Interval -> Bool"
            (:alternatives
             " def isEmptyInterval? {start = x, stop = y} = x = y"
             " def isEmptyInterval? {start = x : Integer, stop = y : Integer} = x = y"
             (" def isEmptyInterval? {start = x : Integer, stop = y : Integer} : Bool ="
              " x = y")
             (" def isEmptyInterval? {start = x : Integer, stop = y : Integer} : Bool"
              " = x = y"))
	    "endspec"
	    ""
	    ""
	    ))

 )
