SpecTransform qualifying
spec
import Simplify, SubtypeElimination, RuntimeSemanticError

op addSubtypeChecksOnResult?: Bool = true
op addSubtypeChecksOnArgs?: Bool = true

op addSubtypeChecks(spc: Spec): Spec =
  addSemanticChecks(spc, true, true, false)

op addSemanticChecksForTerm(tm: MS.Term, top_ty: Sort, qid: QualifiedId, spc: Spec,
                            checkArgs?: Bool, checkResult?: Bool, checkRefine?: Bool): MS.Term =
  let def mkCheckForm(arg, pred, err_msg_fn) =
        let arg_tm = mkTuple [arg, pred, err_msg_fn] in
        simplifiedApply(mkOp(Qualified("SemanticError", "checkPredicate"),
                             mkArrow(inferType(spc, arg_tm), voidType)),
                        simplify spc arg_tm,
                        spc)
  in
  case arrowOpt(spc, top_ty) of
    | None -> tm
    | Some(dom, rng) ->
  let result_sup_ty = stripSubsorts(spc, rng) in
  let tm_1 =
      if checkResult? || checkRefine?
        then
          let result_vn = ("result", result_sup_ty) in
          let checkResult_tests =
              case raiseSubtype(rng, spc) of
                | Subsort(sup_ty, pred, _) | addSubtypeChecksOnResult? ->
                  % let _ = writeLine("Checking "^printTerm pred^" in result of\n"^printTerm tm) in
                  let warn_fn = mkLambda(mkWildPat sup_ty,
                                         mkString("Subtype violation on result of "^show qid))
                  in      
                  [mkCheckForm(mkVar result_vn, pred, warn_fn)]
                | _ -> []
          in
          let checkRefine_tests = []
          in
          let result_tests = checkResult_tests ++ checkRefine_tests in
          if result_tests = [] then tm
          else
          let check_result_Seq = mkSeq(result_tests ++ [mkVar result_vn]) in
          case tm of
            | Lambda([(p, condn, body)], a) ->
              let Some p_tm = patternToTerm p in
              let new_body = mkLet([(mkVarPat result_vn, body)], check_result_Seq) in
              Lambda([(p, condn, new_body)], a)
            | _ ->
              let vn = ("x", result_sup_ty) in
              let body = mkApply(tm, mkVar vn) in
              let new_body = mkLet([(mkVarPat result_vn, body)], check_result_Seq) in
              mkLambda(mkVarPat vn, new_body)
        else tm
  in
  let tm_2 =
      if checkArgs?
        then
          case raiseSubtype(dom, spc) of
            | Subsort(sup_ty, pred, _) | addSubtypeChecksOnArgs? ->
              % let _ = writeLine("Checking "^printTerm pred^" in\n"^printTerm tm) in
              let warn_fn = mkLambda(mkWildPat sup_ty,
                                     mkString("Subtype violation on arguments of "^show qid))
              in      
              let new_tm =
                  case tm_1 of
                    | Lambda([(p, condn, body)], a) | some?(patternToTerm p) ->
                      let Some p_tm = patternToTerm p in
                      let new_body = mkSeq[mkCheckForm(p_tm, pred, warn_fn), body] in
                      Lambda([(p, condn, new_body)], a)
                    | _ ->
                      let vn = ("x", sup_ty) in
                      let new_body = mkSeq[mkCheckForm(mkVar vn, pred, warn_fn), mkApply(tm, mkVar vn)] in
                      mkLambda(mkVarPat vn, new_body)
              in
              new_tm
            | _ -> tm_1
        else tm_1
  in
  tm_2


op addSemanticChecks(spc: Spec, checkArgs?: Bool, checkResult?: Bool, checkRefine?: Bool): Spec =
  let base_spc = getBaseSpec() in
  let result_spc =
      setOps(spc,
             mapOpInfos
               (fn opinfo ->
                let qid = head opinfo.names in
                if some?(findTheOp(base_spc, qid))
                  then opinfo
                  else
                  let (tvs, ty, dfns) = unpackTerm opinfo.dfn in
                  case dfns of
                    | Any _ -> opinfo
                    | _ ->
                  case arrowOpt(spc, ty) of
                    | None -> opinfo
                    | Some(dom, rng) ->
                  % let _ = writeLine("astcs: "^show qid^": "^printSort dom) in
                  let last_index = length(innerTerms dfns) - 1 in
                  let dfn = refinedTerm(dfns, last_index) in
                  let new_dfn = addSemanticChecksForTerm(dfn, ty, qid, spc, checkArgs?, checkResult?, checkRefine?) in
                  let new_dfns = replaceNthTerm(dfns, last_index, new_dfn) in
                  let new_full_dfn = maybePiSortedTerm(tvs, Some ty, new_dfns) in
                  opinfo << {dfn = new_full_dfn})               
               spc.ops)
  in
  % let _ = writeLine(printSpec result_spc) in
  result_spc

end-spec
