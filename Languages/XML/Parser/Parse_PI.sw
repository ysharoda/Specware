XML qualifying spec

  import Parse_Names              % parse_NmToken    [redundant, given Parse_Character_Strings]
  import Parse_Character_Strings  % parse_WhiteSpace

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %%%          PI                                                                                  %%%
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %%
  %% *[16]  PI        ::= '<?' PITarget (S (Char* - (Char* '?>' Char*)))? '?>' 
  %%   ==>
  %% [K10]  PI        ::= '<?' PITarget (S PIValue)? '?>'           
  %% [K11]  PIValue   ::= Char* - (Char* '?>' Char*)
  %%
  %%  [17]  PITarget  ::=  Name - (('X' | 'x') ('M' | 'm') ('L' | 'l'))
  %% 
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  %% -------------------------------------------------------------------------------------------------
  %% 
  %% [K10]  PI        ::= '<?' PITarget (S PIValue)? '?>'           
  %% [K11]  PIValue   ::= Char* - (Char* '?>' Char*)
  %%  [17]  PITarget  ::=  Name - (('X' | 'x') ('M' | 'm') ('L' | 'l'))
  %% 
  %% -------------------------------------------------------------------------------------------------

  def parse_PI (start : UChars) : Required PI =
    %% assumes we're past initial '<?'
    let 
      %%
      %% [K11]  PIValue   ::= Char* - (Char* '?>' Char*)
      %%
      def probe (tail, rev_result) =
	case tail of
	  | 63 :: 62 (* '?>' *) :: tail ->
	    return (rev rev_result,
		    tail)
	  | char :: tail ->
	    probe (tail, cons (char, rev_result))
	  | _ ->
	    hard_error {kind        = EOF,
			requirement = "PI must terminate with '?>'.",
			start       = start,
			tail        = tail,
			peek        = 10,
			we_expected = [("'?>'", "termination of PI")],
			but         = "EOF occurred first",
			so_we       = "fail immediately"}
    in
      {
       %%
       %%  [17]  PITarget  ::=  Name - (('X' | 'x') ('M' | 'm') ('L' | 'l'))
       %%
       (target, tail_0) <- parse_NmToken start;
       (when (~ (pi_target? target))
	(error {kind        = Syntax,
		requirement = "PI name must be normal name not starting with 'xml'.",
		start       = start,
		tail        = tail_0,
		peek        = 10,
		we_expected = [("Name - 'xml' variants", "legal PI target name")], 
		but         = "we saw the illegal name '" ^ (string target) ^ "' instead",
		so_we       = "pretend '" ^ (string target) ^ "' is an acceptable name"}));
       (whitespace_and_value, tail) <- probe (tail_0, []);

       %% TODO -- cleaner approach?

       case whitespace_and_value of
	 | char :: tail ->
	   if white_char? char then
	     {
	      (whitespace, value) <- parse_WhiteSpace whitespace_and_value;
	      return ({target = target,
		       value  = Some (whitespace, value)},
		      tail)
	      }
	   else
	     {
	      (when true
	       (error {kind        = Syntax,
		       requirement = "PI requires whitespace between name and value.",
		       start       = start,
		       tail        = tail,
		       peek        = 10,
		       we_expected = [("( #x9 | #xA | #xD | #x20 )", "at least one character of whitespace")],
		       but         = "no whitespace was seen",
		       so_we       = "pretend some (vacuous) whitespace was seen"}));
	      return ({target = target,
		       value  = Some ([], whitespace_and_value)},
		      tail)
	     }
	 | _ ->
	     return ({target = target,
		      value  = None},
		     tail_0)
	  }

endspec