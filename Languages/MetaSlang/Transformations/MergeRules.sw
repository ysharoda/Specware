%% This spec exports a transformation 'mergeRules' 
%%
%% S0 = S1 { at f { mergeRules [f1,f2]}}
%%
%% that combines a collection of functions (here 'f1', 'f2' identified
%% as parameters to the transformation) into a single function
%% 'f'. The input functions must have the form.
%% 
%%  f1 : (s : StateType |  Pre[s] ) -> (s' : StateType | Post[s,s'])
%%  f2 : (s : StateType |  Pre[s] ) -> (s' : StateType | Post[s,s'])
%%
%% Where 'StateType' can vary between transformation invocations, but
%% must be uniform. The state variables 's' and 's'' can vary between
%% functions 'f1' and 'f2', but will be renamed uniformly in the
%% resulting function 'f'. 'Pre' is a precondition of type 'StateType
%% -> Boolean' which 's' can appear free in, and 'Post' is a
%% postcondition of type 'StateType -> StateType -> Boolean' in which
%% 's' and 's'' can both appear free.

%% TODO: Describe the rule combination algorithm and correctness
%% criteria as documented in Doug's 'rule-composition.sw' note in the
%% HACMS 'Docs' subdirectory.

%% Issues:
%%
%% - Naming is incredibly brittle. Need to come up with a sane
%%   solution. E.g. if two rules share pre/post condition constraints,
%%   but existentially quantified names are different, then the
%%   algorithm will not work correctly.
%%
%% - We need to normalize pre- and post- state names, instead of
%%   relying on them being the same. This should be easy to implement.
%% 
%% - When generating case-splits, the algorithm doesn't handle
%%   renaming of pattern variables (e.g. if one clause has the
%%   predicate 't = Some x' and a second clause has the predicate 't =
%%   Some y', then we should choose a fresh name 'z' to use as the
%%   pattern variable, and rename x to z in the first clause and y to
%%   z in the second clause.
%%
%% - When generating case-splits, the algorithm only looks at the
%%   top-level constructor; it doesn't consider the sub-pattern. This
%%   should be easy to fix (modulo renaming issues) in the
%%   'samePattern?' function below.
%%
%% - When generating case-splits, the algorithm does not attempt to
%%   ensure exhaustiveness. This should be relatively easy to
%%   accomplish, but would be better to split out into a separate
%%   function so that it can be used by the typechecker as well.
%%
%% - The introduction of definitions does not check that the defined
%%   term occurs in each clause. This is a bug. The 'pick' function,
%%   which choses the next BT action, should be improved for
%%   efficiency and to ensure that it is faithful to the pseudocode
%%   definitions.
%% 
%% - The transform doesn't actually even construct a new spec
%%   currently; it merely prints out the combined postcondition and
%%   inferred precondition.
spec

import Script

%% This transformation takes a list of "rules", defined as specware ops, and
%% combines them into a single op.
%% Arguments:
%%  spc: The specification to transform
%%  qids: The names of the ops defining the ruleset to transform.
%% Returns:
%%  An op with the pre (resp. post) conditions of the named input rules merged
%%  into a single pre (resp. post) condition. 
op SpecTransform.mergeRules(spc:Spec)(args:QualifiedIds):Env Spec = 
  let _ = writeLine "MergeRules!" in
  let (fname::qids) = args in
  let _ = List.map (fn o -> writeLine ("Input Rule: "^(show o))) qids in
  { ruleSpecs as (rs1::_) <- mapM (fn o -> getOpPreAndPost(spc,o)) qids
  ; ps <- combineRuleSpecs spc ruleSpecs
  ; let (vars,is) = unzip ps in
    let vars' = nubBy (fn (i,j) -> i.1 = j.1 && i.2 = j.2) (flatten vars : ExVars) in 
    let _ = writeLine ("Starting with " ^ printDNF (flatten is)) in
    let (rterm,pred) = bt [] (map (fn i -> i.1) vars') (flatten is) in
    let _ = writeLine ("Result is " ^ printTerm rterm) in
    let calculatedPostcondition = Bind (Exists,vars',rterm,noPos)  in
    %% Use this representation, rather than DNF, since it's easier to read.
    let preAsConj = ands (map (fn conj -> mkNot (Bind (Exists,vars',ands conj,noPos))) pred) in
    % let calculatedPreconditions = Bind (Exists,vars',dnfToTerm (negateDNF pred),noPos)  in
    let calculatedPreconditions = Bind (Exists,vars',preAsConj,noPos)  in
    let _ = writeLine ("Preconditions are:\n " ^ printTerm preAsConj) in

    % Construct the new term
    let stateType = rs1.1 in
    let preStateVar = rs1.2 in
    let postStateVar = rs1.4 in
    let stPre = Subtype (stateType, Lambda ([(VarPat ((preStateVar, stateType), noPos), mkTrue (),preAsConj)],noPos), noPos) in
    let stPost = Subtype (stateType, Lambda ([(VarPat ((postStateVar, stateType), noPos), mkTrue (),calculatedPostcondition)],noPos), noPos) in
    let stType = Arrow (stPre,stPost,noPos) in
    let stBody = Any noPos in
    let body = TypedTerm (stBody, stType, noPos) in
    let spc' = addOpDef(spc,fname,Nonfix,body) in
    return spc'
  }
  



%% Get the pre and post condition for an op, extracted from its 
%% The type of the op must be a function with a single argument (with a
%% optional subtype constraint) maping to first-order result (with an
%% optional subtype constraint).
%% Arguments:
%%%  spc: The spec that contains the op.
%%   qid: The op to extract.
%% Returns:
%%   A 4-tuple of (stateType, input argument name, precondition, output name, postcondition)
op getOpPreAndPost(spc:Spec, qid:QualifiedId):Env (MSType*Id*Option MSTerm*Id*Option MSTerm) = 
   let _ = writeLine ("Looking up op " ^ (show qid)) in
   case getOpDef(spc,qid) of
     | None -> raise (Fail ("Could not get term pre and post conditions for op " ^ (show qid)))
       % The type should be of the form {x:StateType | Preconditions} -> {y:StateType | Postcondition}
     | Some (tm, ty as (Arrow (dom, codom,_))) ->
       let _ = writeLine ("Arrow type is " ^ printType ty) in
       let _ = writeLine ("Domain is " ^ (printType dom)) in
       let _ = writeLine ("Codomain is " ^ (printType codom)) in
       { (preStateVar,preStateType,preCondition) <- getSubtypeComponents spc dom
       ; (postStateVar,postStateType,postCondition) <- getSubtypeComponents spc codom
         % Require the pre- and poststate types  match.
         % FIXME: Need equality modulo annotations
         % guard (preStateType = postStateType) (
         %   "In the definition of the coalgebraic function: " ^ (show qid) ^ "\n" ^
         %   "Type of prestate:                 " ^ printType preStateType ^ "\n" ^
         %   "Does not match type of poststate: " ^ printType postStateType)
       ; return (preStateType, preStateVar,preCondition,postStateVar,postCondition)
       }
     | Some (tm,ty) -> 
         let m1 = ("getOpPreAndPost:\n Type is " ^ (printType ty)) in 
         let m2 = ("Which is not of the correct form.") in
         raise (Fail (m1 ^ m2))

%% Get the predicate constraining a subtype. 
%% return the bound variable, and its classifier.
%% If there is no predicate (it is not a subtype), 
%% then return None. If there is a subtype,then return the
%% subtype expression. The subtype expression assumes
%% that the bound variable is in scope in the expression.
%% In the case that the type is *not* a subtype, then
%% the bound variable is "_".
%% Arguments:
%%  spc: The spec that the subtype expression appears in.
%%  ty:  The type 
%% Returns:
%%  3-tuple (Bound variable, classifier, Option (subtype expression) )

op getSubtypeComponents(spc:Spec)(ty:MSType):Env (Id * MSType * Option MSTerm) =
  case ty of
   | Subtype (binding,pred,_) ->
      { (n,ty,body) <- getLambdaComponents spc pred
      ; return (n,ty,Some body)
      }
   | Base (_,_,_) -> return ("_",ty,None) 
   | _ ->  
     let _ = (writeLine ("getSubtypeComponents" ^ anyToString ty))
     in raise (Fail ("Can't extract subtype from " ^ printType ty))


%% From `fn (x:T | guard)  -> body` extract (x,T,body).
%% Constraints: function is unary, binding a variable (only)guard is true.
%% _Surely_ this is defined somewhere???
op getLambdaComponents(spc:Spec)(tm:MSTerm):Env (Id * MSType * MSTerm) =
  % let _ = writeLine ("Looking at subtype predicate " ^ printTerm tm) in
  case tm of                                         
   | Lambda ([(VarPat ((n,ty),_),guard,body)], _) -> %% WTF does VarPat take a tuple with a position???
      % let _ = writeLine ("Bound Var: " ^ anyToString n) in
      % let _ = writeLine ("Classifier: " ^ printType ty ) in
      % let _ = writeLine ("Guard: " ^ printTerm guard) in
      % let _ = writeLine ("Body: " ^ printTerm body) in
      return (n,ty,body)
   | _ -> raise (Fail "getLambdaComponents: Not a unary lambda.")
    
%% combineRuleSpecs normalizes pre/post condition naming, and generates
%% a "DNF" representation of the pre- and post-conditions as a list of lists
%% of MSTerms, where each outer term corresponds to a disjunct, and each
%% inner term corresponds to a conjunction, where each element is an
%% atomic formula. Moreover, we normalize the names of the pre- and poststate 
%% variables.
%% FIXME: Currently, there's no variable renaming going on...
op combineRuleSpecs(spc:Spec)(rules:List (MSType*Id*Option MSTerm*Id*Option MSTerm)):Env (List (ExVars * DNFRep)) =
  let types = map (fn r -> r.1) rules  in
  let preconditions = map (fn r -> case r.3 of Some t -> t | None -> (mkTrue ())) rules in
  let postconditions = map (fn r -> case r.5 of Some t -> t | None -> (mkTrue ())) rules in
  { pres <- mapM (normalizeCondition spc) preconditions 
  ; posts <- mapM (normalizeCondition spc) postconditions
  ; let rels = zipWith (fn x -> fn y -> (nubBy equalVar?  (x.1 ++ y.1), andDNF x.2 y.2)) pres posts in 
    let _ = (writeLine (anyToString (List.length (List.flatten (List.map (fn i -> i.2) posts))) ^ " total postconditions.")) in
    % let _ = map printIt ps in 
    return rels
  }
 
type ExVars = List (AVar Position)
type DNFRep = (List (List MSTerm))
%% Remove existential quantifers, flatten to DNF.
op normalizeCondition(spc:Spec)(tm:MSTerm):Env(ExVars *  DNFRep) = 
  % let _ = writeLine ("Normalizing " ^ printTerm tm) in
  case tm of
    | Bind (Exists,vars,body,_) -> 
      { dnf <- splitConjuncts spc body   
      ; return (vars,dnf)
      }
    | _ -> 
      { dnf <- splitConjuncts spc tm
      ; return ([],dnf)
      }

%% Convert a term into DNF, represented as a list of lists.
op splitConjuncts(spc:Spec)(tm:MSTerm):Env DNFRep =
  case tm of
   | (Apply (Fun (f as And,_,_), Record (args,_),_)) -> 
       let Some a1 = getField (args,"1") in
       let Some a2 = getField (args,"2") in
       { r1 <- splitConjuncts spc a1
       ; r2 <- splitConjuncts spc a2
       ; return (flatten (map  (fn l -> map (fn r -> l ++ r) r2) r1))
       }
   | (Apply (Fun (f as Or,_,_), Record (args,_),_)) -> 
       let Some a1 = getField (args,"1") in
       let Some a2 = getField (args,"2") in
       { r1 <- splitConjuncts spc a1
       ; r2 <- splitConjuncts spc a2
       ; return (r1 ++ r2)
       }
   | IfThenElse (p,t,e,_) -> 
     { rp <- splitConjuncts spc p;
       rt <- splitConjuncts spc t;
       re <- splitConjuncts spc e;
       let ut = andDNF rp rt in
       % FIXME: This is not properly negating the guard for the
       % else branch.
       let ue = andDNF (negateDNF rp) re in
       return (ut ++ ue)
      }
   | _ | unfoldable? (tm,spc) ->
         % let _ = writeLine ("Simplifying " ^ printTerm tm) in
         splitConjuncts spc (simplifyOne spc (unfoldTerm (tm,spc)))
   | _ -> % let _ = writeLine ("Can't simplify " ^ printTerm tm) in 
          return [[tm]]



% The 'Choice' type represents the choice of the next conjunct to
% split on in a DNF representation of postconditions.
type BTChoice = | BTSplit MSTerm % if-split on the given term.
                | BTCase (MSTerm * MSType) % Case split on the given term.
                | BTConstraint (List MSTerm) % poststate constraint, for all disjuncts
                | BTSingleton (List MSTerm) % There is only one disjunct left.
                | BTDef (MSTerm *  MSType * Id) % Definition, for all disjuncts.
                | BTTrue DNFRep
                | BTFalse 
                | BTNone % No idea what to do...

op pick(vars:List Id)(i:DNFRep):BTChoice = 
  case valuation i of
    | Some true -> BTTrue (filter (fn c -> ~ (empty? c)) i)
    | Some false -> BTFalse
    | _ -> let cs = commons i in
           let pcs = filter postConstraint? cs in  % Common post constraints.
           let pps = filter (fn i -> ~ (postConstraint? i)) cs in
           % If there is a post-condition constraint shared across all branches.
           if ~ (empty? pcs) 
             then BTConstraint pcs
           else 
           case findLeftmost (forall? postConstraint?) i of
               %% We have found a clause where all of
               %% the atomic formulae are
               %% post-constraints. This means we can stop.
             | Some ps -> BTSingleton ps

             | None ->  case i of
                          | [(x::xs)] -> BTSingleton (x::xs)
                          | ((x::xs)::rest) | postConstraint? x -> 
                            % Move the post-constraint to the end,
                            % repeat. This can only in the case
                            % where all of the formula in the
                            % conjunction are postConstraints, in
                            % which case the conjunction will have
                            % been identified above.
                            let _ = writeLine "Skipping postconstraint" 
                            in pick vars ((xs ++ [x])::rest)
                          | ((x::xs)::rest) | some? (isDefinition? vars x) ->
                            let Some (v,ty) = isDefinition? vars x in
                            BTDef (x, ty, v)

                          | ((x::xs)::rest) | ~ (postConstraint? x) -> 
                            % 'x' is not a post-constraint, so split on it.
                            (case scrutineeRefinement? x of
                              | Some (s, (ty,c,pat)) -> 
                                     BTCase (s, ty) 
                              | None -> BTSplit x)

                          | [] -> BTNone % Dead case.
                          | ([]::rest) -> pick vars rest % Dead case



%% Simplify all of the conjuncts in a DNF, given the assumption
%% condition 'p' is true.
op simplify(p:MSTerm)(i:DNFRep):DNFRep =
   let def conflicts(cn) = 
          case cn of 
            | [] -> false 
            | (q::qs) ->  (equalTerm? (negateTerm p, q)) || conflicts qs in
   
   % remove any atomic predicates matching p.
   let rempos = map (fn cn -> filter (fn t ->  ~ (equalTerm? (t, p))) cn) i in
   let remneg = filter (fn cn -> ~ (conflicts cn)) rempos in
   % let _ = writeLine ("Under " ^ printTerm p) in
   % let _ = writeLine ("simplify " ^ printDNF i) in
   % let _ = writeLine ("yields " ^ printDNF remneg) in
   remneg



op simplifyCase(i:DNFRep)(s:MSTerm)(ty:MSType)((c,pat):(Id * Option MSPattern)):DNFRep =
   % let _ = writeLine ("Under pattern " ^ printPattern (EmbedPat (c,pat,ty,noPos))) in
   % let _ = writeLine (printDNF i) in 
   let def conflicts?(cn) =
            case cn of 
              | [] -> false
              | (q::qs) -> 
                  case scrutineeRefinement? q of
                    | Some (s',(ty,c',pat)) -> 
                        equalTerm? (s,s') &&  ~ (c = c')  || conflicts? qs
                    | None -> conflicts? qs 

   in 
   let def samePattern? t = 
             case scrutineeRefinement? t of
               | Some (s',(ty,c',pat)) -> 
                   equalTerm? (s,s') &&  (c = c') 
               | None -> false

   in 
   let rempos = map (fn cn -> filter (fn c -> ~ (samePattern? c)) cn) i in
   let remneg = filter (fn cn -> ~ (conflicts? cn)) rempos in
   % let _ = writeLine ("New conditions " ^ printDNF remneg) in
   remneg


%% Simplify a DNF representation with respect to an equation t, of the
%% form 'e1 = e2'. For each disjunct, it will remove all conjuncts of
%% the form 'e1 = e2' or 'e2 = e1'.
op simplifyDef(t:MSTerm)(i:DNFRep):DNFRep = 
  let def sameDef? t' = 
          case (t,t') of
           | (Apply (Fun (Equals,_,_), 
                    Record ([(_,l1), (_,r1)], _), _),
              Apply (Fun (Equals,_,_), 
                    Record ([(_,l2), (_,r2)], _), _)) ->
                (equalTerm? (l1,l2) && equalTerm? (r1,r2)) || 
                (equalTerm? (l1,r2) && equalTerm? (r1,l2))
           | _ -> false
   in map (fn cs -> filter (fn c -> ~ (sameDef? c)) cs) i


%%% Simplify a DNF representation with respect to a list of
%%% post-constraints. Remove all atomic formula that occur in
%% the list of postconstraints.
op simplifyPostConstraints(i:DNFRep)(cs:List MSTerm):DNFRep =
   map (fn d -> filter (fn c -> ~ (inTerm? c cs)) d) i

 
%% Give a valuation for the DNF. 'Some false' if dnf is empty, 'Some
%% true' if nonempty and every clause is empty, 'None' otherwise.
%% FIXME: Change forall? be exists? ???
op valuation(i:DNFRep):Option Boolean =
  case i of 
    | [] -> Some false
    | ps -> if forall? empty? i then Some true else None
   

%% The 'BuildTree' operation.  Given a collection of conditions in
%% disjunctive normal form, (as a DNFRep) return an expression that is
%% a splitting tree, along with a predicate representing a precondition.
%%
%% The returned predicate is the **negation** of the precondition that the 
%% function must have.
op bt(assumptions:List MSTerm)(vars:List Id)(inputs:DNFRep):(MSTerm * DNFRep) =
  % let _ = writeLine "Under assumptions:" in
  % let _ = writeLine (printDNF [assumptions]) in
  % let _ = writeLine "With  inputs" in
  % let _ = writeLine (printDNF inputs) in
    case pick vars inputs of
      | BTFalse -> (mkFalse (), [assumptions])
      | BTTrue _ -> (mkTrue (), []) 
      | BTSplit p -> 
          let pos = simplify p inputs in
          let neg = simplify (negateTerm p) inputs in
          let (tb,tp) = bt (p::assumptions) vars pos in
          let (eb,ep) = bt (negateTerm p::assumptions) vars neg in
          (IfThenElse (p, tb, eb, noPos), tp ++ ep)

      | BTCase (s, ty) -> 
          let pats = gatherPatterns s ty inputs in 
          let def mkAlt (p as (con,pvars)) = 
               let pat = EmbedPat (con,pvars,ty,noPos) in
               let Some patTerm = patternToTerm pat in
               let eq = mkEquality (ty, s, patTerm) in
               let (t,pre) = bt (eq::assumptions)
                                (removePatternVars vars pvars) 
                                (simplifyCase inputs s ty p) 
               in ((pat,t),pre) 
          in let (tms,pres) = unzip (map mkAlt pats) in
                 (mkCaseExpr(s,tms), flatten pres)
                 
      | BTSingleton t -> (mkAnd t, [assumptions]) 
      | BTTrue inputs' -> (mkTrue (), [assumptions]) 
      | BTConstraint cs -> 
          let inputs' = map (fn d -> filter (fn c -> ~ (inTerm? c cs)) d) inputs in
          let (tm',pre) = bt assumptions vars inputs' in
          (mkAnd (cs ++ [tm']), pre)
      | BTDef (t,ty,var) -> 
          let (t',p) = bt (t::assumptions) (diff (vars, [var])) (simplifyDef t inputs)
          in (Bind (Exists, [(var,ty)], mkAnd [t,t'],noPos), p)


%%%%%%%%%%%%%%%%%%%%%%
%%% Postconstraints
%%%%%%%%%%%%%%%%%%%%%%

op postConstraint? (t:MSTerm):Boolean =
  postConstraints? 
  ["arch", "provs", "ifds", "rttab", 
   "ts", "files", "listen", "bound", "bndlm", "ticks",
   "fds", "params", "socks", "oq","privs", "iq"] "h'" t



%% postConstraints? obs p t will return true in the cases where
%%   t has the form 
%%     1. postState = e
%%     2. e = postState
%%     3. o postState = e
%%     4. e = o postState
%%   where o in? obs % 
op postConstraints?(obs:List Id)(postState:Id)(t:MSTerm):Boolean =
  let def isObs (tm:MSTerm):Boolean = 
         case tm of 
           % The term is the poststate
          | Var ((v,_),_) -> v = postState
           % The term is an observation on the poststate
          | Apply (Fun (Op (Qualified (_,o),opFix),ftype,fPos),
                   (Var ((v,_),varPos)),
                   appPos) -> v = postState && o in? obs
          | _ -> false
  in 
  % let _ = writeLine ("Checking postConstraint on " ^ (printTerm t)) in
  case t of
    | Apply (Fun (Equals,_,eqPos), 
             Record ([(_,l), (_,r)], argPos), appPos) -> isObs l || isObs r
    | _ -> false

%% Collect all of the post-state constraints.
%% FIXME: Make this work for all post-state identifiers not just a 
%% fixed "h'"
op gatherPostConstraints(l:DNFRep):List MSTerm = 
   filter postConstraint? (nub (flatten l))


%%% Handling equations involving constructions, for which a case
%%% expression in the resulting postcondition will be generated.

%% If a term has the form 
%%  e = C p1 .. pn  (or the symmetric case C p1 .. pn = e)
%% then it can be implemented terms of a case split:
%% case e of C p1 .. pn -> ... | ...
%%
%% The function returns the scrutinee, paired with a triple of the
%% type, the constructor, and any subpattern. The type will be used to
%% identify the other constructors for the type, to generate the other
%% case alternatives.
op scrutineeRefinement?(t:MSTerm):Option (MSTerm * (MSType * Id * Option MSPattern)) =
  let def checkTerm l r = 
            case termToPattern r of
              | Some (EmbedPat (con,vars,pty,_)) -> Some (l,(pty,con,vars))
              | Some p -> None % let _ = writeLine ( "Non-constructor pattern" ^ printPattern p) in None
              | None -> None
  in
  case t of
    | Apply (Fun (Equals,_,eqPos),  % TODO: Probably want the type here???
             Record ([(_,l), (_,r)], argPos), appPos) -> 
      (case checkTerm l r of
        | Some t -> Some t
        | None -> checkTerm r l)
   | _ -> None

%% Given a DNF representation d, gather up all of the patterns
%% (constructor, pattern) that constrain the scrutinee s at type ty.
op gatherPatterns(s:MSTerm)(ty:MSType)(d:DNFRep):List (Id * Option MSPattern) =
   let def altPattern? (t:MSTerm):Option (Id*Option MSPattern) =
            case scrutineeRefinement? t of
              | Some (s', (ty',c,pat)) |
                 equalTerm? (s, s') (* && equalType? (ty, ty') *) -> Some (c,pat)
              | _ -> None 
   in let def samePattern?(p1,p2) =
                case (p1,p2) of
                  | ((i1,Some pat1),(i2,Some pat2)) ->
                     i1 = i2 && equalPattern? (pat1,pat2)
                  | _ -> false
   in nubBy samePattern? (catOptions (map altPattern? (flatten d)))

%%%%%%%%%%%%%%%%%%%%%%
%%% Definitions
%%%%%%%%%%%%%%%%%%%%%%


%% 'Definitions' are equations 'x = e' between an existentially-quantified
%% variable 'x' and some expression 'e', which is *fully
%% defined*; that is, contains no existentially-quantified variables. 
%% 
%% To handle the notion of definedness, we pass in a list of
%% *undefined* variables 'vars'.
%% 
%% If the term t is such a definition, we return 'Some v', where 'v'
%% is the variable being defined. If it is not a definition, then we
%% return 'None'.
op isDefinition?(vars:List Id)(t:MSTerm):Option (Id * MSType) =
   % let _ = writeLine ("Checking to see if " ^ printTerm t ^ " is a definition.") in
   % let _ = map writeLine vars in 
   let def checkDef l r = l in? vars && 
                    (forall? (fn v -> ~ (v in? vars)) (varNames (freeVars r))) in
   case t of
    | Apply (Fun (Equals,_,eqPos), 
             Record ([(_,Var ((l,ty),_)), (_,r)], argPos), appPos) 
      | checkDef l r -> Some (l,ty)
    | Apply (Fun (Equals,_,eqPos), 
             Record ([(_,l), (_,Var ((r,ty),_))], argPos), appPos) 
      | checkDef r l -> Some (r,ty)
    | _ -> None
   



op removePatternVars (vars:List Id)(pat:Option MSPattern):List Id =
  case pat of
    | None -> vars
    | Some thePat -> 
       case patternToTerm thePat of
         | None -> vars
         | Some t -> diff (vars, (varNames (freeVars t)))


%%%%%%%%%%%%%%%%%%%%%%
%%% Utility functions.
%%%%%%%%%%%%%%%%%%%%%%


% Remove duplicate elements (inefficient, as is most stuff in this module ..)
op nub (l:List MSTerm):List MSTerm = nubBy equalTerm? l

op [a] nubBy (p:a * a -> Boolean)(l:List a):List a =
  case l of 
    | [] -> []
    | (x::xs) | exists? (fn y -> p (x,y)) xs -> nubBy p xs
    | (x::xs) -> x::(nubBy p xs)

%% Take a list of Options, remove all of the 'None's, and strip off
%% the 'Some' constructors.
op [a] catOptions(l:List (Option a)):List a =
  case l of 
    | [] -> []
    | (Some x) :: ls -> x :: catOptions ls
    | _::ls -> catOptions ls

% Find all terms in common. Corresponds to intersection of a
% set of sets.
op commons (l:DNFRep):List MSTerm =
  case l of
    | [] -> []
    | [p] -> p
    | (p::ps) -> filter (fn i -> inTerm? i p) (commons ps)

%% Set membership, over an arbitrary equivalence.
op [a] inBy? (p:(a*a)->Boolean)(e:a)(l:List a):Boolean =
   case l of 
     | [] -> false
     | (x::xs) -> p (e, x) || inBy? p e xs


%%% Set membership, specialized to using the 'equalTerm?' relation.
op inTerm? (c:MSTerm) (l:List MSTerm):Boolean = inBy? equalTerm? c l


op printIt ((vs,xs) : (ExVars * DNFRep)):() =

   let _ = map (fn d -> let _ = writeLine "Conjunction:" in
                        % let _ = writeLine (anyToString vs ) in
                        map (fn c -> writeLine ("\t" ^ printTerm c)) d) xs
   in ()

%% Guard on a condition. Raise an exception with the given message if
%% the input condition is false.
op guard(p:Bool)(msg:String):Env () =
  if p then return () else raise (Fail msg)



%%%%%%%%%%%%%%%
%%% Resolution
%%%%%%%%%%%%%%%

%% Code for converting a CNF representation to DNF.
op cnf2Dnf (i:List (List MSTerm)):DNFRep =
   case i of
     | [] -> [[]]
     | c::cs -> let tl = cnf2Dnf cs 
                in flatten (map (fn l -> map (fn rest -> l::rest) tl) c)


%% Given two lists of atomic formulae, find all formula that
%% occur positively in on list and negatively in the other.
op complements (ps:List MSTerm) (qs:List MSTerm):List MSTerm =
  filter (fn p -> inTerm? (negateTerm p) qs) ps

%% Perform one step multi-resolution between a pair of disjunctions of
%% formulas.
op resolution (ps:List MSTerm) (qs:List MSTerm):Option (List MSTerm) =
    let cs = complements ps qs in
    let cs' = cs ++ map negateTerm cs in
    if empty? cs then None 
    else Some ( filter (fn x -> ~ (inTerm? x cs) ) (ps ++ qs))

%% Resolve one disjunction of formulas, ps,  with each of the disjunctions in qs.
op resolveOne (ps:List MSTerm)(qs:List (List MSTerm)) (changed?:Boolean):List (List  MSTerm) =
  case qs of 
    | [] | changed? -> []
    | [] | ~ changed? -> [ps]
    | (q::qss) ->  
      case resolution ps q of
        | None -> q::(resolveOne ps qss changed?)
        | Some resolvant -> resolvant::(resolveOne ps qss true)

%% Given a ***CNF*** representation of formulas, perform resolution to
%% simplify them.
op resolveAll (ps:List (List MSTerm)):List (List MSTerm) =
  case ps of
    | [] -> ps
    | (p::pss) -> resolveOne p (resolveAll pss) false


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Term construction and manipulation utlities
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Conjunction of DNF forms.
op andDNF (p1:DNFRep) (p2:DNFRep):DNFRep =
  flatten (map (fn l -> map (fn r -> l ++ r) p2) p1)


% Construct an n-ary and. Assume t is nonempty.
op ands(t:List MSTerm):MSTerm =
   case t of
     | [t] -> t
     | (x::xs) -> Apply (mkAndOp noPos , Record ([("1", x), ("2", ands xs)], noPos), noPos)

% Construct an n-ary or. Assume t is nonempty.
op ors(t:List MSTerm):MSTerm =
   case t of
     | [t] -> t
     | (x::xs) -> Apply (mkOrOp noPos , Record ([("1", x), ("2", ors xs)], noPos), noPos)


op mkAnd(t:List MSTerm):MSTerm =
   case t of
     | [] -> mkTrue ()
     | [p] -> p
     | _ -> ands t

op mkOr(t:List MSTerm):MSTerm =
   case t of
     | [] -> mkFalse ()
     | [p] -> p
     | _ -> ors t

op printDNF (x:DNFRep):String = printTerm (dnfToTerm x)

op dnfToTerm(x:DNFRep):MSTerm = mkOr (map mkAnd x)

op negateConjunction(conj:List MSTerm):DNFRep =
    map (fn c -> [negateTerm c]) conj


op [a,b,c] zipWith(f:a -> b -> c)(xs:List a)(ys:List b):List c =
  case (xs,ys) of
    | ([],_) -> []
    | (_,[]) -> []
    | (x::xss,y::yss) -> (f x y) :: (zipWith f xss yss)

%% Code for negating then simplifying DNF.
%% Input: 
%%    r, a DNF formula represented as a list of lists.
%% Returns:
%%   a DNF formula equivalent to the negation of r.
op negateDNF(r:DNFRep):DNFRep = 
  let cnf = map (fn c -> map negateTerm c) r in
  let r' = cnf2Dnf (resolveAll cnf) in
  r'

%%%%%%%%%%%%%%%%%%%%%%
%%% Testing 
%%%%%%%%%%%%%%%%%%%%%%

op x : MSTerm = Var (("x", natType),noPos)
op expr : MSTerm = Var (("expr", natType),noPos)
op obs(o:Id)(s:Id):MSTerm =
   mkApplication 
     (mkOp (mkQualifiedId ("Source",o), mkArrow (natType, natType)), 
     [Var (("x", natType),noPos)])

% x = expr --> true
op test1 : MSTerm = 
   mkApplication (mkEquals natType, [x,expr])
% expr = x --> true
op test2 : MSTerm = 
   mkApplication (mkEquals natType, [expr,x])
% expr = expr --> false
op test3 : MSTerm = 
   mkApplication (mkEquals natType, [expr,expr])
% f x = expr --> true
op test4 : MSTerm =
  mkApplication (mkEquals natType, [obs "f" "x",expr])

endspec
