spec

import ToJavaBase

sort Term = JGen.Term

op termToExpression: TCx * JGen.Term * Nat * Nat * Spec -> (Block * Java.Expr * Nat * Nat) * Collected
op termToExpressionRet: TCx * Term * Nat * Nat * Spec -> (Block * Nat * Nat) * Collected
op termToExpressionAsgNV: Id * Id * TCx * Term * Nat * Nat * Spec -> (Block * Nat * Nat) * Collected
op termToExpressionAsgV: Id * TCx * Term * Nat * Nat * Spec -> (Block * Nat * Nat) * Collected
op termToExpressionAsgF: Id * Id * TCx * Term * Nat * Nat * Spec -> (Block * Nat * Nat) * Collected
op translateTermsToExpressions: TCx * List Term * Nat * Nat * Spec -> (Block * List Java.Expr * Nat * Nat) * Collected
op translateApplyToExpr: TCx * Term * Nat * Nat * Spec -> (Block * Java.Expr * Nat * Nat) * Collected
op translateRecordToExpr: TCx * Term * Nat * Nat * Spec -> (Block * Java.Expr * Nat * Nat) * Collected
op translateIfThenElseToExpr: TCx * Term * Nat * Nat * Spec -> (Block * Java.Expr * Nat * Nat) * Collected
op translateLetToExpr: TCx * Term * Nat * Nat * Spec -> (Block * Java.Expr * Nat * Nat) * Collected
op translateCaseToExpr: TCx * Term * Nat * Nat * Spec -> (Block * Java.Expr * Nat * Nat) * Collected
op translateLambdaToExpr: TCx * JGen.Term * Nat * Nat * Spec -> (Block * Java.Expr * Nat * Nat) * Collected

def translateApplyToExpr(tcx, term as Apply (opTerm, argsTerm, _), k, l, spc) =
  let
    def opvarcase(id) =
      let srt = termSort(term) in
      %%Fixed here
      let args = applyArgsToTerms(argsTerm) in
      % use the sort of the operator for the domain, if possible; this
      % avoid problems like: the operator is defined on the restriction type, but
      % the args have the unrestricted type
      let dom = case opTerm of
		  | Fun(Op(_),opsrt,_) -> srtDom(opsrt)
		  | _ -> map (fn(arg) ->
			      let srt = termSort(arg) in
			      %findMatchingUserType(spc,srt)
			      srt
			     ) args
      in
      let args = insertRestricts(spc,dom,args) in
      let argsTerm = exchangeArgTerms(argsTerm,args) in
      let rng = srt in
      if all (fn (srt) ->
	      notAUserType?(srt) %or baseTypeAlias?(spc,srt)
	     ) dom
	then
	  %let _ = writeLine("no user type in "^(foldl (fn(srt,s) -> " "^printSort(srt)) "" dom)) in
	  if notAUserType?(rng)
	    then
	      case utlist_internal (fn(srt) -> userType?(srt) & ~(baseTypeAlias?(spc,srt))) (concat(dom,[srt])) of
		| Some s ->
		  %let _ = writeLine(" ut found user type "^printSort(s)) in
		  let (sid,col1) = srtId s in
		  let (res,col2) = translateBaseApplToExpr(tcx,id,argsTerm,k,l,sid,spc) in
		  (res,concatCollected(col1,col2))
		| None ->
		  translatePrimBaseApplToExpr(tcx, id, argsTerm, k, l, spc)
	  else translateBaseArgsApplToExpr(tcx, id, argsTerm, rng, k, l, spc)
      else
	translateUserApplToExpr(tcx, id, dom, argsTerm, k, l, spc)
  in
  case opTerm of
    | Fun (Restrict, srt, _) -> translateRestrictToExpr(tcx, srt, argsTerm, k, l, spc)
    | Fun (Relax, srt, _) -> translateRelaxToExpr(tcx, argsTerm, k, l, spc)
    | Fun (Quotient, srt, _) -> translateQuotientToExpr(tcx, srt, argsTerm, k, l, spc)
    | Fun (Choose, srt, _) -> translateChooseToExpr(tcx, argsTerm, k, l, spc)
    | Fun (Equals , srt, _) -> translateEqualsToExpr(tcx, argsTerm, k, l, spc)
    | Fun (Project (id) , srt, _) -> translateProjectToExpr(tcx, id, argsTerm, k, l, spc)
    | Fun (Embed (id, _) , srt, _) ->
      let (sid,col1) = srtId(termSort(term)) in
      let (res,col2) = translateConstructToExpr(tcx, sid, id, argsTerm, k, l, spc) in
      (res,concatCollected(col1,col2))
    | Fun (Op (Qualified (q, id), _), _, _) ->
      let id = if (id = "~") & ((q = "Integer") or (q = "Nat")) then "-" else id in
      opvarcase(id)
    | _ -> translateOtherTermApply(tcx,opTerm,argsTerm,k,l,spc)
    %| _ -> (writeLine("translateApplyToExpr: not yet supported term: "^printTerm(term));errorResultExp(k,l))


op translateRestrictToExpr: TCx * Sort * Term * Nat * Nat * Spec -> (Block * Java.Expr * Nat * Nat) * Collected
def translateRestrictToExpr(tcx, srt, argsTerm, k, l, spc) =
  let [arg] = applyArgsToTerms(argsTerm) in
  let ((newBlock, newArg, newK, newL),col1) = termToExpression(tcx, arg, k, l, spc) in
  case srt of
    | Base (Qualified (q, srtId), _, _) ->
      ((newBlock, mkNewClasInst(srtId, [newArg]), newK, newL),col1)
    | _ -> 
      (case findMatchingRestritionType(spc,srt) of
	 | Some (Base(Qualified(q,srtId),_,_)) ->
	   ((newBlock,mkNewClasInst(srtId,[newArg]), newK, newL),col1)
	 | None -> fail("unsupported sort in restrict term: "^printSort(srt))
	  )

op translateRelaxToExpr: TCx * Term * Nat * Nat * Spec -> (Block * Java.Expr * Nat * Nat) * Collected
def translateRelaxToExpr(tcx, argsTerm, k, l, spc) =
  let [arg] = applyArgsToTerms(argsTerm) in
  let ((newBlock, newArg, newK, newL),col) = termToExpression_internal(tcx, arg, k, l, spc,false) in
  ((newBlock, mkFldAcc(newArg, "relax"), newK, newL),col)

op translateQuotientToExpr: TCx * Sort * Term * Nat * Nat * Spec -> (Block * Java.Expr * Nat * Nat) * Collected
def translateQuotientToExpr(tcx, srt, argsTerm, k, l, spc) =
  let [arg] = applyArgsToTerms(argsTerm) in
  let ((newBlock, newArg, newK, newL),col) = termToExpression(tcx, arg, k, l, spc) in
  let Base (Qualified (q, srtId), _, _) = srt in
  ((newBlock, mkNewClasInst(srtId, [newArg]), newK, newL),col)

op translateChooseToExpr: TCx * Term * Nat * Nat * Spec -> (Block * Java.Expr * Nat * Nat) * Collected
def translateChooseToExpr(tcx, argsTerm, k, l, spc) =
  let [arg] = applyArgsToTerms(argsTerm) in
  let ((newBlock, newArg, newK, newL),col) = termToExpression_internal(tcx, arg, k, l, spc, false) in
  ((newBlock, mkFldAcc(newArg, "choose"), newK, newL),col)

op translateEqualsToExpr: TCx * Term * Nat * Nat * Spec -> (Block * Java.Expr * Nat * Nat) * Collected
def translateEqualsToExpr(tcx, argsTerm, k, l, spc) =
  let args = applyArgsToTerms(argsTerm) in
  let ((newBlock, [jE1, jE2], newK, newL),col1) = translateTermsToExpressions(tcx, args, k, l, spc) in
  let (sid,col2) = srtId(termSort(hd(args))) in
  let col = concatCollected(col1,col2) in
  ((newBlock, mkJavaEq(jE1, jE2, sid), newK, newL),col)

op translateProjectToExpr: TCx * Id * Term * Nat * Nat * Spec -> (Block * Java.Expr * Nat * Nat) * Collected
def translateProjectToExpr(tcx, id, argsTerm, k, l, spc) =
  let args = applyArgsToTerms(argsTerm) in
  let ((newBlock, [e], newK, newL),col) = translateTermsToExpressions(tcx, args, k, l, spc) in
  ((newBlock, mkFldAcc(e, id), newK, newL),col)

op translateConstructToExpr: TCx * Id * Id * Term * Nat * Nat * Spec -> (Block * Java.Expr * Nat * Nat) * Collected
def translateConstructToExpr(tcx, srtId, opId, argsTerm, k, l, spc) =
  let args = applyArgsToTerms(argsTerm) in
  let ((newBlock, javaArgs, newK, newL),col) = translateTermsToExpressions(tcx, args, k, l, spc) in
  ((newBlock, mkMethInv(srtId, opId, javaArgs), newK, newL),col)

op translatePrimBaseApplToExpr: TCx * Id * Term * Nat * Nat * Spec -> (Block * Java.Expr * Nat * Nat) * Collected
def translatePrimBaseApplToExpr(tcx, opId, argsTerm, k, l, spc) =
  translateBaseApplToExpr(tcx,opId,argsTerm,k,l,"Primitive",spc)

op translateBaseApplToExpr: TCx * Id * Term * Nat * Nat * Id * Spec -> (Block * Java.Expr * Nat * Nat) * Collected
def translateBaseApplToExpr(tcx, opId, argsTerm, k, l, clsId, spc) =
  let args = applyArgsToTerms(argsTerm) in
  let ((newBlock, javaArgs, newK, newL),col) = translateTermsToExpressions(tcx, args, k, l, spc) in
  let res = if javaBaseOp?(opId)
	      then 
		if (length args) = 2
		  then (newBlock, mkBinExp(opId, javaArgs), newK, newL)
		else (newBlock, mkUnExp(opId, javaArgs), newK, newL)
	    else (newBlock, mkMethInv(clsId, opId, javaArgs), newK, newL)
  in
    (res,col)

op translateBaseArgsApplToExpr: TCx * Id * Term * JGen.Type * Nat * Nat * Spec -> (Block * Java.Expr * Nat * Nat) * Collected
def translateBaseArgsApplToExpr(tcx, opId, argsTerm, rng, k, l, spc) =
  let args = applyArgsToTerms(argsTerm) in
  let ((newBlock, javaArgs, newK, newL),col1) = translateTermsToExpressions(tcx, args, k, l, spc) in
  let (res,col2) = if javaBaseOp?(opId)
	      then ((newBlock, mkBinExp(opId, javaArgs), newK, newL),nothingCollected)
	    else 
	      let (sid,col) = srtId(rng) in
	      ((newBlock, mkMethInv(sid, opId, javaArgs), newK, newL),col)
  in
  let col = concatCollected(col1,col2) in
  (res,col)

op translateUserApplToExpr: TCx * Id * List JGen.Type * Term * Nat * Nat * Spec -> (Block * Java.Expr * Nat * Nat) * Collected
def translateUserApplToExpr(tcx, opId, dom, argsTerm, k, l, spc) =
  let args = applyArgsToTerms(argsTerm) in
  case findIndex (fn(srt) -> userType?(srt)) dom of
    | Some(h, _) -> 
      let ((newBlock, javaArgs, newK, newL),col) = translateTermsToExpressions(tcx, args, k, l, spc) in
      if javaBaseOp?(opId) then % this might occur if the term is a relax/choose
	if (length args) = 2
	  then ((newBlock, mkBinExp(opId,javaArgs), newK, newL),col)
	else ((newBlock,mkUnExp(opId,javaArgs), newK, newL),col)
      else
      let topJArg = nth(javaArgs, h) in
      let resJArgs = deleteNth(h, javaArgs) in
      ((newBlock, mkMethExprInv(topJArg, opId, resJArgs), newK, newL),col)
    | _ -> (warnNoCode(opId,None);errorResultExp(k,l))

def translateRecordToExpr(tcx, term as Record (fields, _), k, l, spc) =
  let recordTerms = recordFieldsToTerms(fields) in
  let recordSrt = termSort(term) in
  let ((newBlock, javaArgs, newK, newL),col) = translateTermsToExpressions(tcx, recordTerms, k, l, spc) in
  let srts = sortsAsList(spc) in
  let foundSrt = find (fn (qualifier, id, (_, _, [(_,srt)])) -> equalSort?(recordSrt, srt)) srts in
  case foundSrt of
     | Some (q, recordClassId, _) ->  ((newBlock, mkNewClasInst(recordClassId, javaArgs), newK, newL),col)
     | None -> fail("Could not find record sort.")
  %%Fix here HACK!!!


def translateIfThenElseToExpr(tcx, term as IfThenElse(t0, t1, t2, _), k, l, spc) =
  let ((b0, jT0, k0, l0),col1) = termToExpression(tcx, t0, k, l, spc) in
  let ((b1, jT1, k1, l1),col2) = termToExpression(tcx, t1, k0, l0, spc) in  
  let ((b2, jT2, k2, l2),col3) = termToExpression(tcx, t2, k1, l1, spc) in
  let col = concatCollected(col1,concatCollected(col2,col3)) in
  (case b1++b2 of
     | [] ->
     let vExpr = CondExp (Un (Prim (Paren (jT0))), Some (jT1, (Un (Prim (Paren (jT2))), None))) in
     ((b0, vExpr, k2, l2),col)
     | _ -> translateIfThenElseToStatement(tcx, term, k, l, spc))

def translateIfThenElseToStatement(tcx, term as IfThenElse(t0, t1, t2, _), k, l, spc) =
  let ((b0, jT0, k0, l0),col1) = termToExpression(tcx, t0, k+1, l, spc) in
  let v = mkIfRes(k) in
  let ((b1, k1, l1),col2) = termToExpressionAsgV(v, tcx, t1, k0, l0, spc) in  
  let ((b2, k2, l2),col3) = termToExpressionAsgV(v, tcx, t2, k1, l1, spc) in  
  let (sid,col4) = srtId(termSort(t2)) in
  let col = concatCollected(col1,concatCollected(col2,concatCollected(col3,col4))) in
  let vDecl = mkVarDecl(v, sid) in
%  let vAss1 = mkVarAssn(v, jT1) in
%  let vAss2 = mkVarAssn(v, jT2) in
%  let ifStmt = mkIfStmt(jT0, b1++[vAss1], b2++[vAss2]) in
  let ifStmt = mkIfStmt(jT0, b1, b2) in
  let vExpr = mkVarJavaExpr(v) in
  (([vDecl]++b0++[ifStmt], vExpr, k2, l2),col)

def translateLetToExpr(tcx, term as Let (letBindings, letBody, _), k, l, spc) =
  let [(VarPat (v, _), letTerm)] = letBindings in
  let (vId, vSrt) = v in
  let vSrt = findMatchingUserType(spc,vSrt) in
  let (sid,col0) = srtId(vSrt) in
  let ((b0, k0, l0),col1) = termToExpressionAsgNV(sid, vId, tcx, letTerm, k, l, spc) in
  let ((b1, jLetBody, k1, l1),col2) = termToExpression(tcx, letBody, k0, l0, spc) in
%  let vInit = mkVarInit(vId, srtId(vSrt), jLetTerm) in
  let col = concatCollected(col0,concatCollected(col1,col2)) in
  ((b0++b1, jLetBody, k1, l1),col)

def translateLetRet(tcx, term as Let (letBindings, letBody, _), k, l, spc) =
  let [(VarPat (v, _), letTerm)] = letBindings in
  let (vId, vSrt) = v in
  let vSrt = findMatchingUserType(spc,vSrt) in
  let (sid,col0) = srtId(vSrt) in
  let ((b0, k0, l0),col1) = termToExpressionAsgNV(sid, vId, tcx, letTerm, k, l, spc) in
  let ((b1, k1, l1),col2) = termToExpressionRet(tcx, letBody, k0, l0, spc) in
%  let vInit = mkVarInit(vId, srtId(vSrt), jLetTerm) in
  let col = concatCollected(col0,concatCollected(col1,col2)) in
  ((b0++b1, k1, l1),col)


def translateCaseToExpr(tcx, term, k, l, spc) =
  let caseType = termSort(term) in
  let (caseTypeId,col0) = srtId(caseType) in
  let caseTerm = caseTerm(term) in
  let cases  = caseCases(term) in
  %% cases = List (pat, cond, body)
  let ((caseTermBlock, caseTermJExpr, k0, l0),col1) =
    case caseTerm of
      | Var _ ->  termToExpression(tcx, caseTerm, k, l+1, spc)
      | _ ->
        let (caseTermSrt,col0) = srtId(termSort(caseTerm)) in
	let tgt = mkTgt(l) in
        let ((caseTermBlock, k0, l0),col1) = termToExpressionAsgNV(caseTermSrt, tgt, tcx, caseTerm, k, l+1, spc) in
	let col = concatCollected(col0,col1) in
	((caseTermBlock, mkVarJavaExpr(tgt), k0, l0),col)
  in
    let cres = mkCres(l) in
    let ((casesSwitches, finalK, finalL),col2) = translateCaseCasesToSwitches(tcx, caseTypeId, caseTermJExpr, cres, cases, k0, l0, l, spc) in
    let switchStatement = Stmt (Switch (caseTermJExpr, casesSwitches)) in
    let cresJavaExpr = mkVarJavaExpr(cres) in
    let col = concatCollected(col0,concatCollected(col1,col2)) in
    ((caseTermBlock++[switchStatement], cresJavaExpr, finalK, finalL),col)


op translateCaseCasesToSwitches: TCx * Id * Java.Expr * Id * Match * Nat * Nat * Nat * Spec -> (SwitchBlock * Nat * Nat) * Collected
def translateCaseCasesToSwitches(tcx, caseType, caseExpr, cres, cases, k0, l0, l, spc) =
  let
    def mkCaseInit(cons,coSrt) =
      let (caseType,col0) = srtId coSrt in
      let sumdType = mkSumd(cons, caseType) in
      let subId = mkSub(cons, l) in
      let castExpr = CondExp (Un (Cast (((Name ([], sumdType)), 0), Prim (Paren (caseExpr)))), None) in
      (mkVarInit(subId, sumdType, castExpr),col0)
  in
	%LocVarDecl (false, sumdType, ((subId, 0), Expr (castExpr)), []) in
  let
    def translateCaseCaseToSwitch(c, ks, ls) =
      let (EmbedPat (cons, argsPat, coSrt, _), _, body) = c in
      let patVars = case argsPat of
		      | Some (RecordPat (args, _)) -> map (fn (id, (VarPat ((vId, _), _))) -> vId) args
		      | Some (VarPat ((vId, _), _)) -> [vId]
		      | None -> [] in
      let subId = mkSub(cons, l) in
      %let sumdType = mkSumd(cons, caseType) in
      let newTcx = addSubsToTcx(tcx, patVars, subId) in
      let ((caseBlock, newK, newL),col1) = termToExpressionAsgV(cres, newTcx, body, ks, ls, spc) in
      let (initBlock,col2) = mkCaseInit(cons,coSrt) in
      let (caseType,col3) = srtId coSrt in
      %let tagId = mkTag(cons) in
      let tagId = mkTagCId(cons) in
      let switchLab = JCase (mkFldAccViaClass(caseType, tagId)) in
      let switchElement = ([switchLab], [initBlock]++caseBlock++[Stmt(Break None)]) in
      let col = concatCollected(col1,concatCollected(col2,col3)) in
      ((switchElement, newK, newL),col)
  in
    let
      def translateCasesToSwitchesRec(cases, kr, lr) =
	case cases of
	  | Nil -> (([mkDefaultCase(cases,spc)], kr, lr),nothingCollected)
	  | hdCase::restCases ->
	    let ((hdSwitch, hdK, hdL),col1) = translateCaseCaseToSwitch(hdCase, kr, lr) in
	    let ((restSwitch, restK, restL),col2) = translateCasesToSwitchesRec(restCases, hdK, hdL) in
	    let col = concatCollected(col1,col2) in
	    ((List.cons(hdSwitch, restSwitch), restK, restL),col)
    in
      translateCasesToSwitchesRec(cases, k0, l0)

op addSubsToTcx: TCx * List Id * Id -> TCx
def addSubsToTcx(tcx, args, subId) =
  let def addSubRec(tcx, args, n) =
         case args of
	   | [] -> tcx
	   | arg::args ->
	     let argName = mkArgProj(natToString(n)) in
	     let argExpr = CondExp (Un (Prim (Name ([subId], argName))), None) in
	     addSubRec(StringMap.insert(tcx, arg, argExpr), args, n+1) in
   addSubRec(tcx, args, 1)

op relaxChooseTerm: Spec * Term -> Term
def relaxChooseTerm(spc,t) =
  case t of
    | Apply(Fun(Restrict,_,_),_,_) -> t
    | Apply(Fun(Choose,_,_),_,_) -> t
    | _ -> 
    let srt0 = termSort(t) in
    let srt = unfoldBase(spc,srt0) in
    case srt of
      | Subsort(ssrt,_,b) ->
      let rsrt = Arrow(srt0,ssrt,b) in
      let t = Apply(Fun(Relax,rsrt,b),t,b) in
      relaxChooseTerm(spc,t)
      | Quotient(ssrt,_,b) ->
      let rsrt = Arrow(srt0,ssrt,b) in
      let t = Apply(Fun(Choose,rsrt,b),t,b) in
      relaxChooseTerm(spc,t)
      | _ -> t

def translateTermsToExpressions(tcx, terms, k, l, spc) =
    case terms of
    | [] -> (([], [], k, l),nothingCollected)
    | term::terms ->
    let ((newBody, jTerm, newK, newL),col1) = termToExpression(tcx, term, k, l, spc) in
    let ((restBody, restJTerms, restK, restL),col2) = translateTermsToExpressions(tcx, terms, newK, newL, spc) in
    let col = concatCollected(col1,col2) in
    ((newBody++restBody, cons(jTerm, restJTerms), restK, restL),col)

(**
 * toplevel entry point for translating a meta-slang term to a java expression 
 * (in general preceded by statements)
 *) 
def termToExpression(tcx, term, k, l, spc) =
  termToExpression_internal(tcx,term,k,l,spc,true)

def termToExpression_internal(tcx, term, k, l, spc, addRelaxChoose?) =
  %let _ = writeLine("termToExpression: "^printTerm(term)) in
  let term = if addRelaxChoose? then relaxChooseTerm(spc,term) else term in
  case term of
    | Var ((id, srt), _) ->
    (case StringMap.find(tcx, id) of
       | Some (newV) -> ((mts, newV, k, l),nothingCollected)
       | _ -> ((mts, mkVarJavaExpr(id), k, l),nothingCollected))
    | Fun (Op (Qualified (q, id), _), srt, _) -> 
       if baseType?(srt) 
	 then ((mts, mkQualJavaExpr("Primitive", id), k, l),nothingCollected)
       else
	 (case srt of
	    | Base (Qualified (q, srtId), _, _) -> ((mts, mkQualJavaExpr(srtId, id), k, l),nothingCollected)
	    | Arrow(dom,rng,_) -> translateLambdaToExpr(tcx,term,k,l,spc)
	    | _ -> fail("unsupported term in termToExpression: "^printTerm(term)))
    | Fun (Nat (n),_,__) -> ((mts, mkJavaNumber(n), k, l),nothingCollected)
    | Fun (Bool (b),_,_) -> ((mts, mkJavaBool(b), k, l),nothingCollected)
    | Fun (Embed (c, _), srt, _) -> 
      if flatType? srt then
	let (sid,col) = srtId(srt) in
	((mts, mkMethInv(sid, c, []), k, l),col)
      else
	translateLambdaToExpr(tcx,term,k,l,spc)
    | Apply (opTerm, argsTerm, _) -> translateApplyToExpr(tcx, term, k, l, spc)
    | Record _ -> translateRecordToExpr(tcx, term, k, l, spc)
    | IfThenElse _ -> translateIfThenElseToExpr(tcx, term, k, l, spc)
    | Let _ -> translateLetToExpr(tcx, term, k, l, spc)
    | Lambda((pat,cond,body)::_,_) -> (*ToJavaHO*)translateLambdaToExpr(tcx,term,k,l,spc)
    | _ ->
	 if caseTerm?(term)
	   then translateCaseToExpr(tcx, term, k, l, spc)
	 else fail("unsupported term in termToExpression"^printTerm(term))

op translateIfThenElseRet: TCx * Term * Nat * Nat * Spec -> (Block * Nat * Nat) * Collected
op translateCaseRet: TCx * Term * Nat * Nat * Spec -> (Block * Nat * Nat) * Collected

def termToExpressionRet(tcx, term, k, l, spc) =
  if caseTerm?(term)
    then translateCaseRet(tcx, term, k, l, spc)
  else
    case term of
      | IfThenElse _ -> translateIfThenElseRet(tcx, term, k, l, spc)
      | Let _ -> translateLetRet(tcx,term,k,l,spc)
      | _ ->
        let ((b, jE, newK, newL),col) = termToExpression(tcx, term, k, l, spc) in
	let retStmt = Stmt (Return (Some (jE))) in
	((b++[retStmt], newK, newL),col)

def translateIfThenElseRet(tcx, term as IfThenElse(t0, t1, t2, _), k, l, spc) =
  let ((b0, jT0, k0, l0),col1) = termToExpression(tcx, t0, k, l, spc) in
  let ((b1, k1, l1),col2) = termToExpressionRet(tcx, t1, k0, l0, spc) in  
  let ((b2, k2, l2),col3) = termToExpressionRet(tcx, t2, k1, l1, spc) in
  let col = concatCollected(col1,concatCollected(col2,col3)) in
  let ifStmt = mkIfStmt(jT0, b1, b2) in
    ((b0++[ifStmt], k2, l2),col)

def translateCaseRet(tcx, term, k, l, spc) =
  let caseType_ = termSort(term) in
  let (caseTypeId,col0) = srtId(caseType_) in
  let caseTerm = caseTerm(term) in
  let cases  = caseCases(term) in
  %% cases = List (pat, cond, body)
  let ((caseTermBlock, caseTermJExpr, k0, l0),col1) =
    case caseTerm of
      | Var _ ->  termToExpression(tcx, caseTerm, k, l+1, spc)
      | _ ->
        let (caseTermSrt,col0) = srtId(termSort(caseTerm)) in
	let tgt = mkTgt(l) in
        let ((caseTermBlock, k0, l0),col1) = termToExpressionAsgNV(caseTermSrt, tgt, tcx, caseTerm, k, l+1, spc) in
	let col = concatCollected(col0,col1) in
	((caseTermBlock, mkVarJavaExpr(tgt), k0, l0),col)
  in
  let ((casesSwitches, finalK, finalL),col2) = translateCaseCasesToSwitchesRet(tcx, caseTypeId, caseTermJExpr, cases, k0, l0, l, spc) in
  let switchStatement = Stmt (Switch (mkFldAcc(caseTermJExpr,"tag"), casesSwitches)) in
  let col = concatCollected(col0,concatCollected(col1,col2)) in
  ((caseTermBlock++[switchStatement], finalK, finalL),col)


op translateCaseCasesToSwitchesRet: TCx * Id * Java.Expr * Match * Nat * Nat * Nat * Spec -> (SwitchBlock * Nat * Nat) * Collected
def translateCaseCasesToSwitchesRet(tcx, caseType, caseExpr, cases, k0, l0, l, spc) =
  let def mkCaseInit(cons,caseSort) =
        let (caseType,col) = srtId(caseSort) in
        let sumdType = mkSumd(cons, caseType) in
	let subId = mkSub(cons, l) in
	let castExpr = CondExp (Un (Cast (((Name ([], sumdType)), 0), Prim (Paren (caseExpr)))), None) in
	(mkVarInit(subId, sumdType, castExpr),col)
  in
	%LocVarDecl (false, sumdType, ((subId, 0), Expr (castExpr)), []) in
  let def translateCaseCaseToSwitch(c, ks, ls) =
        let (EmbedPat (cons, argsPat, coSrt, _), _, body) = c in
	let patVars = case argsPat of
	                | Some (RecordPat (args, _)) -> map (fn (id, (VarPat ((vId, _), _))) -> vId) args
	                | Some (VarPat ((vId, _), _)) -> [vId]
	                | None -> [] 
	                | Some(pat) -> fail("unsupported pattern in case: "^printPattern(pat))
	in
	let subId = mkSub(cons, l) in
	%let sumdType = mkSumd(cons, caseType) in
        let newTcx = addSubsToTcx(tcx, patVars, subId) in
	let ((caseBlock, newK, newL),col1) = termToExpressionRet(newTcx, body, ks, ls, spc) in
	let (initBlock,col2) = mkCaseInit(cons,coSrt) in
	let (caseType,col3) = srtId coSrt in
	let tagId = mkTagCId(cons) in
	let switchLab = JCase (mkFldAccViaClass(caseType, tagId)) in
	let switchElement = ([switchLab], [initBlock]++caseBlock) in
	let col = concatCollected(col1,concatCollected(col2,col3)) in
	((switchElement, newK, newL),col)
  in
  let def translateCasesToSwitchesRec(cases, kr, lr) =
         case cases of
	   | Nil -> (([mkDefaultCase(cases,spc)], kr, lr),nothingCollected)
	   | hdCase::restCases ->
	      let ((hdSwitch, hdK, hdL),col1) = translateCaseCaseToSwitch(hdCase, kr, lr) in
	      let ((restSwitch, restK, restL),col2) = translateCasesToSwitchesRec(restCases, hdK, hdL) in
	      let col = concatCollected(col1,col2) in
	      ((List.cons(hdSwitch, restSwitch), restK, restL),col)
  in
    translateCasesToSwitchesRec(cases, k0, l0)


op translateIfThenElseAsgNV: Id * Id * TCx * Term * Nat * Nat * Spec -> (Block * Nat * Nat) * Collected
op translateCaseAsgNV: Id * Id * TCx * Term * Nat * Nat * Spec -> (Block * Nat * Nat) * Collected

def termToExpressionAsgNV(srtId, vId, tcx, term, k, l, spc) =
  if caseTerm?(term)
    then translateCaseAsgNV(srtId, vId, tcx, term, k, l, spc)
  else
    case term of
      | IfThenElse _ -> translateIfThenElseAsgNV(srtId, vId, tcx, term, k, l, spc)
      | _ ->
        let ((b, jE, newK, newL),col) = termToExpression(tcx, term, k, l, spc) in
	let vInit = mkVarInit(vId, srtId, jE) in
	((b++[vInit], newK, newL),col)

def translateIfThenElseAsgNV(srtId, vId, tcx, term as IfThenElse(t0, t1, t2, _), k, l, spc) =
  let ((b0, jT0, k0, l0),col1) = termToExpression(tcx, t0, k, l, spc) in
  let ((b1, k1, l1),col2) = termToExpressionAsgV(vId, tcx, t1, k0, l0, spc) in  
  let ((b2, k2, l2),col3) = termToExpressionAsgV(vId, tcx, t2, k1, l1, spc) in
  let col = concatCollected(col1,concatCollected(col2,col3)) in
  let varDecl = mkVarDecl(vId, srtId) in
  let ifStmt = mkIfStmt(jT0, b1, b2) in
    (([varDecl]++b0++[ifStmt], k2, l2),col)

%def translateCaseAsgNV(vSrtId, vId, tcx, term, k, l, spc) =
def translateCaseAsgNV(vSrtId, vId, tcx, term, k, l, spc) =
  let caseType = termSort(term) in
  let (caseTypeId,col0) = srtId(caseType) in
  let caseTerm = caseTerm(term) in
  let cases  = caseCases(term) in
  %% cases = List (pat, cond, body)
  let ((caseTermBlock, caseTermJExpr, k0, l0),col1) =
    case caseTerm of
      | Var _ ->  termToExpression(tcx, caseTerm, k, l+1, spc)
      | _ ->
        let (caseTermSrt,col1) = srtId(termSort(caseTerm)) in
	let tgt = mkTgt(l) in
        let ((caseTermBlock, k0, l0),col2) = termToExpressionAsgNV(caseTermSrt, tgt, tcx, caseTerm, k, l+1, spc) in
	let col = concatCollected(col1,col2) in
	((caseTermBlock, mkVarJavaExpr(tgt), k0, l0),col)
  in
   let ((casesSwitches, finalK, finalL),col2) = translateCaseCasesToSwitchesAsgNV(vId, tcx, caseTypeId, caseTermJExpr, cases, k0, l0, l, spc) in
   let switchStatement = Stmt (Switch (mkFldAcc(caseTermJExpr,"tag"), casesSwitches)) in
   let declV = mkVarDecl(vId, vSrtId) in
   let col = concatCollected(col0,concatCollected(col1,col2)) in
   (([declV]++caseTermBlock++[switchStatement], finalK, finalL),col)


op translateCaseCasesToSwitchesAsgNV: Id * TCx * Id * Java.Expr * Match * Nat * Nat * Nat * Spec -> (SwitchBlock * Nat * Nat) * Collected
def translateCaseCasesToSwitchesAsgNV(oldVId, tcx, caseType, caseExpr, cases, k0, l0, l, spc) =
  let def mkCaseInit(cons,srt) =
        let (caseType,col) = srtId srt in
        let sumdType = mkSumd(cons, caseType) in
	let subId = mkSub(cons, l) in
	let castExpr = CondExp (Un (Cast (((Name ([], sumdType)), 0), Prim (Paren (caseExpr)))), None) in
	(mkVarInit(subId, sumdType, castExpr),col)
  in
	%LocVarDecl (false, sumdType, ((subId, 0), Expr (castExpr)), []) in
  let def translateCaseCaseToSwitch(c, ks, ls) =
        let (EmbedPat (cons, argsPat, coSrt, _), _, body) = c in
	let patVars = case argsPat of
	                | Some (RecordPat (args, _)) -> map (fn (id, (VarPat ((vId, _), _))) -> vId) args
	                | Some (VarPat ((vId, _), _)) -> [vId]
	                | Some (pat) -> fail("unsupported pattern: '"^printPattern(pat)^"'")
	                | None -> [] in
	let subId = mkSub(cons, l) in
	%let sumdType = mkSumd(cons, caseType) in
        let newTcx = addSubsToTcx(tcx, patVars, subId) in
	let ((caseBlock, newK, newL),col1) = termToExpressionAsgV(oldVId, newTcx, body, ks, ls, spc) in
	let (initBlock,col2) = mkCaseInit(cons,coSrt) in
	let tagId = mkTagCId(cons) in
	let (caseType,col3) = srtId coSrt in
	let switchLab = JCase (mkFldAccViaClass(caseType, tagId)) in
	let switchElement = ([switchLab], [initBlock]++caseBlock++[Stmt(Break None)]) in
	let col = concatCollected(col1,concatCollected(col2,col3)) in
	((switchElement, newK, newL),col) in
   let def translateCasesToSwitchesRec(cases, kr, lr) =
         case cases of
	   | Nil -> (([mkDefaultCase(cases,spc)], kr, lr),nothingCollected)
	   | hdCase::restCases ->
	      let ((hdSwitch, hdK, hdL),col1) = translateCaseCaseToSwitch(hdCase, kr, lr) in
	      let ((restSwitch, restK, restL),col2) = translateCasesToSwitchesRec(restCases, hdK, hdL) in
	      let col = concatCollected(col1,col2) in
	      ((List.cons(hdSwitch, restSwitch), restK, restL),col)
   in
     translateCasesToSwitchesRec(cases, k0, l0)



op translateIfThenElseAsgV: Id * TCx * Term * Nat * Nat * Spec -> (Block * Nat * Nat) * Collected
op translateCaseAsgV: Id * TCx * Term * Nat * Nat * Spec -> (Block * Nat * Nat) * Collected

def termToExpressionAsgV(vId, tcx, term, k, l, spc) =
  if caseTerm?(term)
    then translateCaseAsgV(vId, tcx, term, k, l, spc)
  else
    case term of
      | IfThenElse _ -> translateIfThenElseAsgV(vId, tcx, term, k, l, spc)
      | _ ->
        let ((b, jE, newK, newL),col) = termToExpression(tcx, term, k, l, spc) in
	let vAssn = mkVarAssn(vId, jE) in
	((b++[vAssn], newK, newL),col)

def translateIfThenElseAsgV(vId, tcx, term as IfThenElse(t0, t1, t2, _), k, l, spc) =
  let ((b0, jT0, k0, l0),col1) = termToExpression(tcx, t0, k, l, spc) in
  let ((b1, k1, l1),col2) = termToExpressionAsgV(vId, tcx, t1, k0, l0, spc) in  
  let ((b2, k2, l2),col3) = termToExpressionAsgV(vId, tcx, t2, k1, l1, spc) in
  let col = concatCollected(col1,concatCollected(col2,col3)) in
  let ifStmt = mkIfStmt(jT0, b1, b2) in
    ((b0++[ifStmt], k2, l2),col)

%def translateCaseAsgV(vId, tcx, term, k, l, spc) =
def translateCaseAsgV(vId, tcx, term, k, l, spc) =
  let caseType = termSort(term) in
  let (caseTypeId,col0) = srtId(caseType) in
  let caseTerm = caseTerm(term) in
  let cases  = caseCases(term) in
  %% cases = List (pat, cond, body)
  let ((caseTermBlock, caseTermJExpr, k0, l0),col1) =
    case caseTerm of
      | Var _ ->  termToExpression(tcx, caseTerm, k, l+1, spc)
      | _ ->
        let (caseTermSrt,col1) = srtId(termSort(caseTerm)) in
	let tgt = mkTgt(l) in
        let ((caseTermBlock, k0, l0),col2) = termToExpressionAsgNV(caseTermSrt, tgt, tcx, caseTerm, k, l+1, spc) in
	let col = concatCollected(col1,col2) in
	((caseTermBlock, mkVarJavaExpr(tgt), k0, l0),col)
  in
   let ((casesSwitches, finalK, finalL),col2) = translateCaseCasesToSwitchesAsgV(vId, tcx, caseTypeId, caseTermJExpr, cases, k0, l0, l, spc) in
   let switchStatement = Stmt (Switch (mkFldAcc(caseTermJExpr,"tag"), casesSwitches)) in
   let col = concatCollected(col0,concatCollected(col1,col2)) in
   ((caseTermBlock++[switchStatement], finalK, finalL),col)


op translateCaseCasesToSwitchesAsgV: Id * TCx * Id * Java.Expr * Match * Nat * Nat * Nat * Spec -> (SwitchBlock * Nat * Nat) * Collected
def translateCaseCasesToSwitchesAsgV(oldVId, tcx, caseType, caseExpr, cases, k0, l0, l, spc) =
  let def mkCaseInit(cons,coSrt) =
	let (caseType,col) = srtId coSrt in
        let sumdType = mkSumd(cons, caseType) in
	let subId = mkSub(cons, l) in
	let castExpr = CondExp (Un (Cast (((Name ([], sumdType)), 0), Prim (Paren (caseExpr)))), None) in
	(mkVarInit(subId, sumdType, castExpr),col)
  in
	%LocVarDecl (false, sumdType, ((subId, 0), Expr (castExpr)), []) in
  let def translateCaseCaseToSwitch(c, ks, ls) =
        let (EmbedPat (cons, argsPat, coSrt, _), _, body) = c in
	let patVars = case argsPat of
	                | Some (RecordPat (args, _)) -> map (fn (id, (VarPat ((vId, _), _))) -> vId) args
	                | Some (VarPat ((vId, _), _)) -> [vId]
	                | None -> [] in
	let subId = mkSub(cons, l) in
	%let sumdType = mkSumd(cons, caseType) in
        let newTcx = addSubsToTcx(tcx, patVars, subId) in
	let ((caseBlock, newK, newL),col1) = termToExpressionAsgV(oldVId, newTcx, body, ks, ls, spc) in
	let (initBlock,col2) = mkCaseInit(cons,coSrt) in
	let (caseType,col3) = srtId coSrt in
	%let tagId = mkTag(cons) in
	let tagId = mkTagCId(cons) in
	let switchLab = JCase (mkFldAccViaClass(caseType, tagId)) in
	let switchElement = ([switchLab], [initBlock]++caseBlock++[Stmt(Break None)]) in
	let col = concatCollected(col1,concatCollected(col2,col3)) in
	((switchElement, newK, newL),col) in
   let def translateCasesToSwitchesRec(cases, kr, lr) =
         case cases of
	   | Nil -> (([mkDefaultCase(cases,spc)], kr, lr),nothingCollected)
	   | hdCase::restCases ->
	      let ((hdSwitch, hdK, hdL),col1) = translateCaseCaseToSwitch(hdCase, kr, lr) in
	      let ((restSwitch, restK, restL),col2) = translateCasesToSwitchesRec(restCases, hdK, hdL) in
	      let col = concatCollected(col1,col2) in
	      ((List.cons(hdSwitch, restSwitch), restK, restL),col)
   in
     translateCasesToSwitchesRec(cases, k0, l0)


op translateIfThenElseAsgF: Id * Id * TCx * Term * Nat * Nat * Spec -> (Block * Nat * Nat) * Collected
op translateCaseAsgF: Id * Id * TCx * Term * Nat * Nat * Spec -> (Block * Nat * Nat) * Collected

def termToExpressionAsgF(cId, fId, tcx, term, k, l, spc) =
  if caseTerm?(term)
    then translateCaseAsgF(cId, fId, tcx, term, k, l, spc)
  else
    case term of
      | IfThenElse _ -> translateIfThenElseAsgF(cId, fId, tcx, term, k, l, spc)
      | _ ->
        let ((b, jE, newK, newL),col) = termToExpression(tcx, term, k, l, spc) in
	let fAssn = mkFldAssn(cId, fId, jE) in
	((b++[fAssn], newK, newL),col)

def translateIfThenElseAsgF(cId, fId, tcx, term as IfThenElse(t0, t1, t2, _), k, l, spc) =
  let ((b0, jT0, k0, l0),col1) = termToExpression(tcx, t0, k, l, spc) in
  let ((b1, k1, l1),col2) = termToExpressionAsgF(cId, fId, tcx, t1, k0, l0, spc) in  
  let ((b2, k2, l2),col3) = termToExpressionAsgF(cId, fId, tcx, t2, k1, l1, spc) in
  let col = concatCollected(col1,concatCollected(col2,col3)) in
  let ifStmt = mkIfStmt(jT0, b1, b2) in
  ((b0++[ifStmt], k2, l2),col)

%def translateCaseAsgF(cId, tcx, term, k, l, spc) =
def translateCaseAsgF(cId, fId, tcx, term, k, l, spc) =
  let caseType = termSort(term) in
  let (caseTypeId,col0) = srtId(caseType) in
  let caseTerm = caseTerm(term) in
  let cases  = caseCases(term) in
  %% cases = List (pat, cond, body)
  let ((caseTermBlock, caseTermJExpr, k0, l0),col1) =
    case caseTerm of
      | Var _ ->  termToExpression(tcx, caseTerm, k, l+1, spc)
      | _ ->
        let (caseTermSrt,col1) = srtId(termSort(caseTerm)) in
	let tgt = mkTgt(l) in
        let ((caseTermBlock, k0, l0),col2) = termToExpressionAsgNV(caseTermSrt, tgt, tcx, caseTerm, k, l+1, spc) in
	let col = concatCollected(col1,col2) in
	((caseTermBlock, mkVarJavaExpr(tgt), k0, l0),col)
  in
   let ((casesSwitches, finalK, finalL),col2) = translateCaseCasesToSwitchesAsgF(cId, fId, tcx, caseTypeId, caseTermJExpr, cases, k0, l0, l, spc) in
   let switchStatement = Stmt (Switch (mkFldAcc(caseTermJExpr,"tag"), casesSwitches)) in
   let col = concatCollected(col0,concatCollected(col1,col2)) in
   ((caseTermBlock++[switchStatement], finalK, finalL),col)


op translateCaseCasesToSwitchesAsgF: Id * Id * TCx * Id * Java.Expr * Match * Nat * Nat * Nat * Spec -> (SwitchBlock * Nat * Nat) * Collected
def translateCaseCasesToSwitchesAsgF(cId, fId, tcx, caseType, caseExpr, cases, k0, l0, l, spc) =
  let def mkCaseInit(cons,coSrt) =
	let (caseType,col) = srtId coSrt in
        let sumdType = mkSumd(cons, caseType) in
	let subId = mkSub(cons, l) in
	let castExpr = CondExp (Un (Cast (((Name ([], sumdType)), 0), Prim (Paren (caseExpr)))), None) in
	(mkVarInit(subId, sumdType, castExpr),col)
  in
	%LocVarDecl (false, sumdType, ((subId, 0), Expr (castExpr)), []) in
  let def translateCaseCaseToSwitch(c, ks, ls) =
        let (EmbedPat (cons, argsPat, coSrt, _), _, body) = c in
	let patVars = case argsPat of
	                | Some (RecordPat (args, _)) -> map (fn (id, (VarPat ((vId, _), _))) -> vId) args
	                | Some (VarPat ((vId, _), _)) -> [vId]
	                | None -> [] in
	let subId = mkSub(cons, l) in
	%let sumdType = mkSumd(cons, caseType) in
        let newTcx = addSubsToTcx(tcx, patVars, subId) in
	let ((caseBlock, newK, newL),col1) = termToExpressionAsgF(cId, fId, newTcx, body, ks, ls, spc) in
	let (initBlock,col2) = mkCaseInit(cons,coSrt) in
	let (caseType,col3) = srtId coSrt in
	%let tagId = mkTag(cons) in
	let tagId = mkTagCId(cons) in
	let switchLab = JCase (mkFldAccViaClass(caseType, tagId)) in
	let switchElement = ([switchLab], [initBlock]++caseBlock++[Stmt(Break None)]) in
	let col = concatCollected(col1,concatCollected(col2,col3)) in
	((switchElement, newK, newL),col) in
   let def translateCasesToSwitchesRec(cases, kr, lr) =
         case cases of
	   | Nil -> (([mkDefaultCase(cases,spc)], kr, lr),nothingCollected)
	   | hdCase::restCases ->
	      let ((hdSwitch, hdK, hdL),col1) = translateCaseCaseToSwitch(hdCase, kr, lr) in
	      let ((restSwitch, restK, restL),col2) = translateCasesToSwitchesRec(restCases, hdK, hdL) in
	      let col = concatCollected(col1,col2) in
	      ((List.cons(hdSwitch, restSwitch), restK, restL),col)
   in
     translateCasesToSwitchesRec(cases, k0, l0)

(**
 * implements v3:p48:r3
 *)
op translateOtherTermApply: TCx * Term * Term * Nat * Nat * Spec -> (Block * Java.Expr * Nat * Nat) * Collected
def translateOtherTermApply(tcx,opTerm,argsTerm,k,l,spc) =
  let
    def doArgs(terms,k,l,block,exprs,col) =
      case terms of
	| [] -> ((block,exprs,k,l),col)
	| t::terms ->
	  let ((si,ei,ki,li),coli) = termToExpression(tcx,t,k,l,spc) in
	  let block = concatBlock(block,si) in
	  let exprs = concat(exprs,[ei]) in
	  let col = concatCollected(col,coli) in
	  doArgs(terms,ki,li,block,exprs,col)
  in
  let ((s,e,k0,l0),col1) = termToExpression(tcx,opTerm,k,l,spc) in
  let argterms = applyArgsToTerms(argsTerm) in
  let ((block,exprs,k,l),col2) = doArgs(argterms,k,l,[],[],nothingCollected) in
  let japply = mkMethExprInv(e,"apply",exprs) in
  let col = concatCollected(col1,col2) in
  ((block,japply,k,l),col)

op concatBlock: Block * Block -> Block
def concatBlock(b1,b2) =
  concat(b1,b2)

op errorResultExp: Nat * Nat -> (Block * Java.Expr * Nat * Nat) * Collected
def errorResultExp(k,l) =
  ((mts,mkJavaNumber(0),k,l),nothingCollected)

def warnNoCode(opId,optreason) =
  writeLine("warning: no code has been generated for op \""^opId^"\""
	    ^ (case optreason of
		 | Some str -> ", reason: "^str
		 | _ -> "."))

endspec
