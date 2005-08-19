% Translation from MetaSlang abstract syntax to proof checker abstract syntax.

% This file will be moved.

% There are some outstanding issues. First, in AC's abstract syntax, an
% instance of an operator is accompanied by instantiations for any type
% variables for that operator. The code below, does not try to recover what
% those instantiations are.

% A number of functions have been left unspecified. This includes functions
% for converting identifiers (strings) in MetaSlang to identifiers in the
% proof checker abstract syntax. It also includes a monadic function
% for generating fresh variable names.

% Errors in /usr/home/kestrel/lindsay/Work/Specware/Specware4/Provers/ProofChecker/TranslateMSToPC.sw
% 53.27-53.28     : Several matches for overloaded op ++ of type Context * Context -> Context :  FSeq.++ List.++
% 58.92-58.97     : Several matches for overloaded op length of type MetaSlang.TyVars -> Integer :  FSeq.length List.length
% 345.23-345.24   : Several matches for overloaded op ++ of type Variables * Variables -> Variables :  FSeq.++ List.++
% 345.38-345.39   : Several matches for overloaded op ++ of type Types * Types -> Types :  FSeq.++ List.++
% 365.26-365.27   : Several matches for overloaded op ++ of type Variables * Variables -> Variables :  FSeq.++ List.++
% 365.39-365.40   : Several matches for overloaded op ++ of type Types * Types -> Types :  FSeq.++ List.++
% 371.26-371.27   : Several matches for overloaded op ++ of type Variables * Variables -> Variables :  FSeq.++ List.++
% 371.39-371.40   : Several matches for overloaded op ++ of type Types * Types -> Types :  FSeq.++ List.++
% 428.88-428.90   : Several matches for overloaded op map of type Char -> Expression -> List(Char) -> List(Expression) :FSeq.map List.map
% 446.6-446.10    : Several matches for overloaded op foldr of type Expression * Expression -> Expression ->
%    Expression -> List(Expression) -> Expression :  FSeq.foldr List.foldr
% CL-USER(7):

% Problems with spec "Implementation"

% The point is that the implementation *defines* FSeq.++ to be List.++ but then the overloader doesn't know that they are
% the same function.

% If we then do a translate of FSeq.++ to List.++ we also get an error:
% 21.37-21.57     : Error in translation: Illegal to translate op FSeq.++ into pre-existing, non-alias, untranslated List.++

% For some reason, I need "embed" in front of the constructor "prefix" for the
% typechecker to do the right thing.

Translate qualifying spec
  % import BasicAbbreviations
  % import OtherAbbreviations
  import /Languages/MetaSlang/AbstractSyntax/AnnTerm
  import /Languages/MetaSlang/Specs/Environment
  import /Languages/SpecCalculus/Semantics/Environment  % for the Specware monad
  import Implementation

  op +++ infixl 25    : [a]   FSeq a * FSeq a -> FSeq a
  def +++ = List.++

  op fSeqLength : [a] FSeq a -> Nat
  def fSeqLength = List.length

  type Subst = List (Constructor * Operation)

%%   op applyConstructorSubst : Subst -> Expression -> Expression
%%   def applyConstructorSubst subst expr =
%%     case expr of
%%       | EMBED (typ,constr) = 
%%           let
%%             def lookup l =
%%               case l of
%%                 | [] -> expr
%%                 | (constructor,opr)::rest ->
%%                    if constructor = constr then
%%                      OPI (opr,empty)     % !!!???
%%                    else
%%                      lookup rest
%%           in
%%             lookup subst
%%       | _ -> expr
   
  op specToContext : Spec -> SpecCalc.Env MetaslangProofChecker.Context
  def specToContext spc =
    let
      def specElemToContextElems fSeq elem = 
        case elem of
            % We recursively process all the elements in the imports as well. It is here
            % that a single spec element can give rise to many context elements
            % and consequently why we are using foldM, rather than the mapListToFSeq function
            % defined later.
          | Import (specTerm,spc,elements) -> {
              otherCtxt <- specToContext spc;
              return (fSeq +++ otherCtxt)
            }
          | Sort qid -> {
              typeInfo <- findInMap spc.sorts qid;
              case typeInfo.dfn of
                | Pi (tyVars,typ,_) -> return (fSeq <| (typeDeclaration (qidToTypeName qid, fSeqLength tyVars)))
                | typ -> return (fSeq <| (typeDeclaration (qidToTypeName qid, 0)))
            }
          | SortDef qid -> {
%%               typeInfo <- findInMap spc.sorts qid;
%%               if recursiveSumOfProducts? spc qid then
%%                 let
%%                   def summandToOp sums =
%%                     case sums of
%%                       | (name, None) ->
%%                           let newOpName = idToOperation (name ^ "$" ^ (printQualifiedId qid)) in 
%%                           (opDeclaration (newOpName,newTyVars,newType),(idToConstructor name,newOpName))
%%                       | (name, Some (TyVar (tVar,_))) -> 
%%                       | (name, Some (typ as (Product (fields,_)))) -> 
%%                           newOpName <- return (idToOperation (name ^ "$" ^ (printQualifiedId qid))); 
%%                           prodType <- msToPC spc typ;
%%                           typeVarTypes <- mapListToFSeq (fn tyVar -> return (VAR (idToTypeVariable tyVar))
%%                           newType <- return (prodType ---> (TYPE (qidToTypeName qid, typeVarTypes)))
%%                           (opDeclaration (newOpName,newTyVars,newType),(idToConstructor name,newOpName))
%%                 in
%%               else {
              typeInfo <- findInMap spc.sorts qid;
              case typeInfo.dfn of
                | Pi (tyVars,typ,_) -> {
                     newTyVars <- mapListToFSeq (fn tyVar -> return (idToTypeVariable tyVar)) tyVars;
                     newType <- Type.msToPC spc typ;
                     return (fSeq <| (typeDefinition (qidToTypeName qid, newTyVars, newType)))
                  }
                | typ -> {
                     newType <- Type.msToPC spc typ;
                     return (fSeq <| (typeDefinition (qidToTypeName qid, empty, newType)))
                  }
             }
          | Op qid -> {
              opInfo <- findInMap spc.ops qid;
              case opInfo.dfn of
                | Pi (tyVars,SortedTerm (Any _,typ,_),_) -> {
                       newTyVars <- mapListToFSeq (fn tyVar -> return (idToTypeVariable tyVar)) tyVars;
                       newType <- Type.msToPC spc typ;
                       return (fSeq <| (opDeclaration (qidToOperation qid (convertFixity opInfo.fixity), newTyVars, newType)))
                    }
                | Pi (tyVars,SortedTerm (term,typ,_),_) -> {
                       newTyVars <- mapListToFSeq (fn tyVar -> return (idToTypeVariable tyVar)) tyVars;
                       newTerm <- msToPC spc term;
                       return (fSeq <| (opDefinition (qidToOperation qid (convertFixity opInfo.fixity), newTyVars, newTerm)))
                    }
                | SortedTerm (_,Pi (tyVars,typ,pos),_) -> {
                      newTyVars <- mapListToFSeq (fn tyVar -> return (idToTypeVariable tyVar)) tyVars;
                      newType <- Type.msToPC spc typ;
                      return (fSeq <| (opDeclaration (qidToOperation qid (convertFixity opInfo.fixity), newTyVars, newType)))
                    }
                | SortedTerm (_,typ,_) -> {
                      newType <- Type.msToPC spc typ;
                      return (fSeq <| (opDeclaration (qidToOperation qid (convertFixity opInfo.fixity), empty, newType)))
                    }
                | _ -> raise (Fail ("translateMSToPC: specToContext: ill-formed declaration for op " ^ (printQualifiedId qid) ^ " term = " ^ (System.anyToString opInfo.dfn)))
             }
           | OpDef qid -> {
               opInfo <- findInMap spc.ops qid;
               case opInfo.dfn of
                 | Pi (tyVars,SortedTerm (term,typ,_),_) -> {
                       newTyVars <- mapListToFSeq (fn tyVar -> return (idToTypeVariable tyVar)) tyVars;
                       newTerm <- msToPC spc term;
                       return (fSeq <| (opDefinition (qidToOperation qid (convertFixity opInfo.fixity), newTyVars, newTerm)))
                     }
                 | SortedTerm (term,Pi (tyVars,typ,pos),_) -> {
                       newTyVars <- mapListToFSeq (fn tyVar -> return (idToTypeVariable tyVar)) tyVars;
                       newTerm <- msToPC spc term;
                       return (fSeq <| (opDefinition (qidToOperation qid (convertFixity opInfo.fixity), newTyVars, newTerm)))
                     }
                 | SortedTerm (term,typ,_) -> {
                       newTerm <- msToPC spc term;
                       return (fSeq <| (opDefinition (qidToOperation qid (convertFixity opInfo.fixity), empty, newTerm)))
                     }
                 | _ -> raise (Fail ("translateMSToPC: specToContext: ill-formed definition for op " ^ (printQualifiedId qid) ^ " term = " ^ (System.anyToString opInfo.dfn)))
             }
           | Property (Axiom,propName,tyVars,term) -> {
               newTyVars <- mapListToFSeq (fn tyVar -> return (idToTypeVariable tyVar)) tyVars;
               newTerm <- msToPC spc term;
               return (fSeq <| (axioM (propNameToAxiomName propName, newTyVars,newTerm)))
             }
               
           | Property (Theorem,propName,tyVars,term) -> {
               newTyVars <- mapListToFSeq (fn tyVar -> return (idToTypeVariable tyVar)) tyVars;
               newTerm <- msToPC spc term;
               return (fSeq <| (axioM (propNameToAxiomName propName, newTyVars,newTerm)))
             }
               
          % | Comment str ->
    in
      foldM specElemToContextElems empty spc.elements
      
  % Convert a term in MetaSlang abstract syntax to a term in the proof checker's abstract syntax.
  op Term.msToPC : Spec -> MS.Term -> SpecCalc.Env Expression
  def Term.msToPC spc trm =
    case trm of
      | Apply (Fun (And,srt,_),Record ([("1",t1),("2",t2)],_),_) -> {
            t1PC <- msToPC spc t1;
            t2PC <- msToPC spc t2;
            return (t1PC &&& t2PC)
          }
      | Apply (Fun (Or,srt,_),Record ([("1",t1),("2",t2)],_),_) -> {
            t1PC <- msToPC spc t1;
            t2PC <- msToPC spc t2;
            return (t1PC ||| t2PC)
          }
      | Apply (Fun (Implies,srt,_),Record ([("1",t1),("2",t2)],_),_) -> {
            t1PC <- msToPC spc t1;
            t2PC <- msToPC spc t2;
            return (t1PC ==> t2PC)
          }
      | Apply (Fun (Iff,srt,_),Record ([("1",t1),("2",t2)],_),_) -> {
            t1PC <- msToPC spc t1;
            t2PC <- msToPC spc t2;
            return (t1PC <==> t2PC)
          }
      | Apply (Fun (Equals,srt,_),Record ([("1",t1),("2",t2)],_),_) -> {
            t1PC <- msToPC spc t1;
            t2PC <- msToPC spc t2;
            return (t1PC == t2PC)
          }
      | Apply (Fun (NotEquals,srt,_),Record ([("1",t1),("2",t2)],_),_) -> {
            t1PC <- msToPC spc t1;
            t2PC <- msToPC spc t2;
            return (t1PC ~== t2PC)
          }
      % | Apply (Fun (RecordMerge,srt,_),Record ([("1",t1),("2",t2)],_),_) -> {
            % t1PC <- msToPC spc t1;
            % t2PC <- msToPC spc t2;
            % return (t1PC <<< t2PC)
          % }
      | Apply (Fun (Project id,srt,_),term,_) -> {
            termPC <- msToPC spc term;
            typePC <- msToPC spc (inferType (spc,term));
            if natConvertible id then
              return (DOT (termPC, typePC, prod (stringToNat id)))
            else
              return (DOT (termPC, typePC, user (idToUserField id)))
          }
      % | Apply (Quotient,arg,pos) -> return (nullary truE)   % ???
      | Apply(Fun (Embed(id,b),srt,_),arg,_) -> {
            newType <- Type.msToPC spc srt;
            argExpr <- Term.msToPC spc arg;
            return ((EMBED (newType, idToConstructor id)) @ argExpr)
          }
      | Apply (Fun (Not,srt,_),t,_) -> {
            tPC <- msToPC spc t;
            return (~~ tPC)
          }
      | Apply (f,a,pos) -> {
            fPC <- msToPC spc f;
            aPC <- msToPC spc a;
            return (fPC @ aPC)
          }
      | ApplyN (terms,pos) -> raise (Fail "trying to translate MetaSlang ApplyN for proof checker")
      | Record (pairs as (("1",_)::_),pos) -> {
            elems <- mapListToFSeq (fn pair -> msToPC spc pair.2) pairs;
            types <- mapListToFSeq (fn pair -> msToPC spc (inferType (spc,pair.2))) pairs;
            return (TUPLE (types,elems))
          }
      | Record (pairs,pos) -> {
            fields <- mapListToFSeq (fn pair -> return (user (idToUserField pair.1))) pairs;
            types <- mapListToFSeq (fn pair -> msToPC spc (inferType (spc,pair.2))) pairs;
            exprs <- mapListToFSeq (fn pair -> msToPC spc pair.2) pairs;
            return (REC (fields,types,exprs))
          }
      | Bind (Forall,vars,term,pos) -> {
            vs <- mapListToFSeq (fn aVar -> return (idToVariable aVar.1)) vars;
            types <- mapListToFSeq (fn aVar -> msToPC spc aVar.2) vars;
            newTerm <- msToPC spc term;
            return (FAA (vs,types,newTerm))
          }
      | Bind (Exists,vars,term,pos) -> {
            vs <- mapListToFSeq (fn aVar -> return (idToVariable aVar.1)) vars;
            types <- mapListToFSeq (fn aVar -> msToPC spc aVar.2) vars;
            newTerm <- msToPC spc term;
            return (EXX (vs,types,newTerm))
          }
      | Let ((lhs,rhs)::rest,term,pos) -> {
            newRhs <- msToPC spc rhs;
            (vars,types,newGuard) <- Pattern.msToPC spc newRhs lhs;
            newType <- Type.msToPC spc (inferType (spc,term));
            if rest = [] then {
              newTerm <- Term.msToPC spc term;
              return (COND (newType, single (vars,types,newGuard,newTerm)))
            }
            else {
              newTerm <- Term.msToPC spc (Let (rest,term,pos));
              return (COND (newType, single (vars,types,newGuard,newTerm)))
            }
          }
      | Let ([],term,pos) -> Term.msToPC spc term
      | LetRec (bindings,term,pos) -> {
            vs <- mapListToFSeq (fn (var,rhs) -> return (idToVariable var.1)) bindings;
            types <- mapListToFSeq (fn (var,rhs) -> Type.msToPC spc var.2) bindings;
            exprs <- mapListToFSeq (fn (var,rhs) -> Term.msToPC spc rhs) bindings;
            expr <- Term.msToPC spc term;
            typ <- Type.msToPC spc (inferType (spc,term));
            return (LETDEF (typ,vs,types,exprs,expr))
          }
      | IfThenElse (pred,yes,no,pos) -> {
            newPred <- msToPC spc pred;
            newYes <- msToPC spc yes;
            newNo <- msToPC spc no;
            return (IF (newPred,newYes,newNo))
          }
      | Fun (Op(id,fxty),typ,_) -> {
            newType <- Type.msToPC spc typ; 
            return (OPI (qidToOperation id (convertFixity fxty),empty))         % ???
          }
      | Fun (Embed(id,b),srt,_) ->  {
            newType <- Type.msToPC spc srt;
            return ((EMBED (newType, idToConstructor id)) @ MTREC)
          }
      | Lambda ([],pos) ->
          raise (Fail "trying to translate empty MetaSlang match for proof checker")
      | Lambda ((match as ((pat,guard,rhs)::_)),pos) -> {
            var <- newVar;
            branches <- mapListToFSeq (GuardedExpr.msToPC spc (VAR var)) match;
            lhsType <- Type.msToPC spc (patternSort pat);
            rhsType <- Type.msToPC spc (inferType (spc,rhs));
            return (FN (var, lhsType, COND (rhsType,branches)))
          }
      | Seq (term::rest,pos) ->
          if rest = [] then 
            Term.msToPC spc term
          else
            Term.msToPC spc (Let ([(WildPat (inferType (spc,term),pos),term)], Seq (rest,pos),pos))
      | Seq ([],pos) -> 
          raise (Fail "trying to translate empty MetaSlang Seq for proof checker")
      | SortedTerm  (term,typ,pos) -> msToPC spc term
      | Pi (tyVars,term,pos) -> msToPC spc term
      | And (terms,pos) -> 
          raise (Fail "trying to translate MetaSlang join operation on terms for proof checker")
      | Fun (Nat n,srt,pos) -> return (primNat n)
      | Fun (Char c,srt,pos) -> return (primChar c)
      | Fun (String s,srt,pos) -> return (primString s)
      | Fun (Bool true,srt,pos) -> return TRUE
      | Fun (Bool false,srt,pos) -> return FALSE
      | Fun (Quotient,srt,pos) -> {
            newType <- Type.msToPC spc srt;
            return (QUOT newType)
          }
      | Var ((id,srt),pos) -> return (VAR (idToVariable id))
      | _ -> {
          print ("Term.msToPC: no match\n");
          % print (printTerm trm);
          print (System.anyToString trm);
          print ("term = " ^ (printTerm trm) ^ "\n");
          raise (Fail "no match in Term.msToPC")
        }

  op OptType.msToPC : Spec -> Option MS.Sort -> SpecCalc.Env Type
  def OptType.msToPC spc typ? =
    case typ? of
      | None -> return UNIT
      | Some typ -> msToPC spc typ

  % Convert a type in MetaSlang abstract syntax to a type in the proof checker's abstract syntax.
  op Type.msToPC : Spec -> MS.Sort -> SpecCalc.Env Type
  def Type.msToPC spc typ =
    case typ of
      | Arrow (ty1,ty2,_) -> {
           newTy1 <- msToPC spc ty1;
           newTy2 <- msToPC spc ty2;
           return (newTy1 --> newTy2)
          }
      | Product (fields as (("1",_)::_),_) -> {
           types <- mapListToFSeq (fn (id,typ) -> msToPC spc typ) fields;
           return (PRODUCT types)
         }
      | Product (fields,_) -> {
           newFields <- mapListToFSeq (fn (id,typ) -> return (user (idToUserField id))) fields;
           types <- mapListToFSeq (fn (id,typ) -> msToPC spc typ) fields;
           return (RECORD (newFields, types))
         }
      | CoProduct (sums,_) -> {
           constructors <- mapListToFSeq (fn (id,typ?) -> return (idToConstructor id)) sums;
           types <- mapListToFSeq (fn (id,typ?) -> OptType.msToPC spc typ?) sums;
           return (SUM (constructors, types))
         }
      | Quotient (typ,term,_) -> {
           newType <- Type.msToPC spc typ;
           newTerm <- Term.msToPC spc term;
           return (QUOT (newType,newTerm))
          }
      | Subsort (typ,term,_) -> {
           newType <- Type.msToPC spc typ;
           newTerm <- Term.msToPC spc term;
           return (RESTR (newType,newTerm))
          }
      | Base (id,types,_) -> {
           newTypes <- mapListToFSeq (Type.msToPC spc) types;
           return (TYPE (qidToTypeName id, newTypes))
          }
      | Boolean _ -> return BOOL
      | TyVar (id,_) -> return (VAR (idToTypeVariable id))
      | MetaTyVar _ ->
           raise (Fail "trying to translate MetaSlang meta type variable for proof checker")
      | Pi (typeVars,types,_) ->
           raise (Fail "trying to translate MetaSlang type scheme for proof checker")
      | And (types,_) -> 
           raise (Fail "trying to translate MetaSlang join type for proof checker")
      | Any _ ->
           raise (Fail "trying to translate MetaSlang any type for proof checker")
      | _ -> {
          print ("Type.msToPC: no match\n");
          print ("type = " ^ (printSort typ) ^ "\n");
          raise (Fail "no match in Type.msToPC")
        }

  % The second argument is the expression to which we will identify (equate) with all patterns.
  op GuardedExpr.msToPC : Spec -> Expression -> (MS.Pattern * MS.Term * MS.Term) -> SpecCalc.Env BindingBranch
  def GuardedExpr.msToPC spc expr (pattern,guard,term) = {
      (vars,types,lhs) <- Pattern.msToPC spc expr pattern; 
      rhs <- msToPC spc term; 
      return (vars,types,lhs,rhs)
    }

  % As above, the second argument is the expression to which we will identify (equate) with the pattern.
  % In many cases it is just a variable. The function computes a list of variables that
  % are bound by the match, the types of the variables and a boolean valued expression (a guard)
  % that represents the pattern.
  op Pattern.msToPC : Spec -> Expression -> MS.Pattern -> SpecCalc.Env (Variables * Types * Expression)
  def Pattern.msToPC spc expr pattern = 
    case pattern of
      | AliasPat (pat1,pat2,_) -> {
          (vars1,types1,expr1) <- Pattern.msToPC spc expr pat1;
          (vars2,types2,expr2) <- Pattern.msToPC spc expr pat2;
          return (vars1+++vars2, types1+++types2, expr1 &&& expr2)
        }
      | VarPat ((id,typ), b) -> {
          newType <- Type.msToPC spc typ;
          return (single (idToVariable id), single newType, (VAR (idToVariable id)) == expr)
        }
      | EmbedPat (id,None,typ,_) -> {
          newType <- Type.msToPC spc typ;
          return (empty, empty, ((EMBED (newType, idToConstructor id)) @ MTREC) == expr)
        }
      | EmbedPat (id,Some pat,typ,_) -> {
          var <- newVar;
          newType <- Type.msToPC spc typ;
          (vars,types,boolExpr) <- Pattern.msToPC spc (VAR var) pat;
          return (var |> vars,newType |> types, ((EMBED (newType, idToConstructor id)) @ (VAR var)) == expr)
        }
      | RecordPat (fields as (("1",_)::_),_) ->
           foldM (fn (vars,types,newExpr) -> fn (n,pat) -> {
              fieldType <- Type.msToPC spc (patternSort pat);
              (fVars,fType,fExpr) <- Pattern.msToPC spc (DOT (expr, fieldType, prod (stringToNat n))) pat;
              return (vars+++fVars,types+++fType,newExpr &&& fExpr)
            }) (empty,empty,TRUE) fields
      | RecordPat (fields,_) -> 
           foldM (fn (vars,types,newExpr) -> fn (id,pat) -> {
              fieldType <- Type.msToPC spc (patternSort pat);
              (fVars,fType,fExpr) <- Pattern.msToPC spc (DOT (expr, fieldType, user (idToUserField id))) pat;
              return (vars+++fVars,types+++fType,newExpr &&& fExpr)
            }) (empty,empty,TRUE) fields
      | StringPat (string, b) -> return (empty,empty,(primString string) == expr)
      | BoolPat (bool, b) -> return (empty,empty,expr)
      | CharPat (char, b) -> return (empty,empty,(primChar char) == expr)
      | NatPat (nat, b) -> return (empty,empty,(primNat nat) == expr)
      | WildPat (srt, _) -> return (empty,empty,TRUE)

  op idToUserField : String -> UserField
  def idToUserField s = s

  op idToVariable : String -> Variable
  def idToVariable s = user s

  op idToConstructor : String -> Constructor
  def idToConstructor s = s

  op idToTypeVariable : String -> TypeVariable
  def idToTypeVariable s = s

  op propNameToAxiomName : PropertyName -> AxiomName
  def propNameToAxiomName qid = printQualifiedId qid

  op qidToTypeName : QualifiedId -> TypeName
  def qidToTypeName qid = printQualifiedId qid

  op qidToOperation : QualifiedId -> MetaslangProofChecker.Fixity -> Operation
  def qidToOperation qid fxty = (printQualifiedId qid,fxty)

  op newVar : SpecCalc.Env Variable
  def newVar = {
    n <- freshNat;   % in the Specware monad
    return (abbr n)
  }

  op mapListToFSeq : fa(a,b) (a -> b) -> List a -> FSeq b
  def mapListToFSeq f list = foldl (fn (x,fSeq) -> (f x) |> fSeq) empty list

  % op MonadFSeq.map : fa(a,b) (a -> SpecCalc.Env b) -> FSeq a -> SpecCalc.Env (FSeq b)

  op MSToPCTranslateMonad.mapListToFSeq : fa(a,b) (a -> SpecCalc.Env b) -> List a -> SpecCalc.Env (FSeq b)
  def MSToPCTranslateMonad.mapListToFSeq f list =
    case list of
      | [] -> return empty
      | x::xs -> {
          xNew <- f x;
          xsNew <- mapListToFSeq f xs;
          return (xNew |> xsNew)
        }

  op MSToPCTranslateMonad.mapQualifierMapToFSeq : fa(a,b) (Qualifier * Id * a -> SpecCalc.Env b) -> AQualifierMap a -> SpecCalc.Env (FSeq b)
  def MSToPCTranslateMonad.mapQualifierMapToFSeq f qMap =
    let
      def newF (qual,id,a,rest) = {
        xNew <- f (qual,id,a); 
        return (xNew |> rest)
      }
    in
      foldOverQualifierMap newF empty qMap

  op primNat : Nat -> Expression
  def primNat n =
    if n = 0 then
      OPI (qidToOperation (Qualified ("Nat","zero")) (embed prefix),empty)
    else
      (OPI (qidToOperation (Qualified ("Nat","succ")) (embed prefix),empty)) @ (primNat (n - 1))

  % Construct an expression in the proof checker's abstract syntax that encodes the given string.
  op primString : String -> Expression
  def primString str =
    (OPI (qidToOperation (Qualified ("String","implode")) (embed prefix),empty)) @ (primList charType (List.map primChar (explode str)))

  op charType : Type
  def charType = TYPE (qidToTypeName (Qualified ("Char","Char")),empty)

  % Construct a expression in the proof checker's abstract syntax that encodes the given char.
  op primChar : Char -> Expression
  def primChar c = (OPI (qidToOperation (Qualified ("Char","chr")) (embed prefix),empty)) @ (primNat (ord c))

  % Construct a expression in the proof checker's abstract syntax that encodes the given
  % list of elements of the given type.
  op primList : Type -> List Expression -> Expression
  def primList typ l =
    let nil = (EMBED (listType typ, idToConstructor "Nil")) @ MTREC in
    let def cons (a, l) =
      let p = PAIR (typ, listType typ, a, l) in
      (EMBED (listType typ, idToConstructor "Cons")) @ p
    in
      List.foldr cons nil l

  op listType : Type -> Type
  def listType typ = TYPE (qidToTypeName (Qualified ("List","List")), single typ)

  op findInMap : [a] AQualifierMap a -> QualifiedId -> SpecCalc.Env a
  def findInMap map (qid as (Qualified (qualifier,id))) =
    case findAQualifierMap (map,qualifier,id) of
      | None -> raise (Fail ("translateMSToPC: failed to find qualified id: " ^ (printQualifiedId qid)))
      | Some x -> return x

  % Simple test to see if a type is a recursive sum of products.  The test returns
  % true if the type is a coproduct and if each summand is a recursive reference
  % to the same type, or a product were each field is either a type variable
  % or a recursive reference to the same type. This will, for example, handle, 
  % polymorphic lists but not monomorphic lists as there can be only recursive references
  % to the same type.
  %
  % A more comprehensive scheme would need handle mutually recursive type definitions
  % presumably using some some of toplogical sort.
 
  op recursiveSumOfProducts? : Spec -> QualifiedId -> SpecCalc.Env Boolean
  def recursiveSumOfProducts? spc qid = {
    typeInfo <- findInMap spc.sorts qid;
    case typeInfo.dfn of
      | CoProduct (pairs,_) -> 
          let
            def checkSums sums =
              case sums of
                | [] -> true
                | (name, None)::rest -> checkSums rest
                | (name, Some (TyVar (tVar,_)))::rest -> checkSums rest
                | (name, Some (Base (otherQid,typs,_)))::rest ->
                    if (qid = otherQid) then
                      checkSums rest
                    else
                      false
                | (name, Some (Product (fields,_)))::rest -> 
                    if checkFields fields then
                      checkSums rest
                    else
                      false
            def checkFields fields =
              case fields of
                | [] -> true
                | (name, TyVar (tVar,_))::rest -> checkFields rest
                | (name, Base (otherQid,typs,_))::rest ->
                    if (qid = otherQid) then
                      checkFields rest
                    else
                      false
          in
            return (checkSums pairs)
      | _ -> return false
    }

  op convertFixity : MetaSlang.Fixity ->  MetaslangProofChecker.Fixity
  def convertFixity fxty =
    case fxty of
      | Nonfix -> embed prefix
      | Infix _ -> infix
      | Unspecified -> embed prefix

    % computeUpperMatrix pairs =
      % case pairs of
        % | [] -> []
        % | sumTerm::rest -> (map (fn x -> (sumTerm,x)) rest) +++ (computeUpperMatrix rest)
            %  
    % (a::l)  zip a with l and then do the same to l
endspec
