JGen qualifying spec

import Java qualifying /Languages/Java/Java
import /Languages/Java/DistinctVariable
import /Languages/MetaSlang/Specs/StandardSpec

sort ToExprSort = Block * Java.Expr * Nat * Nat

sort Collected = {
		  arrowclasses :List Java.ClsDecl
		 }

op baseSrtToJavaType: Sort -> Java.Type
def baseSrtToJavaType(srt) =
  if boolSort?(srt)
    then tt("Boolean")
  else tt("Integer")

op emptyJSpec: JSpec
def emptyJSpec = (None, [], [])

op emptyClsBody: ClsBody
def emptyClsBody =
  { staticInits = [],
    flds        = [],
    constrs     = [], 
    meths       = [],
    clss        = [],
    interfs     = [] }

op setFlds: ClsBody * List FldDecl -> ClsBody
def setFlds(clsBody, fldDecls) =
  { staticInits = clsBody.staticInits,
    flds        = fldDecls,
    constrs     = clsBody.constrs, 
    meths       = clsBody.meths,
    clss        = clsBody.clss,
    interfs     = clsBody.interfs }

op setMethods: ClsBody * List MethDecl -> ClsBody
def setMethods(clsBody, methodDecls) =
  { staticInits = clsBody.staticInits,
    flds        = clsBody.flds,
    constrs     = clsBody.constrs, 
    meths       = methodDecls,
    clss        = clsBody.clss,
    interfs     = clsBody.interfs }

op setConstrs: ClsBody * List ConstrDecl -> ClsBody
def setConstrs(clsBody, constrDecls) =
  { staticInits = clsBody.staticInits,
    flds        = clsBody.flds,
    constrs     = constrDecls, 
    meths       = clsBody.meths,
    clss        = clsBody.clss,
    interfs     = clsBody.interfs }

op setMethodBody: MethDecl * Block -> MethDecl
def setMethodBody(m, b) =
  let (methHeader, _) = m in
  (methHeader, Some (b))

op appendMethodBody: MethDecl * Block -> MethDecl
def appendMethodBody(m as (methHdr,methBody),b) =
  case methBody of
    | Some b0 -> (methHdr,Some(b0++b))
    | None -> (methHdr, Some(b))

op mkPrimOpsClsDecl: ClsDecl
def mkPrimOpsClsDecl =
  ([], ("Primitive", None, []), emptyClsBody)

(**
 * sort A = B is translated to the empty class A extending B (A and B are user sorts).
 * class A extends B {}
 *)
op userTypeToClsDecls: Id * Id -> List ClsDecl * Collected
def userTypeToClsDecls(id,superid) =
%  ([], (id, None, []), emptyClsBody)
  ([([], (id, Some ([],superid), []), emptyClsBody)],nothingCollected)


op varsToFormalParams: Vars -> List FormPar * Collected
def varsToFormalParams(vars) =
%  map varToFormalParam vars
  foldl (fn(v,(fp,col)) ->
	 let (fp0,col0) = varToFormalParam(v) in
	 (concat(fp,[fp0]),concatCollected(col,col0))) ([],nothingCollected) vars

op varToFormalParam: Var -> FormPar * Collected

%def varToFormalParam_v2(var as (id, srt as Base (Qualified (q, srtId), _, _))) =
%  (false, tt(srtId), (id, 0))

def varToFormalParam(var as (id, srt)) =
  let (ty,col) = tt_v3(srt) in
  ((false, ty, (id, 0)),col)

op fieldToFormalParam: Id * Id -> FormPar
def fieldToFormalParam(fieldProj, fieldType) =
  let fieldName = getFieldName fieldProj in
  (false, tt(fieldType), (fieldName, 0))

op fieldToFldDecl: Id * Id -> FldDecl
def fieldToFldDecl(fieldProj, fieldType) =
  let fieldName = getFieldName fieldProj in
  ([], tt(fieldType), ((fieldName, 0), None), [])

(**
 * ensures the generation of legal Java identifiers as field names
 *)
op getFieldName: Id -> Id
def getFieldName(id) =
  let firstchar = sub(id,0) in
  let fieldName = if isNum firstchar then "field_"^id else id in
  fieldName
  

op mkEqualityMethDecl: Id -> MethDecl
def mkEqualityMethDecl(id) =
  (([], Some (tt("Boolean")), "equals", [(false, tt(id) ,(mkEqarg(id), 0))], []), None)

op mkAbstractEqualityMethDecl: Id -> MethDecl
def mkAbstractEqualityMethDecl(id) =
  (([Abstract], Some (tt("Boolean")), "equals", [(false, tt(id) ,(mkEqarg(id), 0))], []), None)

op mkArgProj: Id -> Id
def mkArgProj(fieldProj) =
  "arg_" ^ fieldProj

op mkEqarg: Id -> Id
def mkEqarg(id) =
  "eqarg"

op mkTagCId: Id -> Id
def mkTagCId(cons) = 
  "TAG_C_"^cons

op mkAssertOp: Id -> Id
def mkAssertOp(opId) =
  "asrt_"^opId
 
op mkTagEqExpr: Id * Id -> Java.Expr
def mkTagEqExpr(clsId, consId) =
  let e1 = CondExp (Un (Prim (Name (["eqarg"],"tag"))), None) in
  let e2 = CondExp (Un (Prim (Name ([clsId], mkTagCId(consId)))), None) in
    mkJavaEq(e1, e2, "Integer")

op mkThrowError: () -> Java.Stmt
def mkThrowError() =
  Throw (CondExp (Un (Prim (NewClsInst(ForCls(([],"Error"), [], None)))), None))

op mkThrowException: String -> Java.Stmt
def mkThrowException(msg) =
  let msgstr = CondExp(Un(Prim(String msg)),None)in
  Throw (CondExp (Un (Prim (NewClsInst(ForCls(([],"IllegalArgumentException"), [msgstr], None)))), None))

def mkThrowFunEq() = mkThrowException("illegal function equality") 
def mkThrowMalf() = mkThrowException("malformed sum value") 
def mkThrowUnexp() = mkThrowException("unexpected sum value") 

op mkDefaultCase: Match * Spec -> List SwitchLab * List BlockStmt
def mkDefaultCase(cases,spc) =
  let swlabel = [Default] in
  let stmt = mkThrowMalf() in
  (swlabel,[Stmt stmt])

sort JSpec = CompUnit

op mkIfRes: Nat -> Id
def mkIfRes(k) =
  "ires_" ^ natToString(k)

op mkTgt: Nat -> Id
def mkTgt(l) =
  "tgt_" ^ natToString(l)

op mkcres: Nat -> Id
def mkCres(l) =
  "cres_" ^ natToString(l)

op mkSub: Id * Nat -> Id
def mkSub(id, l) =
  "sub_"^id^"_"^natToString(l)

op mkSumd: Id * Id -> Id
def mkSumd(cons, caseType) =
  %"sumd_"^cons^"_"^caseType
  caseType^"$$"^cons % v3 page 67

op mkTag: Id -> Id
def mkTag(cons) =
  "TAG_"^cons

op mkFinalVar: Id -> Id
def mkFinalVar(id) =
  "fin_"^id

op mkFinalVarDecl: Id * Sort * Java.Expr -> BlockStmt * Collected
def mkFinalVarDecl(varid,srt,exp) =
  let (type,col) = tt_v3 srt in
  let isfinal = true in
  let vdecl = ((varid,0),Some(Expr exp)) in
  (LocVarDecl(isfinal,type,vdecl,[]),col)

sort TCx = StringMap.Map Java.Expr

op mts: Block
def mts = []

def tt = tt_v2

op tt_v2: Id -> Java.Type
def tt_v2(id) =
  case id of
    | "Boolean" -> (Basic (JBool), 0)
    | "Integer" -> (Basic (JInt), 0)
    | "Nat" -> (Basic (JInt), 0)
    | "Char" -> (Basic (Char), 0)
    | _ -> (Name ([], id), 0)

(**
 * the new implementation of tt uses type information in order to generate the arrow type (v3)
 *)
op tt_v3: Sort -> Java.Type * Collected
def tt_v3(srt) =
  case srt of
    | Base(Qualified(_,id),_,_) -> (tt_v2(id),nothingCollected)
    | Arrow(srt0,srt1,_) -> 
      let (sid,col) = srtId(srt) in
      (mkJavaObjectType(sid),col)

op tt_id: Sort -> Id * Collected
def tt_id(srt) = 
  let (ty,col) = tt_v3(srt) in
  (getJavaTypeId(ty),col)

(**
 * srtId returns for a given type the string representation accorinding the rules
 * in v3 page 67 for class names. It replaces the old version in LiftPattern.sw
 *)
op srtId: Sort -> String * Collected
def srtId(srt) =
  let (_,s,col) = srtId_internal(srt) in
  (s,col)

op srtId_internal: Sort -> List Java.Type * String * Collected
def srtId_internal(srt) =
  case srt of
    | Base (Qualified (q, id), _, _) -> ([tt_v2 id],id,nothingCollected)
    | Product(fields,_) -> foldl (fn((_,fsrt),(types,str,col)) ->
				  let (str0,col0) = srtId(fsrt) in
				  let str = str ^ (if str = "" then "" else "$$") ^ str0 in
				  let col = concatCollected(col,col0) in
				  let types = concat(types,[tt_v2(str0)]) in
				  (types,str,col)) ([],"",nothingCollected) fields
    | Arrow(dsrt,rsrt,_) ->
      let (dtypes,dsrtid,col2) = srtId_internal dsrt in
      let (rsrtid,col1) = srtId rsrt in
      let (pars,_) = foldl (fn(ty,(pars,nmb)) -> 
			    let fpar = (false,ty,("arg"^Integer.toString(nmb),0)) in
			    (concat(pars,[fpar]),nmb+1)
			   ) ([],1) dtypes in
      let methHdr = ([],Some(tt_v2(rsrtid)),"apply",pars,[]) in
      let id = dsrtid^"$To$"^rsrtid in
      let clsDecl = mkArrowClassDecl(id,(methHdr,None)) in
      let col3 = {arrowclasses=[clsDecl]} in
      let col = concatCollected(col1,concatCollected(col2,col3)) in
      ([tt_v2 id],id,col)
    | _ -> fail("don't know how to transform sort \""^printSort(srt)^"\"")

op getJavaTypeId: Java.Type -> Id
def getJavaTypeId(jt) =
  case jt of
    | (bon,0) -> (case bon of
		    | Basic JBool -> "boolean"
		    | Basic Byte -> "byte"
		    | Basic Short -> "short"
		    | Basic Char -> "char"
		    | Basic JInt -> "int"
		    | Basic Long -> "long"
		    | Basic JFloat -> "float"
		    | Basic Double -> "double"
		    | Name (_,id) -> id
		 )
    | _ -> fail("can't handle non-scalar types in getJavaTypeId")

(**
 * generates a string representation of the type id1*id2*...*idn -> id
 * the ids are MetaSlang sort ids 
 *)
op mkArrowSrtId: List Id * Id -> String * Collected
def mkArrowSrtId(domidlist,ranid) =
  let p = Internal "" in
  let ran = Base(mkUnQualifiedId(ranid),[],p) in
  let fields = map (fn(id) -> ("x",Base(mkUnQualifiedId(id),[],p):Sort)) domidlist in
  let dom = Product(fields,p) in
  let srt = Arrow(dom,ran,p) in
  srtId(srt)

op mkJavaObjectType: Id -> Java.Type
def mkJavaObjectType(id) =
  (Name ([],id),0)

op mkJavaNumber: Integer -> Java.Expr
def mkJavaNumber(i) =
  CondExp (Un (Prim (IntL (i))), None)

def mkJavaBool(b) =
  CondExp (Un (Prim (Bool (b))), None)

op mkVarJavaExpr: Id -> Java.Expr
def mkVarJavaExpr(id) = CondExp (Un (Prim (Name ([], id))), None)

op mkQualJavaExpr: Id * Id -> Java.Expr
def mkQualJavaExpr(id1, id2) = CondExp (Un (Prim (Name ([id1], id2))), None)

op mkThisExpr:() -> Java.Expr
def mkThisExpr() =
  CondExp(Un(Prim(This None)),None)

op mkBaseJavaBinOp: Id -> Java.BinOp
def mkBaseJavaBinOp(id) =
  case id of
    | "and" -> CdAnd
    | "or" -> CdOr
    | "=" -> Eq
    | ">" -> Gt
    | "<" -> Lt
    | ">=" -> Ge
    | "<=" -> Le
    | "+" -> Plus
    | "-" -> Minus
    | "*" -> Mul
    | "div" -> Div
    | "rem" -> Rem

op mkBaseJavaUnOp: Id -> Java.UnOp
def mkBaseJavaUnOp(id) =
  case id of
    | "-" -> Minus
    | "~" -> LogNot

op javaBaseOp?: Id -> Boolean
def javaBaseOp?(id) =
  case id of
    | "and" -> true
    | "or" -> true
    | "=" -> true
    | ">" -> true
    | "<" -> true
    | ">=" -> true
    | "<=" -> true
    | "+" -> true
    | "-" -> true
    | "*" -> true
    | "div" -> true
    | "rem" -> true
    %%| "-" -> true
    | "~" -> true
    | _ -> false

op mkBinExp: Id * List Java.Expr -> Java.Expr
def mkBinExp(opId, javaArgs) =
  let [ja1, ja2] = javaArgs in
  CondExp (Bin (mkBaseJavaBinOp(opId), Un (Prim (Paren (ja1))), Un (Prim (Paren (ja2)))), None)

op mkUnExp: Id * List Java.Expr -> Java.Expr
def mkUnExp(opId, javaArgs) =
  let [ja] = javaArgs in
  CondExp (Un (Un (mkBaseJavaUnOp(opId), Prim (Paren (ja)))), None)

op mkJavaEq: Java.Expr * Java.Expr * Id -> Java.Expr
def mkJavaEq(e1, e2, t1) =
  if (t1 = "Boolean" or t1 = "Integer" or t1 = "Nat")
    then CondExp (Bin (Eq, Un (Prim (Paren (e1))), Un (Prim (Paren (e2)))), None)
  else
    CondExp (Un (Prim (MethInv (ViaPrim (Paren (e1), "equals", [e2])))), None)
%    CondExp (Un (Prim (MethInv (ViaName (([t1], "equals"), [e2])))), None)
  
op mkFldAcc: Java.Expr * Id -> Java.Expr
def mkFldAcc(e, id) = 
  CondExp (Un (Prim (FldAcc (ViaPrim (Paren (e), id)))), None)

op mkFldAccViaClass: Id * Id -> Java.Expr
def mkFldAccViaClass(cls, id) = 
  CondExp (Un (Prim (FldAcc (ViaCls (([], cls), id)))), None)

op mkFldAssn: Id * Id * Java.Expr -> BlockStmt
def mkFldAssn(cId, vId, jT1) =
  let fldAcc = mkFldAccViaClass(cId, vId) in
  Stmt (Expr (Ass (FldAcc (ViaCls (([], cId), vId)), Assgn, jT1)))

op mkMethInvName: Java.Name * List Java.Expr -> Java.Expr
def mkMethInvName(name, javaArgs) =
  CondExp (Un (Prim (MethInv (ViaName (name, javaArgs)))), None)

op mkMethInv: Id * Id * List Java.Expr -> Java.Expr
def mkMethInv(srtId, opId, javaArgs) =
  CondExp (Un (Prim (MethInv (ViaPrim (Name ([], srtId), opId, javaArgs)))), None)

op mkMethExprInv: Java.Expr * Id * List Java.Expr -> Java.Expr
def mkMethExprInv(topJArg, opId, javaArgs) =
  CondExp (Un (Prim (MethInv (ViaPrim (Paren (topJArg), opId, javaArgs)))), None)

(**
 * takes the ids from the formal pars and constructs a method invocation to the given opId
 *)
op mkMethodInvFromFormPars: Id * List FormPar -> Java.Expr
def mkMethodInvFromFormPars(opId,fpars) =
  let parIds = map (fn(_,_,(id,_)) -> id) fpars in
  let vars = mkVars parIds in
  let opname = ([],opId) in
  mkMethInvName(opname,vars)

op mkVars: List Id -> List Java.Expr
def mkVars(ids) =
  map mkVarJavaExpr ids

(**
 * returns the application that constitutes the assertion for the given var.
 * E.g., (id,(Nat|even)  -> Some(Apply(even,id))
 * This only works, because the super sort of a restriction sort must be a flat sort, no records etc. 
*)
op mkAsrtTestAppl: Spec * Var -> Option Term
def mkAsrtTestAppl(spc,var as (id,srt)) =
  case getRestrictionTerm(spc,srt) of
    | Some t -> 
      let b = sortAnn(srt) in
      Some(Apply(t,Var(var,b),b))
    | None -> None


(**
 * generates the conjunction of assertions for the given variable list
 *)
op mkAsrtExpr: Spec * List Var -> Option Term
def mkAsrtExpr(spc,vars) =
  let
    def mkAsrtExpr0(vars,optterm) =
      case vars of
	| [] -> optterm
	| var::vars -> 
	  let appl = mkAsrtTestAppl(spc,var) in
	  let next = 
	  (case appl of
	     | Some t0 -> (case optterm of
			     | None -> appl
			     | Some t -> 
			       let b = termAnn(t) in
			       let boolSort:Sort = Base(Qualified("Boolean","Boolean"),[],b) in
			       let andsrt = Arrow(Product([("1",boolSort),("2",boolSort)],b),boolSort,b) in
			       let opterm = Fun(Op(Qualified("Boolean","&"),Nonfix),andsrt,b) in
			       let argsterm:Term = Record([("1",t),("2",t0)],b) in
			       Some (Apply(opterm,argsterm,b))
			      )
	     | None -> optterm
	    )
	  in
	  mkAsrtExpr0(vars,next)
  in
  mkAsrtExpr0(vars,None)

(**
 * returns the restriction term for the given sort, if it has one.
 *)
op getRestrictionTerm: Spec * Sort -> Option Term
def getRestrictionTerm(spc,srt) =
  let srt = unfoldBase(spc,srt) in
  case srt of
    | Subsort(_,pred,_) -> Some pred
    | _ -> None


(**
  * returns the Java type for the given id, checks for basic names like "int" "boolean" etc.
  *)
op getJavaTypeFromTypeId: Id -> Java.Type
def getJavaTypeFromTypeId(id) =
  if id = "int" then (Basic JInt,0)
  else
  if id = "boolean" then (Basic JBool,0)
  else
  if id = "byte" then (Basic Byte,0)
  else
  if id = "short" then (Basic Short,0)
  else
  if id = "char" then (Basic Char,0)
  else
  if id = "long" then (Basic Long,0)
  else
  if id = "double" then (Basic Double,0)
  else
  mkJavaObjectType(id)    


(**
 * creates a method declaration from the following parameters:
 * @param methodName
 * @param argTypeNames the list of argument type names
 * @param retTypeName the name of the return type
 * @param argNameBase the basename of the arguments; actual arguments are created by appending 1,2,3, etc to this name
 * @param the statement representing the body of the method; usually a return statement
 *)
op mkMethDeclWithParNames: Id * List Id * Id * List Id * Java.Stmt -> MethDecl
def mkMethDeclWithParNames(methodName,parTypeNames,retTypeName,parNames,bodyStmt) =
  let body = [Stmt bodyStmt] in
%  let (pars,_) = foldl (fn(argType,(types,nmb)) -> 
%		    let type = getJavaTypeFromTypeId(argType) in
%		    let argname = argNameBase^Integer.toString(nmb) in
%		    (concat(types,[(false,type,(argname,0))]),nmb+1))
%                   ([],1) argTypeNames
%  in
  let pars = map (fn(parType,parName) -> (false,getJavaTypeFromTypeId(parType),(parName,0))) 
             (ListPair.zip(parTypeNames,parNames))
  in
  let retType = Some (getJavaTypeFromTypeId(retTypeName)) in
  let mods = [Public] in
  let throws = [] in
  let header = (mods,retType,methodName,pars:FormPars,throws) in
  (header,Some body)

op mkMethDecl: Id * List Id * Id * Id * Java.Stmt -> MethDecl
def mkMethDecl(methodName,argTypeNames,retTypeName,argNameBase,bodyStmt) =
  let (parNames,_) = foldl (fn(argType,(argnames,nmb)) -> 
		    let argname = argNameBase^Integer.toString(nmb) in
		    (concat(argnames,[argname]),nmb+1))
                   ([],1) argTypeNames
  in
  mkMethDeclWithParNames(methodName,argTypeNames,retTypeName,parNames,bodyStmt)

(**
  * creates a method decl with just one return statement as body,
  * see mkMethDecl for the other parameters
  *)
op mkMethDeclJustReturn: Id * List Id * Id * Id * Java.Expr -> MethDecl
def mkMethDeclJustReturn(methodName,argTypeNames,retTypeName,argNameBase,retExpr) =
  let retStmt = mkReturnStmt(retExpr) in
  mkMethDecl(methodName,argTypeNames,retTypeName,argNameBase,retStmt)

def mkNewClasInst(id, javaArgs) =
  CondExp (Un (Prim (NewClsInst (ForCls (([], id), javaArgs, None)))), None)

(**
 * creates a "new" expression for an anonymous class with the given "local" class body
 *)
def mkNewAnonymousClasInst(id, javaArgs,clsBody:ClsBody) =
  CondExp (Un (Prim (NewClsInst (ForCls (([], id), javaArgs, Some clsBody)))), None)

(**
 * creates a "new" expression for an anonymous class with the given method declaration as
 * only element of the "local" class body; it also returns the corresponding interface declaration
 * that is used for generating the arrow class interface
 *)
def mkNewAnonymousClasInstOneMethod(id,javaArgs,methDecl) =
  let clsBody = {staticInits=[],flds=[],constrs=[],meths=[methDecl],clss=[],interfs=[]} in
  let exp = CondExp (Un (Prim (NewClsInst (ForCls (([], id), javaArgs, Some clsBody)))), None) in
  let cldecl = mkArrowClassDecl(id,methDecl) in
  %let _ = writeLine("generated class decl: "^id) in
  (exp,cldecl:Java.ClsDecl)


(**
 * this generates the arrow class definition given the class name and the "apply" method declaration; the "body" part of
 * the methDecl parameter will be ignored; it will be transformed into an abstract method.
 *)
op mkArrowClassDecl: Id * MethDecl -> ClsDecl
def mkArrowClassDecl(id,methDecl) =
  let (methHdr as (mmods,mretype,mid,mpars,mthrows),_) = methDecl in
  let absApplyMethDecl = ((cons(Abstract,mmods),mretype,mid,mpars,mthrows),None) in
  % construct the equality method that does nothing but throwing an exception:
  let eqPars = [(false,(Name ([],id),0),("arg",0))] in
  let eqHdr = ([],Some(Basic JBool,0),"equals",eqPars,[]) in
  let eqBody = [Stmt(mkThrowFunEq())] in
  let equalMethDecl = (eqHdr,Some eqBody) in
  let clmods = [Abstract] in
  let clheader = (id,None,[]) in
  let clbody = {staticInits=[],flds=[],constrs=[],meths=[absApplyMethDecl,equalMethDecl],clss=[],interfs=[]} in
  let cldecl = (clmods,clheader,clbody) in
  cldecl


op mkVarDecl: Id * Id -> BlockStmt
def mkVarDecl(v, srtId) =
  LocVarDecl (false, tt(srtId), ((v, 0), None), [])
  
op mkNameAssn: Java.Name * Java.Name -> BlockStmt
def mkNameAssn(n1, n2) =
  Stmt (Expr (Ass (Name n1, Assgn, CondExp (Un (Prim (Name n2)) , None))))

op mkVarAssn: Id * Java.Expr -> BlockStmt
def mkVarAssn(v, jT1) =
  Stmt (Expr (Ass (Name ([], v), Assgn, jT1)))

op mkVarInit: Id * Id * Java.Expr -> BlockStmt
def mkVarInit(vId, srtId, jInit) =
  LocVarDecl (false, tt(srtId), ((vId, 0), Some ( Expr (jInit))), [])

op mkIfStmt: Java.Expr * Block * Block -> BlockStmt
def mkIfStmt(jT0, b1, b2) =
  Stmt (If (jT0, Block (b1), Some (Block (b2))))

op mkReturnStmt: Java.Expr -> Stmt
def mkReturnStmt(expr) =
  Return(Some expr)

(**
 * creates from the given pattern a list of formal parameters to be used in the definition of a method;
 * if a pattern is a wildcard pattern, the id "argi" is used, where i is the position of the parameter.
 *)
op mkParamsFromPattern: Pattern -> List Id
def mkParamsFromPattern(pat) =
  let
    def errmsg_unsupported(pat) =
      ("unsupported pattern in lambda term: '"^printPattern(pat)^"', only variable pattern and '_' are supported.")
  in
  let
    def patlist(patl,n) =
      case patl of
	| [] -> []
	| pat0::patl ->
	  (let id = case pat0 of
	              | VarPat((id,_),_) -> id
	              | WildPat _ -> "arg"^Integer.toString(n)
		      | _ -> fail(errmsg_unsupported(pat))
	   in
	   let ids = patlist(patl,n+1) in
	   cons(id,ids)
	  )
  in
  case pat of
    | VarPat((id,_),_) -> [id]
    | WildPat _ -> ["arg1"]
    | RecordPat(patl,_) -> patlist(map (fn(_,p)->p) patl,1)
    | _ -> fail(errmsg_unsupported(pat))

(**
 * looks in the spec for a user type matching the given sort; if a matching
 * user type exists, the corresponding sort will be returned, otherwise the sort
 * given as input itself will be returned
 *)
op findMatchingUserType: Spec * Sort -> Sort
def findMatchingUserType(spc,recordSrt) =
  let srts = sortsAsList(spc) in
  let srtPos = sortAnn recordSrt in
  let foundSrt = find (fn (qualifier, id, (_, _, [(_,srt)])) -> equalSort?(recordSrt, srt)) srts in
  case foundSrt of
     | Some (q, recordClassId, _) ->  Base(mkUnQualifiedId(recordClassId),[],srtPos)
     | None -> recordSrt

(**
 * looks in the spec for a user type that is a restriction type, where the given sort is the sort of the
 * restrict operator. The sort must be in the form X -> (X|p), and this op returns the name of the user type
 * that is defined as (X|p)
 *)
op findMatchingRestritionType: Spec * Sort -> Option Sort
def findMatchingRestritionType(spc,srt) =
  case srt of
    | Arrow(X0,ssrt as Subsort(X1,pred,_),_) -> 
      if equalSort?(X0,X1) then
	(let srts = sortsAsList(spc) in
	 let srtPos = sortAnn ssrt in
	 let foundSrt = find (fn(qualifier,id,(_,_,[(_,srt)])) -> equalSort?(ssrt,srt)) srts in
	 case foundSrt of
	   | Some (q,subsortid,_) -> Some(Base(mkUnQualifiedId(subsortid),[],srtPos))
	   | None -> None
	  )
      else None
    | _ -> None

(**
 * compares the summand sort with the match and returns the list of constructor ids
 * that are not present in the match.
 *)
op getMissingConstructorIds: Sort * Match -> List Id
def getMissingConstructorIds(srt as CoProduct(summands,_), cases) =
  let missingsummands = filter (fn(constrId,_) -> 
				case find (fn(pat,_,_) ->
					   case pat of
					     | EmbedPat(id,_,_,_) -> id = constrId
					     | _ -> false) cases of
				  | Some _ -> false
				  | None -> true) summands
  in
  map (fn(id,_) -> id) missingsummands

(**
 * search for the wild pattern in the match and returns the corresponding body, if it
 * has been found.
 *)
op findWildPat: Match -> Option Term
def findWildPat(cases) =
  case cases of
    | [] -> None
    | (pat,cond,term)::cases -> 
      (case pat of
	 | WildPat _ -> Some term
	 | _ -> findWildPat(cases)
	)

op concatCollected: Collected * Collected -> Collected
def concatCollected(col1,col2) =
  {
   arrowclasses=concat(col1.arrowclasses,col2.arrowclasses)
  }

op nothingCollected: Collected
def nothingCollected = {
			arrowclasses = []
		       }

%--------------------------------------------------------------------------------
%
% constants
%
% --------------------------------------------------------------------------------

def primitiveClassName : Id = "Primitive"

endspec
