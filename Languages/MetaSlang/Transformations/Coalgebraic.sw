(* Transformations on coalgebraic definitions in specs *)

Coalgebraic qualifying
spec
import Script

(*
WS st =  (roots st \/ allSucs st (black st)) -- black st

WS H' = let st = addArc H (x,y) in (roots st \/ allSucs st (black st)) -- black st
Simplify rhs with rules
fa(H, x) x in? nodes H
fa(H,x,y) black(addArc H (x, y)) = H
*)

op mkApplyTermFromLambdas (hd: MS.Term, f: MS.Term): MS.Term =
  case f of
    | Lambda([(param_pat, _, bod)], _) ->
      let Some arg = patternToTerm param_pat in
      mkApplyTermFromLambdas(mkApply(hd, arg), bod)
    | _ -> hd

op addPostCondition(post_condn: MS.Term, ty: Sort): Sort =
  let def replaceInRange ty =
        case ty of
           | Arrow(dom, rng, a) -> Arrow(dom, replaceInRange rng, a)
           | Subsort(sup_ty, Lambda([(v, c, pred)], a1), a2) ->
             Subsort(sup_ty, Lambda([(v, c, MS.mkAnd(pred, post_condn))], a1), a2)
  in
  replaceInRange ty
             
def Coalgebraic.introduceOpsCoalgebraically(spc: Spec, qids: QualifiedIds, rules: List RuleSpec): Env Spec =
  let intro_qid = head qids in
  {info <- findTheOp spc intro_qid;
   let (tvs, intro_ty, intro_fn_def) = unpackFirstTerm info.dfn in
   let intro_fn = mkOp(intro_qid, intro_ty) in
   let state_ty = domain(spc, intro_ty) in
   let _ = writeLine("\nIntroduce "^show intro_qid^": "^printSort intro_ty^"\n"^printTerm intro_fn_def) in
   let def addToDef(info, result as (spc, qids)) =
         let qid = primaryOpName info in
         let (tvs, ty, tm) = unpackTerm info.dfn in
         case range_*(spc, ty) of
           | Subsort(result_ty, Lambda([(VarPat(result_var,_), _, _)], _), _)  | equalTypeSubtype?(result_ty, state_ty, true) ->
             let result_tm = mkApplyTermFromLambdas(mkOp(qid, ty), tm) in
             % let _ = writeLine("\nLooking at "^show qid) in
             % let _ = writeLine("Result var is "^result_var.1^"\nParams are "^anyToString(map (fn (v,_) -> v) params)) in
             let new_lhs = mkApply(intro_fn, mkVar result_var) in
             let intro_fn_rng = inferType(spc, new_lhs) in
             let raw_rhs = simplifiedApply(intro_fn_def, result_tm, spc) in
             % let _ = writeLine("\nBody to transform:\n"^printTerm raw_rhs) in
             let new_intro_ty = addPostCondition(mkEquality(intro_fn_rng, new_lhs, raw_rhs), ty) in
             let spc = addRefinedType(spc, info, new_intro_ty) in
             (spc, qid :: qids)
           | _ -> result
   in
   let (spc, qids) = foldOpInfos addToDef (spc, []) spc.ops in
   let script = Steps[%Trace true,
                      At(map Def (reverse qids),
                         Steps [Move [Post, Last, Last],
                                Simplify1(rules),
                                mkSimplify(Fold intro_qid :: rules)])]
   in
   {print "rewriting ... \n";
    print (scriptToString script^"\n"); 
    spc <- interpret(spc, script);
    return spc}}

op findHomomorphismFn(tm: MS.Term): Option QualifiedId =
  case tm of
    | Bind(Forall, _, bod,_) -> findHomomorphismFn bod
    | Apply(Fun(Equals,_,_),Record([(_,e1),(_,Apply(Fun(Op(qid,_),_,_), _, _))], _),_) -> Some qid
    | _ -> None

def Coalgebraic.implementOpsCoalgebraically(spc: Spec, qids: QualifiedIds, rules: List RuleSpec): Env Spec =
  case qids of
    | [replace_op_qid, assert_qid] ->
      (case findPropertiesNamed(spc, assert_qid) of
         | [] -> raise(Fail("Can't find property named "^show assert_qid))
         | [(_, _, _, body, _)] ->
           (case findHomomorphismFn body of
            | None -> raise(Fail("Can't find homomorphism fn from axiom:\n"^printTerm body))
            | Some homo_fn_qid -> 
              {replace_op_info <- findTheOp spc replace_op_qid;
               let (tvs, replace_op_ty, _) = unpackFirstTerm replace_op_info.dfn in
               let _ = writeLine("Implement "^show replace_op_qid^": "^printSort replace_op_ty) in
               let _ = writeLine("With rewrite: "^printTerm body) in
               let def findStateTransformOps(info, qids) =
                     let (tvs, ty, tm) = unpackTerm info.dfn in
                     case range_*(spc, ty) of
                       | Subsort(result_ty, Lambda([(VarPat(result_var,_), _, body)], _), _)
                           | existsSubTerm (fn st -> case st of
                                                       | Fun(Op(qid,_), _, _) -> qid = replace_op_qid
                                                       | _ -> false)
                               body
                         ->
                         primaryOpName info :: qids
                       | _ ->
                     if existsSubTerm (fn st -> case st of
                                                       | Fun(Op(qid,_), _, _) -> qid = replace_op_qid
                                                       | _ -> false)
                         tm
                       then primaryOpName info :: qids
                       else qids
               in
               let state_transform_qids = foldOpInfos findStateTransformOps [] spc.ops in
               let script = Steps[%Trace true,
                                  At(map Def (reverse state_transform_qids),
                                     Steps [mkSimplify(RLeibniz homo_fn_qid :: LeftToRight assert_qid :: rules)])]
               in
               {print "rewriting ... \n";
                print (scriptToString script^"\n");
                spc <- interpret(spc, script);
                return spc}
               })
         | props -> raise(Fail("Ambiguous property named "^show assert_qid)))
    | _ -> raise(Fail("implement expects op and theorem QualifiedIds"))

end-spec