StacksAsVectors =
StacksAsVectors qualifying
spec
  %import Sets % didn't seem needed.

  type VStack a = Map(Nat,a) * Nat

  type Map(a,b) %TODO why not import Maps here?

 %TODO do we need V_apply? V_domainToList?  V_imageToList? V_foldi?
  op MapVec.V_apply : [key,a] Map(key,a) * key -> Option a
  op MapVec.V_empty_map : [key,a] Map (key,a)
  op MapVec.V_update :  [key,a] Map (key,a) * key * a -> Map (key,a)
  op MapVec.V_domainToList : [key,a] Map (key,a) -> List key
  op MapVec.V_imageToList : [key,a] Map (key,a) -> List a                   % was rangeToList
  op MapVec.V_eval  : [key,a] Map(key,a) * key -> a
  op MapVec.V_foldi : [key, a, b] (key * a * b -> b) * b * Map(key,a) -> b

  op [a] empty_stack : VStack a = 
          (MapVec.V_empty_map, 0)

  op [a] empty_stack? (stk:VStack a) : Boolean = 
          (stk.2 = 0)

  op [a] push (elt:a, stk:VStack a): VStack a =
    (MapVec.V_update(stk.1, stk.2, elt), stk.2 + 1)

  %TODO precondition about the stack being non-empty?
  op [a] top (stk:VStack a): a =
     MapVec.V_eval(stk.1, stk.2 - 1)

  %TODO precondition about the stack being non-empty?  
  % This does not remove the element from the map.  It just adjusts the stack
  % height so that the top element becomes invalid.  I wonder if it would ever
  % make sense to remove it (e.g., so that it could be garbage collected).  
  op [a] pop (stk:VStack a): VStack a = (stk.1, (stk.2) - 1)

  op [a] pushl (lst:List a, stk:VStack a): VStack a = 
     push_aux(reverse(lst),stk)

  op [a] push_aux (lst:List a, stk:VStack a): VStack a =
    case lst of
      | [] -> stk
      | elt::y -> push_aux(y, push(elt, stk))

  theorem empty_stack is [a]
    fa(stk:VStack a)((stk = empty_stack) = (stk.2 = 0))

end-spec


S = morphism Stacks -> StacksAsVectors {Stack +-> VStack}