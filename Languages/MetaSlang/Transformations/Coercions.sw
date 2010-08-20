%%% Adds coercion functions between subtype and supertype so they can have
%%% different implementations

Coercions qualifying
spec 
  import /Languages/MetaSlang/Specs/Environment

  op handleOverloading?: Bool = false

  type TypeCoercionInfo = {subtype: QualifiedId,
			   supertype: MS.Sort,
			   coerceToSuper: MS.Term,
			   coerceToSub: MS.Term,
                           overloadedOps: List String}
  type TypeCoercionTable = List TypeCoercionInfo

  op needsCoercion?(ctxt_ty: Sort, gen_ty: Sort, coercions: TypeCoercionTable, spc: Spec)
     : Option(Boolean * TypeCoercionInfo) =
    % let _ = writeLine(printSort gen_ty^" -~-> "^printSort ctxt_ty) in
    let result =
          case findLeftmost (fn tb -> subtypeOf?(gen_ty, tb.subtype, spc) \_and \_not(subtypeOf?(ctxt_ty, tb.subtype, spc))) coercions of
            | Some tb -> Some(true, tb)
            | None ->
          case findLeftmost (fn tb -> subtypeOf?(ctxt_ty, tb.subtype, spc) \_and \_not(subtypeOf?(gen_ty, tb.subtype, spc))) coercions of
            | Some tb -> Some(false, tb)
            | None -> None
    in
    % let _ = writeLine(if some? result then " Yes" else " No") in
    result

  op opaqueTypeQId?(coercions: TypeCoercionTable) (qid: QualifiedId): Bool =
    exists? (fn tb -> qid = tb.subtype) coercions

  op opaqueType?(ty: Sort, coercions: TypeCoercionTable, spc: Spec): Boolean =
    exists? (fn tb -> subtypeOf?(ty, tb.subtype, spc)) coercions

  op idFn?(t: MS.Term): Boolean =
    case t of
      | Fun(Op(Qualified(_, "id"), _), _, _) -> true
      | _ -> false

  op patTermVarsForProduct(fields: List(Id * Sort)): MS.Pattern * MS.Term =
    let (pats, tms, _) = foldr (fn ((fld_i, p_ty), (pats, tms, i)) ->
                                let v = ("x_"^show i, p_ty) in
                                (Cons((fld_i, mkVarPat v), pats),
                                 Cons((fld_i, mkVar    v),  tms),
                                 i-1))
                         ([], [], length fields)
                         fields
    in
    (mkRecordPat pats, mkRecord tms)

  op  addCoercions (coercions: TypeCoercionTable) (spc: Spec): Spec =
    let
      def mapTermTop info =
        % let _ = writeLine("\n") in
	let (tvs, ty, tm) = unpackFirstOpDef info in
	let result = mapTerm(tm, ty) in
        if equalTerm?(result, tm)
          then maybePiTerm(tvs, SortedTerm(tm, ty, termAnn tm)) 
        else
        % let _ = writeLine("Def:\n"^printTerm tm^"\n  changed to\n"^printTerm result) in
        maybePiTerm(tvs, SortedTerm(result, ty, termAnn tm)) 
	
      def mapTerm(tm, ty) =
	let rm_ty = inferType(spc, tm) in
	let delayCoercion? =
	    case tm of
	      | Lambda _ ->
                (case rangeOpt(spc, rm_ty) of   % Don't delay set
                   | Some r_ty | equalType?(r_ty, boolSort) -> false
                   | _ -> false)
	      | Let _ -> true
              | Apply(Lambda _, _, _) -> true
	      | LetRec _ -> true
	      | IfThenElse _ -> true
	      | Record _ -> true
	      | _ -> false
	in
	let n_tm = mapSubTerms(tm, if delayCoercion? \_or embed? Lambda tm then ty else rm_ty) in
	if delayCoercion? \_or (handleOverloading? && overloadedTerm? n_tm) then n_tm
	else
        % let _ = writeLine(printTerm tm^": "^printSort rm_ty ^"\n-> " ^ printSort ty^"\n") in
	case needsCoercion?(ty, rm_ty, coercions, spc) of
          | Some(toSuper?, tb) ->
            (case tm of
              | Fun(Nat i, _, a) -> Fun(Nat i, ty, a)
              | _ -> if toSuper? then coerceToSuper(n_tm, tb) else coerceToSub(n_tm, tb))
          | None ->
        if simpleTerm n_tm then         % Var or Op
          case (arrowOpt(spc, ty), arrowOpt(spc, rm_ty)) of
            | (Some(dom, rng), Some(rm_dom, rm_rng))
                | ~(opaqueType?(ty, coercions, spc))
                  && (some?(needsCoercion?(dom, rm_dom, coercions, spc))
                       || some?(needsCoercion?(rng, rm_rng, coercions, spc))) ->
              (case productOpt(spc, dom) of
                | Some fields ->
                  let (v_pat, v_tm) = patTermVarsForProduct fields in
                  mkLambda(v_pat, mapTerm(mkApply(n_tm, v_tm), rng))
                | None ->
                  mkLambda(mkVarPat("xz", dom), mapTerm(mkApply(n_tm, mkVar("xz", dom)), rng)))
            | _ ->
          case (productOpt(spc, ty), productOpt(spc, rm_ty)) of
            | (Some fields, Some rm_fields)
                | exists? (fn ((_, p_ty), (_, rm_p_ty)) ->
                            some?(needsCoercion?(p_ty, rm_p_ty, coercions, spc)))
                    (if length fields = length rm_fields
                       then zip(fields, rm_fields)
                       else let _ = writeLine("ac zip error: "^printTerm n_tm^": "^printSort rm_ty^"\n"^printSort ty) in
                            []) ->
              let (v_pat, v_tm) = patTermVarsForProduct rm_fields in
              mkLet([(v_pat, n_tm)], v_tm)
            %% !! Need more general cases as well
            | _ -> n_tm
        else n_tm

      def mapSubTerms(tm, ty) =
        % let _ = writeLine("mst: "^printTerm tm^" -> " ^ printSort ty) in
	case tm of
	  | Apply (t1, t2, a) ->
	    let fn_ty = inferType(spc, t1) in
            (case findLeftmost (fn tb -> subtypeOf?(fn_ty, tb.subtype, spc)) coercions of
               | Some tb | tb.subtype = Qualified("Set", "Set")->
                 (case subtypeOf(fn_ty, tb.subtype, spc) of
                    | Some(Base(_, [p], _)) ->
                      let t1 = if embed? Fun t1 then t1 else mapTerm(t1, fn_ty) in
                      let t2 = mapTerm(t2, p) in
                      Apply(mkInfixOp(Qualified("Set", "in?"), Infix(Left, 20),
                                      mkArrow(mkProduct[p, fn_ty], boolSort)),
                            mkTuple[t2, t1],
                            a))
               | _ ->
                 let dom = domain (spc, fn_ty) in
                 Apply (if embed? Fun t1 then t1
                          else mapTerm(t1, mkArrow(dom, ty)),
                        mapTerm(t2, dom), a))
	  | Record (row, a) ->
	    let srts = map (fn (_, x) -> x) (product (spc, ty)) in
	    Record(map (fn ((idi, tmi), tyi) -> (idi, mapTerm(tmi, tyi))) (zip(row, srts)), a)
	  | Bind (bnd, vars, trm, a) ->
	    Bind (bnd, vars, mapTerm(trm, ty), a)
	  | The (var, trm, a) ->
	    The (var, mapTerm(trm, boolSort), a)
	  | Let (decls, bdy, a) ->
	    %Let (map (fn (pat, trm) -> (pat, mapTerm(trm, ty)))   % Assumes no coercions in pattern
	    Let (map (fn (pat, trm) -> (pat, mapTerm(trm, patternSort pat)))   % Assumes no coercions in pattern
		   decls,
		 mapTerm(bdy, ty), a)
	  | LetRec (decls, bdy, a) ->
	    LetRec (map (fn ((id, srt), trm) -> ((id, srt), mapTerm(trm, srt))) decls,
		    mapTerm(bdy, ty), a)
	  | Lambda (match, a) ->
	    Lambda (map (fn (pat, condn, trm) ->
			 (pat, mapTerm(condn, boolSort), mapTerm(trm, range(spc, ty))))
			 match,
		    a)
	  | IfThenElse (t1, t2, t3, a) ->
	    IfThenElse (mapTerm(t1, boolSort), mapTerm(t2, ty), mapTerm(t3, ty), a)
	  | Seq (terms, a) ->
            let pre_trms = butLast terms in
            let lst_trm  =    last terms in 
	    Seq (map (fn trm -> mapTerm(trm, mkProduct [])) pre_trms
                   ++ [mapTerm(lst_trm, ty)], a)
	  | SortedTerm (trm, srt, a) ->
	    SortedTerm (mapTerm(trm, srt), srt, a)
	  | _ -> tm

      def coerceToSuper(tm, tb) =
        case tm of
          | Apply(f, x, _) | f = tb.coerceToSub -> x
          | Let(m, b, a) -> Let(m, coerceToSuper(b, tb), a)
          | _ ->
            if idFn? tb.coerceToSuper then tm
              else mkApply(tb.coerceToSuper, tm)
      def coerceToSub(tm, tb) =
        case tm of
          | Apply(f, x, _) | f = tb.coerceToSuper -> x
          | Let(m, b, a) -> Let(m, coerceToSub(b, tb), a)
          | _ ->
            if idFn? tb.coerceToSub then tm
              else mkApply(tb.coerceToSub, tm)
      def coerceSubtypePreds ty =
        case ty of
          | Subsort(ss, pred, a) -> Subsort(ss, mapTerm(pred, inferType(spc, pred)), a)
          | _ -> ty
    in
    % let _ = printSpecWithSortsToTerminal spc in
    let spc =
        spc << {ops = foldl (fn (ops, el) ->
                             case el of
                               | Op (qid as Qualified(q, id), true, _) ->
                                 %% true means decl includes def
                                 (case AnnSpec.findTheOp(spc, qid) of
                                   | Some info ->
                                     insertAQualifierMap (ops, q, id,
                                                          info << {dfn = mapTermTop info})
                                   | None -> ops)
                               | OpDef (qid as Qualified(q, id), _, _) ->
                                 (case AnnSpec.findTheOp(spc, qid) of
                                   | Some info ->
                                     insertAQualifierMap (ops, q, id,
                                                          info << {dfn = mapTermTop info})
                                   | None -> ops)
                               | _ -> ops)
                        spc.ops
                        spc.elements,
                %% mapOpInfos (fn info -> info << {dfn = mapTermTop info}) spc.ops,
                elements = map (fn el ->
                                  case el of
                                    | Property(pt, nm, tvs, term, a) ->
                                      Property(pt, nm, tvs, mapTerm(term, boolSort), a)
                                    | _ -> el)
                             spc.elements}
    in
    let spc = mapSpec (id, coerceSubtypePreds, id) spc in
    % let _ = writeLine(printSpec spc) in
    spc

  op checkCoercions (tm: MS.Term, coercions: TypeCoercionTable): Option(TypeCoercionInfo * MS.Term) =
    % let _ = writeLine("cc: "^printTerm tm) in
    let result = (checkCoercions1 (tm, coercions)).2 in
    % let _ = writeLine("is "^show (some? result)) in
    result

  op checkCoercions1  (tm: MS.Term, coercions: TypeCoercionTable): Bool * Option(TypeCoercionInfo * MS.Term) =
    case tm of
      | Apply(Lambda (match, _), _, _) ->
        foldl (\_lambda (result, (_, _, x)) -> checkCoercions2(result, x, coercions))
          (true, None) match
      | Apply(f, _, _) ->
        (case findLeftmost (fn tb -> equalTerm?(f, tb.coerceToSuper) \_or equalTerm?(f, tb.coerceToSub))
                coercions of
           | Some tb -> (true, Some(tb, f))
           | None -> (false, None))
      | Record(row, _) ->
        (foldl (\_lambda (result, (_, x)) -> checkCoercions2(result, x, coercions))
           (true, None) row)
      | Let(_, x, _) -> checkCoercions1(x, coercions)
      | IfThenElse(_, x, y, _) -> checkCoercions2(checkCoercions1(x, coercions), y, coercions)
      | _ -> (overloadedTerm? tm, None)

  op checkCoercions2(result: Bool * Option(TypeCoercionInfo * MS.Term), tm: MS.Term, coercions: TypeCoercionTable)
       : Bool * Option(TypeCoercionInfo * MS.Term) =
    case checkCoercions1 (tm, coercions) of
      | (false, _) -> (false, None)
      | new_result ->
     case result of
       | (false, _) -> (false, None)
       | (true, Some _) -> result
       | (true, None) -> new_result

  op removeCoercions(tm: MS.Term, f, product?: Bool, coercions: TypeCoercionTable): MS.Term =
    % let _ = writeLine("rc: "^printTerm tm^" cf: "^printTerm f) in
    let result =
        case tm of
          | Apply(Lambda(match, a1), x, a2) ->
            let n_match = map (fn (p, c, b) -> (p, c, removeCoercions(b, f, product?, coercions))) match in
            Apply(Lambda(n_match, a1), x, a2)
          | Apply(f1, x, _) | f = f1 -> x
          | Let(b, x, a) -> Let(b, removeCoercions(x, f, product?, coercions), a)
          | IfThenElse(p, x, y, a) ->
            IfThenElse(p, removeCoercions(x, f, product?, coercions), removeCoercions(y, f, product?, coercions), a)
          | Record(row, a) | product? ->
            Record(map (\_lambda(id, x) -> (id, removeCoercions(x, f, false, coercions))) row, a)
          | _ -> tm
     in
     % let _ = writeLine("= "^printTerm result) in
     result

  op exploitOverloading  (coercions: TypeCoercionTable) (spc: Spec): Spec =
    let def mapTermTop info =
        % let _ = writeLine("\n") in
	let (tvs, ty, tm) = unpackFirstOpDef info in
	let result = mapTerm(tm, ty) in
        if equalTerm?(result, tm)
          then maybePiTerm(tvs, SortedTerm(tm, ty, termAnn tm)) 
        else
        % let _ = writeLine("Def:\n"^printTerm tm^"\n  changed to\n"^printTerm result) in
        maybePiTerm(tvs, SortedTerm(result, ty, termAnn tm)) 
       def mapTerm(tm, target_ty) =
          let rm_ty = inferType(spc, tm) in
          let tm = mapSubTerms(tm, target_ty) in
          liftCoercion (tm, rm_ty, target_ty)
       def maybeCancelCoercions(f, x, tm) =
         case x of
           | Apply(f1, x1, _) | equalTerm?(f, f1) -> x1
           | _ -> if overloadedTerm? x then x else tm
       def liftCoercion (tm, rm_ty, target_ty) =
        % let _ = toScreen("lc: "^ printTerm tm ^": "^ printSort rm_ty ^" -> "^ printSort target_ty ^"\n ") in
        case tm of
          | Apply(f as Fun(Op(Qualified(qual, idn), _), _, _), x, a) ->
            % let _ = writeLine("lift?: " ^ printTerm tm ^ " with qual: "^qual) in
            (case findLeftmost (fn tb -> equalTerm?(f, tb.coerceToSuper))
                     coercions of
               | Some tb -> maybeCancelCoercions(tb.coerceToSub, x, tm)
               | None ->
             case findLeftmost (fn tb -> equalTerm?(f, tb.coerceToSub))
                     coercions of
               | Some tb -> maybeCancelCoercions(tb.coerceToSuper, x, tm)
               | None ->
             case checkCoercions (x, coercions) of
               | Some(tb, coerce_fn)
                   | idn in? tb.overloadedOps
                     \_or %% Special case for minus (probably not worth generalizing)
                       %% minus on nats is equal to minus on integers if we know result is a nat
                     (qual = "Integer" \_and idn = "-" %\_and coerce_fn = int
                        \_and subtypeOf?(target_ty, Qualified("Nat", "Nat"), spc))
                 ->
                 (case x of
                    | Let(m, b, a1) -> Let(m, liftCoercion(Apply(f, b, a), rm_ty, target_ty), a1)
                    | _ ->
                  let new_x = removeCoercions(x, coerce_fn, true, coercions) in
                  let new_tm = Apply(f, new_x, a) in
                  % let _ = writeLine("\nrm_ty: "^printSort rm_ty^"\ntarget: "^printSort target_ty) in
                  (if possiblySubtypeOf?(rm_ty, tb.supertype, spc)
                    then % let _ = writeLine("Added: "^printTerm (Apply(coerce_fn, new_tm, a))) in
                         Apply(coerce_fn, new_tm, a)
                    else % let _ = writeLine("None: "^printTerm new_tm) in
                         new_tm))
               | _ -> tm)
          | Apply(f as Fun(overloaded_op, _, _), x, a)
              | overloaded_op = Equals \_or overloaded_op = NotEquals ->
            (case checkCoercions (x, coercions) of
               | Some(tb, coerce_fn) ->
                 (case x of
                    | Let(m, b, a1) -> Let(m, liftCoercion(Apply(f, b, a), rm_ty, target_ty), a1)
                    | _ ->
                  let new_x = removeCoercions(x, coerce_fn, true, coercions) in
                  Apply(f, new_x, a))
               | _ -> tm)
          | _ -> tm
       def mapSubTerms(tm, ty) =
        % let _ = writeLine("mst: "^printTerm tm^" -> " ^ printSort ty) in
	case tm of
	  | Apply (t1, t2, a) ->
	    let fn_ty = inferType(spc, t1) in
            let dom = domain (spc, fn_ty) in
            Apply (if embed? Fun t1 then t1
                     else mapTerm(t1, mkArrow(dom, ty)),
                   mapTerm(t2, dom), a)
	  | Record (row, a) ->
	    let srts = map (fn (_, x) -> x) (product (spc, ty)) in
	    Record(map (fn ((idi, tmi), tyi) -> (idi, mapTerm(tmi, tyi))) (zip(row, srts)), a)
	  | Bind (bnd, vars, trm, a) ->
	    Bind (bnd, vars, mapTerm(trm, ty), a)
	  | The (var, trm, a) ->
	    The (var, mapTerm(trm, boolSort), a)
	  | Let (decls, bdy, a) ->
	    %Let (map (fn (pat, trm) -> (pat, mapTerm(trm, ty)))   % Assumes no coercions in pattern
	    Let (map (fn (pat, trm) -> (pat, mapTerm(trm, patternSort pat)))   % Assumes no coercions in pattern
		   decls,
		 mapTerm(bdy, ty), a)
	  | LetRec (decls, bdy, a) ->
	    LetRec (map (fn ((id, srt), trm) -> ((id, srt), mapTerm(trm, srt))) decls,
		    mapTerm(bdy, ty), a)
	  | Lambda (match, a) ->
	    Lambda (map (fn (pat, condn, trm) ->
			 (pat, mapTerm(condn, boolSort), mapTerm(trm, range(spc, ty))))
			 match,
		    a)
	  | IfThenElse (t1, t2, t3, a) ->
	    IfThenElse (mapTerm(t1, boolSort), mapTerm(t2, ty), mapTerm(t3, ty), a)
	  | Seq (terms, a) ->
            let pre_trms = butLast terms in
            let lst_trm  =    last terms in 
	    Seq (map (fn trm -> mapTerm(trm, mkProduct [])) pre_trms
                   ++ [mapTerm(lst_trm, ty)], a)
	  | SortedTerm (trm, srt, a) ->
	    SortedTerm (mapTerm(trm, srt), srt, a)
	  | _ -> tm
      def coerceSubtypePreds ty =
        case ty of
          | Subsort(ss, pred, a) -> Subsort(ss, mapTerm(pred, inferType(spc, pred)), a)
          | _ -> ty
    in
    % let _ = printSpecWithSortsToTerminal spc in
    let spc =
        spc << {ops = foldl (fn (ops, el) ->
                             case el of
                               | Op (qid as Qualified(q, id), true, _) ->
                                 %% true means decl includes def
                                 (case AnnSpec.findTheOp(spc, qid) of
                                   | Some info ->
                                     insertAQualifierMap (ops, q, id,
                                                          info << {dfn = mapTermTop info})
                                   | None -> ops)
                               | OpDef (qid as Qualified(q, id), _, _) ->
                                 (case AnnSpec.findTheOp(spc, qid) of
                                   | Some info ->
                                     insertAQualifierMap (ops, q, id,
                                                          info << {dfn = mapTermTop info})
                                   | None -> ops)
                               | _ -> ops)
                        spc.ops
                        spc.elements,
                %% mapOpInfos (fn info -> info << {dfn = mapTermTop info}) spc.ops,
                elements = map (fn el ->
                                  case el of
                                    | Property(pt, nm, tvs, term, a) ->
                                      Property(pt, nm, tvs, mapTerm(term, boolSort), a)
                                    | _ -> el)
                             spc.elements}
    in
    let spc = mapSpec (id, coerceSubtypePreds, id) spc in
    % let _ = writeLine(printSpec spc) in
    spc

  op coerceLiterals (spc: Spec) (tm: MS.Term): MS.Term =
    let def mapTermTop tm =
              mapTerm(tm, inferType(spc, tm))
        def mapTerm(tm, target_ty) =
          case tm of
            | Fun(Nat i, _, a) -> Fun(Nat i, target_ty, a) 
            | _ ->
          mapSubTerms(tm, target_ty)
          
       def mapSubTerms(tm, ty) =
	case tm of
	  | Apply (t1, t2, a) ->
	    let fn_ty = inferType(spc, t1) in
            let dom = domain (spc, fn_ty) in
            Apply (if embed? Fun t1 then t1
                     else mapTerm(t1, mkArrow(dom, ty)),
                   mapTerm(t2, dom), a)
	  | Record (row, a) ->
	    let srts = map (fn (_, x) -> x) (product (spc, ty)) in
	    Record(map (fn ((idi, tmi), tyi) -> (idi, mapTerm(tmi, tyi))) (zip(row, srts)), a)
	  | Bind (bnd, vars, trm, a) ->
	    Bind (bnd, vars, mapTerm(trm, ty), a)
	  | The (var, trm, a) ->
	    The (var, mapTerm(trm, boolSort), a)
	  | Let (decls, bdy, a) ->
	    %Let (map (fn (pat, trm) -> (pat, mapTerm(trm, ty)))   % Assumes no coercions in pattern
	    Let (map (fn (pat, trm) -> (pat, mapTerm(trm, patternSort pat)))   % Assumes no coercions in pattern
		   decls,
		 mapTerm(bdy, ty), a)
	  | LetRec (decls, bdy, a) ->
	    LetRec (map (fn ((id, srt), trm) -> ((id, srt), mapTerm(trm, srt))) decls,
		    mapTerm(bdy, ty), a)
	  | Lambda (match, a) ->
	    Lambda (map (fn (pat, condn, trm) ->
			 (pat, mapTerm(condn, boolSort), mapTerm(trm, range(spc, ty))))
			 match,
		    a)
	  | IfThenElse (t1, t2, t3, a) ->
	    IfThenElse (mapTerm(t1, boolSort), mapTerm(t2, ty), mapTerm(t3, ty), a)
	  | Seq (terms, a) ->
            let pre_trms = butLast terms in
            let lst_trm  =    last terms in 
	    Seq (map (fn trm -> mapTerm(trm, mkProduct [])) pre_trms
                   ++ [mapTerm(lst_trm, ty)], a)
	  | SortedTerm (trm, srt, a) ->
	    SortedTerm (mapTerm(trm, srt), srt, a)
	  | _ -> tm
    in
    let tm = MetaSlang.mapTerm (id, fn s -> case s of
                                            | Subsort(ss, t, a) -> Subsort(ss, mapTermTop t, a)
                                            | _ -> s,
                                id)
               tm
    in
    tm

  op coerceLiteralsInCoercions (spc: Spec) (coercions: TypeCoercionTable): TypeCoercionTable =
    let coercions = map (fn ci -> ci << {coerceToSuper = coerceLiterals spc ci.coerceToSuper,
                                         coerceToSub   = coerceLiterals spc ci.coerceToSub})
                      coercions
    in
    coercions

  op  overloadedTerm?: MS.Term -> Boolean
  def overloadedTerm? tm =
    case tm of
      | Fun(Nat _, _, _) -> true
      | _ -> false

  op directlyImplementedSubsort?(ty: Sort, coercions: TypeCoercionTable): Boolean =
    case ty of
      | Base(qid, _, _) -> opaqueTypeQId? coercions qid
      | _ -> false

endspec
