SpecCalc qualifying spec {
  import UnitId
  import Spec/SpecUnion
  import /Languages/Snark/SpecToSnark
  import /Languages/MetaSlang/Transformations/ExplicateHiddenAxioms
  import UnitId/Utilities                                    % for uidToString, if used...

 op PARSER4.READ_LIST_OF_S_EXPRESSIONS_FROM_STRING: String -> ProverOptions

 %op explicateHiddenAxioms:AnnSpec.Spec -> AnnSpec.Spec
  
 def SpecCalc.evaluateProve (claim_name, spec_term, prover_name, assertions, possible_options) pos = {
     unitId <- getCurrentUnitId;
     print (";;; Elaborating proof-term at " ^ (uidToString unitId) ^ "\n");
     (value,timeStamp,depUIDs) <- SpecCalc.evaluateTermInfo spec_term;
     (optBaseUnitId,baseSpec) <- getBase;
     baseProverSpec <- getBaseProverSpec;
     rewriteProverSpec <- getRewriteProverSpec;
     %proverBaseUnitId <- pathToRelativeUID "/Library/Base/ProverBase";
     %(Spec baseProverSpec,_,_) <- SpecCalc.evaluateUID (Internal "ProverBase") proverBaseUnitId;
     snarkLogFileName <- UIDtoSnarkLogFile unitId;
     _ <- return (ensureDirectoriesExist snarkLogFileName);
     proof_name <- return (UIDtoProofName unitId);
     spec_name <- return (SpecTermToSpecName(spec_term));
     uspc <- (
	     case coerceToSpec value of
	       | Spec spc -> return spc %specUnion([spc, baseProverSpec])
               | _ -> raise (Proof (pos, "Argument to prove command is not coerceable to a spec.")));
     %subSpec <- return(subtractSpec uspc baseSpec);
     noHOSpec <- return(subtractSpecProperties(instantiateHOFns(uspc), baseSpec));
     liftedNoHOSpec <- return(subtractSpecProperties(lambdaLift(noHOSpec), baseSpec));
     %liftedNoHOSpec <- return(lambdaLift(noHOSpec));
     _ <- return (if specwareDebug? then writeString(printSpec(liftedNoHOSpec)) else ());
     expandedSpec:Spec <- return(explicateHiddenAxioms(liftedNoHOSpec));
%    expandedSpec:Spec <- return(explicateHiddenAxioms(liftedNoHOSpec));
     %expandedSpec:Spec <- return(explicateHiddenAxioms(uspc));
     _ <- return (if specwareDebug? then writeString(printSpec(subtractSpecProperties(expandedSpec, baseSpec))) else ());
     %expandedSpec:Spec <- return(explicateHiddenAxioms(noHOSpec));
     %expandedSpec:Spec <- return(uspc);
     prover_options <- 
       (case possible_options of
	  | OptionString prover_options -> return (prover_options)
	  | OptionName prover_option_name -> 
	        proverOptionsFromSpec(prover_option_name, uspc, spec_name)
	  | Error   (msg, str)     -> raise  (SyntaxError (msg ^ str)));
     proved:Boolean <- (proveInSpec (proof_name,
				     claim_name, 
				     subtractSpecProperties(expandedSpec, baseSpec),
				     %expandedSpec,
				     spec_name,
				     baseProverSpec,
				     rewriteProverSpec,
				     prover_name, 
				     assertions, 
				     prover_options,
				     snarkLogFileName,
				     pos));
     result <- return (Proof {status = if proved then Proved else Unproved, 
			      unit   = unitId});
     return (result, timeStamp, depUIDs)
   }

  op subtractSpecProperties: Spec * Spec -> Spec
  def subtractSpecProperties(spec1, spec2) =
    let spec2PropNames = map (fn (pt, pn, tv, tm) -> pn) spec2.properties in
    let newProperties =
        filter (fn (pt, pn, tv, tm) -> ~(member(pn, spec2PropNames))) spec1.properties in
    {
     importInfo = spec1.importInfo,
     properties = newProperties,
     ops   = mapDiffOps spec1.ops spec2.ops,
     sorts = mapDiffSorts spec1.sorts spec2.sorts
   }
  

  op getBaseProverSpec : Env Spec
  def getBaseProverSpec = 
    {
     (optBaseUnitId,baseSpec) <- getBase;
     proverBaseUnitId <- pathToRelativeUID "/Library/Base/ProverBase";
     (Spec baseProverSpec,_,_) <- SpecCalc.evaluateUID (Internal "ProverBase") proverBaseUnitId;
     return (subtractSpec baseProverSpec baseSpec)
    }

  op getRewriteProverSpec : Env Spec
  def getRewriteProverSpec = 
    {
     (optBaseUnitId,baseSpec) <- getBase;
     proverRewriteUnitId <- pathToRelativeUID "/Library/Base/ProverRewrite";
     (Spec rewriteProverSpec,_,_) <- SpecCalc.evaluateUID (Internal "ProverRewrite") proverRewriteUnitId;
     return (subtractSpec rewriteProverSpec baseSpec)
    }

 def proverOptionsFromSpec(name, spc, spec_name) = {
   possible_options_op <- return(findTheOp(spc, name));
   options_def <-
      (case possible_options_op of
	 | Some (_,_,_,[(_,opTerm)]) -> return (opTerm)
	 | _ -> raise (SyntaxError ("Cannot find prover option definition, " ^ printQualifiedId(name) ^
		       (case spec_name of
			  | Some spec_name -> ", in Spec, " ^ spec_name ^ "."
			  | _ -> "."))));
   options_string <-
      (case options_def of
	 | Fun (String (opString),_,_) -> return (opString)
	 | _ -> raise (SyntaxError ("Prover option definition, " ^ printQualifiedId(name) ^ 
		                    ", is not a string.")));
   possible_options <- return(PARSER4.READ_LIST_OF_S_EXPRESSIONS_FROM_STRING(options_string));
   prover_options <- (case possible_options of
	  | OptionString (prover_options) -> return (prover_options)
	  | Error   (msg, str)     -> raise  (SyntaxError (msg ^ str)));
   return prover_options
  }

 op UIDtoSnarkLogFile: UnitId -> SpecCalc.Env String
 def UIDtoSnarkLogFile (unitId as {path,hashSuffix}) = {
   result <-
   case hashSuffix of
     | None -> UIDtoSingleSnarkLogFile(unitId)
     | Some _ -> UIDtoMultipleSnarkLogFile(unitId);
   return result
 }

 op UIDtoSingleSnarkLogFile: UnitId -> SpecCalc.Env String
 def UIDtoSingleSnarkLogFile (unitId as {path,hashSuffix}) =
    {prefix <- removeLastElem path;
     mainName <- lastElem path;
     let filNm = (uidToFullPath {path=prefix,hashSuffix=None})
        ^ "/snark/" ^ mainName ^ ".log"
     in
      return filNm}

 op UIDtoMultipleSnarkLogFile: UnitId -> SpecCalc.Env String
 def UIDtoMultipleSnarkLogFile (unitId as {path,hashSuffix}) =
   let Some hashSuffix = hashSuffix in
    {prefix <- removeLastElem path;
     newSubDir <- lastElem path;
     mainName <- return hashSuffix;
     let filNm = (uidToFullPath {path=prefix,hashSuffix=None})
        ^ "/snark/" ^ newSubDir ^ "/" ^ mainName ^ ".log"
     in
      return filNm}

 op UIDtoProofName: UnitId -> Option String
 def UIDtoProofName (unitId as {path,hashSuffix}) =
    hashSuffix

 op SpecTermToSpecName: SCTerm -> (Option String)
 def SpecTermToSpecName (scterm as (term,_)) =
   case term of
     | UnitId rUID -> Some (showRelativeUID(rUID))
     | Spec _ -> None
     | _ -> None

 op proveInSpec: Option String * ClaimName * Spec * Option String * Spec * Spec * String * 
                 Assertions * List LispCell * String * Position -> SpecCalc.Env Boolean
 def proveInSpec (proof_name, claim_name, spc, spec_name, base_spc, rewrite_spc, prover_name,
		  assertions, prover_options, snarkLogFileName, pos) = {
   result <-
   let baseHypothesis = base_spc.properties in
   let rewriteHypothesis = rewrite_spc.properties in
   %let _ = debug("pinspec") in
   let findClaimInSpec = firstUpTo (fn (_, propertyName, _, _) -> claim_name = propertyName)
                                   spc.properties in
   case findClaimInSpec of
     | None -> raise (Proof (pos, "Claim name is not in spec."))
     | Some (claim, validHypothesis) ->
	 let actualHypothesis = actualHypothesis(validHypothesis, assertions, pos) in
	 let missingHypothesis = missingHypothesis(actualHypothesis, assertions) in
	   case missingHypothesis of 
		 | [] -> return (proveWithHypothesis(proof_name, claim, actualHypothesis, spc, spec_name, baseHypothesis, base_spc,
						     rewriteHypothesis, rewrite_spc,
						     prover_name, prover_options, snarkLogFileName))
		 | _ -> raise (Proof (pos, "assertion not in spec."));
   return result}

 op actualHypothesis: List Property * Assertions * Position -> List Property

 def actualHypothesis (validHypothesis, assertions, _ (* pos *)) =
     case assertions of
      | All -> validHypothesis
      | Explicit possibilities -> 
         let hypothesis = filter (fn (_, propertyName:String, _, _) -> member(propertyName, (possibilities:(List String)))) validHypothesis in
	   hypothesis

 op missingHypothesis: List Property * Assertions -> List ClaimName

 def missingHypothesis (actualHypothesis, assertions) =
     case assertions of
      | All -> []
      | Explicit possibilities -> 
         let missingHypothesis = filter (fn (claimName:ClaimName) -> ~(exists(fn (_, propName:ClaimName,_,_) -> claimName = propName) actualHypothesis)) possibilities in
	   missingHypothesis

 op displayProofResult: (Option String) * String * String * (Option String) * Boolean * String -> Boolean
 def displayProofResult(proof_name, claim_type, claim_name, spec_name, proved, snarkLogFileName) =
   let _ =
   case proof_name of
     | None -> 
         (case spec_name of
	   | None -> displaySingleAnonymousProofResult(claim_type, claim_name, proved)
	   | Some spec_name -> displaySingleProofResult(claim_type, claim_name, spec_name, proved))
     | Some proof_name ->
	 case spec_name of
	   | None -> displayMultipleAnonymousProofResult(proof_name, claim_type, claim_name, proved)
	   | Some spec_name -> 
	       displayMultipleProofResult(proof_name, claim_type, claim_name, spec_name, proved) in
   let _ = writeLine("    Snark Log file: " ^ snarkLogFileName) in
     proved


  def displaySingleAnonymousProofResult(claim_type, claim_name, proved) =
    let provedString = if proved then "is Proved!" else "is NOT proved." in
    let _ = writeLine(claim_type^" "^claim_name^" "^provedString) in
      proved

  def displaySingleProofResult(claim_type, claim_name, spec_name, proved) =
    let provedString = if proved then "is Proved!" else "is NOT proved." in
    let _ = writeLine(claim_type^" "^claim_name^" in "^spec_name^" "^provedString) in
      proved

  def displayMultipleAnonymousProofResult(proof_name, claim_type, claim_name, proved) =
    let provedString = if proved then "is Proved!" else "is NOT proved." in
    let _ = writeLine(proof_name^": "^claim_type^" "^claim_name^" "^provedString) in
      proved

  def displayMultipleProofResult(proof_name, claim_type, claim_name, spec_name, proved) =
    let provedString = if proved then "is Proved!" else "is NOT proved." in
    let _ = writeLine(proof_name^": "^claim_type^" "^claim_name^" in "^spec_name^" "^provedString) in
      proved

 op proveWithHypothesis: Option String * Property * List Property * Spec * Option String * List Property * Spec *
                         List Property * Spec *
                         String * List LispCell * String -> Boolean

 def proveWithHypothesis(proof_name, claim, hypothesis, spc, spec_name, base_hypothesis, base_spc,
			 rewrite_hypothesis, rewrite_spc,
			 prover_name, prover_options, snarkLogFileName) =
   let _ = debug("preovWithHyp") in
   let _ = if ~(prover_name = "Snark") then writeLine(prover_name ^ " is not supported; using Snark instead.") else () in
   let (claim_type,claim_name,_,_) = claim in
   let def claimType(ct) = 
         case ct of
	   | Conjecture -> "Conjecture" 
	   | Theorem -> "Theorem" 
	   | Axiom -> "Axiom" in
   let claim_type = claimType(claim_type) in
   let snarkSortDecls = snarkSorts(spc) in
   let snarkOpDecls = snarkOpDecls(spc) in
   let context = newContext in
   let snarkBaseHypothesis = map (fn (prop) -> snarkProperty(context, base_spc, prop))
                                 base_hypothesis in
   let snarkRewriteHypothesis = map (fn (prop) -> snarkRewrite(context, rewrite_spc, prop))
                                     rewrite_hypothesis in
   %let snarkHypothesis = map (fn (prop) -> snarkProperty(context, spc, prop)) hypothesis in
   let snarkSubsortHypothesis = snarkSubsortProperties(context, spc) in
   let snarkPropertyHypothesis = foldr (fn (prop, list) -> snarkPropertiesFromProperty(context, spc, prop)++list) [] hypothesis in
   let snarkHypothesis = snarkSubsortHypothesis ++ snarkPropertyHypothesis in
   let snarkConjecture = snarkConjectureRemovePattern(context, spc, claim) in
   let snarkEvalForm = makeSnarkProveEvalForm(prover_options, snarkSortDecls, snarkOpDecls, snarkBaseHypothesis, snarkRewriteHypothesis,
					      snarkHypothesis, snarkConjecture, snarkLogFileName) in
     let _ = if specwareDebug? then writeLine("Calling Snark by evaluating: ") else () in
     let _ = if specwareDebug? then LISP.PPRINT(snarkEvalForm) else Lisp.list [] in
     let result = Lisp.apply(Lisp.symbol("CL","FUNCALL"),
			     [Lisp.eval(Lisp.list [Lisp.symbol("CL","FUNCTION"),
						   Lisp.list [Lisp.symbol("SNARK","LAMBDA"),
							      Lisp.nil(),snarkEvalForm]])]) in
     let proved = ":PROOF-FOUND" = anyToString(result) in
     let _ = displayProofResult(proof_name, claim_type, claim_name, spec_name, proved, snarkLogFileName) in
       proved

 op makeSnarkProveEvalForm: List LispCell * List LispCell * List LispCell * List LispCell * List LispCell
                           * List LispCell * LispCell * String -> LispCell

 def makeSnarkProveEvalForm(prover_options, snarkSortDecl, snarkOpDecls, snarkBaseHypothesis, snarkRewriteHypothesis,
			    snarkHypothesis, snarkConjecture, snarkLogFileName) =
   %let _ = if specwareDebug? then toScreen("Proving snark fmla: ") else () in
   %let _ = if specwareDebug? then LISP.PPRINT(snarkConjecture) else Lisp.list [] in
   %let _ = if specwareDebug? then writeLine(" using: ") else () in
   %let _ = if specwareDebug? then LISP.PPRINT(Lisp.list(snarkHypothesis)) else Lisp.list [] in

   	 Lisp.list 
	 [Lisp.symbol("CL-USER","WITH-OPEN-FILE"),
	  Lisp.list [Lisp.symbol("CL-USER","LOGFILE"),
		     Lisp.string(snarkLogFileName),
		     Lisp.symbol("KEYWORD","DIRECTION"),
		     Lisp.symbol("KEYWORD","OUTPUT"),
		     Lisp.symbol("KEYWORD","IF-EXISTS"),
		     Lisp.symbol("KEYWORD","SUPERSEDE")],
	  Lisp.list
	  [
	   Lisp.symbol("CL","LET"),
	   Lisp.list [Lisp.list [Lisp.symbol("CL-USER","*ERROR-OUTPUT*"),
				 Lisp.symbol("CL-USER","LOGFILE")],
		      Lisp.list [Lisp.symbol("CL-USER","*STANDARD-OUTPUT*"),
				 Lisp.symbol("CL-USER","LOGFILE")]],
	   Lisp.list([Lisp.symbol("SNARK","INITIALIZE")]),
	   Lisp.list([Lisp.symbol("SNARK","RUN-TIME-LIMIT"), Lisp.nat(20)]),
           Lisp.list([Lisp.symbol("SNARK","ASSERT-SUPPORTED"), Lisp.bool(false)]),
           Lisp.list([Lisp.symbol("SNARK","USE-LISP-TYPES-AS-SORTS"), Lisp.bool(true)]),
           Lisp.list([Lisp.symbol("SNARK","USE-CODE-FOR-NUMBERS"), Lisp.bool(true)]),
           Lisp.list([Lisp.symbol("SNARK","USE-CODE-FOR-NUMBERS"), Lisp.bool(true)]),
           Lisp.list([Lisp.symbol("SNARK","USE-NUMBERS-AS-CONSTRUCTORS"), Lisp.bool(true)]),
	   Lisp.list([Lisp.symbol("SNARK","USE-RESOLUTION"), Lisp.bool(true)])
	  ]
	  Lisp.++ (Lisp.list snarkSortDecl)
	  Lisp.++ (Lisp.list snarkOpDecls)
	  Lisp.++ (Lisp.list prover_options)
	  Lisp.++ (Lisp.list snarkBaseHypothesis)
	  Lisp.++ (Lisp.list snarkRewriteHypothesis)
	  Lisp.++ (Lisp.list baseAxioms)
	  Lisp.++ (Lisp.list snarkHypothesis)
	  Lisp.++ (Lisp.list [snarkConjecture])]


}

