spec

  % API public default

  import BasicAbbreviations, Occurrences

  (* In LD, a record updater is labeled by three record types. Here, we label
  it by, essentially, three pairs, each pair consisting of a sequence of
  fields and a sequence of types. Each such pair consists of the fields and
  types of the corresponding record type in LD. *)

  op RECUPDATER : Fields * Types * Fields * Types * Fields * Types -> Expression
  def RECUPDATER (fS,tS,fS1,tS1,fS2,tS2) =
    let t1:Type = RECORD (fS ++ fS1, tS ++ tS1) in
    let t2:Type = RECORD (fS ++ fS2, tS ++ tS2) in
    let x:Variable = abbr 0 in
    let y:Variable = abbr 1 in
    let n:Nat = min (length fS, length tS) in
      % if length fS ~= length tS, excess fields or types are ignored
      % (we avoid subtypes in public ops)
    let n1:Nat = min (length fS1, length tS1) in
      % if length fS1 ~= length tS1, excess fields or types are ignored
      % (we avoid subtypes in public ops)
    let n2:Nat = min (length fS2, length tS2) in
      % if length fS2 ~= length tS2, excess fields or types are ignored
      % (we avoid subtypes in public ops)
    let eS:Expressions = seq (fn(i:Nat) ->
      % common fields come from second record y:
      if i < n then Some (DOT (VAR y, tS@i, fS@i))
      % left-only fields come from first record x:
      else if i < n+n1 then Some (DOT (VAR x, tS1@(i-n), fS1@(i-n)))
      % right-only fields come from first record x:
      else if i < n+n1+n2 then Some (DOT (VAR y, tS2@(i-n-n1), fS2@(i-n-n1)))
      else None) in
    let e = REC (fS ++ fS1 ++ fS2, tS ++ tS1 ++ tS2, eS) in
    FN2 (x, t1, y, t2, e)

  % record update:

  op RECUPDATE : Fields * Types * Fields * Types * Fields * Types ->
                 Expression * Expression -> Expression
  def RECUPDATE (fS,tS,fS1,tS1,fS2,tS2) (e1,e2) =
    RECUPDATER(fS,tS,fS1,tS1,fS2,tS2) @ e1 @ e2

  % simple let:

  op LETSIMP : Variable * Type * Expression * Expression -> Expression
  def LETSIMP (v,t,e,e1) = FN(v,t,e1) @ e

  % branches of binding conditional or pattern matching:

  type BindingBranch = Variables * Types *  % bound variables
                       Expression *         % condition or pattern
                       Expression           % result

  type BindingBranches = FSeq BindingBranch

  (* In LD, the expansions of a binding conditional contains "gamma" variables
  decorated by variables and expressions, such that the "gamma" variables are
  distinct from the decorating variables and from the free variables of the
  decorating expressions. As explained in spec TypesAndExpressions, here we
  simply decorate abbreviation variables with integers. Thus, in order to
  fulfill the distinctness requirement, we define an op that takes as
  arguments the variables and expressions that decorate the "gamma" variables
  in LD, and returns the abbr variable decorated by the minimum natural number
  that does not decorate any abbr variable that appears among the input
  variables or among the free variables of the input expressions. *)

  % API private
  op minDistinctAbbrVar : Variables * Expressions -> Variable
  def minDistinctAbbrVar (vS,eS) =
    abbr (minIn (fn(i:Integer) ->  % min of the set of all i:Integer such that
      % i is a natural:
      i >= 0 &&
      % and i does not decorate any variable in vS or free in eS:
      (abbr i) nin? (toSet vS \/ \\// (map exprFreeVars eS))))

  (* LD defines a binding conditional to consist of one or more
  branches. Since here we avoid subtypes in public ops, we allow a binding
  conditional to have no branches. Therefore, we must define what expression
  is abbreviated by a binding conditional with no branches. We arbitrarily
  pick the description operator for booleans, which is probably unlikely to
  occur in an real-world spec. External code that uses the proof checker
  should not use op COND to create a binding conditional with zero
  branches. *)

  op COND : Type * BindingBranches -> Expression
  def COND (t,brS) =
    if empty? brS then
      IOTA BOOL  % arbitrary
    else
      let (vS,tS,b,e) = first brS in
      let x:Variable = minDistinctAbbrVar (vS, single b <| e) in
      let branchResult:Expression = THE (x, t, EXX (vS, tS, b &&& VAR x == e)) in
      if single? brS then branchResult
      else IF (EXX (vS, tS, b), branchResult, COND (t, rtail brS))

  (* Similarly to binding conditionals, LD defines case expressions to contain
  at least one branch. Here, we allow zero branches, because we avoid subtypes
  in public ops. *)

  op CASE : Type * Type * Expression * BindingBranches -> Expression
  def CASE (t,t1,e,brS) =
    % collect all variables bound by branches:
    let allVS:Variables = foldl (++) empty (map (project 1) brS) in
    % collect all patterns in branches:
    let allPS:Expressions = map (project 3) brS in
    % collect all result expressions in branches:
    let allES:Expressions = map (project 4) brS in
    % pick a distinct abbreviation variable x:
    let x = minDistinctAbbrVar (allVS, allPS ++ allES) in
    % auxiliary function that transforms a branch:
    let def transformBranch (br:BindingBranch) : BindingBranch =
      % turn pattern into equality with abbreviation variable x
      % (leave bound variables, types, and result expression unchanged):
      let (vS,tS,p,e) = br in
      (vS, tS, VAR x == p, e) in
    % definition of case expression:
    LETSIMP (x, t, e, COND (t1, map transformBranch brS))

  % non-recursive let:

  op LET : Type * Type * Variables * Types *
           Expression * Expression * Expression -> Expression
  def LET (t,t1,vS,tS,p,e,e1) = CASE (t, t1, e, single (vS, tS, p, e1))

  % recursive let:

  op LETDEF : Type * Variables * Types * Expressions * Expression -> Expression
  def LETDEF (t,vS,tS,eS,e) =
    let tupleVS = TUPLE (tS, map (embed VAR) vS) in
    let tupleES = TUPLE (tS, eS) in
    LET (PRODUCT tS, t,
         vS, tS,
         tupleVS,
         COND (PRODUCT tS, single (vS, tS, tupleVS == tupleES, tupleVS)),
         e)

  (* In LD, a chooser is labeled by a quotient type and a type. Here, we label
  it by the quotiented type, the equivalence relation (which, together with
  the quotiented type, defines the quotient type), and the other type. *)

  op CHOOSE : Type * Expression * Type -> Expression
  def CHOOSE (t,q,t1) =
    let f:Variable = abbr 0 in
    let x:Variable = abbr 1 in
    let y:Variable = abbr 2 in
    let r:Expression =
      FN (f, t --> t1,
          FA2 (x, t, y, t,
               q @ PAIR (t, t, VAR x, VAR y) ==>
               (VAR f) @ (VAR x) == (VAR f) @ (VAR y))) in
    FN (f, (t --> t1) \ r,
        FN (x, t/q, LET (t/q, t1, single y, single t,
                         QUOT (t/q) @ (VAR y), VAR x, (VAR f) @ (VAR y))))

  (* In LD, an embedding test is labeled by a sum type and a
  constructor. Here, we label it by the constructors of the sum type, the
  optional component types of the sum type, and the constructor. Since here,
  unlike LD, we model constructors without types, the definition of an
  embedding test changes slightly for constructors without types, compared to
  LD, because there is no existential quantification.

  The sequence of constructors that is the first argument of EMBED? may have
  repeated constructors. Thus, we consider the minimum position in the
  sequence in which the constructor appears. The constructor may also not
  appear at all in the sequence; in that case, we define the abbreviation as
  if the constructor had no type associated with it. Of course, external code
  that uses the proof checker should always use EMBED? with a sequence of
  distinct constructors that include the third argument constructor. *)

  op EMBED? : Constructors * Type?s * Constructor -> Expression
  def EMBED? (cS,t?S,c) =
    let n:Nat = min (length cS, length t?S) in
      % if length cS ~= length t?S, excess constructors or optional types are
      % ignored (we avoid subtypes in public ops)
    let x:Variable = abbr 0 in
    let y:Variable = abbr 1 in
    if c in? cS then
      % match constructor with corresponding optional type:
      let i:Nat = minIn (fn(i:Integer) -> 0 <= i && i < n && cS@i = c) in
      case t?S @ i of
        | Some t -> FN (x, SUM(cS,t?S),  % as in LD
                        EX (y, t, VAR x == EMBED (SUM(cS,t?S), c) @ (VAR y)))
        | None -> FN (x, SUM(cS,t?S), VAR x == EMBED (SUM(cS,t?S), c))
                  % simplified translation when constructor has no type
    else  % consider as if constructor had no type associated with it:
      FN (x, SUM(cS,t?S), VAR x == EMBED (SUM(cS,t?S), c))

endspec
