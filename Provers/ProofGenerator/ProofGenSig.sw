ProofGenerator qualifying
spec

  import ../ProofChecker/Spec

  op typeExpProof: Proof * Context * Expression -> Proof * Type
  op contextProof: Context -> Proof
  op typeProof:    Proof * Context * Type -> Proof


endspec

