JGen qualifying spec

import ToJavaStatements
import ToJavaProduct
import ToJavaCoProduct
import ToJavaSubSort
import ToJavaQuotient
import ToJavaHO

%import Java qualifying /Languages/Java/Java
%import /Languages/Java/DistinctVariable
%import /Languages/MetaSlang/Specs/StandardSpec

%sort JSpec = CompUnit

sort JcgInfo = {
		clsDecls : List ClsDecl,
		collected : Collected
	       }

sort ArrowType = List Sort * Sort

sort Type = JGen.Type

op clsDeclsFromSorts: Spec -> JcgInfo
def clsDeclsFromSorts(spc) =
  let initialJcgInfo = {
			clsDecls = [],
			collected = nothingCollected
		       }
  in
   let primClsDecl = mkPrimOpsClsDecl in
   let jcginfo =
   (foldriAQualifierMap (fn (qualifier, id, sort_info, jcginfo) -> 
			 let newjcginfo = sortToClsDecls(qualifier, id, sort_info, jcginfo) in
			 concatClsDecls(newjcginfo,jcginfo))
    initialJcgInfo spc.sorts)
   in
     concatClsDecls({clsDecls=[primClsDecl],collected=nothingCollected},jcginfo)

op sortToClsDecls: Qualifier * Id * SortInfo * JcgInfo -> JcgInfo
def sortToClsDecls(qualifier, id, sort_info, jcginfo) =
  let clsDecls = jcginfo.clsDecls in
  let (_, _, [(_, srtDef)]) = sort_info in
  let newClsDecls = 
  if baseType?(srtDef)
    then fail("Unsupported sort definition: sort "^id^" = "^printSort(srtDef))
  else
    case srtDef of
      | Product (fields, _) -> [productToClsDecl(id, srtDef)]
      | CoProduct (summands, _) -> coProductToClsDecls(id, srtDef)
      | Quotient (superSort, quotientPred, _) -> [quotientToClsDecl(id, superSort, quotientPred)]
      | Subsort (superSort, pred, _) -> [subSortToClsDecl(id, superSort, pred)]
      | Base (Qualified (qual, id1), [], _) -> [userTypeToClsDecl(id,id1)]
      | _ -> fail("Unsupported sort definition: sort "^id^" = "^printSort(srtDef))
  in
    exchangeClsDecls(jcginfo,newClsDecls)

op addFldDeclToClsDecls: Id * FldDecl * JcgInfo -> JcgInfo
def addFldDeclToClsDecls(srtId, fldDecl, jcginfo) =
  let clsDecls = map (fn (cd as (lm, (cId, sc, si), cb)) -> 
		      if cId = srtId
			then
			  let newCb = setFlds(cb, cons(fldDecl, cb.flds)) in
			  (lm, (cId, sc, si), newCb)
		      else cd)
                      jcginfo.clsDecls
  in
    exchangeClsDecls(jcginfo,clsDecls)

op addMethDeclToClsDecls: Id * MethDecl * JcgInfo -> JcgInfo
def addMethDeclToClsDecls(srtId, methDecl, jcginfo) =
  let clsDecls =
  map (fn (clsDecl as (lm, (clsId, sc, si), cb)) -> 
       if clsId = srtId
	 then
	   let newCb = setMethods(cb, cons(methDecl, cb.meths)) in
	   (lm, (clsId, sc, si), newCb)
	   else clsDecl)
  jcginfo.clsDecls
  in
    exchangeClsDecls(jcginfo,clsDecls)

op addMethodFromOpToClsDecls: Spec * Id * Sort * Term * JcgInfo -> JcgInfo
def addMethodFromOpToClsDecls(spc, opId, srt, trm, jcginfo) =
  let dom = srtDom(srt) in
  let rng = srtRange(srt) in
  if all (fn (srt) -> notAUserType?(srt)) dom
    then
      if notAUserType?(rng)
	then
	  case ut(srt) of
	    | Some usrt ->
	      % v3:p45:r8
	      let classId = srtId(usrt) in
	      addStaticMethodToClsDecls(spc,opId,srt,dom,rng,trm,classId,jcginfo)
	    | None ->
	      % v3:p46:r1
	      addPrimMethodToClsDecls(spc, opId, srt, dom, rng, trm, jcginfo)
      else addPrimArgsMethodToClsDecls(spc, opId, srt, dom, rng, trm, jcginfo)
  else
    addUserMethodToClsDecls(spc, opId, srt, dom, rng, trm, jcginfo)

op addStaticMethodToClsDecls: Spec * Id * JGen.Type * List JGen.Type * JGen.Type * Term * Id * JcgInfo -> JcgInfo
def addStaticMethodToClsDecls(spc, opId, srt, dom, rng as Base (Qualified (q, rngId), _,  _), trm, classId, jcginfo) =
  let clsDecls = jcginfo.clsDecls in
  let (vars, body) = srtTermDelta(srt, trm) in
  let methodDecl = (([Static], Some (tt(rngId)), opId, varsToFormalParams(vars), []), None) in
  let (methodBody,col1) = mkPrimArgsMethodBody(body, spc) in
  let (assertStmt,col2) = mkAssertFromDom(dom, spc) in
  let methodDecl = setMethodBody(methodDecl, assertStmt++methodBody) in
  let col = concatCollected(col1,col2) in
  let jcginfo = addCollectedToJcgInfo(jcginfo,col) in
  addMethDeclToClsDecls(classId, methodDecl, jcginfo)

op addPrimMethodToClsDecls: Spec * Id * JGen.Type * List JGen.Type * JGen.Type * Term * JcgInfo -> JcgInfo
def addPrimMethodToClsDecls(spc, opId, srt, dom, rng, trm, jcginfo) =
  addStaticMethodToClsDecls(spc,opId,srt,dom,rng,trm,"Primitive",jcginfo)

op mkAssertFromDom: List JGen.Type * Spec -> Block * Collected
def mkAssertFromDom(dom, spc) =
  case dom of
    | [Subsort(_, subPred, _)] ->
      let ((stmt, jPred, newK, newL),col) = termToExpression(empty, subPred, 1, 1, spc) in
      (case (stmt, newK, newL) of
	 | ([], 1, 1) -> ([Stmt(Expr(mkMethInv("", "assert", [jPred])))],col)
	 | _ -> fail ("Type pred generated statements: not supported"))
    | _ -> ([],nothingCollected)

op mkPrimArgsMethodBody: Term * Spec -> Block * Collected
def mkPrimArgsMethodBody(body, spc) =
  let ((b, k, l),col) = termToExpressionRet(empty, body, 1, 1, spc) in
  (b,col)

op addPrimArgsMethodToClsDecls: Spec * Id * JGen.Type * List JGen.Type * JGen.Type * Term * JcgInfo -> JcgInfo
def addPrimArgsMethodToClsDecls(spc, opId, srt, dom, rng, trm, jcginfo) =
  case rng of
    | Base (Qualified (q, rngId), _, _) -> 
      let clsDecls = jcginfo.clsDecls in
      let (vars, body) = srtTermDelta(srt, trm) in
      let methodDecl = (([Static], Some (tt(rngId)), opId, varsToFormalParams(vars), []), None) in
      let (methodBody,col1) = mkPrimArgsMethodBody(body, spc) in
      let methodDecl = setMethodBody(methodDecl, methodBody) in
      let jcginfo = addCollectedToJcgInfo(jcginfo,col1) in
      addMethDeclToClsDecls(rngId, methodDecl, jcginfo)
    | _ -> %TODO:
      jcginfo

op addUserMethodToClsDecls: Spec * Id * JGen.Type * List JGen.Type * JGen.Type * Term * JcgInfo -> JcgInfo
def addUserMethodToClsDecls(spc, opId, srt, dom, rng, trm, jcginfo) =
  case rng of
    | Base (Qualified (q, rngId), _, _) ->
      (let clsDecls = jcginfo.clsDecls in
       let (vars, body) = srtTermDelta_internal(srt, trm,true) in
       let split = splitList (fn(v as (id, srt)) -> userType?(srt)) vars in
       case split of
	 | Some(vars1,varh,vars2) ->
	 (if caseTerm?(body)
	    then 
	      case caseTerm(body) of
		| Var (var,_) -> if equalVar?(varh, var) 
				   then addCaseMethodsToClsDecls(spc, opId, dom, rng, rngId, vars, body, jcginfo)
				 else addNonCaseMethodsToClsDecls(spc, opId, dom, rng, rngId, vars, body, jcginfo)
	  else addNonCaseMethodsToClsDecls(spc, opId, dom, rng, rngId, vars, body, jcginfo)
	   )
	| _ -> let _ = warnNoCode(opId,Some("cannot find user type in arguments of op "^opId)) in
            jcginfo
      )
    | _ -> let _ = warnNoCode(opId,Some("opId doesn't have a flat type")) in
	jcginfo

op addCaseMethodsToClsDecls: Spec * Id * List Type * Type * Id * List Var * Term * JcgInfo -> JcgInfo
def addCaseMethodsToClsDecls(spc, opId, dom, rng, rngId, vars, body, jcginfo) =
  let clsDecls = jcginfo.clsDecls in
  let Some (vars1, varh, vars2) = splitList (fn(v as (id, srt)) -> userType?(srt)) vars in
  let methodDeclA = (([Abstract], Some (tt(rngId)), opId, varsToFormalParams(vars1++vars2), []), None) in
  let methodDecl = (([], Some (tt(rngId)), opId, varsToFormalParams(vars1++vars2), []), None) in
  let (_, Base (Qualified(q, srthId), _, _)) = varh in
  let newJcgInfo = addMethDeclToClsDecls(srthId, methodDeclA, jcginfo) in
  addMethDeclToSummands(spc, srthId, methodDecl, body, newJcgInfo)

op addNonCaseMethodsToClsDecls: Spec * Id * List Type * Type * Id * List Var * Term * JcgInfo -> JcgInfo
def addNonCaseMethodsToClsDecls(spc, opId, dom, rng, rngId, vars, body, jcginfo) =
  case splitList (fn(v as (id, srt)) -> userType?(srt)) vars of
    | Some (vars1, varh, vars2) ->
      (let (vh, _) = varh in
       let (methodBody,col1) = mkNonCaseMethodBody(vh, body, spc) in
       let (assertStmt,col2) = mkAssertFromDom(dom, spc) in
       let methodDecl = (([], Some (tt(rngId)), opId, varsToFormalParams(vars1++vars2), []), Some (assertStmt++methodBody)) in
       let jcginfo = addCollectedToJcgInfo(jcginfo,concatCollected(col1,col2)) in
       case varh of
	 | (_, Base (Qualified(q, srthId), _, _)) ->
	   addMethDeclToClsDecls(srthId, methodDecl, jcginfo)
	 | _ ->
	   (warnNoCode(opId,Some("can't happen: user type is not flat"));jcginfo)
	  )
    | _ -> (warnNoCode(opId,Some("no user type found in the arg list of op "^opId));jcginfo)

op mkNonCaseMethodBody: Id * Term * Spec -> Block * Collected
def mkNonCaseMethodBody(vId, body, spc) =
  let thisExpr = CondExp (Un (Prim (Name ([], "this"))), None) in
  let tcx = StringMap.insert(empty, vId, thisExpr) in
  let ((b, k, l),col) = termToExpressionRet(tcx, body, 1, 1, spc) in
  (b,col)

op addMethDeclToSummands: Spec * Id * MethDecl * Term * JcgInfo -> JcgInfo
def addMethDeclToSummands(spc, srthId, methodDecl, body, jcginfo) =
  let clsDecls = jcginfo.clsDecls in
  let Some (_, _, [(_,srt)])  = findTheSort(spc, mkUnQualifiedId(srthId)) in 
  let CoProduct (summands, _) = srt in
  let caseTerm = caseTerm(body) in
  let cases = caseCases(body) in
  %% cases = List (pat, cond, body)
  foldr (fn((pat, _, cb), newJcgInfo) -> addSumMethDeclToClsDecls(srthId, caseTerm, pat, cb, methodDecl, newJcgInfo, spc)) jcginfo cases

op addSumMethDeclToClsDecls: Id * Term * Pattern * Term * MethDecl * JcgInfo * Spec -> JcgInfo
def addSumMethDeclToClsDecls(srthId, caseTerm, pat as EmbedPat (cons, argsPat, coSrt, _), body, methodDecl, jcginfo, spc) =
  let Var ((vId, vSrt), _) = caseTerm in
  let args = case argsPat of
               | Some (RecordPat (args, _)) -> map (fn (id, (VarPat ((vId,_), _))) -> vId) args
               | Some (VarPat ((vId, _), _)) -> [vId]
               | None -> [] in
  let summandId = mkSummandId(srthId, cons) in
  let thisExpr = CondExp (Un (Prim (Name ([], "this"))), None) in
  let tcx = StringMap.insert(empty, vId, thisExpr) in
  let tcx = addArgsToTcx(tcx, args) in
  let ((b, k, l),col) = termToExpressionRet(tcx, body, 1, 1, spc) in
  let JBody = b in
  let newMethDecl = setMethodBody(methodDecl, JBody) in
  let jcginfo = addCollectedToJcgInfo(jcginfo,col) in
  addMethDeclToClsDecls(summandId, newMethDecl, jcginfo)

op addArgsToTcx: TCx * List Id -> TCx
def addArgsToTcx(tcx, args) =
  let def addArgRec(tcx, args, n) =
         case args of
	   | [] -> tcx
	   | arg::args ->
	     let argName = mkArgProj(natToString(n)) in
	     let argExpr = CondExp (Un (Prim (Name (["this"], argName))), None) in
	     addArgRec(StringMap.insert(tcx, arg, argExpr), args, n+1) in
   addArgRec(tcx, args, 1)
  

%  foldr (fn((cons, Some (Product (args, _))), newClsDecls) -> addSumMethDeclToClsDecls(srthId, cons, args, newClsDecls) |
%	 ((cons, None), newClsDecls) -> addSumMethDeclToClsDecls(srthId, cons, [], newClsDecls)) clsDecls summands
%  clsDecls


op modifyClsDeclsFromOps: Spec * JcgInfo -> JcgInfo
def modifyClsDeclsFromOps(spc, jcginfo) =
  let clsDecls = jcginfo.clsDecls in
  foldriAQualifierMap (fn (qualifier, id, op_info, jcginfo) -> 
		       let newJcgInfo = modifyClsDeclsFromOp(spc, qualifier, id, op_info, jcginfo) in
		       newJcgInfo)
  jcginfo spc.ops

op modifyClsDeclsFromOp: Spec * Id * Id * OpInfo * JcgInfo -> JcgInfo
def modifyClsDeclsFromOp(spc, qual, id, op_info as (_, _, (_, srt), [(_, trm)]), jcginfo) =
  let clsDecls = jcginfo.clsDecls in
  case srt of
    | Arrow _ -> addMethodFromOpToClsDecls(spc, id, srt, trm, jcginfo)
    | _ ->
    if notAUserType?(srt)
      then
	let (vars, body) = srtTermDelta(srt, trm) in
	let ((_, jE, _, _),col) = termToExpression(empty, body, 1, 1, spc) in
	let fldDecl = ([Static], baseSrtToJavaType(srt), ((id, 0), Some (Expr (jE))), []) in
	%%Fixed here
	let newJcgInfo = addFldDeclToClsDecls("Primitive", fldDecl, jcginfo) in
	addCollectedToJcgInfo(newJcgInfo,col)
    else
      let Base (Qualified (_, srtId), _, _) = srt in
      let (vars, body) = srtTermDelta(srt, trm) in
      let ((_, jE, _, _),col) = termToExpression(empty, body, 1, 1, spc) in
      let fldDecl = ([Static], tt(srtId), ((id, 0), Some (Expr (jE))), []) in
      %%Fixed here
      let newJcgInfo = addFldDeclToClsDecls(srtId, fldDecl, jcginfo) in
      addCollectedToJcgInfo(newJcgInfo,col)

(**
 * creates the interface collecting the arrow interfaces
 *)
op mkArrowInterface: List InterfDecl -> InterfDecl
def mkArrowInterface(arrowifs) =
  let mods = [(*Public*)] in
  let body = {flds=[],meths=[],clss=[],interfs=arrowifs} in
  (mods,(arrowInterfaceId,[]),body)



op concatClsDecls: JcgInfo * JcgInfo -> JcgInfo
def concatClsDecls({clsDecls=cd1,collected=col1},{clsDecls=cd2,collected=col2}) =
  {clsDecls = cd1 ++ cd2,collected=concatCollected(col1,col2)}

op addCollectedToJcgInfo: JcgInfo * Collected -> JcgInfo
def addCollectedToJcgInfo({clsDecls=cd,collected=col1},col2) =
  {clsDecls=cd,collected=concatCollected(col1,col2)}

op exchangeClsDecls: JcgInfo * List ClsDecl -> JcgInfo
def exchangeClsDecls({clsDecls=_,collected=col},newClsDecls) =
  {clsDecls=newClsDecls,collected=col}

% --------------------------------------------------------------------------------


op specToJava : Spec -> JSpec

def specToJava(spc) =
  %let _ = writeLine("Lifting Patterns") in
  %let spc = liftPattern(spc) in
  let _ = writeLine(";;; Renaming Variables") in
  let spc = distinctVariable(spc) in
  let _ = writeLine(";;; Generating Classes") in
  let jcginfo = clsDeclsFromSorts(spc) in
  let _ = writeLine(";;; Adding Bodies") in
  let jcginfo = modifyClsDeclsFromOps(spc, jcginfo) in
  let _ = writeLine(";;; Writing Java file") in
  let clsDecls = jcginfo.clsDecls in
  let arrowifs = jcginfo.collected.arrowifs in
  let arrowifs = uniqueSort (fn(ifd1 as (_,(id1,_),_),ifd2 as (_,(id2,_),_)) -> compare(id1,id2)) arrowifs in
  %let ifdecls = [mkArrowInterface(arrowifs)] in
  let ifdecls = arrowifs in
  let clsOrInterfDecls = List.concat(map (fn (cld) -> ClsDecl(cld)) clsDecls,
				     map (fn (ifd) -> InterfDecl ifd) ifdecls)
  in
  %let imports = [(["Arrow"],"*")] in
  let imports = [] in
  (None, imports, clsOrInterfDecls)

endspec
