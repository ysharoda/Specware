CGen qualifying spec

import /Languages/MetaSlang/CodeGen/I2L/SpecsToI2L       % MetaSlang to I2L
import /Languages/I2L/CodeGen/C/I2LToC                   % I2L       to C

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Generate a C_Spec from an already transformed MetaSlang spec.
%% The filter function is used to selectively generate code only for those ops 
%% and types x for which filter(x) is true.
%% The C_Spec parameter is used for incremental code generation.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

op renameTypes (spc : Spec, renamings : List (String * String)) : Spec =
 let
   def map_term term = term

   def map_type typ =
     case typ of
       | Base (Qualified(q,id), args, _) ->
         (case findLeftmost (fn (old, _) -> id = old) renamings of
            | Some (_, new) -> 
              Base (Qualified(q,new), args, noPos)
            | _ ->
              typ)
       | _ -> typ

   def map_pattern pattern = pattern

 in
 let tsp = (map_term, map_type, map_pattern) in
 %% TODO: rename elements?
 mapSpec tsp spc

%% temporary hack until '#translate C' is working
op generateCSpecFromTransformedSpecHack (ms_spec    : Spec) 
                                        (app_name   : String) 
                                        (old_c_spec : C_Spec)
                                        (filter     : QualifiedId -> Bool) 
                                        (includes        : List String)
                                        (op_extern_types : List (String*String))
                                        (op_extern_defs  : List String)
 : Option C_Spec =
 let use_ref_types?  = true in
 let constructer_ops = []   in
 let ms_spec = renameTypes (ms_spec, op_extern_types) in
 let 
   def filter_wrt_extern_defs (qid as Qualified (q, id)) =
    filter qid && ~(id in? op_extern_defs)
 in
 let i2l_spec   = generateI2LCodeSpecFilter (ms_spec,
                                             use_ref_types?,
                                             constructer_ops,
                                             filter_wrt_extern_defs)
 in
 let new_c_spec = generateC4ImpUnitHack (i2l_spec,
                                         old_c_spec, 
                                         use_ref_types?,
                                         includes)
 in
 Some new_c_spec

op generateCSpecFromTransformedSpecIncrFilter (ms_spec    : Spec) 
                                              (app_name   : String) 
                                              (old_c_spec : C_Spec)
                                              (filter     : QualifiedId -> Bool) 
 : Option C_Spec =
 let use_ref_types?  = true in
 let constructer_ops = []   in

 let i2l_spec   = generateI2LCodeSpecFilter (ms_spec,
                                             use_ref_types?,
                                             constructer_ops,
                                             filter)
 in
 let new_c_spec = generateC4ImpUnit (i2l_spec,
                                    old_c_spec, 
                                    use_ref_types?)
 in
 Some new_c_spec

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Increment a pre-existing C_Spec from an already transformed MetaSlang spec.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

op generateCSpecFromTransformedSpecIncr (ms_spec    : Spec) 
                                        (app_name   : String) 
                                        (old_c_spec : C_Spec)
 : Option C_Spec =
 let accept_all = (fn _ -> true) in
 generateCSpecFromTransformedSpecIncrFilter ms_spec app_name old_c_spec accept_all

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Generate a C_Spec from an already transformed MetaSlang spec.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

op generateCSpecFromTransformedSpec (ms_spec : Spec) (app_name : String) 
 : Option C_Spec =
 generateCSpecFromTransformedSpecIncr ms_spec app_name (emptyCSpec "")

end-spec