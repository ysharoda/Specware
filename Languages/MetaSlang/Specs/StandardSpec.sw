StandardSpec qualifying spec
 import AnnSpec
 import /Library/Legacy/DataStructures/NatMapSplay  % for metaTyVars - should be abstracted
 import /Library/Legacy/DataStructures/StringMapSplay % for makeTyVarMap

 type SortMap      = ASortMap        StandardAnnotation
 type OpMap        = AOpMap          StandardAnnotation

 type SortInfo     = ASortInfo       StandardAnnotation 
 type OpInfo       = AOpInfo         StandardAnnotation

% type Property     = AProperty       StandardAnnotation

 type Specs        = ASpecs          StandardAnnotation
 % type Sorts        = ASorts          StandardAnnotation
 % type Ops          = AOps            StandardAnnotation

 op addTypeDef(spc: Spec, qid as Qualified(q,id): QualifiedId, dfn: Sort): Spec =
   spc << {sorts = insertAQualifierMap(spc.sorts, q, id, {names = [qid], dfn = dfn}),
           elements = spc.elements ++ [SortDef(qid,noPos)]}

 op addOpDef(spc: Spec, qid as Qualified(q,id): QualifiedId, fixity: Fixity, dfn: MS.Term): Spec =
   spc << {ops = insertAQualifierMap(spc.ops, q, id, 
                                     {names = [qid], dfn = dfn, fixity = fixity, fullyQualified? = false}),
           elements = spc.elements ++ [Op(qid,true,noPos)]}

 type MetaSortScheme = AMetaSortScheme StandardAnnotation

 op emptySortMap  : SortMap    
 op emptyOpMap    : OpMap      
 op emptyElements : SpecElements 

 def emptySortMap  = emptyASortMap
 def emptyOpMap    = emptyASortMap
 def emptyElements = emptyAElements

 sort MetaTyVarsContext = {map     : Ref (NatMap.Map String),
                           counter : Ref Nat}
  
 def initializeMetaTyVars() : MetaTyVarsContext =
   { map = (Ref NatMap.empty), counter = (Ref 0)}

 def findTyVar (context : MetaTyVarsContext, uniqueId) : TyVar =
    let mp = ! context.map in
    case NatMap.find(mp,uniqueId) of
       | Some name -> name
       | None -> 
         let number    = ! context.counter in
         let increment = number div 5 in
         let parity    = number mod 5 in
         let prefix = 
             (case parity
                of 0 -> "a" | 1 -> "b" | 2 -> "c" | 3 -> "d" | 4 -> "e")
         in  
         let suffix = if increment = 0 then "" else Nat.toString increment in
         let name = prefix ^ suffix in name 
 def mapImage (m, vars) = 
     List.map (fn d -> case StringMap.find (m, d) of Some v -> v) vars


 % The following are used in the semantic rules in the parser.

 op abstractSort : (String -> TyVar) * List String * MS.Sort -> TyVars * MS.Sort
 def abstractSort (fresh, tyVars, srt) = 
  if null tyVars then ([], srt) else
  let (m, doSort) = makeTyVarMap (fresh, tyVars) in
  let srt = mapSort (fn M -> M, doSort, fn p -> p) srt in
  (mapImage (m, tyVars), srt)

 op newAbstractSort : (String -> TyVar) * List String * MS.Sort -> MS.Sort
 def newAbstractSort (fresh, tyVars, srt) = 
  if null tyVars then 
    srt
  else
    let (m, doSort) = makeTyVarMap (fresh, tyVars) in
    let srt = mapSort (fn M -> M, doSort, fn p -> p) srt in
    let tvs = mapImage (m, tyVars) in
    maybePiSort (tvs, srt)

 op abstractTerm : (String -> TyVar) * List String * MS.Term -> TyVars * MS.Term
 def abstractTerm (fresh, tyVars, trm) = 
  let (m, doSort) = makeTyVarMap (fresh, tyVars) in
  let trm = mapTerm (fn M -> M, doSort, fn p -> p) trm in
  (mapImage (m, tyVars), trm)

 op newAbstractTerm : (String -> TyVar) * List String * MS.Term -> MS.Term
 def newAbstractTerm (fresh, tyVars, trm) = 
  let (m, doSort) = makeTyVarMap (fresh, tyVars) in
  let trm = mapTerm (fn M -> M, doSort, fn p -> p) trm in
  let tvs = mapImage (m, tyVars) in
  maybePiTerm (tvs, trm)

 %%
 %% It is important that the order of the type variables is preserved
 %% as this function is used to abstract sort in recursive sort defintions.
 %% For example, if 
 %% sort ListPair(a,b) = | Nil | Cons a * b * ListPair(a,b)
 %% is defined, then abstractSort is used to return the pair:
 %% ( (a,b), | Nil | Cons a * b * ListPair(a,b) )
 %%

 op makeTyVarMap: (String -> TyVar) * List String
                 -> StringMap.Map String * (MS.Sort -> MS.Sort)
 def makeTyVarMap (fresh, tyVars) = 
  let def insert (tv, map) = StringMap.insert (map, tv, fresh tv) in
  let m = List.foldr insert StringMap.empty tyVars in
  let doSort = 
      fn (srt as (Base (Qualified (_, s), [], pos)) : MS.Sort) -> 
         (case StringMap.find (m, s) of
           | Some tyVar -> (TyVar (tyVar, pos)) : MS.Sort
           | None -> srt) 
       | s -> s
  in
    (m, doSort)

 op mkApplyN      : MS.Term * MS.Term                 -> MS.Term
 def mkApplyN (t1, t2) : MS.Term = ApplyN ([t1, t2],       internalPosition)

 def mkList (terms : List MS.Term, pos: Position, element_type: MS.Sort): MS.Term = 
  let list_type  = Base (Qualified ("List", "List"),  [element_type], pos) in
  let list1_type = Base (Qualified ("List", "List1"), [element_type], pos) in
  let cons_type  = Arrow (Product   ([("1", element_type), ("2", list_type)], pos),
                          list1_type, pos) in
  let consFun    = Fun   (Embed     ("Cons", true),  cons_type, pos) in
  let empty_list = Fun   (Embed     ("Nil",  false), list_type, pos) in
  let def mkCons (x, xs) = ApplyN ([consFun, Record( [("1",x), ("2",xs)], pos)], pos) in
  foldr mkCons empty_list terms

 % ------------------------------------------------------------------------
 %  Recursive constructors of MS.Pattern's
 % ------------------------------------------------------------------------

 op mkListPattern : List MS.Pattern       * Position * MS.Sort -> MS.Pattern
 op mkConsPattern : MS.Pattern * MS.Pattern * Position * MS.Sort -> MS.Pattern

 def mkListPattern (patterns : List MS.Pattern, pos, element_type) : MS.Pattern = 
  let list_type  = Base (Qualified("List","List"),  [element_type], pos) in
  let empty_list = EmbedPat ("Nil",  None,  list_type, pos) in
  let def mkCons (x, xs) = 
       EmbedPat ("Cons", Some (RecordPat ([("1",x), ("2",xs)], pos)), list_type, pos) in
  List.foldr mkCons empty_list patterns

 def mkConsPattern (p1 : MS.Pattern, p2 : MS.Pattern, pos, element_type) : MS.Pattern =
  let list_type  = Base (Qualified("List","List"), [element_type], pos) in
  EmbedPat ("Cons", Some (RecordPat ([("1",p1), ("2",p2)], pos)), list_type, pos)

endspec