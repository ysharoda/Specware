\section{Specware 4 Toplevel Specification}

This constructs Specware and refines various abstract sorts.

\begin{spec}
let Specware4 = spec {
  import /Languages/SpecCalculus/Semantics/Specware
  import /Languages/SpecCalculus/Semantics/Evaluate/NoOther

  import PolyMap qualifying /Library/Structures/Data/Maps/Polymorphic/AsLists
  import Cat qualifying
    /Library/Structures/Data/Categories/Cocomplete/Polymorphic/AsRecord
  import Functor qualifying
    /Library/Structures/Data/Categories/Functors/FreeDomain/Polymorphic/AsRecord
  import Cat qualifying
    /Library/Structures/Data/Categories/Diagrams/Polymorphic/AsRecord
  import Sketch qualifying
    /Library/Structures/Data/Categories/Sketches/Monomorphic/AsRecord
  import Vertex qualifying
    /Library/Structures/Data/Sets/Monomorphic/AsLists
  import Edge qualifying
    /Library/Structures/Data/Sets/Monomorphic/AsLists
  import Sketch qualifying 
    /Library/Structures/Data/Maps/Monomorphic/AsLists
  import NatTrans qualifying
    /Library/Structures/Data/Categories/NatTrans/FreeFunctorDomain/Polymorphic/AsRecord
} in
  generate lisp Specware4
\end{spec}
