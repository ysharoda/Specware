spec

  (* This spec defines various ops that collect variables and other names
  occurring in syntactic entities (e.g. free variables in expressions). *)

  import Judgements

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  % variables introduced by pattern:
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  op pattVars : Pattern -> FSet Variable

  op pattSeqVars : FSeq Pattern -> FSet Variable
  def pattSeqVars patts =
    unionAll (map (pattVars, patts))

  def pattVars = fn
    | variable(v,_)    -> singleton v
    | embedding(_,_,p) -> pattVars p
    | record comps     -> let (_, patts) = unzip comps in
                          pattSeqVars patts
    | alias((v,_),p)   -> pattVars p with v

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  % free variables in expression:
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  (* In LD, free variables of subtype and quotient type predicates are not
  considered in the syntax because the well-typedness rules for expression
  force such predicates to have no free variables. However, here it is easier
  to consider them because of the way we have factored expressions. *)

  op exprFreeVars : Expression -> FSet Variable

  op exprSeqFreeVars : FSeq Expression -> FSet Variable
  def exprSeqFreeVars exprs =
    unionAll (toSet (map (exprFreeVars, exprs)))

  def exprFreeVars = fn
    | nullary(variable v)      -> singleton v
    | unary(_,e)               -> exprFreeVars e
    | binary(_,e1,e2)          -> exprFreeVars e1 \/ exprFreeVars e2
    | ifThenElse(e0,e1,e2)     -> exprFreeVars e0 \/
                                  exprFreeVars e1 \/
                                  exprFreeVars e2
    | nary(_,exprs)            -> exprSeqFreeVars exprs
    | binding(_,(v,_),e)       -> exprFreeVars e wout v
    | multiBinding(_,binds,e)  -> let (vars, _) = unzip binds in
                                  exprFreeVars e -- toSet vars
    | cas(e,branches)          -> let (patts,exprs) = unzip branches in
                                  let varSets =
                                      seqSuchThat (fn(i:Nat) ->
                                        if i < length branches
                                        then Some (exprFreeVars (exprs elem i) --
                                                   pattVars     (patts elem i))
                                        else None) in
                                  let def branchVars
                                          (e:Expression, p:Pattern) : FSet Variable =
                                          exprFreeVars e -- pattVars p in
                                  unionAll (map2 (branchVars, exprs, patts))
                                  \/ exprFreeVars e
    | recursiveLet(asgments,e) -> let (binds, exprs) = unzip asgments in
                                  let (vars, _) = unzip binds in
                                  (exprSeqFreeVars exprs \/ exprFreeVars e)
                                  -- toSet vars
    | nonRecursiveLet(p,e,e1)  -> exprFreeVars e \/
                                  (exprFreeVars e1 -- pattVars p)
    | _                        -> empty

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  % types, ops, type variables, and variables declared in context:
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  op contextElementTypes    : ContextElement -> FSet TypeName
  op contextElementOps      : ContextElement -> FSet Operation
  op contextElementTypeVars : ContextElement -> FSet TypeVariable
  op contextElementVars     : ContextElement -> FSet Variable

  def contextElementTypes = fn
    | typeDeclaration(t,_) -> singleton t
    | _                    -> empty

  def contextElementOps = fn
    | opDeclaration(o,_,_) -> singleton o
    | _                    -> empty

  def contextElementTypeVars = fn
    | tVarDeclaration tv -> singleton tv
    | _                  -> empty

  def contextElementVars = fn
    | varDeclaration(v,_) -> singleton v
    | _                   -> empty

  op contextTypes    : Context -> FSet TypeName
  op contextOps      : Context -> FSet Operation
  op contextTypeVars : Context -> FSet TypeVariable
  op contextVars     : Context -> FSet Variable

  def contextTypes    cx = unionAll (map (contextElementTypes,    cx))
  def contextOps      cx = unionAll (map (contextElementOps,      cx))
  def contextTypeVars cx = unionAll (map (contextElementTypeVars, cx))
  def contextVars     cx = unionAll (map (contextElementVars,     cx))

endspec
