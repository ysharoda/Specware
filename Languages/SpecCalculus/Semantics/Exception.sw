\section{Definition of the exception sort}

These are the exceptions that one might raise.  These should be defined
compositionally ... specs that need an exception should be able to extend
the sort.  We need exceptions for things like:

\begin{itemize}
\item environment: failing to find an op or sort id etc.
\item typechecking: 
\item io: can't open file, permisssions, etc
\item parsing
\end{itemize}

The thought was that \verb+Fail+ would be an exception that cannot
be caught.  As such it will take one to the lisp debugger. This needs
thought.

Many of the exceptions have a field which gives the location (in the
current file) where the error occurred. Putting the position here rather
than directly in the error message means that all error messages display
the position in a uniform way and can more easily be conveyed to the UI.
On the other hand, it seems there are places where the exception is raised
but where the position information is unavailable. Needs thought.

A SyntaxError is one that is raised at the toplevel when the user
enters something bad. A ParserError is raised when the file parser fails.

\begin{spec}
spec
  import /Languages/SpecCalculus/AbstractSyntax/Printer

  sort Exception =
    | Fail         String 
    | FileNotFound  Position * RelativeURI
    | URINotFound  Position * RelativeURI
    | TypeCheck    Position * String
    | TypeCheckErrors List(String * Position)
    %% OldTypeCheck is a temporary hack to avoid gratuitous 0.0-0.0 for position
    | OldTypeCheck String              
    | Unsupported  Position * String
    | SyntaxError  String
    | ParserError  String   % Here the string is the filename.
    | DiagError    Position * String
    | SpecError    Position * String
    | MorphError   Position * String
    | CircularDefinition URI
    | Proof       Position * String

  op printException : Exception -> String
  def printException except =
    case except of

      | Fail str -> 
		"Fail: " ^ str

      | SyntaxError msg ->  
                "Syntax error: " ^ msg

      | ParserError fileName -> 
		"Syntax error for filename: " ^ fileName

      | Unsupported (position,str) ->
		"Unsupported operation: " ^ str
	      ^ "\n  found at " ^ (printAll position)

      | URINotFound (position, uri) ->
		"Unknown unit " ^ (showRelativeURI uri) 
              ^ "\n  referenced from " ^ (printAll position)

      | FileNotFound (position, uri) ->
		"Unknown unit " ^ (showRelativeURI uri) 
              ^ "\n  referenced from " ^ (printAll position)

      | SpecError (position,msg) ->
		"Error in specification: " ^ msg 
              ^ "\n  found " ^ (printAll position)

      | MorphError (position,msg) ->
		"Error in morphism: " ^ msg 
              ^ "\n  found at " ^ (printAll position)

      | DiagError (position,msg) ->
		"Diagram error: " ^ msg 
              ^ "\n  found at " ^ (printAll position)

      | TypeCheck (position, msg) ->
		"Type error: " ^ msg 
              ^ "\n  found at " ^ (printAll position)

      | Proof (position, msg) ->
		"Proof error: " ^ msg 
              ^ "\n  found at " ^ (printAll position)

      | CircularDefinition uri ->
		"Circular definition: " ^ showURI uri

      | TypeCheckErrors errs -> printTypeErrors errs
        
      | _ -> 
		"Unknown exception: " 
              ^ (System.toString except)

  op  numberOfTypeErrorsToPrint: Nat
  def numberOfTypeErrorsToPrint = 20

  op printTypeErrors : List(String * Position) -> String
  def printTypeErrors errs =
    let def printErr((msg,pos),(result,lastfilename)) =
          let filename = (case pos of
			    | File (filename, left, right) -> filename
			    | _ -> "")
          in (result ^ (if filename = lastfilename then print pos else printAll pos)
	       ^ " : " ^ msg ^ "\n",
	      filename)
    in
    (foldl printErr ("","") (firstN(errs,numberOfTypeErrorsToPrint))).1
     ++ (if (length errs) <= numberOfTypeErrorsToPrint
	  then ""
	 else "...  ("^Nat.toString(length errs - numberOfTypeErrorsToPrint)
             ^" additional type errors)")

  op  firstN: fa(a) List a * Nat -> List a
  def firstN(l,n) =
    if n = 0 then []
    else
    case l of
      | [] -> []
      | x::r -> cons(x,firstN(r,n-1))

endspec
\end{spec}
