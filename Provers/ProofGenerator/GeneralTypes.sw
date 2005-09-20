spec

  % API private all

  import ../ProofChecker/Spec
  import ContextAPI, TypesAndExpressionsAPI, SubTypeProofs
  
  op mostGeneralType: (Proof * Context) -> Type -> Proof * Type
  def mostGeneralType(cxP, cx) t =
    let supT = mostGeneralTypeAux(cxP, cx) t in
    let (subTypeP, _) = subTypeProof(cxP, cx, t, supT) in
    (subTypeP, supT)

  op mostGeneralTypeAux: (Proof * Context) -> Type -> Type
  def mostGeneralTypeAux(cxP, cx) t =
    case t of
      | BOOL -> t
      | VAR _ -> t
      | TYPE _ -> t
      | ARROW _ -> mostGeneralTypeArrow(cxP, cx, t)
      | RECORD _ -> mostGeneralTypeRecord(cxP, cx, t)
      | SUM _ -> mostGeneralTypeSum(cxP, cx, t)
      | RESTR _ -> mostGeneralTypeRestr(cxP, cx, t)
      | QUOT _ -> mostGeneralTypeQuot(cxP, cx, t)

  op mostGeneralTypeArrow: Proof * Context * ARROWType -> Type
  def mostGeneralTypeArrow(cxP, cx, t) =
    let dT = domain(t) in
    let rT = range(t) in
    let mgrt = mostGeneralTypeAux(cxP, cx) rT in
    let mgT = ARROW(dT, mgrt) in
    mgT

  op mostGeneralTypeRecord: Proof * Context * RECORDType -> Type
  def mostGeneralTypeRecord(cxP, cx, t) =
    let rfs = RECfields(t) in
    let rts = RECtypes(t) in
    let mgTs = map (mostGeneralTypeAux(cxP, cx)) rts in
    let mgT = RECORD(rfs, mgTs) in
    mgT

  op mostGeneralTypeSum: Proof * Context * SUMType -> Type
  def mostGeneralTypeSum(cxP, cx, t) =
    let cnstrs = SUMcnstrs(t) in
    let typs = SUMtypes(t) in
    let mgTs = map (mostGeneralTypeAux(cxP, cx)) typs in
    let mgT = SUM(cnstrs, mgTs) in
    mgT

  op mostGeneralTypeRest: Proof * Context * RESTRType -> Type
  def mostGeneralTypeRestr(cxP, cx, t) =
    superType(t)

  op mostGeneralTypeQuot: Proof * Context * QUOTType -> Type
  def mostGeneralTypeQuot(cxP, cx, t) = t

endspec
