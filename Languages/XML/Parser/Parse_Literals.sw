
XML qualifying spec

  import Parse_References

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %%%          Literals                                                                            %%%
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %%
  %%   [9]  EntityValue     ::=  '"' ([^%&"] | PEReference | Reference)* '"'  |  "'" ([^%&'] | PEReference | Reference)* "'"
  %%
  %%  [10]  AttValue        ::=  '"' ([^<&"] | Reference)* '"' |  "'" ([^<&'] | Reference)* "'"
  %%
  %% *[11]  SystemLiteral   ::=  ('"' [^"]* '"') | ("'" [^']* "'") 
  %%   ==>
  %% [K32]  SystemuLiteral  ::=  QuotedText
  %%                
  %% *[12]  PubidLiteral    ::=  '"' PubidChar* '"' | "'" (PubidChar - "'")* "'" 
  %%   ==>
  %% [K33]  PubidLiteral    ::=  QuotedText
  %%                
  %%                                                             [KC: Proper Pubid Literal]   
  %%
  %%  [13]  PubidChar       ::=  #x20 | #xD | #xA | [a-zA-Z0-9] | [-'()+,./:=?;!*#@$_%]
  %%
  %% [K34]  QuotedText      ::=  ('"' [^"]* '"') | ("'" [^']* "'") 
  %%
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  %% -------------------------------------------------------------------------------------------------
  %%
  %%   [9]  EntityValue     ::=  '"' ([^%&"] | PEReference | Reference)* '"'  |  "'" ([^%&'] | PEReference | Reference)* "'"
  %%
  %% -------------------------------------------------------------------------------------------------

  def parse_EntityValue (start : UChars) : Required EntityValue =
    let 
       def probe (tail, rev_char_data, rev_items, qchar) =
	 case tail of

	   | 38  (* '&' *)   :: tail -> 
	     {
	      %% parse_Reference assumes we're just past the ampersand.
	      (ref, tail) <- parse_Reference tail;
	      probe (tail,
		     [], 
		     cons (Ref ref,
			   rev_items), 
		     qchar)
	     }
	   | 37  (* '%' *)   :: tail -> 
             {
	      (ref, tail) <- parse_PEReference tail;
	      probe (tail,
		     [], 
		     cons (PERef ref,
			   rev_items), 
		     qchar)}

	   | char :: tail -> 
	     if char = qchar then
	       return ({qchar = qchar,
			items = (case rev_char_data of
				   | [] -> rev rev_items
				   | _ -> 
				     rev (cons (NonRef (rev rev_char_data),
						rev_items)))},
		       tail)
	     else
	       probe (tail,
		      cons (char, rev_char_data), 
		      rev_items,
		      qchar)
	   | _ ->
	     hard_error {kind        = EOF,
			 requirement = "A quoted expression was being parsed as the value for an Entity declaration.",
			 start       = start,
			 tail        = start,
			 peek        = 0,
			 we_expected = [("[" ^ (string [qchar]) ^ "] ", 
					 (if qchar = 39 then "apostrophe" else "double-quote") ^ "to terminate quoted text")],
			 but         = "EOF occurred before it terminated",
			 so_we       = "fail immediately"}
    in
      case start of
	| 34 (* double-quote *) :: tail -> probe (tail, [], [], 34)
	| 39 (* apostrophe   *) :: tail -> probe (tail, [], [], 39)
        | char :: _ ->
	  hard_error {kind        = Syntax,
		      requirement = "A quoted expression is needed for the value of an Entity declaration.",
		      start       = start,
		      tail        = start,
		      peek        = 10,
		      we_expected = [("['\"] ", "apostrophe or double-quote to begin quoted text")],   % silly comment to appease emacs: ")
		      but         = (describe_char char) ^ " was seen instead",
		      so_we       = "fail immediately"}
        | _ ->
	  hard_error {kind        = Syntax,
		      requirement = "A quoted expression is needed for the value of an Entity declaration.",
		      start       = start,
		      tail        = start,
		      peek        = 10,
		      we_expected = [("['\"] ", "apostrophe or double-quote to begin quoted text")],   % silly comment to appease emacs: ")
		      but         = "EOF occurred first",
		      so_we       = "fail immediately"}

  %% -------------------------------------------------------------------------------------------------
  %%
  %%  [10]  AttValue        ::=  '"' ([^<&"] | Reference)* '"' |  "'" ([^<&'] | Reference)* "'"
  %%
  %% -------------------------------------------------------------------------------------------------

  def parse_AttValue (start : UChars) : Possible AttValue =
    let 
       def probe (tail, rev_char_data, rev_items, qchar) =
	 case tail of

	   | 60  (* '<' *)   :: _ -> 
	     {
	      error {kind        = Syntax,
		     requirement = "'<', '&', and '\"' are not allowed in an attribute value.",            % silly comment to appease emacs: ")
		     start       = start,
		     tail        = tail,
		     peek        = 10,
		     we_expected = [("[^<&\"]", "Something other than open-angle, ampersand, or quote")],  % silly comment to appease emacs: ")
		     but         = "'<' was seen",
		     so_we       = "pretend '<' is a normal character"};
	      probe (tail,
		     [60], 
		     cons (NonRef (rev rev_char_data),
			   rev_items),
		     qchar)
	     }

	   | 38  (* '&' *)   :: tail -> 
	     {
	      %% parse_Reference assumes we're just past the ampersand.
	      (ref, tail) <- parse_Reference tail;
	      probe (tail,
		     [], 
		     cons (Ref ref,
			   rev_items), 
		     qchar)
	     }
	   | char :: tail -> 
	     if char = qchar then
	       return (Some {qchar = qchar,
			     items = (case rev_char_data of
					| [] -> rev rev_items
					| _ -> 
					  rev (cons (NonRef (rev rev_char_data),
						     rev_items)))},
		       tail)
	     else
	       probe (tail,
		      cons (char, rev_char_data), 
		      rev_items,
		      qchar)
	   | _ ->
	     hard_error {kind        = EOF,
			 requirement = "An attribute value was expected.", 
			 start       = start,
			 tail        = tail,
			 peek        = 10,
			 we_expected = [("[" ^ (string [qchar]) ^ "] ", 
					 (if qchar = 39 then "apostrophe" else "double-quote") ^ "to terminate quoted text")],
			 but         = "EOF occurred first",
			 so_we       = "fail immediately"}
    in
      case start of
	| 34 (* double-quote *) :: tail -> probe (tail, [], [], 34)
	| 39 (* apostrophe   *) :: tail -> probe (tail, [], [], 39)
        | _ ->
	  return (None, start)

  %% -------------------------------------------------------------------------------------------------
  %%
  %% [K32]  SystemuLiteral  ::=  QuotedText
  %%
  %% -------------------------------------------------------------------------------------------------

  def parse_SystemLiteral (start : UChars) : Required SystemLiteral =
    parse_QuotedText start

  %% -------------------------------------------------------------------------------------------------
  %%                
  %% [K33]  PubidLiteral    ::=  QuotedText
  %%                
  %%                                                             [KC: Proper Pubid Literal]   
  %%
  %%  [13]  PubidChar       ::=  #x20 | #xD | #xA | [a-zA-Z0-9] | [-'()+,./:=?;!*#@$_%]
  %%
  %% -------------------------------------------------------------------------------------------------
  %%
  %%  [KC: Proper Pubid Literal]                   [K33] -- pubid_literal?
  %%
  %%    all chars are PubidChar's
  %%
  %% -------------------------------------------------------------------------------------------------

  def parse_PubidLiteral (start : UChars) : Required PubidLiteral =
    let 
       def find_bad_char tail =
	 case tail of
	   | [] -> None
	   | char :: tail -> 
	     if pubid_char? char then
	       find_bad_char tail
	     else
	       Some char
    in
    {
     (qtext, tail) <- parse_QuotedText start;
     case find_bad_char qtext.text of
       | None ->
         return (qtext, tail)
       | Some bad_char ->
	 {
	  (error {kind        = KC,
		  requirement = "Only PubidChar's are allowed in a PubidLiteral.",
		  start       = start,
		  tail        = tail,
		  peek        = 10,
		  we_expected = [("([#x20 | #xD | #xA | [a-zA-Z0-9] | [-'()+,./:=?;!*#@$_%])*", "pubid chars")],
		  but         = (describe_char bad_char) ^ " was seen",
		  so_we       = "pretend that is a pubid character"});
	  return (qtext, tail)
	  }}
     

  %% -------------------------------------------------------------------------------------------------
  %%
  %% [K34]  QuotedText      ::=  ('"' [^"]* '"') | ("'" [^']* "'") 
  %%
  %% -------------------------------------------------------------------------------------------------

  def parse_QuotedText (start : UChars) : Required QuotedText =
    let 
       def probe (tail, rev_text, qchar) =
	 case tail of
	   | char :: tail -> 
	     if char = qchar then
	       return ({qchar = qchar,
			text  = rev rev_text},
		       tail)
	     else
	       probe (tail,
		      cons (char, rev_text),
		      qchar)
	   | _ ->
	     hard_error {kind        = EOF,
			 requirement = "Quoted text was required.",
			 start       = start,
			 tail        = tail,
			 peek        = 10,
			 we_expected = [("[" ^ (string [qchar]) ^ "] ", 
					 (if qchar = 39 then "apostrophe" else "double-quote") ^ "to terminate quoted text")],
			 but         = "EOF occurred first",
			 so_we       = "fail immediately"}
    in
      case start of
	| 34 (* double-quote *) :: tail -> probe (tail, [], 34)
	| 39 (* apostrophe   *) :: tail -> probe (tail, [], 39)
        | char :: _ ->
	  hard_error {kind        = Syntax,
		      requirement = "Quoted text was required.",
		      start       = start,
		      tail        = start,
		      peek        = 10,
		      we_expected = [("['\"] ", "apostrophe or double-quote to begin quoted text")], % silly comment to appease emacs: ")
		      but         = (describe_char char) ^ " was seen instead",
		      so_we       = "fail immediately"}
        | _ ->
	  hard_error {kind        = Syntax,
		      requirement = "Quoted text was required.",
		      start       = start,
		      tail        = start,
		      peek        = 10,
		      we_expected = [("['\"] ", "apostrophe or double-quote to begin quoted text")], % silly comment to appease emacs: ")
		      but         = "EOF occurred first",
		      so_we       = "fail immediately"}

endspec
