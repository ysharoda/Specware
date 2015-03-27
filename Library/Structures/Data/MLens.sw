MLens qualifying spec
import Monad

(* Monadic lenses are like lenses (see Lens.sw), but where the getter
   and setter functions are monadic. The monadic lens laws are:

     {b <- get a; set a b}       = {get a; return a}
     {a' <- set a b; get a'}     = {set a b; return b}
     {a' <- set a b1; set a' b2} = set a b2

   These are almost the same as the normal lens laws: rule 1 says that
   getting the value of a and then setting this value to itself is a
   essentially no-op; however, the read itself could have a
   side-effect, so it remains in the simpler right-hand side.
   Similarly, rule 2 says that setting a value and then reading it
   again just returns the value set; again, the set remains on the
   right-hand side, since it could have side-effects. Finally, rule 3
   says that any set erases any previous sets.
*)

(* The "raw" type of monadic lenses, without the laws *)
type RawMLens (a,b) = { mlens_get : a -> Monad b,
                        mlens_set : a -> b -> Monad a }

(* The monadic lens laws *)
op [a,b] satisfies_get_put_m (l:RawMLens (a,b)) : Bool =
  fa (a) {b <- l.mlens_get a; l.mlens_set a b} = {l.mlens_get a; return a}
op [a,b] satisfies_put_get_m (l:RawMLens (a,b)) : Bool =
  fa (a,b)
    {a' <- l.mlens_set a b; l.mlens_get a'} =
    {a' <- l.mlens_set a b; return b}
op [a,b] satisfies_put_put_m (l:RawMLens (a,b)) : Bool =
  fa (a,b1,b2)
    {a' <- l.mlens_set a b1; l.mlens_set a' b2} = l.mlens_set a b2

(* The complete type of monadic lenses *)
type MLens (a,b) =
  { l : RawMLens (a,b) |
     satisfies_get_put_m l && satisfies_put_get_m l && satisfies_put_put_m l }

(* Compose two monadic lenses *)
op [a,b,c] mlens_compose (l1 : MLens (a,b), l2 : MLens (b,c)) : MLens (a,c) =
   {mlens_get = (fn a -> {b <- l1.mlens_get a; l2.mlens_get b}),
    mlens_set = (fn a -> fn c ->
                   {b <- l1.mlens_get a;
                    b_new <- l2.mlens_set b c;
                    l1.mlens_set a b_new})}

(* The monadic lens for getting / setting a specific key in a map. It
   is an error to get or set a key not already in the map; the error
   computations are passed in as arguments so that we don't have to
   import MonadError (which makes it easier to use Option instead) *)
op [a,b] mlens_of_key (key:a, getErr:Monad b, setErr:Monad (a -> Option b)) : MLens ((a -> Option b),b) =
   {mlens_get = (fn m -> mapOptionDefault return getErr (m key)),
    mlens_set = (fn m -> fn b ->
                   case m key of
                     | None -> setErr
                     | Some _ ->
                       return (fn a -> if a = key then Some b else m a)) }

(* The monadic lens for the ith element of a list. As with
   mlens_of_key, it is an error in both the get and the set if a list
   does not have an ith element. *)
op [a] mlens_of_list_index (i:Nat, getErr:Monad a, setErr:Monad (List a)) : MLens (List a, a) =
    {mlens_get = (fn l -> if i < length l then return (l @ i) else getErr),
     mlens_set = (fn l -> fn a ->
                    if i < length l then return (update (l,i,a)) else setErr)}

(* FIXME: prove the subtyping constraints! *)

end-spec
