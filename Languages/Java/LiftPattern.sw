spec

import /Languages/MetaSlang/Specs/Utilities
import /Languages/MetaSlang/Specs/Environment
import /Languages/SpecCalculus/Semantics/Environment
import /Languages/SpecCalculus/Semantics/Evaluate/Spec

sort Term = MS.Term
sort Env a = SpecCalc.Env a

sort Op = QualifiedId

sort Type = Sort
sort BaseType = (Sort | baseType?)

sort OpDef = Op * List Sort * Sort * List Var * Term

op unSupported: Op -> String

op baseType?: Sort -> Boolean

def baseType?(type) =
  boolSort?(type) or integerSort?(type) or natSort?(type)


op baseTypeAlias?: Spec * Sort -> Boolean
def baseTypeAlias?(spc,srt) =
  if baseType? srt then true
  else
    let usrt = unfoldBase(spc,srt) in
    case usrt of
      | Subsort(srt,_,_) -> baseTypeAlias?(spc,srt)
      | Quotient(srt,_,_) -> baseTypeAlias?(spc,srt)
      | _ -> baseType? usrt



op baseTypeId?: Id -> Boolean

def baseTypeId?(id) =
  id = "Boolean" or id = "Integer" or id = "Nat"


op userType?: Sort -> Boolean

(**
 * extended the definition of userType? to not only check whether it's not a base type, because it's also not a user
 * type, if it's something different then a name of a type identifier, e.g., an arrow type
 *)
def userType?(srt) =
  if baseType?(srt) then false
  else
    (case srt of
       | Base(qid,_,_) -> true
       %| Subsort(srt,_,_) -> userType?(srt)
       %| Quotient(srt,_,_) -> userType?(srt)
       | _ -> false
      )

def notAUserType?(srt) = ~(userType?(srt))

(**
 * implementation of the ut function as defined in v3:p38
 * returns the first user type occuring in the type srt from left to right, where the constituents of
 * each srt are also considered in case srt is an arrow type
 *)
op ut: Sort -> Option Sort
def ut(srt) = ut_internal userType? srt

op ut_internal: (Sort -> Boolean) -> Sort -> Option Sort
def ut_internal isUserType? srt =
  let
    def utlist(srts) =
      case srts of
	| [] -> None
	| srt::srts -> 
	  (case ut(srt) of
	     | Some s -> Some s
	     | None -> utlist(srts)
	    )
  in
  if isUserType?(srt) then Some srt
  else
    let domsrts = srtDom(srt) in
    case utlist(domsrts) of
      | Some s -> Some s
      | None -> 
        (case srt of
	   | Arrow(_,rng,_) -> ut(rng)
	   | _ -> None
	  )

op utlist_internal: (Sort -> Boolean) -> List Sort -> Option Sort
def utlist_internal isUserType? srts =
  case srts of
    | [] -> None
    | srt::srts ->
      (case ut_internal isUserType? srt of
	 | Some s -> Some s
	 | None -> utlist_internal isUserType? srts
	)

op utlist: List Sort -> Option Sort
def utlist(srt) = utlist_internal userType? srt

(** 
 * returns whether or not the given sort is "flat" meaning that it
is a simple identifier, not an arrow sort, for instance.
*)
op flatType?: Sort -> Boolean
def flatType?(srt) =
  case srt of
    | Base(qid,_,_) -> true
    | _ -> false

op baseVar?: Var -> Boolean
op userVar?: Var -> Boolean

def baseVar?(var) =
  let (id, srt) = var in
  baseType?(srt)

def userVar?(var) =
  ~ (baseVar?(var))

(**
  * disabled this op def, the new srtId op is in ToJavaBase; it also handles other kinds of types.
  *)
op srtId_v2: Sort -> Id 
def srtId_v2(srt as Base (Qualified (q, id), _, _)) = id

op mkNewOp: Op * Nat -> Op

def mkNewOp(oper, k) =
  let Qualified (qual, id) = oper in
  mkQualifiedId(qual, id ^ natToString(k))

op mkNewVar: Op * Nat * Sort -> Var

def mkNewVar(oper, k, t) =
  let Qualified (qual, id) = oper in
  (id ^ natToString(k), t)

op caseTerm?: Term -> Boolean

def caseTerm?(term) =
  case term of
    | Apply (Lambda (match, _), trm, _) -> true
    | _ -> false

op caseTerm: (Term | caseTerm?) -> Term

def caseTerm(term) =
  let Apply (Lambda (match, _), trm, _) = term in
    trm

op caseCases: (Term | caseTerm?) -> Match
def caseCases(trm) =
  let  Apply (Lambda (match, _), trm, _) = trm in
    match

op recordFieldsToTerms: List (Id * Term) -> List Term

def recordFieldsToTerms(fields) : List Term =
  case fields of 
    | [] -> []
    | (id,term)::fields -> cons(term, recordFieldsToTerms(fields))

op applyArgsToTerms: Term -> List Term

def applyArgsToTerms(args) =
  case args of
    | Record (fields,_) -> recordFieldsToTerms(fields)
    | term -> [term]

(**
 * this is the reverse of "applyArgsToTerms": it takes a term and a list of terms and
 * exchanges the terms in argTerm by the terms in args. If argTerm is not a Record, then
 * args must be a one-elementary list of terms, otherwise, the #elems in the Record fields
 * and the #elems in the args list must be the same.
 *) 
op exchangeArgTerms: Term * List Term -> Term
def exchangeArgTerms(argTerm,args) =
  case argTerm of
    | Record(fields,b) ->
      let zip = zip(fields,args) in
      let fields = map (fn((id,_),t) -> (id,t)) zip in
      Record(fields,b)
    | _ -> (case args of
	      | [t] -> t
	      | _ -> argTerm % should not happen
	   )

op opDom: Spec * Op -> List Sort
op opRange: Spec * Op -> Sort

def opDom(spc, oper) =
  let opinfo = findTheOp(spc, oper) in
  case opinfo of
    | Some (_,_,(_,srt),_) -> srtDom(srt)
    | _ -> let _ = unSupported(oper) in []

def opRange(spc, oper) =
  let opinfo = findTheOp(spc, oper) in
  case opinfo of
    | Some (_,_,(_,srt),_) -> srtRange(srt)
    | _ -> let _ = unSupported(oper) in boolSort

op srtDom: Sort -> List Sort
op srtRange: Sort -> Sort

def srtDom(srt) =
  let def domSrtDom(dom) =
       (case dom of
	  | Product (fields, _) -> map (fn (_,srt) -> srt) fields
	  | Subsort (subSrt, _, _) -> domSrtDom(subSrt)
	  | _ -> [dom]) in
  case srt of
    | Arrow (dom, rng, _) ->
    (let argSorts = domSrtDom(dom) in
     argSorts)
    | _ -> []

def srtRange(srt) =
  case srt of
    | Arrow (dom, rng, _) -> rng
    | _ -> srt

 op patternNameOpt : Pattern       -> Option Id
 op patternNamesOpt: Pattern       -> Option (List Id)

 def patternNameOpt (pattern) = 
   case pattern of
     | VarPat((id,_),_) -> Some id 
     | _ -> None

 def patternNamesOpt (pattern) = 
   case pattern of
     | VarPat((id,_),_) -> Some [id]
     | RecordPat(fields,_) ->
         List.foldl (fn ((_,p), namesOpt) ->
		     case namesOpt of
		       | Some names ->
		       (case patternNameOpt(p) of
			  | Some name -> Some (names ++ [name])
			  | _ -> None)
		       | _-> None)
	            (Some ([])) fields
     | _ -> None

op opDelta: Spec * Op -> List Var * Term

def opDelta(spc, oper) =
  let opDom = opDom(spc, oper) in
  let opRng = opRange(spc, oper) in
  let opinfo = findTheOp(spc, oper) in
  case opinfo of
    | Some (_,_,_,[(_,trm)]) ->
    (case trm of
       | Lambda ([(pat, cond, body)],_) ->
       let argNames = patternNamesOpt(pat) in
       (case argNames of
	  | Some argNames ->
	  let numArgs = length argNames in
	  let arity = length(opDom) in
	  if arity = numArgs
	    then 
	      let newArgs = map (fn(id, srt) -> (id,srt)) (argNames, opDom) in
	      (newArgs, body)
	  else
	    let _ = unSupported(oper) in ([], mkFalse())
	    | _ -> let _ = unSupported(oper) in ([], mkFalse()))
       | _ -> ([], trm))
     | _ -> let _ = unSupported(oper) in ([], mkFalse())


op srtTermDelta : Sort * Term -> List Var * Term
def srtTermDelta(srt,term) = srtTermDelta_internal(srt,term,false)

op srtTermDelta_internal: Sort * Term * Boolean-> List Var * Term
def srtTermDelta_internal(srt, term, fail?) =
  let opDom = srtDom(srt) in
  let opRng = srtRange(srt) in
  let
    def arityMismatchError(pat,args1,term,args2) = 
      "unsupported: pattern "^printPattern(pat)^" has "^Integer.toString(args1)^" args, but "
      ^printTerm(term)^" has "^Integer.toString(args2)^" args."
  in
  case term of
    | Lambda ([(pat, cond, body)],_) ->
    let argNames = patternNamesOpt(pat) in
    let arity = length(opDom) in
    (case argNames of
       | Some argNames ->
         (let numArgs = length argNames in
	  if arity = numArgs
	    then 
	      let newArgs = map (fn(id, srt) -> (id,srt)) (argNames, opDom) in
	      (newArgs, body)
	  else
	    if fail? then
	      fail(arityMismatchError(pat,numArgs,term,arity))
	    else ([],term)
	 )
       | _ -> 
	 if fail? then
	   fail(arityMismatchError(pat,0,term,arity))
	 else ([],term)
     )
    | _ -> ([], term)

op liftCaseTopCase: Op * (Term | caseTerm?) * Nat -> Term * Nat * List OpDef

def liftCaseTopCase(oper, body, k) =
  let caseTerm = caseTerm(body) in
  let cases = caseCases(body) in
  let caseBodys = map (fn (pat, cond, patBody) -> patBody) cases in
  let (newCaseBodys, newK, newOds) = liftCases(oper, caseBodys, k) in
  let newCases = ListPair.map (fn ((pat, cond, _), (newPatBody)) -> (pat, cond, newPatBody)) (cases, newCaseBodys) in
  let newTerm = mkApply(Lambda (newCases, noPos), caseTerm) in
  (newTerm, newK, newOds)
  

op liftCase: Op * Term * Nat -> Term * Nat * List OpDef
op liftCaseCase: Op * (Term | caseTerm?) * Nat -> Term * Nat * List OpDef
op liftCaseApply: Op * Term * Nat -> Term * Nat * List OpDef
op liftCaseRecord: Op * Term * Nat -> Term * Nat * List OpDef
op liftCaseIfThenElse: Op * Term * Nat -> Term * Nat * List OpDef
op liftCaseLet: Op * Term * Nat -> Term * Nat * List OpDef

def liftCase(oper, term, k) =
  if caseTerm?(term) then liftCaseCase(oper, term, k) else
  case term of
    | Var _ -> (term, k, [])
    | Fun _ -> (term, k, [])
    | Apply (opTerm, argsTerm, _) -> liftCaseApply(oper, term, k)
    | Record _ -> liftCaseRecord(oper, term, k)
    | IfThenElse _ -> liftCaseIfThenElse(oper, term, k)
    | Let _ -> liftCaseLet(oper, term, k)
    | _ -> let _ = unSupported(oper) in (term, k, [])

def liftCaseApply(oper, term as Apply (opTerm, argsTerm, _), k) =
  let args = applyArgsToTerms(argsTerm) in
  let (newArgs, newK, newOds) = liftCases(oper, args, k) in
  (mkApplication(opTerm, newArgs), newK, newOds)

def liftCaseRecord(oper, term as Record (fields,_), k) =
  let recordTerms = recordFieldsToTerms(fields) in
  let (newTerms, newK, newOds) = liftCases(oper, recordTerms, k) in
  let newFields = map (fn ((id, _), newTerm) -> (id, newTerm)) (fields, newTerms) in
    (mkRecord(newFields), newK, newOds)

def liftCaseIfThenElse(oper, term as IfThenElse(t1, t2, t3, _), k) =
  let args = [t1, t2, t3] in
  let ([newT1, newT2, newT3], newK, newOds) = liftCases(oper, args, k) in
    (MS.mkIfThenElse(newT1, newT2, newT3), newK, newOds)

def liftCaseLet(oper, term as Let (letBindings, letBody, _), k) =
  case letBindings of
    | [(VarPat (v, _), letTerm)] ->
    let args = [letTerm, letBody] in
    let ([newLetTerm, newLetBody], newK, newOds) = liftCases(oper, args, k) in
    (mkLet([(mkVarPat(v), newLetTerm)], newLetBody), newK, newOds)
    | _ -> let _ = unSupported(oper) in (term, k, [])

def liftCaseCase(oper, term, k) =
  let ttermSort = termSort(term) in
  let caseTerm = caseTerm(term) in
  let caseTermSort = termSort(caseTerm) in
  let (newCaseTerm, newK, newOds1) = liftCase(oper, caseTerm, k+1) in
  let cases = caseCases(term) in
  let caseBodys = map (fn (pat, cond, patBody) -> patBody) cases in
  let (newCaseBodys, finalK, newOds2) = liftCases(oper, caseBodys, newK) in
  let newCases = ListPair.map (fn ((pat, cond, _), (newPatBody)) -> (pat, cond, newPatBody)) (cases, newCaseBodys) in
  let freeVarsCases = List.foldr (fn (match,vs) -> vs ++ freeVarsMatch match) [] newCases in
  let freeVars = uniqueSort (fn ((id1, _), (id2, _)) -> compare(id1, id2)) freeVarsCases in
  let freeVarsSorts = map (fn(id, srt) -> srt) freeVars in
  let newOp = mkNewOp(oper, k) in
  let newOpSrt = mkArrow(mkProduct(cons(caseTermSort, freeVarsSorts)), ttermSort) in
  let newVar = mkNewVar(oper, k, caseTermSort) in
  let newOpTerm = mkApply(Lambda (newCases, noPos), mkVar(newVar)) in
  let newOpDef = (newOp, cons(caseTermSort,freeVarsSorts), ttermSort, cons(newVar, freeVars), newOpTerm) in
  let newTerm = mkApplication(mkOp(newOp, newOpSrt), cons(newCaseTerm, map mkVar freeVars)) in
  (newTerm, finalK, newOds1++newOds2++[newOpDef])
  
op liftCases: Op * List Term * Nat -> List Term * Nat * List OpDef

def liftCases(oper, terms, k) =
  case terms of
    | [] -> ([], k, [])
    | term::terms ->
    let (newTerm, newK, newOds) = liftCase(oper, term, k) in
    let (restTerms, restK, restOds) = liftCases(oper, terms, newK) in
    (cons(newTerm, restTerms), restK, newOds++restOds)

op lift: Op * (List Var * Term) -> Term * List OpDef

def lift(oper, (formals, body)) =
  let firstUserVar = find userVar? formals in
  case firstUserVar of
    | Some firstUserVar ->
    if caseTerm?(body)
      then
	case caseTerm(body) of
	  | Var (var, _) ->
	  if equalVar?(var, firstUserVar)
	    then 
	      let (newBody, newK, newOds) = liftCaseTopCase(oper, body, 1) in
	      (newBody, newOds)
	  else
	    let (newBody, newK, newOds) = liftCase(oper, body, 1) in
	    (newBody, newOds)
	  | _ -> let (newBody, newK, newOds) = liftCase(oper, body, 1)in
	    (newBody, newOds)
    else
      let (newBody, newK, newOds) = liftCase(oper, body, 1)in
      (newBody, newOds)
    | _ -> let (newBody, newK, newOds) = liftCase(oper, body, 1)in
      (newBody, newOds)

op liftPattern: Spec -> Spec

def liftPattern(spc) =
  let newOpDefs
  = foldriAQualifierMap 
  (fn (qualifier, name, (op_names, fixity, (tyVars, srt), [(_, term)]),
       result) ->
   let origOp = mkQualifiedId(qualifier, name) in
   let (origOpVars, origOpBody) = srtTermDelta(srt, term) in
   let (newTerm, newOds) = lift(origOp, (origOpVars, origOpBody)) in
   let (origOpNewVars, origOpNewTerm) = srtTermDelta(srt, newTerm) in
   let origOpNewDef = (origOp, srtDom(srt), srtRange(srt), origOpVars, newTerm) in
   cons(origOpNewDef, newOds++result))
  []
  spc.ops in
  let result = emptySpec in
  let result = setSorts(result, spc.sorts) in
  let result = foldr addOpToSpec result newOpDefs in
   result

op addOpToSpec: OpDef * Spec -> Spec

def addOpToSpec((oper:Op, dom:(List Sort), rng:Sort, formals:List Var, body:Term), spc:Spec) =
  let srt = case dom of | [] -> rng | [dom] -> mkArrow(dom, rng) | _ -> mkArrow(mkProduct(dom), rng) in
  let varPatterns = map mkVarPat formals in
  let term = mkLambda(mkTuplePat(varPatterns), body) in
  let (f, t) = srtTermDelta(srt, term) in
  run (addOp (oper, srt, term, spc))
   
def addOp (oper, srt, term, spc) : SpecCalc.Env Spec = addOp [oper] Nonfix ([], srt) [([], term)] spc noPos
endspec
