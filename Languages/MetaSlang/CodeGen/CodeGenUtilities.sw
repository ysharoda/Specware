spec
import /Languages/MetaSlang/Specs/StandardSpec

% this is used to distinguish "real" product from "record-products"
 op productfieldsAreNumbered: [a] List (String * a) -> Boolean
def productfieldsAreNumbered (fields) =
  let
    def fieldsAreNumbered0 (i, fields) =
      case fields of
	| [] -> true
	| (id, _)::fields -> id = Nat.show (i) && fieldsAreNumbered0 (i+1, fields)
  in
  fieldsAreNumbered0 (1, fields)


op patternFromSort: Option Sort * Position -> Pattern
def patternFromSort (optsrt, b) =
  let
    def mkVarPat (id, srt) =
      VarPat ((id, srt), b)
  in
  case optsrt of
    | None -> RecordPat ([], b)
    | Some srt -> 
      case srt of
	| Product ([], _) -> RecordPat ([], b)
	| Product (fields, _) ->
	  if productfieldsAreNumbered fields then
	    RecordPat (List.map (fn (id, srt) -> (id, mkVarPat ("x"^id, srt))) fields, b)
	  else mkVarPat ("x", srt)
	| _ -> mkVarPat ("x", srt)

op argTermFromSort: Option Sort * MS.Term * Position -> MS.Term
def argTermFromSort (optsrt, funterm, b) =
  let
    def mkVarTerm (id, srt) =
      Var ((id, srt), b)
  in
  case optsrt of
    | None -> funterm
    | Some srt -> 
      let term = 
        case srt of
	  | Product (fields, _) ->
	    if productfieldsAreNumbered fields then
	      Record (List.map (fn (id, srt) -> (id, mkVarTerm ("x"^id, srt))) fields, b)
	    else mkVarTerm ("x", srt)
	  | _ -> mkVarTerm ("x", srt)
      in
      Apply (funterm, term, b)

op recordTermFromSort: Sort * Position -> MS.Term
def recordTermFromSort (srt, b) =
  let
    def mkVarTerm (id, srt) =
      Var ((id, srt), b)
  in
      let term = 
        case srt of
	  | Product (fields, _) ->
	    if productfieldsAreNumbered fields then
	      Record (List.map (fn (id, srt) -> (id, mkVarTerm ("x"^id, srt))) fields, b)
	    else mkVarTerm ("x", srt)
	  | _ -> mkVarTerm ("x", srt)
      in term

 op getAccessorOpName: String * QualifiedId * String -> QualifiedId
def getAccessorOpName (srtName, qid as Qualified (q, id), accid) =
  let sep = "_" in
  Qualified (q, "project"^sep^srtName^sep^accid)

op getRecordConstructorOpName: QualifiedId  -> QualifiedId
def getRecordConstructorOpName (qid as Qualified (q, id)) =
  let sep = "_" in
  Qualified (q, "mk_Record"^sep^id)

end-spec
