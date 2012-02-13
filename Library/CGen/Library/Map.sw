Map qualifying spec

import Set

% ------------------------------------------------------------------------------
% ---------- Part 1: Specifications --------------------------------------------
% ------------------------------------------------------------------------------


(* We model a map from A to B as a "partial" function from A to B, where
"partiality" is realized via Option. (Recall that in Metaslang all functions are
total.) *)

type Map(a,b) = a -> Option b

% -------------------------------------------------------------
% domain and range:

op [a,b] domain (m:Map(a,b)) : Set a = fn x:a -> m x ~= None

op [a,b] range (m:Map(a,b))  : Set b = fn y:b -> (ex(x:a) m x = Some y)


% -------------------------------------------------------------
% forward and backward composition:

op [a,b,c] :> (m1:Map(a,b), m2:Map(b,c)) infixl 24 : Map(a,c) =
  fn x:a -> case m1 x of Some y -> m2 y | None -> None

op [a,b,c] o (m1:Map(b,c), m2:Map(a,b)) infixl 24 : Map(a,c) = m2 :> m1

% -------------------------------------------------------------
% application of map to element in domain:

op [a,b] @ (m:Map(a,b), x:a | x in? domain m) infixl 30 : b =
  let Some y = m x in y
proof Isa -> @_m end-proof              % Avoid overloading

% -------------------------------------------------------------
% (strict) sub/supermap:

op [a,b] <= (m1:Map(a,b), m2:Map(a,b)) infixl 20 : Bool =
  fa(x:a) x in? domain m1 => m1 x = m2 x

op [a,b] < (m1:Map(a,b), m2:Map(a,b)) infixl 20 : Bool =
  m1 <= m2 && m1 ~= m2
proof Isa -> <_m end-proof              % Avoid overloading

op [a,b] >= (m1:Map(a,b), m2:Map(a,b)) infixl 20 : Bool =
  m2 <= m1

op [a,b] > (m1:Map(a,b), m2:Map(a,b)) infixl 20 : Bool =
  m2 < m1
proof Isa -> >_m end-proof              % Avoid overloading

% -------------------------------------------------------------
% empty map:

op [a,b] empty : Map(a,b) = fn x:a -> None

op [a,b] empty? (m:Map(a,b)) : Bool = (m = empty)


% -------------------------------------------------------------
% update map at point(s) (analogous to record update):

op [a,b] <<< (m1:Map(a,b), m2:Map(a,b)) infixl 25 : Map(a,b) =
  fn x:a -> case m2 x of Some y -> Some y | None -> m1 x

op [a,b] update (m: Map(a,b)) (x:a) (y:b) : Map(a,b) =
  fn z:a -> if z = x then Some y else m z

% -------------------------------------------------------------
% restrict domain/range to set:

op [a,b] restrictDomain (m:Map(a,b), xS:Set a) infixl 25 : Map(a,b) =
  fn x:a -> if x in? xS then m x else None

op [a,b] restrictRange (m:Map(a,b), yS:Set b) infixl 25 : Map(a,b) =
  fn x:a -> if x in? domain m && (m @ x) in? yS then m x else None

% -------------------------------------------------------------
% remove domain value(s) from map:

op [a,b] -- (m:Map(a,b), xS:Set a) infixl 25 : Map(a,b) =
  fn x:a -> if x in? xS then None else m x
proof Isa -> --_m end-proof

op [a,b] - (m: Map(a,b), x:a) infixl 25 : Map(a,b) = m -- single x
proof Isa -> mless [simp] end-proof

% -------------------------------------------------------------
% injectivity:

op [a,b] injective? (m:Map(a,b)) : Bool =
  fa (x1:a, x2:a) x1 in? domain m && x2 in? domain m && m x1 = m x2 => x1 = x2

type InjectiveMap(a,b) = (Map(a,b) | injective?)
proof Isa -typedef 
 by (rule_tac x="Map__update empty x y" in exI,
     simp add: mem_def Map__injective_p_def Map__update_def dom_if Collect_def)
end-proof


% -------------------------------------------------------------
% cardinalities:

op [a,b] finite?      (m:Map(a,b)) : Bool = finite?      (domain m)
op [a,b] infinite?    (m:Map(a,b)) : Bool = infinite?    (domain m)
op [a,b] countable?   (m:Map(a,b)) : Bool = countable?   (domain m)
op [a,b] uncountable? (m:Map(a,b)) : Bool = uncountable? (domain m)

type      FiniteMap(a,b) = (Map(a,b) | finite?)
proof Isa -typedef 
 by (rule_tac x="empty" in exI, simp add: mem_def Map__finite_p_def Collect_def)
end-proof


theorem FiniteMap_finite is  [a,b] fa (m:FiniteMap(a,b)) finite? m


theorem update_preserves_finite1 is [a,b]
  fa (m:Map(a,b), x:a, y:b) finite? (domain (update m x y)) = finite? (domain m)

theorem update_preserves_finite is [a,b]
  fa (m:Map(a,b), x:a, y:b) finite? (update m x y) = finite? m

type    InfiniteMap(a,b) = (Map(a,b) | infinite?)
type   CountableMap(a,b) = (Map(a,b) | countable?)
type UncountableMap(a,b) = (Map(a,b) | uncountable?)

% -------------------------------------------------------------
% convert association list to map:

op [a,b] fromAssocList
   (alist: List (a * b) | let (xs,_) = unzip alist in noRepetitions? xs)
   : FiniteMap (a, b) =
  let (xs,ys) = unzip alist in
  fn x:a -> if x in? xs then Some (ys @ (positionOf(xs,x))) else None

% ------------------------------------------------------------------------------
% ---------- Part 2: Theorems about properties of operations -------------------
% ------------------------------------------------------------------------------


% ------------------------------------------------------------------------------
% ---------- Part 3: Main theorems ---------------------------------------------
% ------------------------------------------------------------------------------

% ------------------------------------------------------------------------------
% ---------- Part 4: Theory Morphisms ------------------------------------------
% ------------------------------------------------------------------------------


% ------------------------------------------------------------------------------
% ---------- Mapping to Isabelle -----------------------------------------------
% ------------------------------------------------------------------------------


proof Isa Thy_Morphism Map
  type Map.Map       -> map
  Map.domain         -> dom
  Map.range          -> ran
  Map.:>             -> o_m                 Left  55 reversed
  Map.o              -> o_m                 Left  55
  Map.<=             -> \<subseteq>\<^sub>m Left  50
  Map.empty          -> empty
  Map.<<<            -> ++                  Left 100
  Map.restrictDomain -> |`                  Left 110
end-proof



% ------------------------------------------------------------------------------
% ---------- Part 5: The proofs ------------------------------------------------
% ------------------------------------------------------------------------------
% Note: for the time being we place Isabelle lemmas that are needed for a proof 
%       and cannot be expressed in SpecWare as "verbatim" lemmas into the
%       preceeding proofs 
% ------------------------------------------------------------------------------


proof Isa range__def
 by (auto simp: ran_def)
end-proof

proof Isa e_lt_eq__def
  by (auto simp: map_le_def)
end-proof

proof Isa empty_p [simp] end-proof

proof Isa e_lt_lt_lt__def
  by (auto simp: map_add_def split: option.split)
end-proof

proof Isa e_lt_lt_lt__def1
  by (auto simp: map_add_def)
end-proof

proof Isa finite_p [simp] end-proof

proof Isa FiniteMap_finite [simp]
  by (case_tac "m",
      simp add: Abs_Map__FiniteMap_inverse Map__FiniteMap_def 
                Collect_def mem_def)

(******************************************************************************)
declare Rep_Map__FiniteMap_inverse [simp add]
declare Abs_Map__FiniteMap_inverse [simp add]
(******************************************************************************)

(* Here is a very specific form that I need *)

lemma Map__FiniteMap_has_finite_domain [simp]:
  "finite (dom (Rep_Map__FiniteMap m))"
  by (case_tac "m",
      simp add: Abs_Map__FiniteMap_inverse Map__FiniteMap_def 
                Collect_def mem_def)

lemma Rep_Map__FiniteMap_simp [simp]:
  "\<lbrakk>Map__finite_p y\<rbrakk> \<Longrightarrow>  (Rep_Map__FiniteMap x = y) = (x = Abs_Map__FiniteMap y)"
apply (subst Abs_Map__FiniteMap_inject [symmetric],
       simp add: Rep_Map__FiniteMap,
       simp add: Map__FiniteMap_def Collect_def mem_def,
       simp add: Rep_Map__FiniteMap_inverse)
(******************************************************************************)

end-proof


proof Isa update_preserves_finite1 [simp]
  apply (auto simp add: Map__update_def mem_def dom_if)
  apply (erule rev_mp,
         rule_tac t="{z. z \<noteq> x}" and s="UNIV - {x}" in subst, 
         auto simp add: Diff_Int_distrib)
end-proof

proof Isa update_preserves_finite1 [simp] end-proof

proof Isa fromAssocList_Obligation_subtype 
  by (simp add: member_def dom_if)
end-proof

proof Isa fromAssocList_Obligation_subtype1
  apply (cut_tac d__x=alist in List__unzip_subtype_constr)  
  apply (auto simp add: Collect_def dom_if member_def 
         List__positionOf_def List__theElement_def)
  apply (rule the1I2,
         rule List__theElement_Obligation_the, 
         rule List__positionOf_Obligation_subtype,
         simp_all add: member_def List__positionsOf_subtype_constr)
  apply (simp add: List__positionsOf_def List__positionsSuchThat_def)
  apply (rotate_tac -1, erule rev_mp)
  apply (rule the1I2,
         cut_tac l=xs_1 and p="\<lambda>z. z=x" 
            in List__positionsSuchThat_Obligation_the, 
         simp, clarify)
  apply (drule spec, auto)

(******************************************************************************
*** Note the correct type of Map__fromAssocList__stp is
consts Map__fromAssocList__stp :: "('a \<Rightarrow> bool) \<Rightarrow> 
                                   ('a \<times> 'b) list \<Rightarrow>  ('a, 'b)Map__FiniteMap"
******************************************************************************)

end-proof
  

% ------------------------------------------------------------------------------
% ---------- Part 6: verbatim Isabelle lemmas             ----------------------
% ----------         that cannot be expressed in SpecWare ----------------------
% ------------------------------------------------------------------------------


%  ---------- most of the following can be converted into SpecWare Theorems 
% ----------- need to do this later

proof Isa -verbatim

(******************************************************************************)
lemma finiteRange [simp]: 
  "finite  (\<lambda> (x::int). l \<le> x \<and> x \<le> u)"
  by (rule_tac t="\<lambda>x. l \<le> x \<and> x \<le> u" and  s="{l..u}" 
      in subst, simp_all,
      auto simp add: atLeastAtMost_def atLeast_def atMost_def mem_def)

lemma finiteRange2 [simp]: 
  "finite  (\<lambda>(x::int). l \<le>  x \<and>  x < u)"
  by (rule_tac t="\<lambda>(x::int). l \<le>  x \<and>  x < u" and  s="{l..u - 1}" 
      in subst, simp_all,
      auto simp add: atLeastAtMost_def atLeast_def atMost_def mem_def)

(******************************************************************************)

(******* ZIP ... move into the base libraries ********)

lemma List__unzip_zip_inv [simp]:
  "\<lbrakk>l1 equiLong l2\<rbrakk> \<Longrightarrow> List__unzip (zip l1 l2) = (l1,l2)"
  apply (simp add: List__unzip_def del: List__equiLong_def)
  apply (rule_tac t="zip l1 l2"
              and s="(\<lambda>(x_1, x_2). zip x_1 x_2)(l1,l2)" in subst, simp)
  apply (cut_tac List__unzip_Obligation_subtype,
         simp only: TRUE_def Function__bijective_p__stp_univ)
  apply (subst Function__inverse__stp_simp, simp)
  apply (subst inv_on_f_f, simp_all add: bij_on_def mem_def)
done

lemma List__unzip_as_zip [simp]:
  "\<lbrakk>List__unzip l = (l1,l2)\<rbrakk> \<Longrightarrow>  l = (zip l1 l2)"
  apply (simp add: List__unzip_def del: List__equiLong_def)
  apply (rule_tac t="zip l1 l2" and s="split zip (l1,l2)" in subst, simp)
  apply (drule sym, erule ssubst)
  apply (cut_tac List__unzip_Obligation_subtype,
         simp only: TRUE_def Function__bijective_p__stp_univ)
  apply (subst Function__inverse__stp_simp, auto)
  apply (cut_tac y=l and f="split zip" and A="\<lambda>(x, y). x equiLong y" 
             and B=UNIV in surj_on_f_inv_on_f)
  apply (simp_all add: bij_on_def del: List__equiLong_def)
done

lemma List__unzip_zip_conv:
  "\<lbrakk>l1 equiLong l2\<rbrakk> \<Longrightarrow> (List__unzip l = (l1,l2)) = (l = (zip l1 l2))"
  by auto

lemma List__unzip_empty [simp]:
  "List__unzip [] = ([],[])"
  by (simp add:  List__unzip_zip_conv)

lemma List__unzip_singleton [simp]:
  "List__unzip [(x,y)] = ([x],[y])"
  by (simp add:  List__unzip_zip_conv)

lemma List__unzip_cons [simp]:
  "\<lbrakk>List__unzip l = (l1,l2)\<rbrakk> \<Longrightarrow> List__unzip ((x,y) # l) = (x#l1,y#l2)"
  by (cut_tac d__x=l in List__unzip_subtype_constr,
      simp add: List__unzip_zip_conv)

lemma List__unzip_append [simp]:
  "\<lbrakk>List__unzip l = (l1,l2); List__unzip l' = (l1',l2')\<rbrakk>
   \<Longrightarrow> List__unzip (l @ l') = (l1@l1', l2@l2')"
  by (cut_tac d__x=l in List__unzip_subtype_constr,
      cut_tac d__x="l'" in List__unzip_subtype_constr,
      simp add: List__unzip_zip_conv)

lemma List__unzip_snoc [simp]:
  "\<lbrakk>List__unzip l = (l1,l2)\<rbrakk>
   \<Longrightarrow> List__unzip (l @ [(x,y)]) = (l1@[x], l2@[y])"
  by simp

lemma List__unzip_double [simp]:
  "List__unzip [(x,y),(u,v)] = ([x,u],[y,v])"
  by simp

(******* Increasing ********)


lemma List__increasingNats_p_nil [simp]:
   "List__increasingNats_p []"
  by (simp add: List__increasingNats_p_def)

lemma List__increasingNats_p_snoc [simp]:
   "List__increasingNats_p (l @ [i]) = 
        (List__increasingNats_p l \<and> (\<forall>j \<in> set l. j < i))"
  by (auto simp add: List__increasingNats_p_def 
                     nth_append not_less set_conv_nth,
      induct_tac ia rule: strict_inc_induct, auto)


(****** Positions *********)

lemma List__positionsSuchThat_distinct [simp]: 
  "distinct (List__positionsSuchThat(l, p))"
  by (simp add: List__positionsSuchThat_subtype_constr)

lemma List__positionsSuchThat_increasing [simp]: 
  "List__increasingNats_p (List__positionsSuchThat(l, p))"
  by (simp add: List__positionsSuchThat_def,
      rule the1I2, 
      simp_all add: List__positionsSuchThat_Obligation_the)

lemma List__positionsSuchThat_membership [simp]: 
  "i mem  List__positionsSuchThat(l, p) = (i < length l \<and> p (l ! i))"
  by (simp add: List__positionsSuchThat_def,
      rule the1I2, 
      simp_all add: List__positionsSuchThat_Obligation_the)

lemma List__positionsSuchThat_membership2 [simp]: 
  "i \<in> set (List__positionsSuchThat(l, p)) = (i < length l \<and> p (l ! i))"
  by simp

lemma List__positionsSuchThat_nil [simp]:
  "List__positionsSuchThat ([], p) = []"
  by (simp add: List__positionsSuchThat_def member_def,
      rule the_equality, auto)

lemma List__positionsSuchThat_snoc1 [simp]:
  "\<lbrakk>p x\<rbrakk> \<Longrightarrow> 
   List__positionsSuchThat (l@[x], p) = List__positionsSuchThat (l, p) @ [length l]"
  apply (subst List__positionsSuchThat_def, simp)
  apply (rule the_equality, simp add: member_def nth_append, safe, simp_all)
  apply (simp add: List__positionsSuchThat_def)
  apply (rule the1I2, simp add: List__positionsSuchThat_Obligation_the)
  apply (simp add: list_eq_iff_nth_eq, subst conj_imp [symmetric], safe)
  (*** this is actually quite complex - prove it later ***)
  (*** Must reason about distinct, increasing at the same time ***)
sorry

lemma List__positionsSuchThat_snoc2 [simp]:
  "\<lbrakk>\<not> (p x)\<rbrakk> \<Longrightarrow> 
   List__positionsSuchThat (l@[x], p) = List__positionsSuchThat (l, p)"
  apply (subst List__positionsSuchThat_def, simp)
  apply (rule the_equality, simp add: member_def nth_append, safe)
  apply (simp add: List__positionsSuchThat_def)
  apply (rule the1I2, simp add: List__positionsSuchThat_Obligation_the)
  apply (simp add: list_eq_iff_nth_eq, subst conj_imp [symmetric], safe)
  (*** this is actually quite complex - prove it later ***)
sorry

lemma List__positionsOf_nil [simp]:
  "List__positionsOf ([], x) = []"
  by (simp add: List__positionsOf_def)

lemma List__positionsOf_snoc1 [simp]:
  "List__positionsOf (l@[x], x) = List__positionsOf (l, x) @ [length l]"
  by (simp add: List__positionsOf_def)

lemma List__positionsOf_snoc2 [simp]:
  "\<lbrakk>a \<noteq> x\<rbrakk> \<Longrightarrow> List__positionsOf (l @ [a], x) = List__positionsOf (l, x)"
  by (simp add: List__positionsOf_def)

lemma List__positionsOf_singleton [simp]:
  "List__positionsOf ([x], x) = [0]"
  by (rule_tac t="[x]" and s="[]@[x]" in subst, simp,
      simp only: List__positionsOf_snoc1, simp)

lemma List__positionsOf_not_found [simp]:
  "\<lbrakk>\<forall>a\<in>set l. a \<noteq> x\<rbrakk> \<Longrightarrow> List__positionsOf (l, x) = []"
  by (induct l rule: rev_induct, simp_all)

lemma List__positionsOf_not_found_later [simp]:
  "\<lbrakk>\<forall>a\<in>set l'. a \<noteq> x\<rbrakk> \<Longrightarrow> List__positionsOf (l@l', x) =  List__positionsOf (l, x)"
  by (induct l' rule: rev_induct, 
      simp_all add: append_assoc [symmetric] del: append_assoc)

lemma List__positionsOf_last [simp]:
  "\<lbrakk>\<forall>a\<in>set l. a \<noteq> x\<rbrakk>
   \<Longrightarrow> List__positionsOf (l@[x], x) = [length l]"
  by simp

lemma List__positionsOf_only_one [simp]:
  "\<lbrakk>\<forall>a\<in>set l. a \<noteq> x; \<forall>a\<in>set l'. a \<noteq> x\<rbrakk>
   \<Longrightarrow> List__positionsOf (l@[x]@l', x) = [length l]"
  by (simp only: append_assoc [symmetric], simp del: append_assoc)

lemma List__positionsOf_2 [simp]:
  "\<lbrakk>a \<noteq> x\<rbrakk> \<Longrightarrow> List__positionsOf ([a,x], x) = [1]"
 by (rule_tac t="[a,x]" and s="[a]@[x]" in subst, simp,
     subst List__positionsOf_last, auto)

lemma List__theElement_singleton [simp]:
  "List__theElement [x] = x"
  by (simp add: List__theElement_def)

lemma List__positionOf_singleton [simp]:
  "List__positionOf ([x], x) = 0"
  by (simp add:  List__positionOf_def)

lemma List__positionOf_2 [simp]:
  "\<lbrakk>a \<noteq> x\<rbrakk> \<Longrightarrow> List__positionOf ([a,x], x) = 1"
  by (simp add:  List__positionOf_def)

(*********************************)

lemma Map__fromAssocList_empty [simp]:
  "Rep_Map__FiniteMap (Map__fromAssocList [])  = Map.empty"
  by (simp add: Map__fromAssocList_def Map__FiniteMap_def dom_if)


lemma Map__fromAssocList_singleton [simp]:
  "Rep_Map__FiniteMap (Map__fromAssocList [(x,y)]) = Map__update empty x y "
  by (simp add: Map__fromAssocList_def Map__FiniteMap_def dom_if 
                Map__update_def ext)


lemma Map__singleton_element [simp]: 
  "Map__update Map.empty x y x = Some y"
  by (simp add: Map__update_def)


lemma Map__double_update [simp]: 
  "Map__update (Map__update m x y) x z  = Map__update m x z"
  by (rule ext, simp add: Map__update_def)


end-proof
% ------------------------------------------------------------------------------

endspec
