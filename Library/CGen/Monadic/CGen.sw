CGen qualifying spec
  import C_Permissions, C_DSL


  (***
   *** Boolean Expressions
   ***)

  op bool_valueabs : ValueAbs Bool =
    scalar_value_abstraction (fn (v,b) -> zeroScalarValue? v = return b)

  theorem true_correct is [a]
    fa (envp,perms_in:PermSet a,perms_out,m)
      m = ICONST_m "1" && perms_out = (perms_in, ([], bool_valueabs)) =>
      abstracts_expression envp perms_in perms_out (fn _ -> true) m

  theorem false_correct is [a]
    fa (envp,perms_in:PermSet a,perms_out,m)
      m = ICONST_m "0" && perms_out = (perms_in, ([], bool_valueabs)) =>
      abstracts_expression envp perms_in perms_out (fn _ -> false) m


  (***
   *** Return Statements and Assignments to Output Variables
   ***)

  (* FIXME: document all these! *)

  op [a,b] RETURN (e: a -> b) : a -> a * b =
    fn a -> (a, e a)

  theorem RETURN_correct is [a,b]
    fa (envp,perms_in,perms_out,eperms_out,e:a->b,expr,stmt)
      stmt = RETURN_m expr &&
      perms_out = (perm_set_map (invert_biview proj1_biview) eperms_out.1,
                   Some (val_perm_map (invert_biview proj2_biview) eperms_out.2)) &&
      abstracts_expression envp perms_in eperms_out e expr =>
      abstracts_ret_statement
        envp perms_in perms_out
        (RETURN e)
        stmt

  op [a] RETURN_VOID : a -> a * () = fn a -> (a, ())

  theorem RETURN_VOID_correct is [a]
    fa (envp,perms_in:PermSet a,perms_out,stmt)
      stmt = RETURN_VOID_m &&
      perms_out = (perm_set_map (invert_biview proj1_biview) perms_in, None) =>
      abstracts_ret_statement
        envp perms_in perms_out
        RETURN_VOID
        stmt


  (***
   *** Functions
   ***)


end-spec