CurryUtils qualifying spec
  import ../Specs/Utilities
  import ../Specs/Environment

  op  curriedType?: Spec * MSType -> Bool
  def curriedType?(sp,srt) = curryShapeNum(sp,srt) > 1

  op  curryShapeNum: Spec * MSType -> Nat
  def curryShapeNum(sp,srt) =
    let srt = typeInnerType srt in % might not be needed, but ...
    case arrowOpt(sp,srt)
      of Some (_,rng) -> 1 + curryShapeNum(sp,rng)
       | _ -> 0

  op  curryArgTypes: Spec * MSType -> MSTypes
  def curryArgTypes(sp,srt) =
    let srt = typeInnerType srt in % might not be needed, but ...
    case arrowOpt(sp,srt)
      of Some (dom,rng) -> Cons(stripSubtypes(sp,dom),curryArgTypes(sp,rng))
       | _ -> []

  op curryTypes(ty: MSType, spc: Spec): MSTypes * MSType =
    case arrowOpt(spc, ty)
      of Some (dom,rng) -> let (doms, rng) = curryTypes(rng,spc) in (dom :: doms, rng)
       | _ -> ([], ty)


  op foldrPred: [a] (a -> Bool * a) -> Bool -> List a -> (Bool * List a)
  def foldrPred f i l =
    List.foldr (fn (x,(changed?,result)) ->
	   let (nchanged?,nx) = f x in
	   (changed? || nchanged?,Cons(nx,result)))
      (i,[])
      l

  op  getCurryArgs: MSTerm -> Option (MSTerm * MSTerms)
  def getCurryArgs t =
    let def aux(term, i, args) =
        case term
          of Fun(_, srt, _) ->
             if i > 1
               then Some(term, args)
              else None
           | Apply(t1, t2, _) -> aux(t1, i+1, t2::args)
           | _ -> None
  in aux(t, 0, [])

  op mkCurriedLambda(params, body): MSTerm =
    case params of
      | [] -> body
      | p::r -> mkLambda(p, mkCurriedLambda(r, body))

  op  curriedParams: MSTerm -> MSPatterns * MSTerm
  def curriedParams defn =
    let def aux(t,vs) =
          case t of
	    | Lambda([(p,_,body)],_) ->
              let p = deRestrict p in
	      if (case p of
		    | VarPat _ -> true
		    | RecordPat _ -> true
                    | QuotientPat _ -> true
		    | _ -> false)
		then aux(body,vs ++ [p])
		else (vs,t)
	    | _ -> (vs,t)
    in
    aux(defn,[])

  op curriedParamsBody(defn: MSTerm): MSPatterns * MSTerm =
    let def aux(vs,t) =
          case t of
	    | Lambda([(p,_,body)],_) -> aux(vs ++ [p], body)
            | _ -> (vs,t)
    in
    aux([],defn)

  op etaExpandCurriedBody(tm: MSTerm, dom_tys: MSTypes): MSTerm =
    case dom_tys of
      | [] -> tm
      | ty1 :: r_tys ->
    case tm of
      | Lambda([(p,p1,body)], a) -> Lambda([(p,p1,etaExpandCurriedBody(body, r_tys))], a)
      | _ ->
    let v = ("cv__"^show(length r_tys), ty1) in
    mkLambda(mkVarPat v, etaExpandCurriedBody(mkApply(tm, mkVar v), r_tys))
 

  op  noncurryArgTypes: Spec * MSType -> MSTypes
  def noncurryArgTypes(sp,srt) =
    case arrowOpt(sp,srt)
      of Some (dom,_) ->
	 (case productOpt(sp,dom) of
	   | Some fields -> map (fn(_,s) -> s) fields
	   | _ -> [dom])
       | _ -> []

  def duplicateString(n,s) =
    case n
      of 0 -> ""
       | _ -> s^duplicateString(n - 1,s)

  def unCurryName(name,n) =
    if n <= 1 then name
      else name^duplicateString(n,"-1")

endspec

