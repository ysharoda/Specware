PosSpecToSpec qualifying spec {
 %%  convert pos terms to standard terms

 import ../StandardSpec
 import /Library/Legacy/DataStructures/NatMapSplay  % for metaTyVars

 op convertPosSpecToSpec: Spec -> Spec

 def convertPosSpecToSpec spc =
   let context = initializeMetaTyVars() in
   let
     def convertPTerm term =
           case term of
	     | ApplyN([t1,t2],pos) -> Apply(t1,t2,pos)
	     | ApplyN (t1::t2::terms,pos) -> 
	       convertPTerm (ApplyN([t1,ApplyN(cons(t2,terms),pos)],pos))
	     | Fun (f,s,pos) -> Fun(convertPFun f,s,pos)
	     | _ -> term
     def convertPSort srt =
           case srt of
	     | MetaTyVar(tv,pos) -> 
	       let {name,uniqueId,link} = ! tv in
	       (case link
		  of None -> TyVar (findTyVar(context,uniqueId),pos)
		   | Some ssrt -> convertPSort ssrt)
	     | _ -> srt
     def convertPFun (f) = 
           case f
	     of PQuotient equiv  -> Quotient 
	      | PChoose equiv    -> Choose
	      | PRestrict pred   -> Restrict
	      | PRelax pred      -> Relax
	      | OneName(n,fxty)  -> Op(Qualified(UnQualified,n), fxty)
	      | TwoNames(qn,n,fxty) -> Op(Qualified(qn,n), fxty)
	      | _ -> f
   in
%% mapSpec is correct but unnecessarily maps non-locals
%   mapSpec (convertPTerm, convertPSort, fn x -> x)
%     spc
  let {importInfo, sorts, ops, properties} = spc in
  let {imports = _, localOps, localSorts, localProperties} = importInfo in
  let tsp_maps = (convertPTerm, convertPSort, fn x -> x) in
  { importInfo       = importInfo,

    ops              = mapOpInfos (fn info as (aliases, fixity, (tvs, srt), defs) ->
				   if someAliasIsLocal? (aliases, localOps) then
				     (aliases, 
				      fixity, 
				      (tvs, mapSort tsp_maps srt), 
				      mapTermSchemes tsp_maps defs)
				   else 
				     info)
                                  ops,

    sorts            = mapSortInfos (fn info as (aliases, tvs, defs) ->
				     if someAliasIsLocal? (aliases, localSorts) then
				       (aliases, tvs, mapSortSchemes tsp_maps defs)
				     else 
				       info)
                                    sorts,

    properties       = map (fn prop as (pt, qid, tvs, term) -> 
			       (pt, qid, tvs, 
				if member (qid, localProperties) then
				  mapTerm tsp_maps term
				else 
				  term))
			   properties
   }
}
