(* The identity monad *)

IdentityM = Monad qualifying spec
  type Monad a = a

  op [a,b] monadBind (m: Monad a, f: a -> Monad b) : Monad b = f m
  op [a,b] monadSeq (m1: Monad a, m2: Monad b) : Monad b = m2
  op [a] return (x:a) : Monad a = x

  theorem left_unit  is [a,b]
    fa (f: a -> Monad b, x: a) monadBind (return x, f) = f x

  theorem right_unit is [a]
    fa (m: Monad a) monadBind (m, return) = m

  theorem associativity is [a,b,c]
    fa (m: Monad a, f: a -> Monad b, h: b -> Monad c)
      monadBind (m, fn x -> monadBind (f x, h)) = monadBind (monadBind (m, f), h)

  theorem non_binding_sequence is [a]
    fa (f :Monad a, g: Monad a)
    monadSeq (f, g) = monadBind (f, fn _ -> g) 

  proof Isa left_unit
    by (simp add: return_def monadBind_def)
  end-proof

  proof Isa right_unit
    by (simp add: return_def monadBind_def)
  end-proof

  proof Isa associativity
    by (simp add: monadBind_def)
  end-proof

  proof Isa non_binding_sequence
    by (auto simp add: monadSeq_def monadBind_def)
  end-proof

end-spec


% The morphism that instantiates a monad into the identity monad
Identity_M = morphism ../Monad -> IdentityM { }
