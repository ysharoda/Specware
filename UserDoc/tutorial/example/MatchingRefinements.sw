Symbols = spec

  sort Symbol = (Char | isUpperCase)

end

Symbols_Ref = morphism MatchingSpecs#Symbols ->
                       MatchingRefinements# Symbols {}


WordMatching0 = spec

  import MatchingSpecs#Words
  import MatchingSpecs#Messages
  import MatchingSpecs#SymbolMatching

  op word_matches_at? : Word * Message * Nat -> Boolean
  def word_matches_at?(wrd,msg,pos) =
      if pos + length wrd > length msg
      then false
      else word_matches_aux?(wrd,
                             if pos = 0 then msg else nthTail(msg, pos - 1))

  op word_matches_aux? : {(wrd,msg) : Word * Message |
                          length wrd <= length msg} -> Boolean
  def word_matches_aux?(wrd,msg) =
      case wrd of Nil -> true
                | Cons(wsym,wrd1) -> let Cons(msym,msg1) = msg in
                                         if symb_matches?(wsym,msym)
                                         then word_matches_aux?(wrd1,msg1)
                                         else false

end

WordMatching_Ref0 = morphism MatchingSpecs#WordMatching ->
                             WordMatching0 {}


WordMatching = colimit diagram {
  ab : a -> b +-> Symbols_Ref,
  ac : a -> c +-> morphism MatchingSpecs#Symbols -> WordMatching0 {}
}

WordMatching_Ref = morphism MatchingSpecs#WordMatching ->
                            MatchingRefinements#WordMatching {}


FindMatches0 = spec

  import MatchingSpecs#WordMatching
  import MatchingSpecs#Matches

  op find_matches : Message * List Word -> List Match
  def find_matches(msg,wrds) =
      foldl (fn(wrd,mtchs) ->
               case find_matches_aux(msg,wrd,0)
                 of Some pos -> Cons({word = wrd, position = pos}, mtchs)
                  | None -> mtchs)
            Nil
            wrds

  op find_matches_aux : Message * Word * Nat -> Option Nat
  def find_matches_aux(msg,wrd,pos) =
      if pos + length wrd > length msg
      then None
      else if word_matches_at?(wrd,msg,pos)
           then Some pos
           else find_matches_aux(msg, wrd, pos + 1)

end

FindMatches_Ref0 = morphism MatchingSpecs#FindMatches -> FindMatches0 {}


FindMatches = colimit diagram {
  ab : a -> b +-> WordMatching_Ref,
  ac : a -> c +-> morphism MatchingSpecs#WordMatching -> FindMatches0 {}
}

FindMatches_Ref = morphism MatchingSpecs#FindMatches ->
                           MatchingRefinements#FindMatches {}
