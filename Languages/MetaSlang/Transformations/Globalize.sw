Globalize qualifying spec
{
 import /Languages/MetaSlang/Specs/Environment
 import /Languages/MetaSlang/Transformations/SliceSpec
 import /Languages/MetaSlang/CodeGen/SubstBaseSpecs  
 import /Languages/SpecCalculus/Semantics/Evaluate/Spec/AddSpecElements  % for addOp of global var

  op compressWhiteSpace (s : String) : String =
   let 
     def whitespace? char = 
       char = #\s || char = #\n || char = #\t

     def compress (chars, have_whitespace?) =
       %% avoid deep recursions...
       let (chars, _) = 
           foldl (fn ((chars, have_whitespace?), char) ->
                    if whitespace? char then
                      if have_whitespace? then
                        (chars, have_whitespace?)
                      else
                        ([#\s] ++ chars, true)
                    else
                      ([char] ++ chars, false))
                 ([], true)
                 chars
       in
         reverse chars
   in
     implode (compress (explode s, true))

 type OpTypes  = AQualifierMap MSType
 type MSRule   = MSPattern * MSTerm * MSTerm
 type MSVar    = AVar Position
 type VarNames = List Id

 type Context = {spc                  : Spec, 
                 root_ops             : OpNames,
                 global_var_name      : OpName,
                 global_var           : MSTerm,
                 global_type_name     : TypeName,
                 global_type          : MSType,
                 global_var_setter    : MSTerm,
                 global_field_setters : List (String * MSTerm * MSTerm), % LHS and setter
                 tracing?             : Bool}
                   
 op nullTerm : MSTerm    = Record  ([], noPos)
 op nullType : MSType    = Product ([], noPos)
 op nullPat  : MSPattern = WildPat (nullType, noPos)

 op showTypeName (info : TypeInfo) : String = printQualifiedId (primaryTypeName info)
 op showOpName   (info : OpInfo)   : String = printQualifiedId (primaryOpName   info)

 op baseOp? (qid as Qualified(q, id) : QualifiedId) : Bool = 
  q in? ["Bool", "Char", "Compare", "Function", "Integer", "IntegerAux", "List", "List1", "Nat", "Option", "String"]

 op baseType? (qid as Qualified(q, id) : QualifiedId) : Bool = 
  q in? ["Bool", "Char", "Compare", "Function", "Integer", "IntegerAux", "List", "List1", "Nat", "Option", "String"]

 op myTrue : MSTerm = Fun (Bool true, Boolean noPos, noPos)

 %% ================================================================================
 %% Verify that the suggested global type actually exists
 %% ================================================================================

 op checkGlobalType (spc: Spec, gtype as Qualified(q,id) : TypeName) : SpecCalc.Env TypeName =
  case findTheType (spc, gtype) of
    | Some _ -> return gtype
    | _ ->
      if q = UnQualified then
        case wildFindUnQualified (spc.types, id) of
          | [_]   -> return gtype
          | []    -> raise (Fail ("Proposed type to globalize does not exist: " ^ show gtype))
          | first :: rest -> 
            let names = foldl (fn (names, info) -> names ^ ", " ^ showTypeName info) (showTypeName first) rest in
            raise (Fail ("Proposed type to globalize is ambiguous: " ^ names))
      else
        raise (Fail ("Proposed type to globalize does not exist: " ^ show gtype))
          
 %% ================================================================================
 %% Verify that the suggested global var is plausible
 %% ================================================================================

 op checkGlobalVar (spc: Spec, gvar as Qualified(q,id) : OpName, gtype : TypeName) : SpecCalc.Env OpName =
  let
    def verify opinfo =
      let typ = termType opinfo.dfn in
      case typ of
        | Base (qid, [], _) | gtype = qid -> return gvar
        | _ ->
          raise (Fail ("Global var " ^ show gvar ^ " with expected type " ^ show gtype ^ " is already defined with type " ^ printType typ))
  in
  case findTheOp (spc, gvar) of
    | Some opinfo -> verify opinfo
    | _ ->
      if q = UnQualified then
        case wildFindUnQualified (spc.ops, id) of
          | [opinfo] -> verify opinfo
          | []       -> return gvar    % Ok -- we will add the proposed var later.
          | first :: rest ->
            let names = foldl (fn (names, info) -> names ^ ", " ^ showOpName info) (showOpName first) rest in
            raise (Fail ("Proposed global var is already ambiguous among " ^ names))
      else
        % Ok -- we will add the proposed var later.
        return gvar 
          
%% ================================================================================
 %% Find a plausible init op that produces something of the appropriate type
 %% ================================================================================

 op valTypeMatches? (typ : MSType, name : TypeName) : Bool =
  case typ of
    | Base    (nm, [], _) -> nm = name 
    | Subtype (typ, _, _) -> valTypeMatches? (typ, name)
    | Product (pairs,  _) -> exists? (fn (_, typ) -> valTypeMatches? (typ, name)) pairs
    | Arrow   (_, rng, _) -> valTypeMatches? (rng, name)
    | _ -> false

 op findInitOp (spc : Spec, gtype: TypeName) : SpecCalc.Env QualifiedId =
  let candidates =
      foldriAQualifierMap (fn (q, id, info, candidates) ->
                             let optype = termType info.dfn in
                             if valTypeMatches? (optype, gtype) && ~ (valTypeMatches? (optype, gtype)) then
                               (mkQualifiedId (q, id)) :: candidates 
                             else
                               candidates)
                          []
                          spc.ops
  in
  case candidates of
    | []             -> raise (Fail ("Could not find an initializer for type " ^ show gtype))
    | [init_op_name] -> return init_op_name
    | first :: rest  -> let init_ops = foldl (fn (names, init_op_name) -> 
                                                names ^ ", " ^ show init_op_name) 
                                             (show first)
                                             rest
                        in
                        raise (Fail ("Found multiple initializers for type " ^ show gtype ^ " : " ^ init_ops))

 %% ================================================================================
 %% Verify that the suggested init op produces something of the appropriate type
 %% ================================================================================

 op checkGlobalInitOp (spc: Spec, ginit as Qualified(q,id) : OpName, gtype : TypeName) : SpecCalc.Env QualifiedId =
  let
    def removeSubtypes typ = % do not use stripSubtypes, which uses unfoldBase
      case typ of
        | Subtype (typ, _, _) -> removeSubtypes typ
        | _ -> typ
          
    def verify opinfo =
      let full_type = termType opinfo.dfn in
      case full_type of
        
        | Base (qid, [], _) | gtype = qid -> return ginit        % op foo : State
          
        | Subtype (typ, _, _) ->
          (let typ = removeSubtypes typ in
           case typ of
             
             | Base (qid, [], _) | gtype = qid -> return ginit   % op foo : (State | p?)
               
             | _ ->
               raise (Fail ("Op " ^ show ginit ^ " for producing initial global " ^ 
                              show gtype ^ " is defined with type " ^ printType full_type)))
          
        | Arrow (_, rng, _) ->
          (let rng = removeSubtypes rng in
           case rng of
             
             | Base (qid, [], _) | gtype = qid -> return ginit    % op foo : X -> State  %  op foo : X -> (State | p?)
               
             | _ ->
               raise (Fail ("Op " ^ show ginit ^ " for producing initial global " ^ 
                              show gtype ^ " is defined with type " ^ printType full_type)))
          
        | _ ->
          raise (Fail ("Op " ^ show ginit ^ " for producing initial global " ^ 
                         show gtype ^ " is defined with type " ^ printType full_type))
  in
  case findTheOp (spc, ginit) of
    | Some opinfo -> verify opinfo
    | _ ->
      if q = UnQualified then
        case wildFindUnQualified (spc.ops, id) of
          | [opinfo] -> verify opinfo
          | []       -> raise (Fail ("Op " ^ show ginit ^ " for producing initial global " ^ show gtype ^ " is undefined."))
          | first :: rest -> 
            let names = foldl (fn (names, qid) -> names ^ ", " ^ showOpName qid) (showOpName first) rest in
            raise (Fail ("Op " ^ show ginit ^ " for producing initial global " ^ show gtype ^ " is ambiguous among " ^ names))
      else
        raise (Fail ("Op " ^ show ginit ^ " for producing initial global " ^ show gtype ^ " is undefined."))
          

 op globalizeInitOp (spc               : Spec, 
                     global_var        : MSTerm,
                     global_type       : MSType,
                     global_init_name  : OpName,
                     global_var_setter : MSTerm,
                     tracing?          : Bool)
  : Option OpInfo =
  %% modify init fn to set global variable rather than return value
  let Some info = findTheOp (spc, global_init_name) in
  let old_dfn   = info.dfn in
  let 
    def aux tm =
      case tm of

        | Lambda (rules, _) ->
          let new_rules = map (fn (pat, cond, body) -> 
                                 let set_args = Record ([("1", global_var), ("2", body)], noPos) in
                                 let new_tm   = Apply  (global_var_setter, set_args, noPos) in
                                 (pat, cond, new_tm))
                              rules
          in
          let new_dfn = Lambda (new_rules, noPos) in
          let _ = if tracing? then
                    let _ = writeLine ""                          in
                    let _ = writeLine ("Globalizing init fn " ^ show global_init_name) in
                    let _ = writeLine (printTerm old_dfn)         in
                    let _ = writeLine "  => "                     in
                    let _ = writeLine (printTerm new_dfn)         in
                    let _ = writeLine ""                          in
                    ()
                  else
                    ()
          in
          Some new_dfn

        | TypedTerm (tm, typ, _) -> 
          aux tm

        | _ ->
          let _ = writeLine("--------------------") in
          let _ = writeLine("??? Globalize: global init fn " ^ show global_init_name ^ " is not defined using lambda rules:") in
          let _ = writeLine("   ----   ") in
          let _ = writeLine(printTerm info.dfn) in
          let _ = writeLine("   ----   ") in
          let _ = writeLine(anyToString info.dfn) in
          let _ = writeLine("--------------------") in
          None
  in
  case aux old_dfn of
    | Some new_dfn -> Some (info << {dfn = new_dfn})
    | _ -> None

 %% ================================================================================
 %% Remove vars of given type from pattern
 %% ================================================================================

 op [a] renumber (fields : List (Id * a)) : List (Id * a) =
  %% [("1", a), ("2", b), ("4", c), ("5", d)]
  %%   =>
  %% [("1", a), ("2", b), ("3", c), ("4", d)]
  if forall? (fn (id, _) -> natConvertible id) fields then
    let (new_fields, _) =
        foldl (fn ((row, n), (_, tm)) ->
                 (row ++ [(show n, tm)], n+1))
              ([], 1)
              fields
    in
    new_fields
  else
    fields

 op globalizeAliasPat (context                       : Context)
                      (vars_to_remove                : VarNames) % vars of global type, remove on sight
                      (pat as AliasPat (p1, p2, pos) : MSPattern)
  : Ids * Option MSPattern = 
  let (ids1, opt_new_p1) = globalizePattern context vars_to_remove p1 in
  let (ids2, opt_new_p2) = globalizePattern context vars_to_remove p2 in
  (ids1 ++ ids2,
   case (opt_new_p1, opt_new_p2) of
     | (Some new_p1, Some new_p2) -> Some (AliasPat (new_p1, new_p2, noPos))
     | (None, None)               -> None
     | _ -> fail ("inconsistent globalization of alias patterns"))

 op globalizeEmbedPat (context                                 : Context)
                      (vars_to_remove                          : VarNames) % vars of global type, remove on sight
                      (pat as EmbedPat (id, opt_pat, typ, pos) : MSPattern)
  : Ids * Option MSPattern = 
  % let _ = writeLine("??? globalize ignoring EmbedPat: " ^ anyToString pat) in
  ([], Some pat)

 op globalizeRecordPat (context                 : Context)
                       (vars_to_remove          : VarNames) % vars of global type, remove on sight
                       (RecordPat (fields, pos) : MSPattern)
  : Ids * Option MSPattern = 
  let
    def aux (vars_to_remove, new_fields, old_fields) =
      case old_fields of
        | [] -> (vars_to_remove, new_fields)
        | (id, pat) :: ptail ->
          let (ids, opt_pat) = globalizePattern context vars_to_remove pat in
          let new_vars_to_remove = vars_to_remove ++ ids in
          let new_fields =
              case opt_pat of
                | Some new_pat -> new_fields ++ [(id, new_pat)]
                | _ -> new_fields
          in
          aux (new_vars_to_remove, new_fields, ptail)
  in
  let (vars_to_remove, new_fields) = aux ([], [], fields) in
  (vars_to_remove,
   Some (case new_fields of
           | [(id, pat)] | natConvertible id -> pat
           | _ -> RecordPat (renumber new_fields, noPos)))

 op globalizeQuotientPat (context                                  : Context)
                         (vars_to_remove                           : VarNames) % vars of global type, remove on sight
                         (pat as (QuotientPat (p1, typename, pos)) : MSPattern)
  : Ids * Option MSPattern = 
  globalizePattern context vars_to_remove p1

 op globalizeRestrictedPat (context                              : Context)
                           (vars_to_remove                       : VarNames) % vars of global type, remove on sight
                           (pat as (RestrictedPat (p1, tm, pos)) : MSPattern)
  : Ids * Option MSPattern = 
  globalizePattern context vars_to_remove p1

 op globalType? (context : Context) (typ : MSType) : Bool =
  case typ of
    | Base     (nm, [], _) -> nm = context.global_type_name
    | Subtype  (typ, _, _) -> globalType? context typ
    | Quotient (typ, _, _) -> globalType? context typ  %% TODO??
    | _ -> false

 op globalizeVarPat (context                          : Context)
                    (vars_to_remove                   : VarNames) % vars of global type, remove on sight
                    (pat as (VarPat ((id, typ), pos)) : MSPattern)
  : Ids * Option MSPattern =
  if globalType? context typ then
    ([id], None)
  else
    ([], Some pat)

 op globalizeTypedPat (context                          : Context)
                      (vars_to_remove                   : VarNames) % vars of global type, remove on sight
                      (pat as (TypedPat (p1, typ, pos)) : MSPattern)
  : Ids * Option MSPattern =
  let _ = writeLine("??? Globalize doesn't know how to globalize type pattern: " ^ printPattern pat) in
  ([], Some pat)

 op globalizePattern (context        : Context)
                     (vars_to_remove : VarNames)  % vars of global type, remove on sight
                     (pat            : MSPattern) 
  : Ids * Option MSPattern = 
  case pat of
    | AliasPat      _ -> globalizeAliasPat      context vars_to_remove pat
    | EmbedPat      _ -> globalizeEmbedPat      context vars_to_remove pat
    | RecordPat     _ -> globalizeRecordPat     context vars_to_remove pat
    | QuotientPat   _ -> globalizeQuotientPat   context vars_to_remove pat
    | RestrictedPat _ -> globalizeRestrictedPat context vars_to_remove pat
    | VarPat        _ -> globalizeVarPat        context vars_to_remove pat
    | TypedPat      _ -> globalizeTypedPat      context vars_to_remove pat
   %| WildPat       
   %| BoolPat       
   %| NatPat        
   %| StringPat     
   %| CharPat       
    | _ -> ([], None)


 %% ================================================================================
 %% Given global type, find patterns and terms of that type and remove them
 %% ================================================================================

 op makeGlobalAccess (context    : Context)
                     (field_name : Id)
                     (field_type : MSType) 
  : MSTerm =
  let global_type  = Base  (context.global_type_name, [],                      noPos) in
  let global_var   = Fun   (Op (context.global_var_name, Nonfix), global_type, noPos) in
  let project_type = Arrow (global_type, field_type,                           noPos) in
  let projection   = Fun   (Project field_name, project_type,                  noPos) in
  Apply (projection, global_var, noPos)

 op globalSetterInfo (global_type_name : TypeName) : MSType * QualifiedId * MSType =
  let global_type = Base (global_type_name, [], noPos) in
  let setter_name = Qualified ("System", "set") in
  let setter_type = Arrow (Product ([("1", global_type), ("2", global_type)], noPos),
                           Product ([], noPos),
                           noPos)
  in
  (global_type, setter_name, setter_type)

 op makeGlobalUpdate (context    : Context)
                     (merger     : MSTerm)  % RecordMerge
                     (new_fields : MSTerm)  % record of fields to update
  : MSTerm =
  let (global_type, setter_name, setter_type) = globalSetterInfo context.global_type_name in
  let setter      = Fun    (Op (setter_name,             Nonfix), setter_type, noPos) in
  let global_var  = Fun    (Op (context.global_var_name, Nonfix), global_type, noPos) in
  let merge_args  = Record ([("1", global_var), ("2", new_fields)],            noPos) in
  let merge       = Apply  (merger, merge_args,                                noPos) in
  let set_args    = Record ([("1", global_var), ("2", merge)],                 noPos) in
  let new_tm      = Apply  (setter, set_args,                                  noPos) in
  new_tm
  
 op applyHeadType (tm : MSTerm, context : Context) : MSType =
  case tm of
    | Apply (t1, t2, _) -> applyHeadType (t1, context)
    | Fun (Op (qid, _), typ, _) -> 
      (case findTheOp (context.spc, qid) of
         | Some opinfo -> firstOpDefInnerType opinfo
         | _ -> termType tm)
    | _ -> 
      termType tm
      
 op globalizeApply (context                     : Context)
                   (vars_to_remove              : VarNames) % vars of global type, remove on sight
                   (tm as (Apply (t1, t2, pos)) : MSTerm)
  : Option MSTerm = 
  let
    def dom_type typ =
      case typ of
        | Arrow   (t1, _, _) -> Some t1
        | Subtype (typ, _, _) -> dom_type typ
        | _ -> None

    def retype_fun (tm, typ) =
      case tm of
        | Fun (x, _, pos) -> Fun (x, typ, pos)
        | _ ->
          let _ = writeLine ("??? Globalize expected a primtive Fun term for retyping, but got : " ^ compressWhiteSpace(printTerm tm)) in
          TypedTerm (tm, typ, pos)
  in
  case (t1, t2) of
    | (Fun (RecordMerge, _, _),  Record ([(_, Var ((id, _), _)), (_, t3)], _)) | id in? vars_to_remove 
      ->
      %%  special case for global update:  
      %%     local_var_to_be_globalized << {...}
      %%       =>
      %%     global_update (global_var, {...})
      let new_t3 = case globalizeTerm context vars_to_remove t3 of
                     | Some new_t3 -> new_t3
                     | _ -> t3
      in
      let new_tm = makeGlobalUpdate context t1 new_t3 in
      Some new_tm
   | _ ->
     let opt_new_t1 = globalizeTerm context vars_to_remove t1 in
     let opt_new_t2 = globalizeTerm context vars_to_remove t2 in
     %% Vars to be removed will have been removed from inside t1 and t2, but not if t1 or t2 itself is global.
     let (changed1?, new_t1) =
         case opt_new_t1 of
           | Some new_t1 -> (true,  new_t1)
           | _           -> (false, t1)
     in
     let (changed2?, new_t2) =
         case opt_new_t2 of
           | Some new_t2 -> (true,  new_t2)
           | _           -> (false, t2)
     in
     case new_t2 of
       | Var ((id, _), _) | id in? vars_to_remove ->
         %% f x ...  where x has global type
         let head_type = applyHeadType (t1, context) in
         let head_type = unfoldToArrow (context.spc, head_type) in
         Some (case dom_type head_type of
                 | Some dtype ->  
                   if globalType? context dtype then
                     case t1 of
                       | Fun (Project field_name, _, _) ->
                         %%  special case for global access:  
                         %%    (local_var_to_be_globalized.xxx)
                         %%      =>
                         %%    (global_var.xxx)
                         makeGlobalAccess context field_name (termType tm)
                       | _ ->
                         case head_type of
                           | Arrow (_, Arrow _, _) ->
                             %% (f x y ...)  where x has global type, and domain of f is global type
                             %%   =>
                             %% (f y ...)
                             let range_type = termType tm in
                             retype_fun (t1, range_type)
                           | _ ->
                             %% (f x) where x has global type, and domain of f is global type
                             %%   =>
                             %% (f ())
                             Apply (new_t1, nullTerm, pos)
                   else
                     %% (f x y ...)  where x has global type, but domain of f is NOT global type (presumably is polymorphic)
                     %%   =>
                     %% (f gvar y ...)
                     let global_type = Base (context.global_type_name, [],                      noPos) in
                     let global_var  = Fun  (Op (context.global_var_name, Nonfix), global_type, noPos) in
                     Apply (new_t1, global_var, pos)
                 | _ ->
                   %% (f(x))  where x has global type, domain of f is global type
                   %%   =>
                   %% (f())
                   Apply (new_t1, nullTerm, pos))
       | _ ->
         if changed1? || changed2? then
           Some (Apply (new_t1, new_t2, pos))
         else
           None
      
 %% ================================================================================

 op globalizeRecord (context              : Context)
                    (vars_to_remove       : VarNames)  % vars of global type, remove on sight
                    (Record (fields, pos) : MSTerm)
  : Option MSTerm = 
  let (revised?, new_fields) = 
      foldl (fn ((revised?, new_fields), (id, old_tm)) -> 
               case old_tm of
                 | Var ((id, _), _) | id in? vars_to_remove -> 
                   (true, new_fields)
                 | _ -> 
                   case globalizeTerm context vars_to_remove old_tm of
                     | Some new_tm -> (true,     new_fields ++ [(id, new_tm)])
                     | _           -> (revised?, new_fields ++ [(id, old_tm)]))
            (false, [])
            fields 
  in
  if revised? then
    Some (case new_fields of
            | [(lbl, tm)] | natConvertible lbl -> 
              % If a var x is removed from 2-element record '(x, y)' 
              %  simplify resulting singleton record '(y)' down to 'y'.
              % But don't simplify a 1-element record with an explicitly named 
              %  field such as {a = x}
              tm  
            | _ -> Record (renumber new_fields, pos))
  else 
    % term is unchanged
    None

 %% ================================================================================
 %% Given global type, find argument variables of that type and remove them
 %% ================================================================================

 op globalizeLet (context                   : Context)
                 (vars_to_remove            : VarNames)  % vars of global type, remove on sight
                 (Let (bindings, body, pos) : MSTerm)
  : Option MSTerm = 
  let (new_bindings, vars_to_remove, changed_bindings?) = 
      foldl (fn ((bindings, vars_to_remove, changed_binding?), (pat, tm)) -> 
               let (changed_tm?, new_tm) =
                   case globalizeTerm context vars_to_remove tm of
                     | Some new_tm -> (true, new_tm)
                     | _ -> (false, tm)
               in
               let (new_vars_to_remove, opt_new_pat) = globalizePattern context vars_to_remove pat in
               let new_pat =
                   case opt_new_pat of
                     | Some new_pat -> new_pat
                     | _ -> nullPat
               in
               let new_bindings = bindings ++ [(new_pat, new_tm)] in
               case new_vars_to_remove of
                 | [] -> (new_bindings, 
                          vars_to_remove, 
                          changed_tm?)
                 | _ -> (new_bindings, 
                         vars_to_remove ++ new_vars_to_remove,
                         true))
            ([],vars_to_remove, false)
            bindings 
  in
  let opt_new_body = globalizeTerm context vars_to_remove body in
  let (changed_body?, new_body) = 
      case opt_new_body of
        | Some new_body -> (true,  new_body)
        | _ ->             
          case body of
            | Var ((id, _), _) | id in? vars_to_remove -> (true, nullTerm)
            | _ -> (false, body)
  in
  if changed_bindings? || changed_body? then
    Some (Let (new_bindings, new_body, pos))
  else
    None

 %% ================================================================================

 op globalizeLetRec (context                      : Context)
                    (vars_to_remove               : VarNames)  % vars of global type, remove on sight
                    (LetRec (bindings, body, pos) : MSTerm)
  : Option MSTerm = 
  %% (old_bindings   : List (MSVar * MSTerm))  (old_body       : MSTerm) 
  None

 %% ================================================================================
 %% Given global type, find argument variables of that type and remove them
 %% ================================================================================

 op globalizeLambda (context             : Context)
                    (vars_to_remove      : VarNames)  % vars of global type, remove on sight
                    (Lambda (rules, pos) : MSTerm)
  : Option MSTerm = 
  let 
    def globalizeRule (rule as (pat, cond, body)) =
      let (new_vars_to_remove, opt_new_pat) = globalizePattern context vars_to_remove pat in
      let vars_to_remove = vars_to_remove ++ new_vars_to_remove in
      let opt_new_body =
          case globalizeTerm context vars_to_remove body of
            | Some (Var ((id, _), _)) | id in? vars_to_remove -> 
              let global_type = Base (context.global_type_name, [],                      noPos) in
              let global_var  = Fun  (Op (context.global_var_name, Nonfix), global_type, noPos) in
              Some global_var
            | opt_new_body -> opt_new_body
      in
      case new_vars_to_remove of
        | [] ->
          (case opt_new_body of
             | None -> None %% no changes...
             | Some new_body ->
               %% fn pat -> body
               %%  =>
               %% fn new_pat -> new_body
               let new_pat =
                   case opt_new_pat of
                     | Some new_pat -> new_pat
                     | _ -> pat
               in
               Some (new_pat, myTrue, new_body))
        | _ ->
          let new_body =
              case opt_new_body of
                | Some new_body -> new_body
                | _ -> Record ([], noPos)
          in
          case opt_new_pat of
            | Some new_pat ->
              %% fn (x:Global, y:Foo) -> body
              %%   =>
              %% fn (y:Foo) -> new_body
              Some (new_pat, myTrue, new_body)
            | _ ->
              %% fn (x:Global) -> body
              (case new_body of
                 | Lambda ([(inner_pat, new_cond, inner_body)], _) ->
                   %% fn (x:Global) -> fn (new_pat) -> inner_body
                   %%  =>
                   %%                  fn (new_pat) -> inner_body
                   Some (inner_pat, myTrue, inner_body)
                 | _ ->
                   %% fn (x:Global) -> body
                   %%  =>
                   %% fn () -> new_body
                   let null_pat = WildPat (TyVar ("wild", noPos),noPos) in
                   Some (null_pat, myTrue, new_body))
  in
  let opt_new_rules = map globalizeRule rules in
  if exists? (fn opt_rule -> case opt_rule of | Some _ -> true | _ -> false) opt_new_rules then
    let new_rules = map2 (fn (rule, opt_new_rule) -> 
                            case opt_new_rule of
                              | Some new_rule -> new_rule
                              | _ -> rule)
                         (rules, opt_new_rules)
    in
    Some (Lambda (new_rules, pos))
  else
    % None indicates no change
    None

 %% ================================================================================

 op globalizeIfThenElse (context                      : Context)
                        (vars_to_remove               : VarNames)  % vars of global type, remove on sight
                        (IfThenElse (t1, t2, t3, pos) : MSTerm)
  : Option MSTerm = 
  let opt_new_t1 = globalizeTerm context vars_to_remove t1 in
  let opt_new_t2 = globalizeTerm context vars_to_remove t2 in
  let opt_new_t3 = globalizeTerm context vars_to_remove t3 in
  case (opt_new_t1, opt_new_t2, opt_new_t3) of
    | (None, None, None) -> 
      % Term is unchanged
      None 
    | _ -> 
      let new_t1 = case opt_new_t1 of
                     | Some new_t1 -> new_t1
                     | _ -> t1
      in
      let new_t2 = case opt_new_t2 of
                     | Some new_t2 -> new_t2
                     | _ -> t2
      in
      let new_t2 = case new_t2 of
                     | Var ((id, _), _) | id in? vars_to_remove -> nullTerm
                     | _ -> new_t2
      in
      let new_t3 = case opt_new_t3 of
                     | Some new_t3 -> new_t3
                     | _ -> t3
      in
      let new_t3 = case new_t3 of
                     | Var ((id, _), _) | id in? vars_to_remove -> nullTerm
                     | _ -> new_t3
      in
      Some (IfThenElse (new_t1, new_t2, new_t3, pos))


 %% ================================================================================

 op globalizeSeq (context        : Context)
                 (vars_to_remove : VarNames)  % vars of global type, remove on sight
                 (Seq (tms, pos) : MSTerm) 
  : Option MSTerm = 
  let opt_new_tms = map (fn tm -> globalizeTerm context vars_to_remove tm) tms in
  if exists? (fn opt_tm -> case opt_tm of | Some _ -> true | _ -> false) opt_new_tms then  
    let new_tms = map2 (fn (tm, opt_new_tm) ->
                         case opt_new_tm of 
                           | Some new_tm -> new_tm
                           | _ -> tm)
                       (tms, opt_new_tms)
    in
    Some (Seq (new_tms, pos))
  else
    None

 %% ================================================================================

 op globalizeTypedTerm (context                  : Context)
                       (vars_to_remove           : VarNames)  % vars of global type, remove on sight
                       (TypedTerm (tm, typ, pos) : MSTerm)
  : Option MSTerm = 
  let
   def nullify_global typ =
     if globalType? context typ then
       nullType
     else
       case typ of

         | Arrow (dom, rng, pos) -> 
           let rng = nullify_global rng in
           if globalType? context dom then
             case rng of
               | Arrow _ -> rng
               | _ -> Arrow (nullify_global dom, rng, noPos)
           else
             Arrow (nullify_global dom, rng, noPos)

         | Product (fields, pos) ->
           (let new_fields = foldl (fn (fields, (id, typ)) ->
                                      if globalType? context typ then
                                        fields
                                      else
                                        fields ++ [(id, nullify_global typ)])
                                   []
                                   fields
            in
            case new_fields of
              | [(id, typ)] | natConvertible id -> typ
              | _ -> Product (renumber new_fields, noPos))
         | CoProduct (fields, pos) -> 
           %% TODO: revise CoProduct ??
           let new_fields = foldl (fn (fields, field as (id, opt_typ)) ->
                                     case opt_typ of
                                       | Some typ ->
                                         if globalType? context typ then
                                           fields
                                         else
                                           fields ++ [(id, Some (nullify_global typ))]
                                       | _ ->
                                         fields ++ [field])
                                  []
                                  fields
           in
           CoProduct (new_fields, noPos)
         | _ -> typ

  in
  case globalizeTerm context vars_to_remove tm of
    | Some new_tm ->
      let new_typ = nullify_global typ in 
      Some (TypedTerm (new_tm, new_typ, pos))
    | _ ->
      None

 %% ================================================================================

 op globalizePi (context              : Context)
                (vars_to_remove       : VarNames)  % vars of global type, remove on sight
                (Pi (tyvars, tm, pos) : MSTerm)
  : Option MSTerm = 
  case globalizeTerm context vars_to_remove tm of
    | Some new_tm ->
      Some (Pi (tyvars, new_tm, pos)) % TODO: remove unused tyvars
    | _ ->
      None

 %% ================================================================================

 op globalizeAnd (context        : Context)
                 (vars_to_remove : VarNames)  % vars of global type, remove on sight
                 (And (tms, pos) : MSTerm)
  : Option MSTerm = 
  case tms of
    | tm :: _ -> globalizeTerm context vars_to_remove tm 
    | [] -> None

 %% ================================================================================

 op globalizeTerm (context        : Context)
                  (vars_to_remove : VarNames)  % vars of global type, remove on sight
                  (term           : MSTerm) 
  : Option MSTerm = 
  case term of
    | Apply      _ -> globalizeApply      context vars_to_remove term
    | Record     _ -> globalizeRecord     context vars_to_remove term
    | Let        _ -> globalizeLet        context vars_to_remove term
    | LetRec     _ -> globalizeLetRec     context vars_to_remove term
    | Lambda     _ -> globalizeLambda     context vars_to_remove term
    | IfThenElse _ -> globalizeIfThenElse context vars_to_remove term
    | Seq        _ -> globalizeSeq        context vars_to_remove term
    | TypedTerm  _ -> globalizeTypedTerm  context vars_to_remove term
    | Pi         _ -> globalizePi         context vars_to_remove term
    | And        _ -> globalizeAnd        context vars_to_remove term

   %| ApplyN     _ -> None % not present after elaborateSpec is called
   %| Bind       _ -> None % should not be globalizing inside quantified terms
   %| The        _ -> None % should not be globalizing inside 'the' term
   %| Var        _ -> None % vars to be globalized should be removed from parent before we get to this level
   %| Fun        _ -> None % primitive terms are never global
   %| Transform  _ -> None % doesn't make sense to globalize this
   %| Any        _ -> None % can appear within typed term, for example

    | _ -> None

 %% ================================================================================

 op globalizeOpInfo (context    : Context,
                     old_info   : OpInfo)
  : OpInfo =
  let qid as Qualified(q, id) = primaryOpName old_info in
  if baseOp? qid then
    old_info
  else
    let old_dfn = case old_info.dfn of 
                    | And (tm :: _, _) -> tm 
                    | tm -> tm 
    in
    case globalizeTerm context [] old_dfn of
      | Some new_dfn -> 
        let new_info = old_info << {dfn = new_dfn} in
        let _ = if context.tracing? then
              let _ = writeLine ""                          in
              let _ = writeLine ("Globalizing " ^ show qid) in
              let _ = writeLine (printTerm old_dfn)         in
              let _ = writeLine "  => "                     in
              let _ = writeLine (printTerm new_dfn)         in
              let _ = writeLine ""                          in
              ()
            else
              ()
        in
        new_info
      | _ -> 
        old_info

 op replaceLocalsWithGlobalRefs (context : Context) : SpecCalc.Env (Spec * Bool) =
  (*
   * At this point, we know:
   *  gtype names a unique existing base type in spc,
   *  gvar  names a unique existing op in spc, of type 'gtype'
   *
   * For every op f in spc, remove local vars of type gtype, and replace with references to gvar.
   * If the final returned value is constructed "on-the-fly", add an assignment of that value to gvar.
   *)
  let spc = context.spc in
  let (root_ops, root_types) = 
      case context.root_ops of
        | [] -> topLevelOpsAndTypesExcludingBaseSubsts spc 
        | root_ops -> (root_ops, [])
  in
  let base_ops = mapiPartialAQualifierMap (fn (q, id, info) ->
                                             if baseOp? (Qualified(q, id)) then
                                               Some info
                                             else
                                               None)
                                          spc.ops
  in
  let base_types = mapiPartialAQualifierMap (fn (q, id, info) ->
                                               if baseType? (Qualified(q, id)) then
                                                 Some info
                                               else
                                                 None)
                                            spc.types
  in
  let (ops_to_revise, types_to_keep) =
      let chase_terms_in_types? = false in
      let chase_theorems?       = false in
      sliceSpecInfo (spc, 
                     root_ops, root_types,  % start searching from these, and include them
                     baseOp?, baseType?,    % stop searching at these, and do not include them
                     chase_terms_in_types?, 
                     chase_theorems?)
  in
  let new_ops =
      foldriAQualifierMap (fn (q, id, x, pending_ops) ->
                             case findTheOp (spc, Qualified (q, id)) of
                               | Some info -> 
                                 let new_info = globalizeOpInfo (context, info) in
                                 insertAQualifierMap (pending_ops, q, id, new_info)
                               | _ -> 
                                 let _ = writeLine("??? Globalize could not find op " ^ q ^ "." ^ id) in
                                 pending_ops)
                          base_ops
                          ops_to_revise
  in
  let new_types =
      foldriAQualifierMap (fn (q, id, x, pending_types) ->
                             case findTheType (spc, Qualified (q, id)) of
                               | Some info -> 
                                 insertAQualifierMap (pending_types, q, id, info)
                               | _ -> 
                                 let _ = writeLine("??? Globalize could not find type " ^ q ^ "." ^ id) in
                                 pending_types)
                          base_types
                          types_to_keep
  in
  let new_spec = spc << {ops = new_ops, types = new_types} in
  let 
    def globalize_elements elements =
      foldl (fn (new_elts, elt) ->
               case elt of
                 | Import (sc_term, imported_spec, imported_elts, pos) ->
                   new_elts ++ [Import (sc_term, 
                                        imported_spec, 
                                        globalize_elements imported_elts, 
                                        pos)]
                 | Type (Qualified(q,id), _) ->
                   (case findAQualifierMap (new_types, q, id) of
                      | Some _ -> new_elts ++ [elt]
                      | _ -> new_elts)
                 | TypeDef (Qualified(q,id), _) ->
                   (case findAQualifierMap (new_types, q, id) of
                      | Some _ -> new_elts ++ [elt]
                      | _ -> new_elts)
                 | Op (Qualified(q,id), _, _) ->
                   (case findAQualifierMap (new_ops, q, id) of
                      | Some _ -> new_elts ++ [elt]
                      | _ -> new_elts)
                 | OpDef (Qualified(q,id), _, _) ->
                   (case findAQualifierMap (new_ops, q, id) of
                      | Some _ -> new_elts ++ [elt]
                      | _ -> new_elts)
                 | _ -> new_elts)
             []
             elements
  in
  let new_elements = globalize_elements spc.elements in
  let new_spec = spc << {ops      = new_ops, 
                         types    = new_types, 
                         elements = new_elements} 
  in
  return (new_spec, context.tracing?)

 op globalizeSingleThreadedType (spc              : Spec, 
                                 root_ops         : OpNames,
                                 global_type_name : TypeName, 
                                 global_var_name  : OpName, 
                                 opt_ginit        : Option OpName,
                                 tracing?         : Boolean)
  : SpecCalc.Env (Spec * Bool) =
  {
   global_type_name <- checkGlobalType (spc, global_type_name);
   global_var_name  <- checkGlobalVar  (spc, global_var_name, global_type_name);
   global_type      <- return (Base (global_type_name, [], noPos));
   global_var       <- return (Fun (Op (global_var_name, Nonfix), global_type, noPos));
   global_init_name <- (case opt_ginit of
                          | Some ginit -> checkGlobalInitOp (spc, ginit, global_type_name)
                          | _ -> findInitOp (spc, global_type_name));

   global_var_setter_name <- return (Qualified ("System", "set"));
   global_var_setter_type <- return (Arrow (Product ([("1", global_type), ("2", global_type)], noPos),
                                            Product ([], noPos),
                                            noPos));
   global_var_setter      <- return (Fun (Op (global_var_setter_name, Nonfix), global_var_setter_type, noPos));

   spc_with_ginit   <- return (case findTheOp (spc, global_init_name) of
                                 | Some info ->
                                   (case globalizeInitOp (spc,
                                                          global_var, 
                                                          global_type, 
                                                          global_init_name,
                                                          global_var_setter,
                                                          tracing?)
                                      of
                                      | Some new_info ->
                                        let Qualified (q,id) = global_init_name in
                                        let new_ops  = insertAQualifierMap (spc.ops, q, id, new_info) in
                                        spc << {ops = new_ops}
                                      | _ ->
                                        let _ = writeLine ("??? Globalize could not revise init op " ^ show global_init_name) in
                                        spc)
                                 | _ -> 
                                   let _ = writeLine ("??? Op " ^ show global_init_name ^ " for producing initial global " ^ show global_type_name ^ " is undefined.") in
                                   spc);

   spc_with_gvar    <- (case findTheOp (spc_with_ginit, global_var_name) of
                          | Some _ -> return spc_with_ginit
                          | _ -> 
                            let names   = [global_var_name]                   in
                            let refine? = false                               in
                            let gtype   = Base (global_type_name, [],  noPos) in
                            let dfn     = TypedTerm (Any noPos, gtype, noPos) in
                            addOp names Nonfix refine? dfn spc_with_ginit noPos);

   spc_with_gset    <- let (_, setter_name, setter_type) = globalSetterInfo global_type_name in
                       let names   = [setter_name]                             in
                       let refine? = false                                     in
                       let dfn     = TypedTerm (Any noPos, setter_type, noPos) in
                       addOp names Nonfix refine? dfn spc_with_gvar noPos;

   let global_field_setters = [] 
   in
   let context = {spc                  = spc_with_gset,
                  root_ops             = root_ops,
                  global_var_name      = global_var_name,
                  global_var           = global_var,
                  global_type_name     = global_type_name,
                  global_type          = global_type,
                  global_var_setter    = global_var_setter,
                  global_field_setters = global_field_setters,
                  tracing?             = tracing?}
   in
   replaceLocalsWithGlobalRefs context
   }

 %% ================================================================================

}

