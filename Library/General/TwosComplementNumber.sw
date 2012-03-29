TwosComplement qualifying spec

(* A two's complement number ("TC number") is a (finite) list of bits,
interpreted as an integer. We consider the bit list in big endian format,
i.e. the sign bit is the leftmost one and the least significant bit is the
rightmost one. There must be at least one bit. *)

import BitList

type TCNumber = List1 Bit

op sign : TCNumber -> Bit = head

% (non-)zero, (non-)positive, (non-)negative:

op zero? (x:TCNumber) : Bool = forall? (fn b -> b = B0) x

op nonZero? : TCNumber -> Bool = ~~ zero?

type TCNumber0 = (TCNumber | nonZero?)

op negative? (x:TCNumber) : Bool = (sign x = B1)

op nonNegative? : TCNumber -> Bool = ~~ negative?

theorem nonNegative?_alt_def is
  fa(x:TCNumber) nonNegative? x <=> sign x = B0

proof Isa nonNegative_p_alt_def
 by (auto simp add: TwosComplement__nonNegative_p_def fun_Compl_def 
                  TwosComplement__negative_p_def bool_Compl_def
                  TwosComplement__sign_def)
end-proof

op positive? : TCNumber -> Bool = nonNegative? /\ (~~ zero?)

op nonPositive? : TCNumber -> Bool = ~~ positive?

% conversion to integers:

op toInt (x:TCNumber) : Int = if nonNegative? x then toNat x
                              else toNat x - 2 ** (length x)

% -----------------------------------------------------------------------------
% Note that the first bit is used both as a sign and as the top bit of toNat
% Thus toNat ranges for nonNegative numbers from 0 to 2 ** (length x - 1) - 1
%    and for negative Numbers from 2 ** (length x - 1) to 2 ** (length x) - 1
% which effectively gives us a range from  - 2 ** (length x - 1) 
% to 2 ** (length x - 1) - 1. 
% 
% The more conventional definition
% 
% op toInt (x:TCNumber) : Int = if nonNegative? x then toNat (tl x)
%                              else toNat (tl x) - 2 ** (length (tl x))
%
% has the same effect but is more complicated to compute and reason about.
% -----------------------------------------------------------------------------

proof Isa -verbatim  

(************ important insights that we need over and over again*********)

declare One_nat_def [simp del] 

(********************************************************************
 As long as some of the the subtype information about TC numbers 
 doesn't carry over from Specware to Isabelle we have to provide them 
 as axiom stating that a TCNumber is never empty.
 ********************************************************************)

axiomatization where TwosComplement__toInt_subtype_constr:
  "TwosComplement__toInt x = i \<Longrightarrow> x \<noteq> []"

lemma TwosComplement__negative_p_iff_less_0:
 "\<lbrakk>bs\<noteq>[]\<rbrakk>
  \<Longrightarrow> TwosComplement__negative_p bs = (TwosComplement__toInt bs < 0)"
  by (auto simp add: TwosComplement__toInt_def fun_Compl_def bool_Compl_def
                   TwosComplement__nonNegative_p_def) 

lemma TwosComplement__nonNegative_p_iff_ge_0:
 "\<lbrakk>bs\<noteq>[]\<rbrakk>
  \<Longrightarrow> 
  TwosComplement__nonNegative_p bs = (TwosComplement__toInt bs \<ge> 0)"
 by (simp add: TwosComplement__nonNegative_p_def fun_Compl_def
               TwosComplement__negative_p_iff_less_0 bool_Compl_def not_less)

lemma TwosComplement__zero_p_iff_eq_0:
 "\<lbrakk>bs\<noteq>[]\<rbrakk>
  \<Longrightarrow>  
  TwosComplement__zero_p bs = (TwosComplement__toInt bs = 0)"
  apply (auto simp add: TwosComplement__toInt_def fun_Compl_def 
                        TwosComplement__nonNegative_p_def bool_Compl_def 
                        TwosComplement__negative_p_def TwosComplement__sign_def
                        TwosComplement__zero_p_def 
                        Bits__toNat_zero [symmetric]
                        list_all_iff member_def)
  apply (drule_tac x="hd bs" in bspec, erule hd_in_set, simp)
  apply (cut_tac bs=bs in Bits__toNat_bound, 
         simp_all add: zless_power_convert_1 [symmetric])
done

lemma TwosComplement__nonZero_p_iff_neq_0:
 "\<lbrakk>bs\<noteq>[]\<rbrakk>
  \<Longrightarrow> 
  TwosComplement__nonZero_p bs = (TwosComplement__toInt bs \<noteq> 0)"
  by (simp add: TwosComplement__nonZero_p_def fun_Compl_def bool_Compl_def
                TwosComplement__zero_p_iff_eq_0)  

lemma TwosComplement__positive_p_alt_def: 
 "\<lbrakk>bs\<noteq>[]\<rbrakk>
  \<Longrightarrow> 
  TwosComplement__positive_p bs =
    (TwosComplement__nonNegative_p bs \<and>  TwosComplement__nonZero_p bs)"
 by (cut_tac Set__e_fsl_bsl__def, 
     simp add: TwosComplement__positive_p_def fun_Compl_def
               TwosComplement__nonZero_p_def mem_def)

lemma TwosComplement__positive_p_iff_greater_0:
 "\<lbrakk>bs\<noteq>[]\<rbrakk>
  \<Longrightarrow> 
  TwosComplement__positive_p bs = (TwosComplement__toInt bs > 0)"
 by (auto simp add: TwosComplement__positive_p_alt_def
                    TwosComplement__nonZero_p_iff_neq_0
                    TwosComplement__nonNegative_p_iff_ge_0)

lemma TwosComplement__nonPositive_p_iff_le_0:
 "\<lbrakk>bs\<noteq>[]\<rbrakk>
  \<Longrightarrow> 
  TwosComplement__nonPositive_p bs = (TwosComplement__toInt bs \<le> 0)" 
  by (simp add: TwosComplement__nonPositive_p_def fun_Compl_def bool_Compl_def
                TwosComplement__positive_p_iff_greater_0 not_less) 

lemma TwosComplement__toInt_inject [simp]:
 "\<lbrakk>x\<noteq>[]; length x = length y\<rbrakk>
  \<Longrightarrow> (TwosComplement__toInt x = TwosComplement__toInt y) = (x = y)"
 apply (subgoal_tac "y\<noteq>[]", auto simp add: TwosComplement__toInt_def)
 apply (simp_all only: convert_to_nat_2 zpower_int zadd_int int_int_eq)
 apply (cut_tac bs=x in Bits__toNat_bound, simp_all)
done

lemma TwosComplement__toInt_inject_rule:
 "\<lbrakk>TwosComplement__toInt x = TwosComplement__toInt y; 
   length x = length y; 0 < length x \<rbrakk>
  \<Longrightarrow> x = y"
 by (erule rev_mp, subst  TwosComplement__toInt_inject, auto)
 
lemma TwosComplement__sign_extension_aux: 
  "\<lbrakk>x \<noteq> []\<rbrakk> \<Longrightarrow> 
    TwosComplement__toInt
     (List__extendLeft (x, TwosComplement__sign x, length x + k)) =
    TwosComplement__toInt x"
   apply (cases "k=0",
          auto simp add: TwosComplement__sign_def 
                         TwosComplement__toInt_def 
                         TwosComplement__nonNegative_p_alt_def
                         List__extendLeft_def
                         Bits__extendLeft_toNat_B0
                         algebra_simps)
   apply (simp only: convert_to_nat_2 zpower_int zadd_int int_int_eq,
          simp add: Bits__extendLeft_toNat_B1)
done
(*************************************************************************)
end-proof

theorem twos_complement_of_negative is
  fa(x:TCNumber) negative? x =>  % given negative TC number
    toNat (not x) + 1 =  % two's complement operation
      - (toInt x)  % yields absolute value of represented integer

proof Isa twos_complement_of_negative_Obligation_subtype
 by (auto simp: not_bs_def)
end-proof

proof Isa twos_complement_of_negative
 apply (simp add: TwosComplement__toInt_def fun_Compl_def
                  TwosComplement__nonNegative_p_def bool_Compl_def
                  algebra_simps)
 apply (drule Bits__toNat_complement_sum, simp, 
        simp only: convert_to_nat zpower_int)
end-proof

% minimum/maximum integer representable as TC number of length len:

op minForLength (len:PosNat) : Int = - (2 ** (len - 1))

op maxForLength (len:PosNat) : Int = 2 ** (len - 1) - 1

% range of integers representable as TC numbers of length len:

op rangeForLength (len:PosNat) : Set Int =
  fn i -> minForLength len <= i && i <= maxForLength len

theorem integer_range is
  fa(x:TCNumber) toInt x in? rangeForLength (length x)

proof Isa integer_range [simp]
 apply (auto simp add: TwosComplement__toInt_def mem_def
                       TwosComplement__rangeForLength_def 
                       TwosComplement__minForLength_def 
                       TwosComplement__maxForLength_def
                       TwosComplement__nonNegative_p_alt_def 
                       TwosComplement__sign_def neq_Nil_conv)
 apply (case_tac "ys = []", simp_all)
 apply (case_tac "ys = []", simp_all, simp only: convert_to_nat zpower_int)
 apply (case_tac "ys = []", simp_all, 
        frule Bits__toNat_bound2, simp only: convert_to_nat zpower_int)
end-proof

% zero TC number of given length (i.e. number of bits):

op zero (len:PosNat) : TCNumber = repeat B0 len

theorem zero_is_zero is
  fa(len:PosNat) zero? (zero len)

proof Isa zero_is_zero
  by (simp add: TwosComplement__zero_p_def TwosComplement__zero_def list_all_iff)
end-proof

% extend sign bit to given length (>= current length):

op signExtend (x:TCNumber, newLen:PosNat | newLen >= length x) : TCNumber =
  extendLeft (x, sign x, newLen)

proof Isa signExtend_Obligation_subtype
  by (simp add: List__extendLeft_def)
end-proof

theorem sign_extension_does_not_change_value is
  fa (x:TCNumber, newLen:PosNat)
    newLen >= length x =>
    toInt (signExtend (x, newLen)) = toInt x

proof Isa sign_extension_does_not_change_value
 by (simp add: TwosComplement__signExtend_def,
     frule_tac k="newLen - length x" in TwosComplement__sign_extension_aux,
     simp)
end-proof

% sign-extend shorter TC number to length of longer TC number:

op equiSignExtend (x:TCNumber, y:TCNumber) : TCNumber * TCNumber =
  equiExtendLeft (x, y, sign x, sign y)

proof Isa equiSignExtend_Obligation_subtype
 by (simp add:  Let_def List__equiExtendLeft_def List__extendLeft_def
          split: split_if_asm)
end-proof

% change length of TC number by either sign-extending or discarding higher
% bits (depending on whether new length is > or <= current length)

op changeLength (x:TCNumber, newLen:PosNat) : TCNumber =
  if newLen > length x then signExtend (x, newLen)
                       else suffix     (x, newLen)

% convert integer to TC number of given or minimal length:

op tcNumber (i:Int, len:PosNat | i in? rangeForLength len) : TCNumber =
  the(x:TCNumber) length x = len && toInt x = i

proof Isa tcNumber_Obligation_the
 apply (simp add: TwosComplement__toInt_def mem_def
                  TwosComplement__rangeForLength_def 
                  TwosComplement__minForLength_def 
                  TwosComplement__maxForLength_def
                  TwosComplement__nonNegative_p_def fun_Compl_def 
                  TwosComplement__negative_p_def    bool_Compl_def
                  TwosComplement__sign_def,
        clarify)
 apply (cases "len = 1", simp_all)
 apply (case_tac "i = 0", simp_all) 
 (* can't use auto before I assign the solutions *)
 (* 1 *) apply (rule_tac a="[B0]" in ex1I, simp_all) defer
 (* 2 *) apply (rule_tac a="[B1]" in ex1I, simp_all) defer 
 apply (subgoal_tac "1 < len", simp_all)
 apply (cut_tac n="nat i" and len = "len - 1" in Bits__bits_length,
        simp, simp  add: zless_power_convert_1 [symmetric])
 apply (case_tac "i \<ge> 0", simp_all add: not_le) 
 (* 3 *) apply (rule_tac a="B0 # toBits (nat i, len - 1)" in ex1I, simp_all) defer defer
 (* 4 *) apply (rule_tac a="B1 # toBits (nat (i + 2 ^ (len - 1)), len - 1)" in ex1I, simp_all) 
         defer defer
 (* Now we're back at cases 1 and 2 *)
 apply (case_tac "hd x", simp_all add: length_1_hd_conv, clarsimp)
 (* 3a *)
 apply (subst Bits__toNat_induct, simp only: length_greater_0_iff, simp)
 apply (subst Bits__inverse_toNat_bits, simp_all)
 (* 3b *)
 apply (case_tac "hd x", simp_all, clarsimp simp add: neq_Nil_conv)
 apply (clarify, simp only: not_less [symmetric], erule notE, simp)
 (* 4a *)
 apply (cut_tac n="nat (i + 2^(len - 1))" and len = "len - 1" in Bits__bits_length,
        simp, simp  add: zless_power_convert_1 [symmetric])
 apply (subst Bits__toNat_induct, simp only: length_greater_0_iff, simp)
 apply (simp add:  power2_nat One_nat_def power_sub_1_eq_int)
 (* 4b *)
 apply (case_tac "hd x", simp_all, clarsimp, simp add: neq_Nil_conv, clarsimp)
 apply (simp only: convert_to_nat zpower_int, simp)
end-proof

proof Isa -verbatim
(******************************************************************************)

lemma TwosComplement__tcNumber_length [simp]:
  "\<lbrakk>0 < len; i \<in> TwosComplement__rangeForLength len\<rbrakk>  
   \<Longrightarrow> length (TwosComplement__tcNumber (i, len)) = len"
 by (simp add: TwosComplement__tcNumber_def, rule the1I2,
     rule TwosComplement__tcNumber_Obligation_the, simp_all)

lemma TwosComplement__tcNumber_length2 [simp]:
  "\<lbrakk>0 < len; -(2 ^ (len - 1)) \<le> i; i < 2 ^ (len - 1)\<rbrakk>  
   \<Longrightarrow> length (TwosComplement__tcNumber (i, len)) = len"
 by (simp add: TwosComplement__rangeForLength_def 
               TwosComplement__minForLength_def 
               TwosComplement__maxForLength_def mem_def)
  
lemma TwosComplement__tcNumber_non_nil [simp]:
  "\<lbrakk>0 < len; i \<in> TwosComplement__rangeForLength len\<rbrakk> 
   \<Longrightarrow> TwosComplement__tcNumber (i, len) \<noteq> []"
 by (frule TwosComplement__tcNumber_length, auto)
  
lemma TwosComplement__tcNumber_non_nil2 [simp]:
  "\<lbrakk>0 < len; -(2 ^ (len - 1)) \<le> i; i < 2 ^ (len - 1)\<rbrakk> 
   \<Longrightarrow> TwosComplement__tcNumber (i, len) \<noteq> []"
 by (simp add: TwosComplement__rangeForLength_def 
               TwosComplement__minForLength_def 
               TwosComplement__maxForLength_def mem_def)

lemma TwosComplement__toInt_tcNumber_reduce [simp]:
  "\<lbrakk>0 < len; i \<in> TwosComplement__rangeForLength len\<rbrakk>  
   \<Longrightarrow> TwosComplement__toInt (TwosComplement__tcNumber (i, len)) = i"
 by (simp add: TwosComplement__tcNumber_def, rule the1I2,
     rule TwosComplement__tcNumber_Obligation_the, safe)

lemma TwosComplement__tcNumber_toInt_reduce [simp]:
  "\<lbrakk>0 < len; length x = len\<rbrakk>  
   \<Longrightarrow> TwosComplement__tcNumber (TwosComplement__toInt x, len) = x"
 by (simp add: TwosComplement__tcNumber_def, rule the1I2,
     rule TwosComplement__tcNumber_Obligation_the, auto)

lemma TwosComplement__tcNumber_inverse [simp]:
  "\<lbrakk>0 < len; length x = len; i \<in> TwosComplement__rangeForLength len\<rbrakk>
   \<Longrightarrow> (TwosComplement__toInt x = i) = (x = TwosComplement__tcNumber (i, len))"
  by (auto, erule ssubst, auto)

lemma TwosComplement__tcNumber_inverse2 [simp]:
  "\<lbrakk>0 < len; length x = len; -(2 ^ (len - 1)) \<le> i; i < 2 ^ (len - 1)\<rbrakk>  
   \<Longrightarrow> (TwosComplement__toInt x = i) = (x = TwosComplement__tcNumber (i, len))"
 by (simp add: TwosComplement__rangeForLength_def 
               TwosComplement__minForLength_def 
               TwosComplement__maxForLength_def mem_def)

lemma TwosComplement__tcNumber_inverse_sym:
  "\<lbrakk> x = TwosComplement__tcNumber (i, len);
    i \<in> TwosComplement__rangeForLength len; 0 < len\<rbrakk>
   \<Longrightarrow> TwosComplement__toInt x = i"
  by simp

lemma TwosComplement__tcNumber_inverse_fwd:
  "\<lbrakk>TwosComplement__toInt x = i; 0 < len; length x = len\<rbrakk>  
   \<Longrightarrow> x = TwosComplement__tcNumber (i, len)"
 by (subst TwosComplement__tcNumber_inverse [symmetric], auto)


(*** note that rules (not simplifications) are a lot easier to use
     if the main premise comes first ******************************)

lemma TwosComplement__tcNumber_inject [simp]:
  "\<lbrakk>0 < len; i \<in> TwosComplement__rangeForLength len;
             j \<in> TwosComplement__rangeForLength len\<rbrakk>  
   \<Longrightarrow> (TwosComplement__tcNumber (i, len) = TwosComplement__tcNumber (j,len))
     = (i = j)"
  by (auto, drule TwosComplement__tcNumber_inverse_sym, auto)


(******************************************************************************)


(******************* I need these often ***************************************)
lemmas TwosComplementInt =  
                   TwosComplement__toInt_def 
                   TwosComplement__nonNegative_p_def 
                   TwosComplement__negative_p_def 
                   fun_Compl_def bool_Compl_def 
                   TwosComplement__sign_def
                 
lemmas TwosComplement_tcN =  
                   TwosComplement__toInt_tcNumber_reduce mem_def
                   TwosComplement__rangeForLength_def 
                   TwosComplement__minForLength_def 
                   TwosComplement__maxForLength_def

(******************************************************************************)
(** Binary logarithm on integers. Actually, the minimal length of TC numbers **)

consts zld :: "int \<Rightarrow> nat"
defs zld_def: "zld i \<equiv> if i \<ge> 0 then ld (nat i, 2) else ld (nat (-(i+1)), 2)"

lemma ld_zero [simp]:   "\<lbrakk>2 \<le> base\<rbrakk> \<Longrightarrow> ld (0,base) = 0"
  apply (simp add: ld_def, simp only: Least_def, rule the1_equality, auto)
  apply (drule spec, drule spec, auto simp add: le_trans)
done


lemma zld_zero [simp]:   "zld 0 = 0"
  by (simp add: zld_def)
lemma zld_neg1 [simp]:   "zld (-1) = 0"
  by (simp add: zld_def)

lemma zld_pos1:          "\<lbrakk>0 < i\<rbrakk> \<Longrightarrow> 0 < zld i"
  by (auto simp add:  zld_def ld_positive)
lemma zld_pos2:          "\<lbrakk>i < -1\<rbrakk> \<Longrightarrow> 0 < zld i"
  by (auto simp add:  zld_def ld_positive)

lemma zld_positive:  "\<lbrakk>0 \<noteq> i;-1\<noteq>i\<rbrakk> \<Longrightarrow> 0 < zld i"
  by (auto simp add:  zld_def ld_positive)

lemma zld_power_pos [simp]: "0 < (2::int) ^ zld i"
  by (auto simp add:  zld_def ld_positive)

lemma zld_upper:    "i < 2 ^ zld i"
  by (cases "i \<ge> 0", auto simp add:  not_le less_trans,
      cut_tac x="nat i" and base=2 in ld_mono, simp, simp add: zld_def)

lemma zld_at_least_pos:   "\<lbrakk>0 < i\<rbrakk> \<Longrightarrow> i \<ge> 2 ^ (zld i - 1)"
  by (cut_tac x="nat i" and base=2 in ld_mono2, auto simp add: zld_def,
      simp only: convert_to_nat_2 zpower_int)

lemma zld_lower:   "i \<ge> - (2 ^ zld i)"
  by (cases "i \<ge> 0", rule zle_trans, auto,
      cut_tac x="nat (-(i+1))" and base=2 in ld_mono, simp, simp add: zld_def)

lemma zld_at_most_neg:   "\<lbrakk>i < -1\<rbrakk> \<Longrightarrow> i < -(2 ^ (zld i - 1))"
  by (cut_tac x="nat (-(i+1))" and base=2 in ld_mono2, auto simp add: zld_def,
      simp only: convert_to_nat_2 zpower_int)
          
lemmas zld_props = zld_positive zld_power_pos
                   zld_upper zld_at_least_pos
                   zld_lower zld_at_most_neg

(******************************************************************************)

lemma TwosComplement__toInt_length:
 (*************************************************************
    This is the only lemma that makes use of the axiom
    TwosComplement__toInt_subtype_constr
 **************************************************************)
  "\<lbrakk>TwosComplement__toInt x = i\<rbrakk> \<Longrightarrow> length x > zld i"
 apply (frule_tac TwosComplement__toInt_subtype_constr)
 apply (case_tac "i = 0 \<or> i = -1", erule disjE, simp_all)
 apply (frule_tac TwosComplement__integer_range, simp,  thin_tac "?a = i")
 apply (auto simp add: TwosComplement_tcN)
 apply (subst not_le [symmetric], rule notI)
 apply (drule_tac m="length x" and l=1 in diff_le_mono)
 apply (drule_tac a="(2::int)" and n="length x - 1" in power_increasing, simp)
 apply (drule less_le_trans, simp (no_asm_simp))
 apply (drule_tac a="2 ^ (length x - 1)" in le_imp_neg_le)
 apply (drule_tac i="- ((2::int) ^ (zld i - 1))" in zle_trans, simp)
 apply (thin_tac ?P, case_tac "0<i")
 apply (drule zld_at_least_pos, simp)
 apply (subgoal_tac "i < -1", drule zld_at_most_neg, simp, arith)
done 
  
lemma TwosComplement__toInt_length1:
  "\<lbrakk>TwosComplement__toInt x = i\<rbrakk> \<Longrightarrow> length x \<ge> zld i + 1"
 by (frule TwosComplement__toInt_length, auto)

lemma TwosComplement__minTCNumber_exists: 
  "\<exists>a. TwosComplement__toInt a = i \<and>
               (\<forall>y. TwosComplement__toInt y = i \<longrightarrow> length a \<le> length y)"
   by (rule_tac x="TwosComplement__tcNumber (i, zld i + 1)" in exI,
       clarsimp simp add: TwosComplement__toInt_tcNumber_reduce 
                          TwosComplement_tcN zld_props
                          TwosComplement__toInt_length1)
(******************************************************************************)

(******************************************************************************)
end-proof

op minTCNumber (i:Int) : TCNumber =
  minimizer (fn x:TCNumber -> length x, fn x:TCNumber -> toInt x = i)


proof Isa minTCNumber_Obligation_subtype
   apply (simp add: Set_P_def Integer__hasUniqueMinimizer_p__stp_def
                    Set__single_p__stp_def Integer__minimizers__stp_def 
                    Integer__minimizes_p__stp_def mem_def conj_imp,
          auto simp add: set_eq_iff)
   apply (rule_tac x="TwosComplement__tcNumber (i, zld i + 1)" in exI,
          clarsimp simp add: TwosComplement__toInt_tcNumber_reduce 
                             TwosComplement_tcN zld_props            )
   apply (rule iffI, erule conjE, erule conjE)
   apply (drule_tac x="TwosComplement__tcNumber (i, zld i + 1)" in spec,
          simp add: TwosComplement__toInt_tcNumber_reduce 
                    TwosComplement_tcN zld_props)
   apply (simp add: TwosComplement__tcNumber_inverse_fwd 
                    TwosComplement__toInt_length1 eq_iff)
   apply (auto simp add: TwosComplement__toInt_tcNumber_reduce 
                    TwosComplement__tcNumber_length
                    TwosComplement_tcN zld_props 
                    TwosComplement__toInt_length1)
end-proof

theorem length_of_minTCNumber is
  fa (i:Int, len:PosNat) i in? rangeForLength len =>
                         length (minTCNumber i) <= len

proof Isa length_of_minTCNumber
  apply (simp add: TwosComplement__minTCNumber_def LeastM_def,
         rule someI2_ex, rule TwosComplement__minTCNumber_exists)
  apply (erule conjE)
  apply (drule_tac x="TwosComplement__tcNumber (i, len)" in spec,
         simp add: TwosComplement_tcN )
 done

(**************** we may need that later ***********************)

lemma TwosComplement__length_of_minTCNumber_is_zld:
   "length (TwosComplement__minTCNumber i) = zld i + 1"
  apply (simp add: TwosComplement__minTCNumber_def LeastM_def,
         rule someI2_ex, rule TwosComplement__minTCNumber_exists)
  apply (erule conjE)
  apply (frule TwosComplement__toInt_length1)
  apply (drule_tac x="TwosComplement__tcNumber (i, zld i + 1)" in spec,
         simp add: TwosComplement__toInt_tcNumber_reduce 
                   TwosComplement_tcN zld_props)
(******************************************************************************)

end-proof

(* The following arithmetic operations on TC numbers are all calculated
according to the same pattern: convert operand(s) to integer(s), perform exact
operation, truncate result to operand length. *)

% unary minus:

op TCNumber.- (x:TCNumber) : TCNumber =
   % qualifier needed to avoid confusion with binary -
  let y = minTCNumber (- (toInt x)) in
  changeLength (y, length x)
proof Isa -> minus_tc end-proof

% addition:

op + (x:TCNumber, y:TCNumber | x equiLong y) infixl 25 : TCNumber =
  let z = minTCNumber (toInt x + toInt y) in
  changeLength (z, length x)
proof Isa -> +_tc end-proof

% subtraction:

op - (x:TCNumber, y:TCNumber | x equiLong y) infixl 25 : TCNumber =
  let z = minTCNumber (toInt x - toInt y) in
  changeLength (z, length x)
proof Isa -> -_tc end-proof

% multiplication:

op * (x:TCNumber, y:TCNumber | x equiLong y) infixl 27 : TCNumber =
  let z = minTCNumber (toInt x * toInt y) in
  changeLength (z, length x)
proof Isa -> *_tc end-proof

% integer division and modulus (same variants as in base spec for integers):

op divT (x:TCNumber, y:TCNumber0 | x equiLong y) infixl 26 : TCNumber =
  let z = minTCNumber (toInt x divT toInt y) in
  changeLength (z, length x)
proof Isa -> divT_tc end-proof

proof Isa divT_Obligation_subtype
  by (simp add: TwosComplement__nonZero_p_iff_neq_0)
end-proof

op modT (x:TCNumber, y:TCNumber0 | x equiLong y) infixl 26 : TCNumber =
  let z = minTCNumber (toInt x modT toInt y) in
  changeLength (z, length x)
proof Isa -> modT_tc end-proof

proof Isa modT_Obligation_subtype
  by (simp add: TwosComplement__nonZero_p_iff_neq_0)
end-proof

op divF (x:TCNumber, y:TCNumber0 | x equiLong y) infixl 26 : TCNumber =
  let z = minTCNumber (toInt x divF toInt y) in
  changeLength (z, length x)
proof Isa -> divF_tc end-proof

proof Isa divF_Obligation_subtype
  by (simp add: TwosComplement__nonZero_p_iff_neq_0)
end-proof

op modF (x:TCNumber, y:TCNumber0 | x equiLong y) infixl 26 : TCNumber =
  let z = minTCNumber (toInt x modF toInt y) in
  changeLength (z, length x)
proof Isa -> modF_tc end-proof

proof Isa modF_Obligation_subtype
  by (simp add: TwosComplement__nonZero_p_iff_neq_0)
end-proof

op divC (x:TCNumber, y:TCNumber0 | x equiLong y) infixl 26 : TCNumber =
  let z = minTCNumber (toInt x divC toInt y) in
  changeLength (z, length x)
proof Isa -> divC_tc end-proof

proof Isa divC_Obligation_subtype
  by (simp add: TwosComplement__nonZero_p_iff_neq_0)
end-proof

op modC (x:TCNumber, y:TCNumber0 | x equiLong y) infixl 26 : TCNumber =
  let z = minTCNumber (toInt x modC toInt y) in
  changeLength (z, length x)
proof Isa -> modC_tc end-proof

proof Isa modC_Obligation_subtype
  by (simp add: TwosComplement__nonZero_p_iff_neq_0)
end-proof

op divR (x:TCNumber, y:TCNumber0 | x equiLong y) infixl 26 : TCNumber =
  let z = minTCNumber (toInt x divR toInt y) in
  changeLength (z, length x)
proof Isa -> divR_tc end-proof

proof Isa divR_Obligation_subtype
  by (simp add: TwosComplement__nonZero_p_iff_neq_0)
end-proof

op modR (x:TCNumber, y:TCNumber0 | x equiLong y) infixl 26 : TCNumber =
  let z = minTCNumber (toInt x modR toInt y) in
  changeLength (z, length x)
proof Isa -> modR_tc end-proof

proof Isa modR_Obligation_subtype
  by (simp add: TwosComplement__nonZero_p_iff_neq_0)
end-proof

op divE (x:TCNumber, y:TCNumber0 | x equiLong y) infixl 26 : TCNumber =
  let z = minTCNumber (toInt x divE toInt y) in
  changeLength (z, length x)
proof Isa -> divE_tc end-proof

proof Isa divE_Obligation_subtype
  by (simp add: TwosComplement__nonZero_p_iff_neq_0)
end-proof

op modE (x:TCNumber, y:TCNumber0 | x equiLong y) infixl 26 : TCNumber =
  let z = minTCNumber (toInt x modE toInt y) in
  changeLength (z, length x)
proof Isa -> modE_tc end-proof

proof Isa modE_Obligation_subtype
  by (simp add: TwosComplement__nonZero_p_iff_neq_0)
end-proof

% relational operators:

op < (x:TCNumber, y:TCNumber | x equiLong y) infixl 20 : Bool =
  toInt x < toInt y
proof Isa -> <_tc end-proof

op <= (x:TCNumber, y:TCNumber | x equiLong y) infixl 20 : Bool =
  toInt x <= toInt y
proof Isa -> <=_tc end-proof

op > (x:TCNumber, y:TCNumber | x equiLong y) infixl 20 : Bool =
  toInt x > toInt y
proof Isa -> >_tc end-proof

op >= (x:TCNumber, y:TCNumber | x equiLong y) infixl 20 : Bool =
  toInt x >= toInt y
proof Isa -> >=_tc end-proof

% TC numbers represent the same integer:

op EQ (x:TCNumber, y:TCNumber) infixl 20 : Bool =
  toInt x = toInt y

% shifting:

op shiftLeft (x:TCNumber, n:Nat | n <= length x) : TCNumber =
  shiftLeft (x, B0, n)

proof Isa shiftLeft_Obligation_subtype
 by (auto simp add: List__shiftLeft_def)
end-proof

op shiftRightSigned (x:TCNumber, n:Nat | n <= length x) : TCNumber =
  shiftRight (x, sign x, n)

proof Isa shiftRightSigned_Obligation_subtype
 by (simp, simp only: length_greater_0_iff List__length_shiftRight)
end-proof

op shiftRightUnsigned (x:TCNumber, n:Nat | n <= length x) : TCNumber =
  shiftRight (x, B0, n)

proof Isa shiftRightUnsigned_Obligation_subtype
 by (simp, simp only: length_greater_0_iff List__length_shiftRight)
end-proof


% ------------------------------------------------------------

% ------------------------------------------------------------------------------
% ---------- Part 6: verbatim Isabelle lemmas             ----------------------
% ----------         that cannot be expressed in SpecWare ----------------------
% ------------------------------------------------------------------------------

proof Isa -verbatim
(******************************************************************************)

lemma TwosComplement__rangeForLength_0 [simp]:
  "0 \<in> TwosComplement__rangeForLength len"
  by (simp add: TwosComplement_tcN)
  
lemma TwosComplement__rangeForLength_1 [simp]:
  "\<lbrakk>1 < len\<rbrakk> \<Longrightarrow> 1 \<in> TwosComplement__rangeForLength len"
   by (simp add: TwosComplement_tcN,
       rule order_less_imp_le, rule_tac y=0 in less_trans, auto) 

lemma TwosComplement__toInt_nat:
  "\<lbrakk>0 < length a; TwosComplement__toInt a = int i\<rbrakk>  \<Longrightarrow> toNat a = i"
   by (simp add: TwosComplementInt algebra_simps split: split_if_asm,
       cut_tac bs=a in Bits__toNat_bound, simp_all add: int_power_simp)

lemma TwosComplement__toInt_pos:
  "\<lbrakk>0 < length a; TwosComplement__toInt a = i; i \<ge> 0\<rbrakk> 
       \<Longrightarrow> toNat a = nat i"
   by (erule TwosComplement__toInt_nat, simp)

lemma TwosComplement__toInt_neg:
  "\<lbrakk>0 < length a; TwosComplement__toInt a = i; i < 0\<rbrakk> 
       \<Longrightarrow> toNat a = nat (i + 2 ^ length a)"
   by (simp only: TwosComplementInt algebra_simps,
       simp split: split_if_asm)

lemma TwosComplement__toInt_hd_0:
  "\<lbrakk>0 < length a; TwosComplement__toInt a \<ge> 0\<rbrakk> \<Longrightarrow> hd a = B0"
   by (simp only: TwosComplementInt, 
       simp add: power2_int algebra_simps not_less [symmetric]
          split: split_if_asm)

lemma TwosComplement__toInt_hd_1:
  "\<lbrakk>0 < length a; TwosComplement__toInt a < 0\<rbrakk> \<Longrightarrow> hd a = B1"
   by (simp only: TwosComplementInt, simp split: split_if_asm)

lemma TwosComplement__toInt_base0 [simp]: "TwosComplement__toInt [B0] = 0"
  by (simp add: TwosComplementInt)
lemma TwosComplement__toInt_base1 [simp]: "TwosComplement__toInt [B1] = -1"
  by (simp add: TwosComplementInt)  

lemma TwosComplement__toInt_induct_pos [simp]:
  "\<lbrakk>bs\<noteq>[]; TwosComplement__toInt bs \<ge> 0\<rbrakk> \<Longrightarrow>
    TwosComplement__toInt (B0 # bs) = TwosComplement__toInt bs"
  by (simp add: TwosComplementInt not_less [symmetric] split: split_if_asm )

lemma TwosComplement__toInt_induct_neg [simp]:
  "\<lbrakk>bs\<noteq>[]; TwosComplement__toInt bs < 0\<rbrakk> \<Longrightarrow>
    TwosComplement__toInt (B1 # bs) = TwosComplement__toInt bs"
  by (simp add: TwosComplementInt not_less [symmetric] power2_int
          split: split_if_asm )

lemma TwosComplement__toInt_neg_range:
  "\<lbrakk>bs\<noteq>[]; 
    TwosComplement__toInt (B1#bs) \<in> TwosComplement__rangeForLength (length bs)\<rbrakk>
   \<Longrightarrow> TwosComplement__toInt bs < 0"
  by (clarsimp simp add: TwosComplement_tcN  TwosComplementInt algebra_simps, 
      simp add: power2_nat power_sub_1_eq_int One_nat_def)

lemma TwosComplement__toInt_neg_range2:
  "\<lbrakk>bs\<noteq>[]; len \<le>  length bs;
    TwosComplement__toInt (B1#bs) \<in> TwosComplement__rangeForLength len\<rbrakk>
   \<Longrightarrow> TwosComplement__toInt bs < 0"
  by (erule TwosComplement__toInt_neg_range, 
      auto simp add:  TwosComplement_tcN,
      rule zle_trans, auto, rule less_le_trans, auto)

lemma TwosComplement_surjective: 
  "\<lbrakk>bs \<noteq> []\<rbrakk> \<Longrightarrow> 
   \<exists>(i::int). i \<in> TwosComplement__rangeForLength (length bs)
              \<and> bs = (TwosComplement__tcNumber(i, length bs))"
  by (rule_tac x="TwosComplement__toInt bs" in exI, auto)

lemma TwosComplement_sign_TC_pos:
  "\<lbrakk>0 < len; int i \<in> TwosComplement__rangeForLength len\<rbrakk>
    \<Longrightarrow> TwosComplement__sign (TwosComplement__tcNumber (int i, len)) = B0"
  by (simp add: TwosComplement__tcNumber_def, rule the1I2,
      rule TwosComplement__tcNumber_Obligation_the, 
      simp_all add: TwosComplement__sign_def TwosComplement__toInt_hd_0) 

lemma TwosComplement_sign_TC_pos2:
  "\<lbrakk>0 < len; i \<in> TwosComplement__rangeForLength len; 0 \<le> i\<rbrakk>
    \<Longrightarrow> TwosComplement__sign (TwosComplement__tcNumber (i, len)) = B0"
  by (drule_tac i="nat i" in TwosComplement_sign_TC_pos, simp_all)

lemma TwosComplement_sign_TC_neg:
  "\<lbrakk>0 < len; i \<in> TwosComplement__rangeForLength len; i < 0\<rbrakk>
    \<Longrightarrow> TwosComplement__sign (TwosComplement__tcNumber (i, len)) = B1"
  by (simp add: TwosComplement__tcNumber_def, rule the1I2,
      rule TwosComplement__tcNumber_Obligation_the, 
      simp_all add: TwosComplement__sign_def TwosComplement__toInt_hd_1) 

lemma TwosComplement_TC_toBits_pos:
  "\<lbrakk>0 < len; int i \<in> TwosComplement__rangeForLength len\<rbrakk>
    \<Longrightarrow> TwosComplement__tcNumber (int i, len) = toBits (i, len)"
  apply (simp add: TwosComplement__tcNumber_def, rule the1I2,
         rule TwosComplement__tcNumber_Obligation_the, simp_all)
  apply (clarsimp simp add: TwosComplement_tcN)
  apply (cut_tac a=x in TwosComplement__toInt_nat, simp, simp)
  apply (thin_tac "?tc = ?i", drule sym, simp)
done
  
lemma TwosComplement_TC_toBits_pos2:
  "\<lbrakk>0 < len; i \<in> TwosComplement__rangeForLength len; 0 \<le> i\<rbrakk>
    \<Longrightarrow> TwosComplement__tcNumber (i, len) = toBits (nat i, len)"
  by (drule_tac i="nat i" in TwosComplement_TC_toBits_pos, simp_all)
  
lemma TwosComplement_TC_toBits_neg:
  "\<lbrakk>0 < len; i \<in> TwosComplement__rangeForLength len; i < 0\<rbrakk>
    \<Longrightarrow> TwosComplement__tcNumber (i, len) = toBits (nat (i + 2^len), len)"
  apply (simp add: TwosComplement__tcNumber_def, rule the1I2,
         rule TwosComplement__tcNumber_Obligation_the, simp_all) 
  apply (clarsimp simp only: TwosComplementInt TwosComplement_tcN
                      split: split_if_asm,
         simp_all)
done

lemma TwosComplement_toInt_bits_pos: 
  "\<lbrakk>0 < len; i \<in> TwosComplement__rangeForLength len;  0 \<le> i\<rbrakk>
    \<Longrightarrow> TwosComplement__toInt (toBits (nat i, len)) = i"
  by (subst TwosComplement__tcNumber_inverse, 
      simp_all add: TwosComplement_tcN TwosComplement_TC_toBits_pos2 [symmetric])

lemma TwosComplement_toInt_bits_neg: 
  "\<lbrakk>0 < len; i \<in> TwosComplement__rangeForLength len;  i < 0\<rbrakk>
    \<Longrightarrow> TwosComplement__toInt (toBits (nat (i + 2^len) , len)) = i"
  by (subst TwosComplement__tcNumber_inverse, 
      simp_all add: TwosComplement_tcN TwosComplement_TC_toBits_neg [symmetric])

(******************************************************************************)
lemmas TwosComplement_TC = TwosComplement_sign_TC_pos
                           TwosComplement_sign_TC_pos2
                           TwosComplement_sign_TC_neg
                           TwosComplement_TC_toBits_pos
                           TwosComplement_TC_toBits_pos2
                           TwosComplement_TC_toBits_neg
(******************************************************************************)

lemma TwosComplement__toInt_zero_val:
  "\<lbrakk>length a = len; 0 < len; TwosComplement__toInt a = 0\<rbrakk>
          \<Longrightarrow> a = replicate len B0"
  by (rule Bits__toNat_zero_val, simp_all add: TwosComplement_TC)

lemma TwosComplement_extendLeft_tcInt_pos:
  "\<lbrakk>bs1 \<noteq> []; length bs1 < length bs2; 
    TwosComplement__toInt bs1 = i; TwosComplement__toInt bs2 = i; i \<ge> 0\<rbrakk>
    \<Longrightarrow> bs2 = List__extendLeft (bs1, B0, length bs2)"
  by (drule zero_le_imp_eq_int, frule Bits__nonempty_less_length, 
      auto simp add: Bits__extendLeft_toNat TwosComplement__toInt_nat)

lemma TwosComplement_extendLeft_tcInt_pos2:
  "\<lbrakk>bs1 \<noteq> []; length bs1 < len2 ; length bs2 = len2; 
    TwosComplement__toInt bs1 = i; TwosComplement__toInt bs2 = i; i \<ge> 0\<rbrakk>
    \<Longrightarrow> bs2 = List__extendLeft (bs1, B0, len2)"
   by (clarsimp simp add: TwosComplement_extendLeft_tcInt_pos)

lemma TwosComplement__extendLeft_to_len_pos: 
   "\<lbrakk>len > 0; i < 2 ^ (len - 1); len < len2; length bs = len2;
     TwosComplement__toInt bs = int i\<rbrakk>
    \<Longrightarrow> bs = List__extendLeft (toBits (i, len), B0, len2)"
  by (rule TwosComplement_extendLeft_tcInt_pos2, 
      auto simp add: TwosComplement_tcN TwosComplement_TC One_nat_def)

lemma TwosComplement_extendLeft_tcInt_neg_aux:
  "\<lbrakk>bs1 \<noteq> []; TwosComplement__toInt bs1 = i; i < 0\<rbrakk>
    \<Longrightarrow> \<forall>bs2. length bs2 = length bs1 + k \<and> TwosComplement__toInt bs2 = i \<longrightarrow> 
              bs2 =  replicate k B1 @ bs1"
   apply (induct k, clarsimp simp add: Bits__nonempty_eqlength,  
          clarsimp simp add: add_Suc_right length_Suc_conv)
   apply (cut_tac a="y#ys" in TwosComplement__toInt_hd_1, simp_all)
   apply (drule_tac x=ys in spec, simp, erule mp)
   apply (cut_tac bs=ys and len ="length bs1" in 
          TwosComplement__toInt_neg_range2)
   apply (simp only: length_greater_0_iff, simp_all)
   apply (frule Bits__nonempty_le_length, auto)
done

lemma TwosComplement_extendLeft_tcInt_neg:
  "\<lbrakk>bs1 \<noteq> []; length bs1 < length bs2; 
    TwosComplement__toInt bs1 = i; TwosComplement__toInt bs2 = i; i < 0\<rbrakk>
    \<Longrightarrow> bs2 = List__extendLeft (bs1, B1, length bs2)"
   by (frule_tac k="length bs2 - length bs1" in TwosComplement_extendLeft_tcInt_neg_aux,
       auto simp add: List__extendLeft_def)

lemma TwosComplement_extendLeft_tcInt_neg2:
  "\<lbrakk>bs1 \<noteq> []; length bs1 < len2 ; length bs2 = len2; 
    TwosComplement__toInt bs1 = i; TwosComplement__toInt bs2 = i; i < 0\<rbrakk>
    \<Longrightarrow> bs2 = List__extendLeft (bs1, B1, len2)"
   by (clarsimp simp add: TwosComplement_extendLeft_tcInt_neg)

lemma TwosComplement__extendLeft_to_len_neg_aux: 
   "\<lbrakk>len > 0; i < 2 ^ len\<rbrakk>
    \<Longrightarrow> \<forall>bs. length bs = len+k \<and> toNat bs =  i + 2 ^ length bs - 2 ^ len 
              \<longrightarrow> bs = replicate k B1 @ toBits (i, len)"
   apply (induct k,
          clarsimp, simp only: length_greater_0_iff Bits__inverse_bits_toNat,
          clarsimp simp add: add_Suc_right length_Suc_conv)
   apply (cut_tac bs="y#ys" in Bits__toNat_hd_1, simp_all)
   apply (simp add: nat_mult_2 add_assoc [symmetric],
          rule le_add_diff, rule_tac j="2 ^ (len + k)" in le_trans, simp_all)   
done

lemma TwosComplement__extendLeft_to_len_neg:
   "\<lbrakk>len > 0; i < 2 ^ len; len < len2; length bs = len2;
     TwosComplement__toInt bs = int i - 2 ^ len\<rbrakk>
    \<Longrightarrow> bs = List__extendLeft (toBits (i, len), B1, len2)"
   apply (auto simp add: List__extendLeft_def,
          simp add: TwosComplementInt split: split_if_asm,
          simp only: int_power_simp algebra_simps,
          simp only: power2_int zadd_int int_int_eq)
   apply (cut_tac k="length bs - len" in TwosComplement__extendLeft_to_len_neg_aux,
          auto)
done


lemma TwosComplement__tcN_Nat_extend: 
  "\<lbrakk>bs\<noteq>[]; length bs < len;  int (toNat bs) = i; 
    i \<in> TwosComplement__rangeForLength len\<rbrakk>  
   \<Longrightarrow> TwosComplement__tcNumber (i, len) = List__extendLeft (bs, B0, len)"
 apply (simp add: TwosComplement__tcNumber_def, rule the1I2,
        rule TwosComplement__tcNumber_Obligation_the, auto)
 apply (rule Bits__extendLeft_toNat2, 
        simp_all add: TwosComplement__toInt_nat)
done

lemma TwosComplement__tcN_TC_extend: 
  "\<lbrakk>x \<noteq> []; length x < len; TwosComplement__toInt x = i; 
    i \<in> TwosComplement__rangeForLength len\<rbrakk>  
   \<Longrightarrow> TwosComplement__tcNumber (i, len) = List__extendLeft (x, hd x, len)"
 apply (simp add: TwosComplement__tcNumber_def, rule the1I2,
        rule TwosComplement__tcNumber_Obligation_the, auto)
 apply (cases "hd x", auto)
 apply (rule TwosComplement_extendLeft_tcInt_pos, simp_all, simp add: TwosComplementInt)
 apply (rule TwosComplement_extendLeft_tcInt_neg, simp_all, simp add: TwosComplementInt)
done

lemma TwosComplement__tcN_Nat_extend2:
  "\<lbrakk>x \<noteq> []; length x < len; int (toNat x) = i; i < 2 ^ (length x)\<rbrakk>  
   \<Longrightarrow> TwosComplement__tcNumber (i, len) = List__extendLeft (x, B0, len)"
 apply (rule TwosComplement__tcN_Nat_extend, auto simp add: TwosComplement_tcN)
 apply (cut_tac bs=x in Bits__toNat_bound, simp, erule less_le_trans, simp)
done

lemma TwosComplement__tcN_TC_extend2: 
  "\<lbrakk>x \<noteq> []; length x < len; TwosComplement__toInt x = i; 
     - (2 ^ (length x - 1)) \<le> i;  i < 2 ^ (length x - 1 )\<rbrakk>  
   \<Longrightarrow> TwosComplement__tcNumber (i, len) = List__extendLeft (x, hd x, len)"
 apply (rule TwosComplement__tcN_TC_extend, auto simp add: TwosComplement_tcN)
 apply (rule zle_trans, simp_all,
        rule less_trans, simp_all, rule power_strict_increasing, simp_all,
        rule diff_less_mono, simp, simp only: length_greater_0_iff)
done

lemma TwosComplement_mod_pos:
  "\<lbrakk>0<len; len\<le> length bits; TwosComplement__toInt bits = i; 0 \<le> i\<rbrakk>
   \<Longrightarrow> toBits (nat (i mod 2^len), len) = List__suffix (bits, len)"
  apply (cut_tac TwosComplement__toInt_pos, simp_all)
  apply (frule_tac toBits_mod, simp_all add: nat_mod_distrib power2_int)
done

lemma TwosComplement_mod_neg:
  "\<lbrakk>0<len; len\<le> length bits; TwosComplement__toInt bits = i; i < 0\<rbrakk>
   \<Longrightarrow> toBits (nat (i mod 2^len), len) = List__suffix (bits, len)"
  apply (cut_tac TwosComplement__toInt_neg, simp_all)
  apply (frule_tac toBits_mod, simp, simp)
  apply (subgoal_tac "0 \<le> i + 2 ^ length bits")
  apply (rule_tac t="nat (i mod 2^len)"
              and s="nat (i + 2 ^ length bits) mod 2 ^ len" in subst,
         simp_all add:  power2_nat)
  apply (subst nat_mod_distrib [symmetric], simp_all add: eq_nat_nat_iff,
         rule_tac t="2 ^ length bits" and s="2 ^ (length bits - len) * 2 ^ len"
         in subst, simp_all, simp add: zpower_zadd_distrib [symmetric])
  apply (cut_tac x=bits in TwosComplement__integer_range, simp_all,
          rule_tac j="i+(2 ^ (length bits - 1))" in zle_trans, 
          simp_all add: TwosComplement_tcN)
done

lemma TwosComplement_mod:
  "\<lbrakk>0<len; len\<le> length bits; TwosComplement__toInt bits = i\<rbrakk>
   \<Longrightarrow> toBits (nat (i mod 2^len), len) = List__suffix (bits, len)"
  by (cases "0 \<le> i", 
      simp_all add: not_le TwosComplement_mod_pos TwosComplement_mod_neg)


lemma TwosComplement_mod2:
  "\<lbrakk>0<len; len\<le> length bits; 
    toNat bs = nat (TwosComplement__toInt bits mod 2^len); length bs = len\<rbrakk>
   \<Longrightarrow> bs = List__suffix (bits, len)"
  by (frule_tac TwosComplement_mod [symmetric], simp_all, drule sym, simp)


(******************************************************************************)

(******************************************************************************)
end-proof

endspec