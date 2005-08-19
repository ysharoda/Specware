% Temporary test function for translation.

Translate qualifying spec
  import /Languages/SpecCalculus/Semantics/Specware  % for the Specware monad
  import translate TranslateMSToPC by {Set._ +-> Blech._}

  op +++ infixl 25    : [a]   FSeq a * FSeq a -> FSeq a
  def +++ = List.++

  op fSeqLength : [a] FSeq a -> Nat
  def fSeqLength = List.length

  op test : String -> Boolean
  def test path =
    let prog = {
      cleanEnv;
      currentUID <- pathToCanonicalUID ".";
      setCurrentUID currentUID;
      path_body <- return (removeSWsuffix path);
      unitId <- pathToRelativeUID path_body;
      position <- return (String (path, startLineColumnByte, endLineColumnByte path_body));
      catch {
        (val,_,_) <- evaluateUID position unitId;
        case val of
          | Spec spc -> {
              ctxt <- specToContext spc;
              print (printContext ctxt);
              return ()
            }
          | _ -> {
              print "Unit is not a spec";
              return ()
            }
      } (fileNameHandler unitId);
      return true
    } in
    runSpecCommand (catch prog toplevelHandler)
endspec

