% derived from SW4/Languages/MetaSlang/ADT/Specs/Environment.sl v1.4
% Some names have had to be introduced qualified with SpecEnvironment
% to avoid clashes with others qualified with MetaSlang

(*
 * SpecEnvironment builds an association map of type identifiers 
 * to their definitional unfolding. 
 *) 
 
SpecEnvironment qualifying
spec
 import Utilities
 import Printer
 import /Library/Legacy/DataStructures/ListPair
 %% importing TypecChecker is overkill
 %import Elaborate/TypeChecker

 type SpecEnvironment = StringMap Spec
 % type Env             = SpecName * SpecEnvironment

 op makeEnv     : List Spec              -> SpecEnvironment
 op empty       : ()                     -> SpecEnvironment
 op add         : SpecEnvironment * Spec -> SpecEnvironment 
 op add_rev     : Spec * SpecEnvironment -> SpecEnvironment 

% %% makeSpecReportError is called only from ui::loadFile
% %%  (and from some mysterious GlueFront routines)
% def makeSpecReportError (specs, spc, env, fileName) = 
%  %% env will be ignored!
%  makeSpecReportError_ (specs, spc, env, true, fileName)

% def makeSpecNoMergeImportsReportError (specs, spc, env, fileName) =
%  %% env will be ignored!
%  makeSpecReportError_ (specs, spc, env, false, fileName)

% def makeSpecReportError_ (specs, spc, env, _(* mergeImports? *), fileName) =
%  let specs2 = StringMap.listItems (empty ()) in
%  %% env will be ignored!
%  case elaborateSpecReportError(specs2 ++ specs,spc,env,fileName) 
%    of Error msg -> Error msg
%     | Ok spc -> 
%       let spc = convertPosSpecToSpec spc in
%       let spc = addImportedSpecsEnv(spc,makeEnv specs2)
%       in Ok spc


 op unfoldBeforeCoProduct: Spec * MSType -> MSType
 def unfoldBeforeCoProduct(sp, srt) =
   case srt of
     | Base (qid, srts, a) ->
      (case findTheType (sp, qid) of
	 | None -> srt
	 | Some info ->
	   if definedTypeInfo? info then
	     let (tvs, fsrt) = unpackFirstTypeDef info in
	     case fsrt of
	       | CoProduct _ -> srt
	       | _ -> 
	       let ssrt = substType (zip (tvs, srts), fsrt) in
		 unfoldBeforeCoProduct (sp, ssrt)
	   else
	     srt)
    | _ -> srt

op stripSubtypesAndBaseDefs (spc : Spec) (typ : MSType) : MSType =
  let 
    def strip typ =
      case typ of

        | Subtype (typ, _, _) -> strip typ

        | Base (qid, typs, a) ->
          (case findTheType (spc, qid) of
             | Some info ->
               if definedTypeInfo? info then
                 let (tvs, tdef) = unpackFirstTypeDef info in
                 let recur? = (length tvs = length typs)
                              &&
                              (case tdef of
                                 | Subtype _ -> true
                                 | Base    _ -> true
                                 | _ -> false)
                 in
                 if recur? then 
                   strip (substType (zip (tvs, typs), tdef))
                 else
                   typ
               else
                 typ
             | _ -> typ)

        | _ -> typ
  in
  strip typ

op specStripSubtypesAndBaseDefs (spc : Spec) : Spec =
  let stripper = stripSubtypesAndBaseDefs spc in
  mapSpec (fn t -> t, stripper, fn p -> p) spc

 %% This is dangerous as there may be recursion (I have removed calls to it -- sjw)
 op unfoldStripType : Spec * MSType * Bool -> MSType
 def unfoldStripType (spc, srt, verbose) =
  unfoldStripType1 (spc, srt, [], verbose)

 op unfoldStripType1 : Spec * MSType * List(MSType) * Bool -> MSType
 def unfoldStripType1 (sp, srt, vsrts, verbose) =
  if typeIn?(srt, vsrts) then
    srt
  else
    case srt of
       | Arrow(srt1,srt2,a) -> 
         Arrow(unfoldStripType1(sp,srt1,vsrts,verbose),
               unfoldStripType1(sp,srt2,vsrts,verbose),
               a)
       | Product(srtlist, a) -> 
         Product(List.map (fn(id,s) -> (id,unfoldStripType1(sp,s,vsrts,verbose))) srtlist,
                  a)
       | CoProduct (srtlist, a) -> 
         CoProduct (List.map (fn 
                              | (id, None)   -> (id, None)
                              | (id, Some s) -> (id, Some (unfoldStripType1 (sp,
                                                                             s, 
                                                                             vsrts,
                                                                             verbose))))
                             srtlist,
                     a)
       | Quotient (srt, _,    _) -> unfoldStripType1 (sp, srt, vsrts, verbose)
       | Subtype  (srt, t,    _) -> unfoldStripType1 (sp, srt, vsrts, verbose)
       | Base     (qid, srts, a) ->
         let srts = List.map (fn(s) -> unfoldStripType1 (sp, s, vsrts, verbose)) srts in
         let srt0 = Base (qid, srts, a) in
         let srt = unfoldBaseV (sp, srt0, verbose) in
         if srt = srt0 then
             srt
         else
          unfoldStripType1 (sp, srt, Cons(srt0,vsrts), verbose)
       | Boolean _ -> srt
       | TyVar (tv, a) -> srt
     

op stripRangeSubtypes(sp: Spec, srt: MSType, dontUnfoldQIds: List QualifiedId): MSType =
   case srt of
     | Base(qid, _, _) | qid in? dontUnfoldQIds -> srt
     | Subtype (s_srt, _, _) -> stripRangeSubtypes (sp, s_srt, dontUnfoldQIds)
     | Arrow (d_srt, r_srt, a)-> Arrow(d_srt, stripRangeSubtypes (sp, r_srt, dontUnfoldQIds), a)
     | Base _ ->
       let uf_srt = unfoldBase (sp, srt) in
       if equalType?(uf_srt, srt) || embed? CoProduct srt || embed? Quotient srt
         then srt
         else stripRangeSubtypes (sp, uf_srt, dontUnfoldQIds)
     | _ -> srt
   
 op arrow : Spec * MSType -> MSType * MSType

 def arrow (sp : Spec, srt : MSType) = 
   case stripSubtypes (sp, srt) of
     | Arrow (dom, rng, _) -> (dom, rng)
     | mystery ->
       % let _ = writeLine(printSpecFlat sp) in
       System.fail ("Could not extract arrow type: " ^ (printType srt) ^ " yielded " ^ (printType mystery))
     
 def product (sp : Spec, srt : MSType) = 
   let srt = unfoldBase(sp,srt) in
   case stripSubtypes (sp, srt) of
     | Product (fields, _) -> fields
     | mystery -> System.fail ("Could not extract product type: " ^ (printType srt) ^ " yielded " ^ (printType mystery))
      
 op  productTypes: Spec * MSType -> List MSType
 def productTypes (sp, srt1) =
   let srt = unfoldBase(sp,srt1) in
   case stripSubtypes (sp, srt)
    of Product (fields, _) ->
       if tupleFields? fields
	 then map (fn (_,x) -> x) fields
	 else [srt1]
     | _ -> [srt1]

 op recordTypes(sp: Spec, ty1: MSType): List MSType =
   let ty = unfoldBase(sp, ty1) in
   case stripSubtypes (sp, ty)
    of Product (fields, _) ->
       map (fn (_,x) -> x) fields
     | _ -> [ty1]

 def coproduct (sp : Spec, srt : MSType) = 
  case stripSubtypes (sp, srt) of
    | CoProduct (fields, _) -> fields
    | mystery -> System.fail ("Could not extract co-product type: " ^ (printType srt) ^ " yielded " ^ (printType mystery))
  
 def domain (sp, srt) = 
  let (dom, _) = arrow (sp, srt) in dom
 
 def range (sp, srt) = 
  let (_, rng) = arrow (sp, srt) in rng

 op  arrow?     : Spec * MSType -> Bool
 def arrow? (sp, srt) =
   case stripSubtypes (sp, srt)
    of Arrow _ -> true
     | _ -> false

 op range_*(spc: Spec, ty: MSType, ign_subtypes?: Bool): MSType =
   case unfoldBase (spc, ty)
    of Arrow(_, rng, _) -> range_*(spc, rng, ign_subtypes?)
     | Subtype(st, _, _) | ign_subtypes? -> range_*(spc, st, ign_subtypes?)
     | _ -> ty

 %- def arrowOpt(sp:Spec,srt:Type) = 
 %-   let res = arrowOpt_(sp,srt) in
 %-   let _ = writeLine("arrowOpt("^printType(srt)^")="^
 %-                       (case res
 %-                          of None -> "None"
 %-                           | Some(dom,rng) -> printType(Arrow(dom,rng)))) in
 %-   res


% def SpecEnvironment.stringType : MSType = Base (Qualified ("String",  "String"), [], noPos)
% def boolType                   : MSType = Boolean noPos
% def SpecEnvironment.charType   : MSType = Base (Qualified ("Char",    "Char"),   [], noPos)
% def intType                    : MSType = Base (Qualified ("Integer", "Int"),    [], noPos)

%% This is no different than MetaSlang.patternType 
% op SpecEnvironment.patternType : MSPattern -> MSType
% def SpecEnvironment.patternType = fn
%   | AliasPat   (pat1, _,       _) -> SpecEnvironment.patternType pat1
%   | VarPat     ((_,srt),       _) -> srt
%   | EmbedPat   (_,_,srt,       _) -> srt
%   | RecordPat  (idpatternlist, _) -> let fields = List.map (fn (id, pat) -> 
%                                                             (id, SpecEnvironment.patternType pat)) 
%                                                            idpatternlist in
%                                      Product (fields, noPos)
%   | WildPat     (srt,          _) -> srt
%   | StringPat   _                 -> SpecEnvironment.stringType
%   | BoolPat     _                 -> boolType
%   | CharPat     _                 -> SpecEnvironment.charType
%   | NatPat      _                 -> intType
%   | QuotientPat (pat, _,       _) -> SpecEnvironment.patternType pat


 op mkRestrict    : Spec * {pred : MSTerm, term : MSTerm} -> MSTerm
 op mkProjectTerm : Spec * Id * MSTerm                    -> MSTerm
 op mkSelectTerm  : Spec * Id * MSTerm                    -> MSTerm

 def mkRestrict (sp, {pred, term}) = 
  let srt = inferType (sp, term) in
  let srt = mkArrow (srt, mkSubtype (srt, pred)) in
  mkApply ((Fun (Restrict, srt, noPos)), 
           term)
 
 def mkProjectTerm (sp, id, term) = 
  let srt = inferType (sp, term) in
  let fields = product (sp, srt) in
    (case findLeftmost (fn (id2, s)-> id = id2) fields
       of Some (_, s) -> 
          mkApply(Fun (Project id, mkArrow(srt,s), noPos),
                  term)
        | _ -> System.fail "Projection index not found in product")

 def mkSelectTerm (sp, id, term) = 
  let srt    = inferType (sp, term) in
  let fields = coproduct (sp, srt)  in
  case findLeftmost (fn (id2, s)-> id = id2) fields
    of Some (_,Some s) -> mkApply (Fun (Select id, mkArrow (srt, s), noPos),
                                   term)
     | _ -> System.fail "Selection index not found in product"

 
 % Assuming that op names are unambiguous in a spec
 % one can obtain the type of ops given the name and spec only.

%%  ### unused
%%  op  getTypeOfOp : Spec * String * String -> TyVars * Type
%%  def getTypeOfOp (spc, qid, opName) =
%%   % sjw: (4/02) Not sure if should check imports
%%   case findAQualifierMap (spc.ops, qid, opName)
%%     of None -> (printSpecToTerminal spc;
%%                 System.fail ("Operator "^qid^"."^opName^" has not been declared"
%%                              ))
%%      | Some (op_names, fixity, (tyVars, srt), opt_def) -> (tyVars, srt)
%% 

 %- ----------------------------------------------------------------
 %- get dependencies transitively
 %- ----------------------------------------------------------------

% op getDependenciesSpecTrans : SpecEnvironment * Spec -> List Spec
% def getDependenciesSpecTrans (env, spc) =
%  let
%   def getDependenciesSpecTrans0 (env, spclist : List Spec, spcsfinished : List Spec) =
%    case spclist
%      of [] -> spcsfinished
%       | spc :: spclist ->
%         let spcname = spc.name in
%         if member(spcname, List.map (fn(spc) -> spc.name) spcsfinished) then 
%          %- spec is already in the list of processed specs
%          getDependenciesSpecTrans0 (env, spclist, spcsfinished)
%         else
%          let specdepslist = StringSet.toList(getDependenciesSpec(spc)) in
%          let spcsfinished = cons(spc,spcsfinished) in
%          let spclist = List.foldl
%                        (fn (spclist, spcn) ->
%                         let spcnl = List.map (fn(spc) -> spc.name) spclist in
%                         if member (spcn, spcnl) then 
%                           spclist
%                         else
%                           case lookupSpec(env,spcn)
%                             of Some spc -> cons(spc,spclist)
%                              | None     ->
%                                (writeLine("*** WARNING: spec "^spcn^" not found ***");
%                                 spclist))
%                        spclist specdepslist
%          in
%            getDependenciesSpecTrans0(env,spclist,spcsfinished)
%  in
%  %- allspecs contain all specs that are used by specs + the spec itself
%  let allspecs = getDependenciesSpecTrans0(env,[spc],[]) in
%  let allspecs = foldl (fn (spcs,spcname) ->
%                        let spcnames = List.map (fn (spc : Spec) -> spc.name) spcs in
%                        if member (spcname, spcnames) then 
%                         spcs
%                        else
%                         case lookupSpec (env, spcname)
%                           of None     -> spcs
%                            | Some spc -> cons (spc, spcs))
%                         allspecs 
%                       primitiveSpecNames
%  in
%  let usedspecs = filter (fn(s) -> ~(s.name = spc.name)) allspecs in
%  usedspecs

 %- ---------------------------------------------------------------------------------
 %- calculate the minimal SpecEnvironment for a spec in that sense that the resulting
 %- SpecEnvironment contains only those specs that the input spec uses
 %- ---------------------------------------------------------------------------------

% op getMinimalSpecEnvironment : SpecEnvironment * Spec -> SpecEnvironment
% def getMinimalSpecEnvironment (env, spc) =
%  let usedspecs = getDependenciesSpecTrans (env, spc) in
%  StringMap.fromList (List.map (fn(spc) -> (spc.name, spc)) usedspecs)

 %- --------------------------------------------------------------------------
 %- search for a spec with a given name

(* ### unused
 op lookupSpec : SpecEnvironment * String -> Option Spec
 def lookupSpec (env, spcname) =
  StringMap.foldli (fn (_,     _,   Some spc) -> Some spc
                     | (sname, spc, None)     -> if sname = spcname 
                                                 then Some spc
                                                 else None)
                   None 
                   (env : StringMap Spec)
*)

 %- --------------------------------------------------------------------------------
 (**
  unfold to an arrow type; if it doesn't unfold to an arrow, leave it unchanged.
  *)

(* ### unused #NO! **)
 op unfoldToArrow: Spec * MSType -> MSType
 def unfoldToArrow (sp, srt) =
  let 
    def unfoldRec srt = 
     let usrt = unfoldBase (sp, srt) in
     if usrt = srt then srt else unfoldRec usrt
  in
  let usrt = unfoldRec srt in
  case usrt of
    | Arrow _ -> usrt
    | _       -> srt

 %- --------------------------------------------------------------------------------
 (**
   determine the type of a term including unfolding of base types.
  *)

 op termTypeEnv : Spec * MSTerm -> MSType
 def termTypeEnv(sp,term) = 
  let res =
   case term 
     of Apply      (t1, t2,               _) -> 
        (case stripSubtypes(sp,termTypeEnv (sp, t1)) of
           | Arrow (dom, rng, _)            -> rng
	   | _ -> System.fail ("Cannot extract type of application "^ printTerm term))
      | Bind       _                         -> boolType
      | Record     (fields,               _) -> Product(map (fn (id, t)-> 
                                                             (id, termTypeEnv (sp, t)))
                                                            fields,
                                                        noPos)
      | Let        (_, t,                 _) -> termTypeEnv   (sp, t)
      | LetRec     (_, t,                 _) -> termTypeEnv   (sp, t)
      | Var        ((_, srt),             _) -> unfoldToArrow (sp, srt)
      | Fun        (fun, srt,             _) -> unfoldToArrow (sp, srt)
      | Lambda     (Cons((pat,_,body),_), _) -> mkArrow (patternType pat,
                                                         termTypeEnv (sp, body))
      | Lambda     ([],                   _) -> System.fail "Ill formed lambda abstraction"
      | The        ((_,srt),_,            _) -> unfoldToArrow (sp, srt)
      | IfThenElse (_, t2, t3,            _) -> termTypeEnv   (sp, t2)
      | Seq        _                         -> mkProduct     []
      | TypedTerm  (_, s,                 _) -> s
      | Pi         (_, t,                 _) -> termTypeEnv   (sp, t)
      | mystery                              ->
	System.fail ("In termTypeEnv, unrecognized term: " ^ printTerm mystery)
  in
  %let _ = writeLine("termTypeEnv: "^printTerm(term)^"="^printType(res)) in
  res

  op  maybeIntroduceVarsForTerms: MSTerm * List MSTerm * Spec -> MSTerm
  def maybeIntroduceVarsForTerms(mainTerm,vterms,spc) =
  %% Introduces variables for vterms if they occur in mainTerm and they are non-trivial
    case filter(fn t -> ~(simpleTerm t) && (existsSubTerm (fn st -> st = t) mainTerm)) vterms of
      | [] -> mainTerm
      | rvterms ->
	let (_,vbinds) =
	      foldl (fn ((i,result),t) -> (i+1,result ++ [(t,"tv--"^show i,inferType(spc,t))]))
	        (0,[]) rvterms
	in
	mkLet(map (fn (tm,v,s) -> (mkVarPat (v,s),tm)) vbinds,
	      mapTerm ((fn t -> case findLeftmost (fn (tm,_,_) -> t = tm) vbinds of
				| Some(_,v,s) -> mkVar(v,s)
				| None -> t),
			id,id)
		 mainTerm)

  op  fieldAcessTerm: MSTerm * String * Spec -> MSTerm
  def fieldAcessTerm(t,field,spc) =
    case t of
      | Record(fields,_) ->
	(case getField(fields,field) of
	  | Some fld -> fld
	  | _ -> mkProjection(field,t,spc))	% Shouldn't happen
      | _ -> mkProjection(field,t,spc)

  op  mkProjection  : Id * MSTerm * Spec -> MSTerm
  def mkProjection (id, term, spc) = 
    let super_type = termType(term) in
    case productOpt(spc,super_type) of
     | Some (fields) -> 
       (case findLeftmost (fn (id2, _) -> id = id2) fields of
	 | Some (_,sub_type) -> 
	   mkApply (mkProject (id, super_type, sub_type),term)
	 | _ -> System.fail ("Projection index "^id^" not found in product with fields "
                             ^(foldl (fn (res,(id2, _)) -> res^id2^" ") "" fields)
                             ^"at "^print(termAnn term)))
     | _ -> System.fail("Product type expected for mkProjectTerm: "^printTermWithTypes term)


 op productLength(sp: Spec, srt:MSType): Nat = 
   case productOpt(sp,srt)
     of Some fields -> length fields
      | None -> 1

 op typeArity : Spec * MSType            -> Option(MSType * Nat)
 def typeArity(sp,srt) =
     case arrowOpt(sp,srt)
       of Some(dom,rng) -> 
          let len = productLength(sp,dom) in 
          if ~(len = 1)
             then Some (dom,len)
          else None
        | _ -> None

 def polymorphicDomainOp? (spc, idf) =
   case findTheOp (spc, idf) of
     | Some info -> 
       let srt = firstOpDefInnerType info in
       polymorphicDomain? (spc, srt)
     | None -> false

 def polymorphicDomain? (sp, srt) =
   case arrowOpt (sp, srt) of
     | Some (TyVar _, _) -> true
     | _                -> false

 op mkCondEqualityFromLambdaDef(spc: Spec, lhs_tm: MSTerm, rhs_tm: MSTerm): MSTerm * List MSTerm * List Var =
   case rhs_tm of
     | Lambda ([(pat, _, body)], _) ->
       let (arg_tm, conds, vs) = patternToTermPlusExConds(pat) in
       let (eql, r_conds, r_vs) = mkCondEqualityFromLambdaDef(spc, mkApply(lhs_tm, arg_tm), body) in
       (eql, conds ++ r_conds, vs ++ r_vs)
     | _ -> (mkEquality (inferType(spc, lhs_tm), lhs_tm, rhs_tm), [], [])

 op defToTheorem(spc: Spec, ty: MSType, name: QualifiedId, term: MSTerm): MSTerm =
    let (new_equality, conds, faVars) = mkCondEqualityFromLambdaDef (spc, mkOp(name, ty), term) in
    % let _ = writeLine("new_eq: "^printTerm new_equality) in
    let cond_equality = mkSimpImplies(mkSimpConj conds, new_equality) in
    let faVars        = freeVars cond_equality in
    let cond_equality = mkBind (Forall, faVars, cond_equality) in
    let eqltyWithPos  = withAnnT (cond_equality, termAnn term) in
    eqltyWithPos

(*
 * Freshvar generates a unique suffix with the inserted name.
 *)

 type UsedNames = StringSet.Set

 op freshName: String * UsedNames -> String * UsedNames 
 def freshName(name0,names) = 
     let name1 = StringUtilities.freshName(name0,names) in
     (name1,StringSet.add(names,name1))

 op [a] freshNames(name0: String, xs: List a, names: UsedNames): List String * UsedNames =
     let (nameList,names) =  
             foldr (fn (_,(nameList,names)) -> 
                let (name1,names) = freshName(name0,names) in
                (Cons(name1,nameList),names))
                ([],names) xs
     in
     (nameList,names)


 op normalizeLambda(term: MSTerm, dom: MSType, ran: MSType, usedNames: StringSet.Set, spc: Spec): MSTerm =
   case term of
     | Lambda((pat1,_,_)::(_::_),_) ->
       (case productOpt(spc, dom) of
          | None ->
            let (name,_) = freshName("xx",usedNames) in
            let x = (name, dom) in
            mkLambda(mkVarPat x, mkApply(term, mkVar x))
          | Some fields ->
            let (names,_) = freshNames("xx",fields,usedNames) in
            let vars = map (fn (name,(label,srt)) -> (label,(name,srt))) (names,fields) in
            mkLambda(mkRecordPat(map (fn (l,v) -> (l, mkVarPat v)) vars),
                     mkApply(term, mkRecord(map (fn (l,v) -> (l, mkVar v)) vars))))
      | Lambda([(pat, cnd, bod)], pos) ->
        let usedNames = foldl (fn (usedNames, (vn,_)) ->
                                 StringSet.add(usedNames, vn))
                          usedNames (patVars pat)
        in
        let bod = case arrowOpt(spc, ran) of
                    | None -> bod
                    | Some(dom1, ran1) -> normalizeLambda(bod, dom1, ran1, usedNames, spc)
        in
        Lambda([(pat, cnd, bod)], pos)
      | And(tm1::r_tms, a) -> And((normalizeLambda(tm1, dom, ran, usedNames, spc))::r_tms, a) 
      | _ -> term

 op normalizeTopLevelLambdas(spc: Spec): Spec =
   setOps (spc, 
           mapOpInfos (fn info -> 
                         let pos = termAnn info.dfn in
                         let (old_decls, old_defs) = opInfoDeclsAndDefs info in
                         let new_defs =
                             map (fn dfn ->
                                    let pos = termAnn dfn in
                                    let (tvs, srt, term) = unpackTerm dfn in
                                    case arrowOpt(spc, srt) of
                                      | None -> dfn
                                      | Some(dom, ran) ->
                                    let tm = normalizeLambda(term, dom, ran, empty, spc) in
                                    maybePiTerm (tvs, TypedTerm (tm, srt, pos)))
                               old_defs
                         in
                           let new_dfn = maybeAndTerm (old_decls ++ new_defs, pos) in
                           info << {dfn = new_dfn})
           spc.ops)

endspec
