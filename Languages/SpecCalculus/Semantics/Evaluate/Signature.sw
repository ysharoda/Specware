\section{Evalution of a term in the Spec Calculus}

\begin{spec}
SpecCalc qualifying spec {
  import ../../AbstractSyntax/Types
  import ../Environment

  sort SCTerm = SpecCalc.Term Position

  %% Generic mechanism:

  op evaluateTerm        : SCTerm                                                                   -> SpecCalc.Env Value
  op evaluateLet         : List (Decl Position) -> SCTerm                                           -> SpecCalc.Env ValueInfo

  %% Specific kinds of terms:

  op evaluateReturnURI   : Position -> RelativeURI -> Env (ValueInfo * URI)
  op evaluateURI         : Position -> RelativeURI                                                  -> SpecCalc.Env ValueInfo
  op evaluateSpec        : List (SpecElem Position)                                     -> Position -> SpecCalc.Env ValueInfo
  op evaluateSpecMorph   : SCTerm * SCTerm * (List (SpecMorphRule Position))                        -> SpecCalc.Env ValueInfo
  op evaluateExtendMorph : SCTerm                                                                   -> SpecCalc.Env ValueInfo
  op evaluateLispCompile : ValueInfo * SCTerm * Option String                                       -> SpecCalc.Env ValueInfo
  op evaluateDiag        : List (DiagElem Position)                                                 -> SpecCalc.Env ValueInfo
  op evaluateDiagMorph   : SCTerm * SCTerm * (List (DiagMorphRule Position))                        -> SpecCalc.Env ValueInfo
  op evaluateColimit     : SCTerm                                                                   -> SpecCalc.Env ValueInfo
  op evaluateTermInfo    : SCTerm                                                                   -> SpecCalc.Env ValueInfo
  op evaluatePrint       : SCTerm                                                                   -> SpecCalc.Env ValueInfo
  op evaluateQualify     : SCTerm -> Qualifier                                                      -> SpecCalc.Env ValueInfo
  op evaluateTranslate   : SCTerm -> TranslateExpr Position                                         -> SpecCalc.Env ValueInfo
  op evaluateSubstitute  : SCTerm * SCTerm                                              -> Position -> SpecCalc.Env ValueInfo
  op evaluateProve       : ClaimName * SCTerm * ProverName * Assertions * ProverOptions -> Position -> SpecCalc.Env ValueInfo
  op evaluateObligations : SCTerm                                                                   -> SpecCalc.Env ValueInfo
  op evaluateGenerate    : String * SCTerm * Option String -> Position -> SpecCalc.Env ValueInfo

  op setBaseToPath : String -> Env ()
  op reloadBase : Env ()

  %% Hook for extensions to specware
  op evaluateOther       : OtherTerm Position -> Position -> SpecCalc.Env ValueInfo
  op evaluateOtherSpecMorph :
       ValueInfo
    -> ValueInfo
    -> List (SpecMorphRule Position)
    -> Position
    -> SpecCalc.Env ValueInfo

  op SpecCalc.evaluateOtherSubstitute :
       ValueInfo
    -> ValueInfo
    -> SCTerm
    -> Position
    -> SpecCalc.Env ValueInfo

  op evaluateOtherPrint : OtherValue -> Position -> SpecCalc.Env ()

  op evaluateOtherGenerate :
       String * SCTerm * Option String
    -> OtherValue * TimeStamp * URI_Dependency
    -> Position
    -> SpecCalc.Env ValueInfo

  %% Lower-level support routines:

  op getURI : SCTerm -> SpecCalc.Env URI
  op coerceToSpec : Value -> Value

  op Specware.toplevelHandler : Exception -> SpecCalc.Env Boolean
}
\end{spec}
