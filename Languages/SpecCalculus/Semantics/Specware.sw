\section{Specware toplevel}

It seems clear now that some of specs that make up the calculus need
some amount of refactoring.

\begin{spec}
Specware qualifying spec {
  import Evaluate/Term 
  import Environment 
  import SpecPath
  % import ../../MetaSlang/Specs/PosSpec    
  import ../../MetaSlang/Specs/Position     
  import ../AbstractSyntax/Printer % for showUI
\end{spec}

The following is what starts Specware. It initializes the state and
enters the read/eval/print loop. 

I would like to remove the dummy argument from the following but
then it seems to be executed at compile time ... and fails
immediately. Perhaps it won't be a problem when the bootstrap
changes and when the toplevel loop actually does something.

This is not used at present.

\begin{spec}
  op runSpecware : () -> Boolean
  def runSpecware () =
    case catch toplevelLoop toplevelHandler initialSpecwareState of
      | (Ok val,_)      -> fail "Specware toplevel loop terminated unexpectedly"
      | (Exception _,_) -> fail "Specware toplevel handler failed"
\end{spec}

For the near term, we have a variation of the above which evaluates
a given URI without looping.

evaluateTerm has the side effect of parsing, loading, and
caching the unit referenced by the uri, plus all the units that unit
depends on.  

Roadmap:
evaluateTerm calls evaluateURI, which calls searchFileSystemForURI,
which calls loadFile, which calls evaluateTerm on expressions parsed.

In all of the following, we set the initial value of the currentURI to
the current directory suffixed with "/.". The current URI is used to resolve
relative URI references. These are URIs that do no begin with "/". Setting
the current URI in this way means that the user can provide a top level
relative path. If a relative path is given at the toplevel, then the canonical 
path is obtained by discarding the "." in the current URI and appending
the relative path. See URI.sl. In fact any non-empty string would do
in place of ".".

The toplevel functions that follow are all meant to be called from
Lisp. They return a boolean. Returning true means the that unit has been
evaluated without raising an exception. They return false only when the
toplevel handler is called.

Returning a boolean is useful in order to convey whether the request
to evaluate something was successful. At present, the failure of the
toplevel is used within the bootstrap. If the toplevel fails, then lisp
exists with a non-zero status and hence the bootstrap fails.

\begin{spec}
  op runSpecwareURI : String -> Boolean
  def runSpecwareURI path = 
    let run = {
      currentURI <- pathToCanonicalURI ".";
      setCurrentURI currentURI;
      path_body <- return (removeSWsuffix path);
      uri <- pathToRelativeURI path_body;
      position <- return (String (path, startLineColumnByte, endLineColumnByte path_body));
      evaluateURI position uri;
      return true
    } in
    case catch run toplevelHandler initialSpecwareState of
      | (Ok val,_) -> val
      | (Exception _,_) -> fail "Specware toplevel handler failed"
\end{spec}

evaluateUnitId is designed to be called from application programs to
get a unit from a unit id string.

\begin{spec}
  op evaluateUnitId: String -> Option Value
  def evaluateUnitId(path) =
    let run = {
      restoreSavedSpecwareState;
      currentURI <- pathToCanonicalURI ".";
      setCurrentURI currentURI;
      %% removeSWsuffix could be generalized to extractURIpath
      %% and then the code to create the position would use the
      %% start and end positions of path_body within path
      path_body <- return (removeSWsuffix path);
      uri <- pathToRelativeURI path_body;
      position <- return (String (path, startLineColumnByte, endLineColumnByte path_body));
      (val,_,_) <- evaluateURI position uri;
      saveSpecwareState;
      return val
    } in
    case run ignoredState of
      | (Ok val,_) -> Some val
      | (Exception _,_) -> (warn "evaluateUnitId failed"; None)
\end{spec}


We provide two functions (callable from the Lisp read-eval-print loop)
that invoke the corresponding evaluation functions for the Spec Calculus.
The first just evaluates a URI. The second evaluates a URI and then
compiles the resulting specification to lisp.

\begin{spec}
  op evaluateURI_fromLisp : String -> Boolean
  def evaluateURI_fromLisp path = 
    let run = {
      restoreSavedSpecwareState;
      currentURI <- pathToCanonicalURI ".";
      setCurrentURI currentURI;
      %% removeSWsuffix could be generalized to extractURIpath
      %% and then the code to create the position would use the
      %% start and end positions of path_body within path
      path_body <- return (removeSWsuffix path);
      uri <- pathToRelativeURI path_body;
      position <- return (String (path, startLineColumnByte, endLineColumnByte path_body));
      catch {
        evaluateURI position uri;
        return ()
      } (fileNameHandler uri);
      saveSpecwareState;
      return true
    } in
    case catch run toplevelHandler ignoredState of
      | (Ok val,_) -> val
      | (Exception _,_) -> fail "Specware toplevel handler failed"
\end{spec}

\begin{spec}
  op fileNameHandler : RelativeURI -> Exception -> SpecCalc.Env ()
  def fileNameHandler unitId except =
    case except of
      | URINotFound (position, badUnitId) ->
         if badUnitId = unitId then
           return ()
         else
           raise except
      | _ -> raise except
\end{spec}

\begin{spec}
  op evaluatePrint_fromLisp : String -> Boolean
  def evaluatePrint_fromLisp path = 
    let run = {
      restoreSavedSpecwareState;
      currentURI <- pathToCanonicalURI ".";
      setCurrentURI currentURI;
      path_body <- return (removeSWsuffix path);
      uri <- pathToRelativeURI path_body;
      position <- return (String (path, startLineColumnByte, endLineColumnByte path_body));
      evaluatePrint (URI uri, position);
      saveSpecwareState;
      return true
    } in
    case catch run toplevelHandler ignoredState of
      | (Ok val,_) -> val
      | (Exception _,_) -> fail "Specware toplevel handler failed"
\end{spec}

The following corresponds to the :show command.

\begin{spec}
  op listLoadedUnits : () -> Boolean
  def listLoadedUnits () = 
    let run = {
      restoreSavedSpecwareState;
      globalContext <- getGlobalContext;
      uriList <-
        return (foldMap (fn lst -> fn dom -> fn _ (* cod *) -> Cons (dom, lst)) 
		        [] 
			globalContext);
      print (ppFormat (ppSep ppNewline (map (fn uri -> ppString (uriToString uri)) uriList)));
      saveSpecwareState;     % shouldn't change anything
      return true
    } in
    case catch run toplevelHandler ignoredState of
      | (Ok val,_) -> val
      | (Exception _,_) -> fail "Specware toplevel handler failed"
\end{spec}

\begin{spec}
  op evaluateLispCompile_fromLisp : String * Option String -> Boolean
  def evaluateLispCompile_fromLisp (path,targetFile) = 
    let target =
      case targetFile of
        | None -> None
        | Some name -> Some (maybeAddSuffix name ".lisp") in
    let run = {
      restoreSavedSpecwareState;
      currentURI <- pathToCanonicalURI ".";
      setCurrentURI currentURI;
      path_body <- return (removeSWsuffix path);
      uri <- pathToRelativeURI path_body;
      position <- return (String (path, startLineColumnByte, endLineColumnByte path_body));
      spcInfo <- evaluateURI position uri;
      evaluateLispCompile (spcInfo, (URI uri, position), target);
      saveSpecwareState;
      return true
    } in
    case catch run toplevelHandler ignoredState of
      | (Ok val,_) -> val
      | (Exception _,_) -> fail "Specware toplevel handler failed"
\end{spec}


\begin{spec}
  op evaluateURI_fromJava : String -> Boolean
  def evaluateURI_fromJava path = 
    let run = {
      restoreSavedSpecwareState;
      currentURI <- pathToCanonicalURI ".";
      setCurrentURI currentURI;
      %% removeSWsuffix could be generalized to extractURIpath
      %% and then the code to create the position would use the
      %% start and end positions of path_body within path
      path_body <- return (removeSWsuffix path);
      uri <- pathToRelativeURI path_body;
      position <- return (String (path, startLineColumnByte, endLineColumnByte path_body));
      catch {
        evaluateURI position uri;
        return ()
      } (fileNameHandler uri);
      saveSpecwareState;
      return true
    } in
    case catch run toplevelHandlerForJava ignoredState of
      | (Ok val,_) -> val
      | (Exception _,_) -> fail "Specware toplevel handler failed"
\end{spec}

When the lisp file for Specware is compiled and loaded, the following
will initialize a lisp variable holding the initial state for the
Specware environment. Subsequent invocations of the evaluate functions
above, retrieve and restore the saved state, do some work, and save the
state again in the lisp variable.

\begin{spec}
  op initializeSavedSpecwareState : ()
  def initializeSavedSpecwareState = 
    case saveSpecwareState initialSpecwareState of
      | (Ok val,_) -> toScreen "Initializing Specware state ..."
      | (Exception _,_) -> fail "initializeSavedSpecwareState failed"

  % op ignoredState : State % see Signature.sw
  def ignoredState = initialSpecwareState
\end{spec}

\begin{spec}
  op removeSWsuffix : String -> String
  def removeSWsuffix path =
    case (rev (explode path)) of
      | #w :: #s :: #. ::rest -> implode (rev rest)
      | _ -> path
\end{spec}

Maybe this belongs in Evaluate/Generate.sw and applied to
in all cases where a Generate term is evaluated rather
than only at toplevel invocations?

\begin{spec}
  op maybeAddSuffix : String -> String -> String
  def maybeAddSuffix path suffix =
    if (List.member (#., explode path)) then
      path
    else
      path ^ suffix
\end{spec}

Eventually, this will be a read/eval/print loop for Specware.
At present we are using the Lisp interface and the following is
not used.

Right now this returns a boolean to be consistent with the hander.
When written, this should never return. All the Boolean's should
become unit types.

\begin{spec}
  op toplevelLoop : SpecCalc.Env Boolean
  def toplevelLoop = return true
\end{spec}

This is the toplevel exception handler. Eventually, when we have our own
read-eval-print loop, this will be used only for uncaught exceptions. For
now, this handles all exceptions, For all exceptions except Fail, it
constructs and prints a message.  For Fail exceptions, it calls fail to
enter the Lisp debugger as this indicates an internal (Specware) error.

Note that the toplevel handler is now monomorphic. All toplevel
functions have unit type (within the monad). It seems to make
sense that no toplevel functions return anything.

\begin{spec}
  % op Specware.toplevelHandler : Exception -> SpecCalc.Env Boolean % See Signature.sw
  def toplevelHandler except =
    {cleanupGlobalContext;		% Remove InProcess entries
     saveSpecwareState;			% So work done before error is not lost
     message <- return (printException except);
     return (gotoErrorLocation except);
     if specwareWizard? then
       fail message
     else
       print message;
     return false}

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
              ^ "\n  found at " ^ (printAll position)

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
        
      %% OldTypeCheck is a temporary hack to avoid gratuitous 0.0-0.0 for position
      | OldTypeCheck str ->
		"Type errors:\n" ^ str

      | _ -> 
		"Unknown exception: " 
              ^ (System.toString except)

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
    (foldl printErr ("","") errs).1
	   
  op gotoErrorLocation: Exception -> ()
  def gotoErrorLocation except = 
   case getFirstErrorLocation except of
     | Some (File (file, (left_line, left_column, left_byte), right)) ->   
       IO.gotoFilePosition (file, left_line, left_column)
     | _ -> ()

  op getFirstErrorLocation : Exception -> Option Position
  def getFirstErrorLocation except =
    case except of
      | Unsupported  (position,_) -> Some position
      | URINotFound  (position,_) -> Some position
      | FileNotFound (position,_) -> Some position
      | SpecError    (position,_) -> Some position
      | MorphError   (position,_) -> Some position
      | DiagError    (position,_) -> Some position
      | TypeCheck    (position,_) -> Some position
      | Proof        (position,_) -> Some position
      | TypeCheckErrors errs      -> getFirstRealPosition errs
      | _ -> None

  op getFirstRealPosition : List (String * Position) -> Option Position
  def getFirstRealPosition errs =
    case errs of
      | [] -> None
      | (err,pos)::rest ->
        (case pos of
	   | File (file, (left_line, left_column, left_byte), right) ->
	     if left_line = 0 & left_column = 0
	       then getFirstRealPosition rest
	      else Some pos
	   | _ -> getFirstRealPosition rest)
\end{spec}

\begin{spec}
  op toplevelHandlerForJava: Exception -> SpecCalc.Monad Boolean
  def toplevelHandlerForJava except =
    {cleanupGlobalContext;		% Remove InProcess entries
     saveSpecwareState;			% So work done before error is not lost
     return (reportExceptionToJava except);
     return false}

  op reportExceptionToJava: Exception -> ()
  def reportExceptionToJava except =
    case except of
      | Unsupported  (position,msg) -> 
        reportErrorAtPosToJava(position,"Unsupported operation: " ^ msg)
      | URINotFound  (position,uri) ->
	reportErrorAtPosToJava(position,"Unknown unit " ^ (showRelativeURI uri))
      | FileNotFound (position,uri) ->
	reportErrorAtPosToJava(position,"Unknown unit " ^ (showRelativeURI uri))
      | SpecError    (position,msg) ->
	reportErrorAtPosToJava(position,"Error in specification: " ^ msg)
      | MorphError   (position,msg) ->
	reportErrorAtPosToJava(position,"Error in morphism: " ^ msg)
      | DiagError    (position,msg) ->
	reportErrorAtPosToJava(position,"Diagram error: " ^ msg)
      | TypeCheck    (position,msg) ->
	reportErrorAtPosToJava(position,"Type error: " ^ msg)
      | Proof        (position,msg) ->
	reportErrorAtPosToJava(position,"Proof error: " ^ msg)
      | TypeCheckErrors errs      -> reportTypeErrorsToJava errs
      | _ -> reportErrorToJava("",0,0,printException except)

  op reportTypeErrorsToJava : List(String * Position) -> ()
  def reportTypeErrorsToJava errs =
    app (fn (msg,pos) -> reportErrorAtPosToJava(pos,msg)) errs

  op reportErrorAtPosToJava: Position * String -> ()
  def reportErrorAtPosToJava(pos,msg) =
    case pos of
      | File (file, (left_line, left_column, left_byte), right) ->
        reportErrorToJava(file,left_line,left_column,msg)
      | _ -> reportErrorToJava("",0,0,msg)

  op reportErrorToJava: String * Nat * Nat * String -> ()
  %% defined in /Gui/src/Lisp/init-java-connection.lisp

\end{spec}


getBaseSpec is a bit of a hack used by colimit to avoid some bootstrapping 
and typing issues.

\begin{spec}
  def SpecCalc.getBaseSpec () =
    let run : SpecCalc.Env Spec = 
	{restoreSavedSpecwareState;
	 base_URI               <- pathToRelativeURI "/Library/Base";
	 (Spec base_spec, _, _) <- SpecCalc.evaluateURI (Internal "base") base_URI;
	 saveSpecwareState;
	 return base_spec} 
    in
    let def myHandler except = {toplevelHandler except; return emptySpec} 
    in
    case catch run myHandler ignoredState of
      | (Ok base_spec,_) -> base_spec
      | (Exception _,_) -> fail "Can't find base spec!"
}
\end{spec}
