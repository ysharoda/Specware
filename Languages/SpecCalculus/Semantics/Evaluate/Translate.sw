\subsection{Spec Translation}

TODO: This has file suffers greatly from having to accommodate the representation
of specs, ops, sorts and ids. 

Also the parser seems to set up a cod_aliases field. I would argue that
this should be removed from the parser. I disagree. I, on the other hand,
agree with myself. I couldn't agree more.

\begin{spec}
SpecCalc qualifying spec
  import Signature 
  import Spec/CompressSpec
  import Spec/AccessSpec
  import Spec/MergeSpecs
  import Spec/QualifyCapture
  import Spec/VarOpCapture
  import UnitId/Utilities                                % for uidToString, if used...
\end{spec}

Perhaps evaluating a translation should yield a morphism rather than just 
a spec. Then perhaps we add dom and cod domain operations on morphisms.
Perhaps the calculus is getting too complicated.

\begin{spec}
  def SpecCalc.evaluateTranslate term translation = {
    unitId <- getCurrentUID;
    print (";;; Elaborating spec-translation at " ^ (uidToString unitId)^"\n");
    (value,timeStamp,depUIDs) <- evaluateTermInfo term;
    case coerceToSpec value of
      | Spec spc -> {
            spcTrans <- translateSpec spc translation;
            return (Spec spcTrans,timeStamp,depUIDs)
		    }
      | _ -> raise (TypeCheck (positionOf term,
			       "translating a term that is not a specification"))
    }
\end{spec}

To translate a spec means to recursively descend the hierarchy of imports
and translate names. This can raise exceptions since ops may end up with
the same names.

If the following, assume we are given the rule "<lhs> +-> <rhs>"

We lookup <lhs> in the domain spec to find a domain item, raising an exception
if nothing can be found.  The rules are intended to be the same as those used
when linking names in formulas within a spec, but the keywords "type" and "op" 
are allowed here to disambiguate an otherwise missing context:

\begin{verbatim}
  "type [A.]X"   will look at types only
  "op   [A.]X"   will look at ops   only
  "[A.]X"        will look at types and ops, raising an exception if there are both
  "[A.]f : B.X"  will lookup [A.]f of type [B.]X
  "X"            will find unqualified "X" in preference to "A.X" if both exist.
\end{verbatim}

Translate all references to the found item into <rhs>, withe following
caveats:

\begin{itemize}
\item If <rhs> lacks an explicit qualifier, the rhs item is unqualified.

\item If multiple lhs items map to the same rhs item, then their (translated)
      properties (e.g. types or definitions) must be mergable or an exception 
      is raised.

\item Given types A and B, plus ops (f : A) and (f : B), if A and B are both
      mapped to the same C, then (f : A) and (f : B) will implicitly map to 
      the same rhs item (unless they are explicitly mapped elsewhere).

\end{itemize}

Note: The code below does not yet match the documentation above, but should.

\begin{spec}
  op translateSpec : Spec -> TranslateExpr Position -> Env Spec
  def translateSpec spc expr = 
    let pos = positionOf expr in
    {
     translation_maps <- makeTranslationMaps spc expr;
     %%
     %% translation_maps is an explicit map for which each name in its 
     %% domain refers to a particular type or op in the domain spec.  
     %%
     %% Each rule explicitly states that it is mapping a type or an op, 
     %% and there are no wildcards.   
     %%
     %% makeTranslationMaps raises various exceptions if it cannot 
     %% guarantee all of this
     %%                          ----
     %% However, it is still possible that a renaming would cause an
     %% inadvertant ambiguity or even capture, so we check for that.
     %%
     %% In particular, we worry the following situation:
     %%
     %%   an unqualified Y that refers to B.Y in the domain spec  
     %%
     %%   and translation rules:
     %%     B.Y +-> B.Y 
     %%     A.X +-> Y 
     %% 
     %%   creating a spec in which the unqualified Y refers to the 
     %%   translation of A.X, as opposed to the transation of B.Y
     %%
     %% Moreover, we wish to avoid gratuitously qualifying every reference, 
     %%  to keep print forms for specs as similar as possible to their 
     %%  original input text.  Seeing Integer.+, String.^ etc. everywhere 
     %%  would be confusing and annoying.
     %%
     translation_maps <- removeQualifyCaptures spc translation_maps pos;
     raise_any_pending_exceptions;
     %%
     %% Now we produce a new spec using these unmbiguous maps.
     %%
     spc <- auxTranslateSpec spc translation_maps pos;
     raise_any_pending_exceptions;
     %%
     %% Next we worry about traditional captures in which a (global) op Y,
     %% used under a binding of var X, is renamed to X.   Internally, this 
     %% is not a problem, since the new refs to op X are distinguishable 
     %% from the refs to var X, but printing the resulting formula loses
     %% that distinction, so refs to the op X that are under the binding 
     %% of var X would be read back in as refs to the var X.
     %% 
     %% So we do alpha conversions if a bound var has an op of the same
     %% name under its scope:
     %%
     spc <- return (removeVarOpCaptures spc);
     %%
     %% One final pass to see if we've managed to collapse necessarily 
     %% distinct types (e.g. A = X * Y and B = Z | p), or necessarily
     %% distinct ops (e.g. op i = 4 and op j = "oops") onto the same name.
     %%
     complainIfAmbiguous (compressDefs spc) pos
    } 

  % see QualifyCapture.sw
  % sort TranslationMap  = AQualifierMap (QualifiedId * Aliases) 
  % sort TranslationMaps = TranslationMap * TranslationMap

  op makeTranslationMaps :
        Spec
     -> TranslateExpr Position
     -> SpecCalc.Env TranslationMaps

  def makeTranslationMaps dom_spec (translation_rules, position) =
    %% Similar to code in SpecMorphism.sw
    %% and types are factored as Foo a = (Foo_ a) * a
    %% TODO:  Detect multiple rules for same dom item.
    let 

      def insert (translation_op_map, translation_sort_map) (translation_rule, rule_pos) =

	let 
          def add_type_rule translation_op_map translation_sort_map (dom_qid as Qualified (dom_q, dom_id)) dom_types cod_qid cod_aliases =
	    case dom_types of
	      | first_info :: other_infos ->
	        (let primary_dom_qid as Qualified (found_q, _) = primarySortName first_info in
		 if other_infos = [] || found_q = UnQualified then
		  %% dom_qid has a unique referent, either because it refers to 
		  %% exactly one type, or becauses it is unqualified and refers 
		  %% to an unqualified type (perhaps among others), in which 
		  %% case that unqualified type is (by language definition) 
		  %% the unique unique referent.  
		  %% (Note that a qualified dom_qid can't refer to an unqualified 
		  %% type, so we can suppress the test for unqualified dom_qid.)						     
		  if basicSortName? primary_dom_qid then
		    {
		     raise_later (TranslationError ("Illegal to translate from base type : " ^ (explicitPrintQualifiedId dom_qid),
						    rule_pos));
		     return (translation_op_map, translation_sort_map)
		    }
		  else
		    case findAQualifierMap (translation_sort_map, dom_q, dom_id) of
		      | None -> 
		        let new_sort_map = insertAQualifierMap (translation_sort_map, dom_q, dom_id, (cod_qid, cod_aliases)) in
			let new_sort_map = (if dom_q = found_q then
					      new_sort_map
					    else
					      insertAQualifierMap (new_sort_map, found_q, dom_id, (cod_qid, cod_aliases)))
			in
			  return (translation_op_map, new_sort_map)
		      | _  -> 
			{
			 raise_later (TranslationError ("Multiple rules for source type " ^ (explicitPrintQualifiedId dom_qid),
							rule_pos));
			 return (translation_op_map, translation_sort_map)
			}
		else 
		  {
		   raise_later (TranslationError ("Ambiguous source type " ^ (explicitPrintQualifiedId dom_qid), 
						  rule_pos));
		   return (translation_op_map, translation_sort_map)
		  })
	      | _ -> 
		{
		 raise_later (TranslationError ("Unrecognized source type " ^ (explicitPrintQualifiedId dom_qid),
						rule_pos));
		 return (translation_op_map, translation_sort_map)
		}
		  
	      
	  def add_op_rule translation_op_map translation_sort_map (dom_qid as Qualified(dom_q, dom_id)) dom_ops cod_qid cod_aliases =
	    case dom_ops of
	      | first_op :: other_ops ->
	        (let primary_dom_qid as Qualified (found_q, _) = primaryOpName first_op in
		 if other_ops = [] || found_q = UnQualified then
		   %% See note above for types.
		   if basicOpName? primary_dom_qid then
		     {
		      raise_later (TranslationError ("Illegal to translate from base op: " ^ (explicitPrintQualifiedId dom_qid),
						     rule_pos));
		      return (translation_op_map, translation_sort_map)
		     }
		   else
		     case findAQualifierMap (translation_op_map, dom_q, dom_id) of
		       
		       | None -> 
		         %% No rule yet for dom_qid...
		         let new_op_map = insertAQualifierMap (translation_op_map, dom_q, dom_id, (cod_qid, cod_aliases)) in
			 let new_op_map = (if dom_q = found_q then
					      new_op_map
					    else
					      insertAQualifierMap (new_op_map, found_q, dom_id, (cod_qid, cod_aliases)))
			 in
			   return (new_op_map, translation_sort_map)
		       | _ -> 
			 %% Already had a rule for dom_qid...
			 {
			  raise_later (TranslationError ("Multiple rules for source op "^
							 (explicitPrintQualifiedId dom_qid),
							 rule_pos));
			  return (translation_op_map, translation_sort_map)
			 }
		 else 
		   {
		    raise_later (TranslationError ("Ambiguous source op "^   (explicitPrintQualifiedId dom_qid), 
						   rule_pos));
		    return (translation_op_map, translation_sort_map)
		    })
	      | _ -> 
		{
		 raise_later (TranslationError ("Unrecognized source op "^(explicitPrintQualifiedId dom_qid),
						rule_pos));
		 return (translation_op_map, translation_sort_map)
		 }
		  
	  def add_wildcard_rules translation_op_map translation_sort_map dom_q cod_q cod_aliases =
	    %% Special hack for aggregate renamings: X._ +-> Y._
	    %% Find all dom sorts/ops qualified by X, and requalify them with Y
	    (if basicQualifier? dom_q then
	       {
		raise_later (TranslationError ("Illegal to translate from base : " ^ dom_q, 
					       position));
		return (translation_op_map, translation_sort_map)
		}
	     else if basicQualifier? cod_q then
	       {
		raise_later (TranslationError ("Illegal to translate into base: " ^ cod_q,
					       position));
		return (translation_op_map, translation_sort_map)
		}
	     else
	       let

		 def extend_sort_map (sort_q, sort_id, _ (* sort_info *), translation_sort_map) =
		   if sort_q = dom_q then
		     %% This is a candidate to be translated...
		     case findAQualifierMap (translation_sort_map, sort_q, sort_id) of
		       | None -> 
		         %% No rule yet for this candidate...
		         let new_cod_qid = mkQualifiedId (cod_q, sort_id) in
			 if basicCodSortName? new_cod_qid then
			   {
			    raise_later (TranslationError ("Illegal to translate into base type: " ^ (explicitPrintQualifiedId new_cod_qid),
							   rule_pos));
			    return translation_sort_map
			   }
			 else
			    return (insertAQualifierMap (translation_sort_map, sort_q, sort_id, (new_cod_qid, [new_cod_qid])))
		       | _ -> 
			 {
			  raise_later (TranslationError ("Multiple (wild) rules for source type "^
							 (explicitPrintQualifiedId (mkQualifiedId (sort_q, sort_id))),
							 rule_pos));
			  return translation_sort_map
			  }
		   else
		     return translation_sort_map

                 def extend_op_map (op_q, op_id, _ (* op_info *), translation_op_map) =
		   if op_q = dom_q then
		     %% This is a candidate to be translated...
		     case findAQualifierMap (translation_op_map, op_q, op_id) of
		       | None -> 
		         %% No rule yet for this candidate...
		         let new_cod_qid = mkQualifiedId (cod_q, op_id) in
			 {
			  new_cod_qid <- (if syntactic_qid? new_cod_qid then
					    {
					     raise_later (TranslationError ("`" ^ (explicitPrintQualifiedId new_cod_qid) ^ 
									    "' is syntax, not an op, hence cannot be the target of a translation.",
									    rule_pos));
					     return new_cod_qid
					     }
					  else
					    foldM (fn cod_qid -> fn alias ->
						   if syntactic_qid? alias then 
						     {
						      raise_later (TranslationError ("Alias `" ^ (explicitPrintQualifiedId alias) ^ 
										     "' is syntax, not an op, hence cannot be the target of a translation.",
										     rule_pos));
						      return cod_qid
						      }
						   else
						     return cod_qid)
					          new_cod_qid
						  cod_aliases);
			 if basicCodOpName? new_cod_qid then
			   {
			    raise_later (TranslationError ("Illegal to translate into base op: " ^ (explicitPrintQualifiedId new_cod_qid),
							   rule_pos));
			    return translation_op_map
			    }
			 else
			   return (insertAQualifierMap (translation_op_map, op_q, op_id, (new_cod_qid, [new_cod_qid])))
			 }
		       | _ -> 
			 %% Candidate already has a rule (e.g. via some explicit mapping)...
			 {
			  raise_later (TranslationError ("Multiple (wild) rules for source op "^
							 (explicitPrintQualifiedId (mkQualifiedId (op_q, op_id))),
							 rule_pos));
			  return translation_op_map
			  }
						  
		   else
		     return translation_op_map 
	       in 
		 {
		  %% Check each dom type and op to see if this abstract ambiguous rule applies...
		  translation_sort_map <- foldOverQualifierMap extend_sort_map translation_sort_map dom_spec.sorts;
		  translation_op_map   <- foldOverQualifierMap extend_op_map   translation_op_map   dom_spec.ops;
		  return (translation_op_map, translation_sort_map)
		 })

    in
      case translation_rule of
	
	%% TODO: ?? Add special hack for aggregate type renamings: X._ +-> Y._  ??
	%% TODO: ?? Add special hack for aggregate op   renamings: X._ +-> Y._  ??

        | Sort (dom_qid, cod_qid, cod_aliases) -> 
	  if basicSortName? dom_qid then
	    {
	     raise_later (TranslationError ("Illegal to translate from base type : " ^ (explicitPrintQualifiedId dom_qid),
					    rule_pos));
	     return (translation_op_map, translation_sort_map)
	    }
	  else if basicCodSortName? cod_qid then
	    {
	     raise_later (TranslationError ("Illegal to translate into base type: " ^ (explicitPrintQualifiedId cod_qid),
					    rule_pos));
	     return (translation_op_map, translation_sort_map)
	    }
	  else
	    let dom_types = findAllSorts (dom_spec, dom_qid) in
	    add_type_rule translation_op_map translation_sort_map dom_qid dom_types cod_qid cod_aliases

	| Op   ((dom_qid, dom_type), (cod_qid, cod_type), cod_aliases) ->  
	  if syntactic_qid? dom_qid then 
	    {
	     raise_later (TranslationError ("`" ^ (explicitPrintQualifiedId dom_qid) ^ "' is syntax, not an op, hence cannot be translated.",
					    rule_pos));
	     return (translation_op_map, translation_sort_map)
	    }
	  else if basicOpName? dom_qid then
	    {
	     raise_later (TranslationError ("Illegal to translate from base op: " ^ (explicitPrintQualifiedId dom_qid),
					    rule_pos));
	     return (translation_op_map, translation_sort_map)
	    }
	  else if basicCodOpName? cod_qid then
	    {
	     raise_later (TranslationError ("Illegal to translate into base op: " ^ (explicitPrintQualifiedId cod_qid),
					    rule_pos));
	     return (translation_op_map, translation_sort_map)
	    }
	  else
	    let dom_ops = findAllOps (dom_spec, dom_qid) in
	    add_op_rule translation_op_map translation_sort_map dom_qid dom_ops cod_qid cod_aliases

	| Ambiguous (Qualified(dom_q, "_"), Qualified(cod_q,"_"), cod_aliases) -> 
	  add_wildcard_rules translation_op_map translation_sort_map dom_q cod_q cod_aliases

	| Ambiguous (dom_qid, cod_qid, cod_aliases) -> 
	  if syntactic_qid? dom_qid then 
	    {
	     raise_later (TranslationError ("`" ^ (explicitPrintQualifiedId dom_qid) ^ "' is syntax, not an op, hence cannot be translated.",
					    rule_pos));
	     return (translation_op_map, translation_sort_map)
	     }
	  else if basicQualifiedId? dom_qid then
	    {
	     raise_later (TranslationError ("Illegal to translate from base type or op: " ^ (explicitPrintQualifiedId dom_qid),
					    rule_pos));
	     return (translation_op_map, translation_sort_map)
	     }
	  else if basicCodName? cod_qid then
	    {
	     raise_later (TranslationError ("Illegal to translate into base type or op: " ^ (explicitPrintQualifiedId cod_qid),
					    rule_pos));
	     return (translation_op_map, translation_sort_map)
	     }
	  else
	    %% Find a sort or an op, and proceed as above
	    let dom_types = findAllSorts (dom_spec, dom_qid) in
	    let dom_ops   = findAllOps   (dom_spec, dom_qid) in
	    case (dom_types, dom_ops) of
	      | ([], []) -> {
			     raise_later (TranslationError ("Unrecognized source type or op "^(explicitPrintQualifiedId dom_qid), 
							    rule_pos));
			     return (translation_op_map, translation_sort_map)
			     }
	      | (_,  []) -> add_type_rule translation_op_map translation_sort_map dom_qid dom_types cod_qid cod_aliases
	      | ([], _)  -> add_op_rule   translation_op_map translation_sort_map dom_qid dom_ops   cod_qid cod_aliases
	      | (_,  _)  -> {
			     raise_later (TranslationError ("Ambiguous source type or op: "^(explicitPrintQualifiedId dom_qid),
							    rule_pos));
			     return (translation_op_map, translation_sort_map)
			     }
    in
      foldM insert (emptyAQualifierMap, emptyAQualifierMap) translation_rules

  def basicCodSortName? qid =
    let base_spec = getBaseSpec () in
    case findAllSorts (base_spec, qid) of
      | [] -> false
      | _  -> true

  def basicCodOpName? qid =
    let base_spec = getBaseSpec () in
    case findAllOps (base_spec, qid) of
      | [] -> false
      | _  -> true

  def basicCodName? qid =
    let base_spec = getBaseSpec () in
    case findAllSorts (base_spec, qid) of
      | [] ->
        (case findAllOps (base_spec, qid) of
	   | [] -> false
	   | _  -> true)
      | _ -> true

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  op  translateOpQualifiedId   : TranslationMap -> QualifiedId -> QualifiedId
  op  translateSortQualifiedId : TranslationMap -> QualifiedId -> QualifiedId
  op  translateOp              : TranslationMap -> MS.Term -> MS.Term
  op  translateSort            : TranslationMap -> MS.Sort -> MS.Sort

  def translateOpQualifiedId op_id_map (qid as Qualified (q, id)) =
    case findAQualifierMap (op_id_map, q,id) of
      | Some (nQId,_) -> nQId
      | None -> qid

  def translateSortQualifiedId sort_id_map (qid as Qualified (q, id)) =
    case findAQualifierMap (sort_id_map, q,id) of
      | Some (nQId,_) -> nQId
      | None -> qid

  def translateOp op_id_map op_term =
    case op_term of
      | Fun (Op (qid, fixity), srt, pos) ->
	(let new_qid = translateOpQualifiedId op_id_map qid in
	 if new_qid = qid then op_term else Fun (Op (new_qid, fixity), srt, pos))
      | _ -> op_term

  def translateSort sort_id_map sort_term =
    case sort_term of
      | Base (qid, srts, pos) ->
	(let new_qid = translateSortQualifiedId sort_id_map qid in
	 if new_qid = qid then sort_term else Base (new_qid, srts, pos))
      | _ -> sort_term


  op auxTranslateSpec : Spec -> TranslationMaps -> Position -> SpecCalc.Env Spec

  def auxTranslateSpec spc (op_id_map, sort_id_map) position =
    %% TODO: need to avoid capture that occurs for "X +-> Y" in "fa (Y) ...X..."
    %% TODO: ?? Change UnQualified to new_q in all qualified names ??
    let
      def translateOpQualifiedIdToAliases op_id_map (qid as Qualified (q, id)) =
        case findAQualifierMap (op_id_map, q,id) of
          | Some (_,new_aliases) -> new_aliases
          | None -> [qid]
  
      def translateSortQualifiedIdToAliases sort_id_map (qid as Qualified (q, id)) =
        case findAQualifierMap (sort_id_map, q,id) of
          | Some (_,new_aliases) -> new_aliases
          | None -> [qid]
  
      def translatePattern pat = pat

      def translateOpMap old_ops =
        let 
          def translateStep (old_q, old_id, old_info, new_op_map) =
	    let primary_qid as Qualified (primary_q, primary_id) = primaryOpName old_info in
	    if ~ (old_q = primary_q && old_id = primary_id) then
	      return new_op_map
	    else if exists basicOpName? old_info.names then
	      return (insertAQualifierMap (new_op_map, old_q, old_id, old_info))
	    else
	      {
	       new_names <- foldM (fn new_qids -> fn old_qid ->
				   foldM (fn new_qids -> fn new_qid ->
					  if member (new_qid, new_qids) then
					    return new_qids
					  else 
					    return (Cons (new_qid, new_qids)))
				         new_qids
					 (translateOpQualifiedIdToAliases op_id_map old_qid))
	                          [] 
				  old_info.names;
	       new_names <- return (rev new_names);
	       mapM (fn new_qid ->
		     if basicOpName? new_qid then
		       {
			raise_later (TranslationError ("Illegal to translate into base op " ^ (explicitPrintQualifiedId new_qid),
						       position));
			return new_qid
		       }
		     else
		       return new_qid)
	            new_names;
	       new_info <- foldM (fn merged_info -> fn (Qualified (new_q, new_id)) ->
				  mergeOpInfo merged_info 
					      (findAQualifierMap (new_op_map, new_q, new_id))
					      position)
	                         (old_info << {names = new_names})
				 new_names;
	       foldM (fn new_op_map -> fn (Qualified (new_q, new_id)) ->
		      return (insertAQualifierMap (new_op_map, new_q, new_id, new_info)))
	             new_op_map  
		     new_names
	      }
	in
	  foldOverQualifierMap translateStep emptyAQualifierMap old_ops 

      def translateSortMap old_sorts =
        let 
          def translateStep (old_q, old_id, old_info, new_sort_map) =
	    let Qualified (primary_q, primary_id) = primarySortName old_info in
	    if ~ (old_q = primary_q && old_id = primary_id) then
	      return new_sort_map
	    else if exists basicSortName? old_info.names then
	      return (insertAQualifierMap (new_sort_map, old_q, old_id, old_info))
	    else
	      {
	       new_names <- foldM (fn new_qids -> fn old_qid ->
				   foldM (fn new_qids -> fn new_qid ->
					  if member (new_qid, new_qids) then
					    return new_qids
					  else 
					    return (Cons (new_qid, new_qids)))
				         new_qids
					 (translateSortQualifiedIdToAliases sort_id_map old_qid))
	                          [] 
				  old_info.names;
	       new_names <- return (rev new_names);
	       mapM (fn new_qid ->
		     if basicSortName? new_qid then
		       {
			raise_later (TranslationError ("Illegal to translate into base type " ^ (explicitPrintQualifiedId new_qid),
						       position));
			return new_qid
		       }
		     else
		       return new_qid)
	            new_names;
	       if member (unqualified_Boolean, new_names) || member (Boolean_Boolean, new_names) then
		 return new_sort_map
	       else
		{ 
		 new_info <- foldM (fn merged_info -> fn Qualified (new_q, new_id) ->
				     mergeSortInfo merged_info 
						   (findAQualifierMap (new_sort_map, new_q, new_id))
						   position)
				    (old_info << {names = new_names})
				    new_names;
		  foldM (fn new_sort_map -> fn (Qualified (new_q, new_id)) ->
			 return (insertAQualifierMap (new_sort_map, new_q, new_id, new_info)))
		        new_sort_map  
			new_names 
		}}
	in
	  foldOverQualifierMap translateStep emptyAQualifierMap old_sorts 

    in
    let {importInfo = {imports,localOps,localSorts,localProperties}, sorts, ops, properties}
         = 
         mapSpec (translateOp op_id_map, translateSort sort_id_map, translatePattern) spc
    in 
    {
     newSorts <- translateSortMap sorts;
     newOps   <- translateOpMap   ops;
     return {importInfo = {imports      = [],
			   localOps     = map (translateOpQualifiedId op_id_map) localOps,
			   localSorts   = foldl (fn (ty, local_types) -> 
						 let new_type = translateSortQualifiedId sort_id_map ty in
						 %% Avoid adding Boolean or Boolean.Boolean to local sorts,
						 %% since it is built in.
						 if new_type = Boolean_Boolean || new_type = unqualified_Boolean then
						   local_types
						 else
						   local_types ++ [new_type])
			                        []
						localSorts,
			   localProperties = localProperties},  
	     sorts      = newSorts,
	     ops        = newOps,
	     properties = properties}
    }

endspec
\end{spec}
