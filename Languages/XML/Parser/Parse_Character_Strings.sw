
XML qualifying spec

  import Parse_Literals

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %%%          Character_Strings                                                                   %%%
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %%
  %%  [3]  S         ::=  (#x20 | #x9 | #xD | #xA)+
  %%
  %% [14]  CharData  ::=  [^<&]* - ([^<&]* ']]>' [^<&]*)
  %%
  %% [15]  Comment   ::=  '<!--' ((Char - '-') | ('-' (Char - '-')))* '-->'
  %%
  %% [18]  CDSect    ::=  CDStart CData CDEnd 
  %% [19]  CDStart   ::=  '<![CDATA[' 
  %% [20]  CData     ::=  (Char* - (Char* ']]>' Char*)) 
  %% [21]  CDEnd     ::=  ']]>'
  %%
  %%  Note that the anonymous rule about characters (see section below on WFC's) implicitly 
  %%  restricts the characters that may appear in CharData to be Char's.
  %%
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  %% -------------------------------------------------------------------------------------------------
  %%
  %%  [3]  S          ::=  (#x20 | #x9 | #xD | #xA)+
  %%
  %% -------------------------------------------------------------------------------------------------

  def parse_WhiteSpace (start : UChars) : Required WhiteSpace =
    let
       def probe (tail, rev_whitespace) =
	 case tail of
	   | char :: scout ->
	     if white_char? char then
	       probe (scout, cons (char, rev_whitespace))
	     else
	       return (rev rev_whitespace,
		       tail)
	   | _ ->
	     return (rev rev_whitespace,
		     tail)
    in
      probe (start, [])

  %% -------------------------------------------------------------------------------------------------
  %%
  %% [14]  CharData  ::=  [^<&]* - ([^<&]* ']]>' [^<&]*)
  %%
  %% -------------------------------------------------------------------------------------------------

  def parse_CharData (start : UChars) : (Option CharData) * UChars =
    let 
       def probe (tail, rev_char_data) =
	 case tail of
	   | 93 :: 93 :: 62 (* ']]>' *) :: _ -> (Some (rev rev_char_data), tail)	
	   | char :: scout -> 
	     if char_data_char? char then
	       %% note that char_data_char? is false for 60 (* '<' *) and 38 (* '&' *) 
	       probe (scout, cons (char, rev_char_data))
	     else
	       (Some (rev rev_char_data),
		tail)
	   | _ ->
	     (Some (rev rev_char_data),
	      tail)
    in
      probe (start, [])

  %% -------------------------------------------------------------------------------------------------
  %%
  %% [15]  Comment   ::=  '<!--' ((Char - '-') | ('-' (Char - '-')))* '-->'
  %%
  %% -------------------------------------------------------------------------------------------------

  def parse_Comment (start : UChars) : Required Comment	=
    %% assumes we're past initial '<!--'
    let
       def probe (tail, rev_comment) =
	 case tail of
	   | 45 :: 45 (* '--' *) :: scout ->
	     (case scout of
		| 62  (* '>' *) :: tail ->
		  return (rev rev_comment, 
			  tail)
		| _ ->
		  {
		   error {kind        = Syntax,
			  requirement = "'--' may not appear in a comment.",
			  problem     = "'--' appears inside a comment.",
			  expected    = [("'>'",   "remainder of '-->', to end comment")],
			  start       = start,
			  tail        = tail,
			  peek        = 10,
			  action      = "Leave bogus '--' in comment"};
		   probe (tl tail, cons (45, cons (45, rev_comment)))
		   })
	   | [] ->
	     hard_error {kind        = EOF,
			 requirement = "A comment must terminate with '-->'.",
			 problem     = "EOF occured first.",
			 expected    = [("'-->'",   "end of comment")],
			 start       = start,
			 tail        = start,
			 peek        = 0,
			 action      = "immediate failure"}
	   | char :: tail ->
	     probe (tail, cons (char, rev_comment))
    in
      probe (start, [])

  %% -------------------------------------------------------------------------------------------------
  %%
  %% [18]  CDSect    ::=  CDStart CData CDEnd 
  %% [19]  CDStart   ::=  '<![CDATA[' 
  %% [20]  CData     ::=  (Char* - (Char* ']]>' Char*)) 
  %% [21]  CDEnd     ::=  ']]>'
  %%
  %% -------------------------------------------------------------------------------------------------

  def parse_CDSect (start : UChars) : Required CDSect =
    %% parse_CDSECT assumes we're past "<![CDATA["
    let
       def probe (tail, rev_comment) =
	 case tail of
	   | 93 :: 93 :: 62 (* ']]>' *) :: tail ->
	     return ({cdata = rev rev_comment}, 
		     tail)
	   | [] ->
	     hard_error {kind        = EOF,
			 requirement = "A CDSect must terminate with ']]>'.",
			 problem     = "EOF occurred first",
			 expected    = [("']]>'",   "end of CDSect")],
			 start       = start,
			 tail        = start,
			 peek        = 0,
			 action      = "immediate failure"}
	   | char :: tail ->
	     probe (tail, cons (char, rev_comment))
    in
      probe (start, [])

endspec
