SpecCalc qualifying spec {
  import Signature 
  import UnitId/Utilities

 % This implements the "print" command, which evaluates its argument and 
 %  returns that value, with the side effect of printing the value.  
 % This strategy makes it cognizant of the results of type-checking, 
 %  overload resolution, colimit/translate computations, etc., which
 %  presumably is valuable information for a confused user, or a user
 %  exploring a new and unfamiliar system.
 %
 % Exactly how deeply recursively it should print is an open question.
 % Perhaps it should accept parameters to control that.
 %
 % An alternative strategy would be to simply call ppTerm on the argument,
 %  then evaluate that term and return its value.  That would simply echo
 %  back essentially the same term that was parsed, which makes it much
 %  simpler but also probably less useful.
 % ppTerm, the printer for a SpecCalculus Term, is in 
 %  /Languages/SpecCalculus/AbstractSyntax/Printer.sw

 % from Environment.sw :
 % sort ValueInfo = Value * TimeStamp * UnitId_Dependency
 % sort GlobalContext = PolyMap.Map (UnitId, ValueInfo)
 % sort LocalContext  = PolyMap.Map (RelativeUID, ValueInfo)
 % sort State = GlobalContext * LocalContext * Option UnitId * ValidatedUIDs

 % These may be used in various places throughout this file:
 %  uidToString          produces (unparseable) UnitId's that are relative to the root of the OS, using ~ for home,    e.g. "~/foo"
 %  relativeUID_ToString produces (parseable?)  UnitId's that are relativized to the currentUID, using ".." to ascend, e.g. "foo" or "../../foo"
       
 sort ReverseContext = PolyMap.Map (Value, RelativeUnitId)

 def printSpecExpanded? = false

 def SpecCalc.evaluatePrint term = {
   (value, time_stamp, depUnitIds) <- SpecCalc.evaluateTermInfo term;
   (optBaseUnitId,base_spec)     <- getBase;
   global_context                <- getGlobalContext;   
   currentUnitId                 <- getCurrentUnitId;
   reverse_context <- return (foldr (fn (unitId, value_to_unit_id_map) -> 
				     update value_to_unit_id_map
                                            ((eval global_context unitId).1) 
				            (relativizeUID currentUnitId unitId))
			            emptyMap
				    depUnitIds);
   SpecCalc.print "\n";
   (case value of
      | Spec    spc -> SpecCalc.print (if printSpecExpanded?
					 then printSpecExpanded base_spec reverse_context spc
					 else printSpec base_spec reverse_context spc)
      | Morph   sm  -> SpecCalc.print (printMorphism base_spec reverse_context sm)
      | Diag    dg  -> SpecCalc.print (printDiagram  base_spec reverse_context dg)
      | Colimit col -> SpecCalc.print (printColimit  base_spec reverse_context col)
      | Other other -> evaluateOtherPrint other (positionOf term)
      | Proof _     -> SpecCalc.print ""
      | InProcess   -> SpecCalc.print "No value!");
   SpecCalc.print "\n";
   return (value, time_stamp, depUnitIds)
   }

 op printSpec     : Spec -> ReverseContext -> Spec              -> String
 op printMorphism : Spec -> ReverseContext -> Morphism          -> String
 op printDiagram  : Spec -> ReverseContext -> SpecDiagram       -> String
 op printColimit  : Spec -> ReverseContext -> SpecInitialCocone -> String

 %% ======================================================================
 %% Spec
 %% ======================================================================

  %The following loses too much information
  def printSpec base_spec reverse_context spc =
    %% this uses /Languages/MetaSlang/Specs/Printer
    %% which uses /Library/PrettyPrinter/BjornerEspinosa
    PrettyPrint.toString (format(80, 
 				ppSpecHidingImportedStuff
 				  (initialize(asciiPrinter,false))
				  base_spec
				  spc))

 def printSpecExpanded base_spec _ (* ignore reverse_context *) spc =
   %% use reverse_context for imports ?
   AnnSpecPrinter.printSpec (subtractSpec (spc << {importInfo = emptyImportInfo}) base_spec)

 %% ======================================================================
 %% Morphism
 %% ======================================================================

 def printMorphism base_spec reverse_context sm =
   %% this uses /Languages/MetaSlang/Specs/Categories/AsRecord
   %% which uses /Library/PrettyPrinter/WadlerLindig
   %%
   %% Some possible formats this might generate:
   %%
   %%  A -> B {}
   %%
   %%  A -> B { ... }
   %%  
   %%  A -> B 
   %%   { ... }      
   %%  
   %%  A -> B 
   %%   {... 
   %%    ...
   %%    ...}
   %%  
   ppFormat (ppMorphismX base_spec reverse_context sm)

 %% Not to be confused with ppMorphism in /Languages/MetaSlang/Specs/Categories/AsRecord.sw (sigh)
 def ppMorphismX base_spec reverse_context sm =
   let dom_spec = dom sm in
   let cod_spec = cod sm in
   %% Use of str_1 is a bit of a hack to get the effect that
   %% dom/cod specs are grouped on one line if possible,
   %% and they either follow "morphism" on the first line 
   %% (with map on same line or indented on next line),
   %% or are by themselves, indented, on the second line,
   %% with the map indented starting on the third line.
   let str_1 = ppFormat
               (ppGroup 
		(ppConcat 
		 [ppString "morphism",
		  ppNest 4 (ppGroup
			    (ppConcat 
			     [ppBreak,
			      ppString (case evalPartial reverse_context (Spec dom_spec) of
					  | Some rel_uid -> relativeUID_ToString rel_uid  
					  | None         -> printSpec base_spec reverse_context dom_spec),
			      ppBreak,
			      ppString "->",
			      ppBreak,
			      ppString (case evalPartial reverse_context (Spec cod_spec) of
					  | Some rel_uid -> relativeUID_ToString rel_uid  
					  | None         -> printSpec base_spec reverse_context cod_spec)
			     ]))
		 ]))
   in
   ppGroup 
    (ppConcat 
     [ppString str_1,
      ppNest 4 (ppMorphismMap sm)])


  %% inspired by ppMorphMap from /Languages/MetaSlang/Specs/Categories/AsRecord.sw,
  %%  but substantially different
  op ppMorphismMap : Morphism -> Doc
  def ppMorphismMap {dom=_, cod=_, sortMap, opMap, sm_tm=_} =
    let 
      def abbrevMap map =
	foldMap (fn newMap -> fn d -> fn c ->
		 if d = c then
		   newMap
		 else
		   update newMap d c) 
	        emptyMap 
		map 
      def ppAbbrevMap keyword map =
	foldMap (fn lst -> fn dom -> fn cod ->
		 Cons (ppGroup (ppConcat [ppString keyword,				    
					  ppQualifiedId dom,
					  ppBreak,
					  ppString "+->",
					  ppBreak,
					  ppQualifiedId cod]), 
		       lst))
                [] 
		(abbrevMap map)
    in
    ppGroup (ppConcat
	     (case (ppAbbrevMap "type " sortMap) ++ (ppAbbrevMap "op " opMap) of
		| []         -> [ppBreak, 
				 ppString "{}"]
		| abbrev_map -> [ppBreak,
				 ppString "{",
				 ppNest 1 (ppSep (ppCons (ppString ",") ppBreak) abbrev_map),
				 ppString "}"]))


 %% ======================================================================
 %% Diagram
 %% ======================================================================

 def printDiagram base_spec reverse_context dg =
   %% this uses /Library/Structures/Data/Categories/Diagrams/Polymorphic
   %% which uses /Library/PrettyPrinter/WadlerLindig

   let shape       = shape    dg    in
   let vertice_set = vertices shape in
   let edge_set    = edges    shape in
   let src_map     = src      shape in
   let target_map  = target   shape in

   let functor     = functor   dg      in
   let vertex_map  = vertexMap functor in
   let edge_map    = edgeMap   functor in

   %% warning: vertex.difference (based on sets) is not defined!
   %%  so we use lists instead for linked_vertices and isolated_vertices
   let linked_vertices = 
       fold (fn linked_vertices -> fn edge -> 
	     let src = eval src_map    edge in
	     let tgt = eval target_map edge in
	     %% simpler and faster to allow duplicates
	     Cons (src, Cons (tgt, linked_vertices)))
            []
	    edge_set
   in
   let isolated_vertices =  
       fold (fn isolated_vertices -> fn vertice ->
	     if member (vertice, linked_vertices) then
	       isolated_vertices
	     else
	       Cons (vertice, isolated_vertices))
            []
	    vertice_set
   in
   let pp_vertice_entries = 
       foldl (fn (vertex, pp_entries) -> 
	      Cons (ppGroup 
		    (ppConcat 
		     [ppElem vertex, 
		      ppBreak,
		      ppString "+->",
		      ppBreak,
		      let spc = eval vertex_map vertex in
		      ppString (case evalPartial reverse_context (Spec spc) of
				  | Some rel_uid -> relativeUID_ToString rel_uid  
				  | None         -> printSpec base_spec reverse_context spc)]),
		    pp_entries))
             []
	     isolated_vertices
   in
   let pp_edge_entries = 
       fold (fn pp_entries -> fn edge -> 
	     Cons (ppGroup 
		    (ppConcat 
 		      [ppGroup 
		        (ppConcat 
			  [ppElem edge,
			   ppBreak,
			   ppString ":",
			   ppBreak,
			   ppElem (eval src_map edge),
			   ppBreak,
			   ppString "->",
			   ppBreak,
			   ppElem (eval target_map edge)]),
			ppBreak,
			ppString "+->",
		        ppBreak,
			let sm = eval edge_map edge in
			case evalPartial reverse_context (Morph sm) of
			  | Some rel_uid -> ppString (relativeUID_ToString rel_uid)  
			  | None         -> ppMorphismX base_spec reverse_context sm]),
		   pp_entries))
            []
            edge_set
   in 
   ppFormat 
     (ppGroup 
       (ppConcat [ppString "diagram {",
		  ppNest 9 (ppSep (ppCons (ppString ",") ppBreak) (pp_vertice_entries ++ pp_edge_entries)),
		  ppString "}"]))

   %% ppFormat (ppDiagram
   %%	     (mapDiagram dg 
   %%	      (fn obj -> subtractSpec obj base_spec) 
   %%	      (fn arr -> arr)))

 %% ======================================================================
 %% Colimit
 %% ======================================================================

 def printColimit base_spec reverse_context col =
   %% Just print the spec at the apex of the colimit.
   printSpec base_spec reverse_context (Cat.apex (Cat.cocone col))

   %%% was:
   %%%  %% ppColimit uses /Languages/MetaSlang/Specs/Categories/AsRecord
   %%%  %% which uses /Library/PrettyPrinter/WadlerLindig
   %%%  %% ppFormat  (ppColimit col)
   %%%  let apex_spec = Cat.apex (Cat.cocone col) in
   %%%  %% Note: localSorts and localOps in apex_spec will both be empty,
   %%%  %%       so whether or not it makes sense, we must work around this fact.
   %%%  let trimmed_apex_spec = subtractSpec apex_spec base_spec in
   %%%  AnnSpecPrinter.printSpec trimmed_apex_spec
}
