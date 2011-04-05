(**
 translation from the Intermediate Imperative Language to C
 *)

I2LToC qualifying spec 
{
  import /Languages/C/C
  import /Languages/C/CUtils
  import /Languages/I2L/I2L
  import CGenOptions

  % import ESpecsCodeGenerationOptions

  import /Library/Legacy/DataStructures/ListPair

  type I2C_Context = {
                      xcspc            : C_Spec,    % for incrementatl code generation, xcspc holds the existing cspec that is extended
                      useRefTypes      : Bool,
                      currentFunName   : Option String,
                      currentFunParams : C_VarDecls
                      }

  op default_I2C_Context : I2C_Context =
   {
    xcspc            = emptyCSpec "",
    useRefTypes      = true,
    currentFunName   = None,
    currentFunParams = []
    }

  op setCurrentFunName (ctxt : I2C_Context, id : String) : I2C_Context =
    ctxt << {currentFunName = Some id}

  op setCurrentFunParams (ctxt : I2C_Context, params : C_VarDecls) : I2C_Context =
    ctxt << {currentFunParams = params}                        

  op generateC4ImpUnit (impunit : I_ImpUnit, xcspc : C_Spec, useRefTypes : Bool) : C_Spec =
  %let _ = writeLine(";;   phase 2: generating C...") in
    let ctxt = {xcspc            = xcspc,
                useRefTypes      = useRefTypes,
                currentFunName   = None,
                currentFunParams = []}
    in
    let cspc = emptyCSpec impunit.name in
    let cspc = addBuiltIn (ctxt, cspc) in
    let cspc = foldl (fn (cspc, typedef) -> c4TypeDefinition (ctxt, cspc, typedef)) cspc impunit.decls.typedefs in
    let cspc = foldl (fn (cspc, typedef) -> c4OpDecl         (ctxt, cspc, typedef)) cspc impunit.decls.opdecls  in
    let cspc = foldl (fn (cspc, typedef) -> c4FunDecl        (ctxt, cspc, typedef)) cspc impunit.decls.funDecls in
    let cspc = foldl (fn (cspc, typedef) -> c4FunDefn        (ctxt, cspc, typedef)) cspc impunit.decls.funDefns in
    let cspc = foldl (fn (cspc, typedef) -> c4VarDecl        (ctxt, cspc, typedef)) cspc impunit.decls.varDecls in
    let cspc = foldl (fn (cspc, typedef) -> c4MapDecl        (ctxt, cspc, typedef)) cspc impunit.decls.mapDecls in
    let cspc = postProcessCSpec cspc
    in
    cspc

  op postProcessCSpec (cspc : C_Spec) : C_Spec =
    let cspc = sortStructUnionTypeDefns cspc in
    let cspc = deleteUnusedTypes cspc in
    cspc

  op addBuiltIn (_ : I2C_Context, cspc : C_Spec) : C_Spec =
    %%    let cspc = addDefine(cspc,"COPRDCTSELSIZE 20") in
    %%    let cspc = addDefine(cspc,"FALSE 0") in
    %%    let cspc = addDefine(cspc,"TRUE 1") in
    %%    let cspc = addDefine(cspc,
    %%			 "SetConstructor(_X_,_SELSTR_) "^
    %%			 "strncpy(_X_.sel,_SELSTR_,COPRDCTSELSIZE)"
    %%			)
    %%    in
    %%    let cspc = addDefine(cspc,
    %%			 "ConstructorEq(_X_,_SELSTR_) "^
    %%			 "(strncmp(_X_.sel,_SELSTR_,COPRDCTSELSIZE)==0)"
    %%			)
    %%    in
    %%    let cspc = addDefine(cspc,
    %%			 "ConstructorArg(_X_,_CONSTR_) "^
    %%			 "_X_.alt._CONSTR_")
    %%    in
    %%    let cspc =
    %%          %if generateCodeForMotes then
    %%	  %  addDefine(cspc,"NONEXHAUSTIVEMATCH_ERROR 0")
    %%	  %else
    %%	    addDefine(cspc,"NONEXHAUSTIVEMATCH_ERROR "^
    %%		      "printf(\"Nonexhaustive match failure\\n\")")
    %%    in
    %%    let cspc = addInclude(cspc,"stdio.h") in
    %%    let cspc = addInclude(cspc,"string.h") in
    let cspc = addInclude (cspc, "SWC_Common.h") in
    cspc

  % --------------------------------------------------------------------------------

  op c4TypeDefinition (ctxt : I2C_Context, cspc : C_Spec, (tname,typ) : I_TypeDefinition) : C_Spec =
    let tname        = qname2id tname            in
    let (cspc,ctype) = c4Type(ctxt,cspc,typ)     in
    let typedef      = (tname,ctype)             in
    let cspc         = addTypeDefn(cspc,typedef) in
   %let cspc = if typ = Any then cspc else addDefine(cspc,"TypeDef_For_"^tname) in
    cspc

  op c4OpDecl (ctxt :  I2C_Context, cspc : C_Spec, decl : I_Declaration) : C_Spec =
    c4OpDecl_internal (ctxt, cspc, decl, None)

  op c4OpDecl_internal (ctxt                         : I2C_Context, 
                        cspc                         : C_Spec, 
                        decl as (opname,typ,optexpr) : I_Declaration, 
                        optinitstr                   : Option String) 
    : C_Spec =
    let vname        = qname2id opname       in
    let (cspc,ctype) = c4Type(ctxt,cspc,typ) in
    case optexpr of
      | Some expr -> 
        let emptyblock         = ([],[]) in
        let (cspc,block,cexpr) = c4InitializerExpression (ctxt, cspc, emptyblock, expr) in
        if (block = emptyblock) && constExpr?(cspc,cexpr) then
          addVarDefn(cspc, (vname, ctype, cexpr))
        else
          c4NonConstVarDef (ctxt, vname, ctype, cspc, block, cexpr)
          % fail("code generation cannot handle the kind of definition terms as\n       "
          %	 ^"the one you specified for op/var \""
          %	 ^vname^"\".")
      | _ -> 
        case optinitstr of
          | None         -> addVar     (cspc, voidToUInt (vname, ctype))
          | Some initstr -> addVarDefn (cspc, (vname, ctype, C_Var (initstr, C_Void))) % ok,ok, ... 
            
  op voidToUInt ((vname, ctype) : C_VarDecl) : C_VarDecl =
    %% TODO: precise type (C_UInt16, C_UInt32, C_UInt64) depends on target machine
    (vname, if ctype = C_Void then C_UInt32 else ctype)

  (*
   * for each non-constant variable definition X an function get_X() and a
   * boolean variable _X_initialized is generated 
   *)
  op c4NonConstVarDef (ctxt : I2C_Context, vname : Id, ctype : C_Type, cspc : C_Spec, block as (decls, stmts) : C_Block, cexpr : C_Exp) 
    : C_Spec =
    let initfname  = "get_" ^ vname   in
    let valuevname = vname ^ "_value" in
    let cspc       = addDefine  (cspc, vname ^ " " ^ initfname ^ "()")   in
    let cspc       = addVarDefn (cspc, (valuevname, ctype, NULL))        in
    let condexp    = C_Binary   (C_Eq,  C_Var(valuevname, ctype), NULL)  in
    let setexp     = C_Binary   (C_Set, C_Var(valuevname, ctype), cexpr) in
    let body       = C_Block    (decls, stmts ++ [C_IfThen (condexp, C_Exp setexp), 
                                                  C_Return (C_Var (valuevname, ctype))]) 
    in
    let fndefn     = (initfname, [], ctype, body)             in
    let cspc       = addFnDefn (cspc, fndefn)                 in
    let cspc       = addFn     (cspc, (initfname, [], ctype)) in
    cspc

  op c4FunDecl (ctxt : I2C_Context, cspc : C_Spec, fdecl : I_FunDeclaration) : C_Spec =
    let (cspc, fname, ctypes, rtype) = c4FunDecl_internal (ctxt, cspc, fdecl) in
    addFn (cspc, (fname, ctypes, rtype))

  op c4FunDecl_internal (ctxt : I2C_Context, cspc : C_Spec, fdecl : I_FunDeclaration) 
    : C_Spec * String * C_Types * C_Type =
    let fname          = qname2id fdecl.name                    in
    let paramtypes     = map (fn (_, t) -> t) fdecl.params      in
    let (cspc, ctypes) = c4Types (ctxt, cspc, paramtypes)       in
    let (cspc, rtype)  = c4Type  (ctxt, cspc, fdecl.returntype) in
    (cspc, fname, ctypes, rtype)

  op c4FunDefn (ctxt : I2C_Context, cspc : C_Spec, fdefn : I_FunDefinition) : C_Spec =
    let fdecl                        = fdefn.decl                             in
    let (cspc, fname, ctypes, rtype) = c4FunDecl_internal (ctxt, cspc, fdecl) in
    let ctxt                         = setCurrentFunName  (ctxt, fname)       in
    let body                         = fdefn.body                             in
    let parnames                     = map (fn (n, _) -> n) fdecl.params      in
    let vardecls                     = zip (parnames, ctypes)                 in
    case body of

      | I_Stads stadsbody -> 
        let returnstmt           = C_ReturnVoid in
        let (cspc, block, stmts) = foldl (fn ((cspc, block, stmts), stadcode) -> 
                                            let (cspc, block, stadstmts) = 
                                            c4StadCode (ctxt, cspc, block, stadsbody, returnstmt, stadcode) in
                                            let stmts = stmts++stadstmts in
                                            (cspc, block, stmts))
                                         (cspc, ([], []), []) 
                                         stadsbody
        in
        let stmt  = addStmts (C_Block block, stmts) in
        let fdefn = (fname, vardecls, rtype, stmt) in
        addFnDefn (cspc, fdefn)

      | I_Exp expr ->
	let ctxt                                   = setCurrentFunParams (ctxt, vardecls)      in
        let (cspc, block as (decls, stmts), cexpr) = c4Expression (ctxt, cspc, ([], []), expr) in
	let (stmts1, cexpr1)                       = commaExprToStmts (ctxt, cexpr)            in
	let stmts2                                 = conditionalExprToStmts (ctxt, cexpr1, (fn e -> C_Return e)) in
	let block                                  = (decls, stmts++stmts1++stmts2)            in
	let block                                  = findBlockForDecls block                   in
	let stmt                                   = C_Block block                             in
	let fdefn                                  = (fname, vardecls, rtype, stmt)            in
	addFnDefn (cspc, fdefn)

  op c4VarDecl (ctxt : I2C_Context, cspc : C_Spec, vdecl : I_Declaration) : C_Spec =
    % check for records containing functions
    let
      def structCheck (cspc, typ, ids) =
        case typ of

          | I_Struct fields ->
            let (cspc, initstr, initstrIsUseful) =
            foldl (fn ( (cspc, initstr, useful), (id, t)) -> 
                     let (cspc, initstr0, useful0) = structCheck (cspc, t, id::ids)                               in
                     let initstr                   = if initstr = "" then initstr0 else initstr ^ ", " ^ initstr0 in
                     (cspc, initstr, useful || useful0))
                  (cspc, "", false) 
                  fields
            in
            (cspc, "{" ^ initstr ^ "}", initstrIsUseful)
           
          | I_FunOrMap (types, rtype) ->
            let fname           = foldr (fn (id, s) -> if s="" then id else s^"_"^id) "" ids in
            let (cspc, vardecl) = addMapForMapDecl (ctxt, cspc, fname, types, rtype)         in
            % todo: add a initializer for the field!
            (addVar (cspc, voidToUInt vardecl), "&" ^ fname, true)
            
          | _ -> (cspc, "0", false)
    in
    let (vname, vtype, e)                = vdecl                                          in
    let vid                              = (qname2id vname)                               in
    let (cspc, initstr, initstrIsUseful) = structCheck (cspc, vtype, [vid])               in
    let optinitstr                       = if initstrIsUseful then Some initstr else None in
    c4OpDecl_internal (ctxt, cspc, vdecl, optinitstr)

  % --------------------------------------------------------------------------------

  op c4MapDecl (ctxt : I2C_Context, cspc : C_Spec, mdecl : I_FunDeclaration) : C_Spec =
    let fid             = qname2id mdecl.name in
    let paramtypes      = map (fn (_, t)->t) mdecl.params in
    let (cspc, vardecl) = addMapForMapDecl (ctxt, cspc, fid, paramtypes, mdecl.returntype) in
    addVar (cspc, voidToUInt vardecl)

  % addMapForMapDecl is responsible for creating the arrays and access functions for
  % n-ary vars. The inputs are the name of the var, the argument types and the return t_ype.
  % outputs the updates cspec and a var decl for the array. The var decl is not inserted in the cspec
  % because it may also be used as a field of a record and has to be added there
  op addMapForMapDecl (ctxt : I2C_Context, cspc : C_Spec, fid : String, paramtypes : I_Types, returntype : I_Type)
    : C_Spec * C_VarDecl =
    let id                  = getMapName fid in
    let (cspc, paramctypes) = c4Types (ctxt, cspc, paramtypes) in
    case getBoundedNatList paramtypes of
      
      | Some bounds ->
        let (cspc, rtype) = c4Type (ctxt, cspc, returntype)                                      in
        let arraytype     = C_ArrayWithSize (bounds, rtype)                                      in
        let vardecl       = (id, arraytype)                                                      in
        % construct the access function
        let paramnames    = map getParamName (getNumberListOfSameSize paramtypes)                in
        let vardecls      = zip (paramnames, paramctypes)                                        in
        let arrayvarexpr  = C_Var (id, C_Ptr rtype)                                              in 
        let arrayrefs     = foldr (fn (v, e2) -> C_ArrayRef (e2, C_Var v)) arrayvarexpr vardecls in
        let stmt          = C_Return arrayrefs                                                   in
        let cspc          = addFnDefn (cspc, (fid, vardecls, rtype, stmt))                       in
        (cspc, vardecl)
        
      | _ -> 
        fail ("in this version of the code generator you can use either 0-ary vars\n"^
                "or 1-ary vars of the form \"var "^id^": {n:Nat|n<C}\", where C must be\n"^
                "an natural number.")

  op getBoundedNatList (types : I_Types) : Option C_Exps =
    case types of
      | [] -> None
      | _ ->
        let
          def getBoundedNatList0 types =
            case types of
              | [] -> Some []
              | (I_BoundedNat n) :: types ->
                (case getBoundedNatList0 types of
                   | Some bounds -> 
                     let bound = C_Const (C_Int (true, n)) in
                     Some (bound::bounds)
                   | None -> None)
              | _ -> None
        in
        getBoundedNatList0 types

  op coproductSelectorStringLength : C_Exp = C_Const (C_Macro "COPRDCTSELSIZE")

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %                                                                     %
  %                               TYPES                                 %
  %                                                                     %
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  op c4Type (ctxt : I2C_Context, cspc : C_Spec, typ : I_Type) : C_Spec * C_Type =
    let
      def structUnionFields (cspc, fields) =
        case fields of
          | [] -> (cspc, [])
          | (fname, itype)::fields -> 
            let (cspc, ctype)   = c4Type (ctxt, cspc, itype)                 in
            let ctype           = if ctype = C_Void then C_UInt32 else ctype in % no void fields allowed
            let (cspc, sfields) = structUnionFields (cspc, fields)           in
            (cspc, (fname, ctype) :: sfields)

      def addFieldNamesToTupleTypes (types) =
        let fieldnames = getFieldNamesForTuple types in
        zip (fieldnames, types)

    in
    case c4TypeSpecial (cspc, typ) of
      | Some res -> res
      | _ ->
        %let _ = writeLine ("Looking at " ^ anyToString typ) in
        let xx =
        case typ of

          | I_Primitive p -> (cspc, c4PrimitiveType p)

          | I_Base tname  -> (cspc, C_Base (qname2id tname))

          | I_Struct fields -> 
            let (cspc, sfields)    = structUnionFields (cspc, fields)                                             in
            let structname         = genName (cspc, "Product", length (getStructDefns cspc))                      in
            let (cspc, structtype) = addNewStructDefn (cspc, ctxt.xcspc, (structname, sfields), ctxt.useRefTypes) in
            (cspc, structtype)
            
          | I_Tuple types ->
            let fields = addFieldNamesToTupleTypes types in
            c4Type (ctxt, cspc, I_Struct fields)
            
          | I_Union fields ->
            let (cspc, ufields)    = structUnionFields (cspc, fields)                                             in
            let unionname          = genName (cspc, "CoProduct",  length (getUnionDefns  cspc))                   in
            let structname         = genName (cspc, "CoProductS", length (getStructDefns cspc))                   in
            let (cspc, uniontype)  = addNewUnionDefn (cspc, ctxt.xcspc, (unionname, ufields))                     in
            let sfields            = [("sel", C_ArrayWithSize ([coproductSelectorStringLength], C_Char)), 
                                      ("alt", uniontype)] 
            in
            let (cspc, structtype) = addNewStructDefn (cspc, ctxt.xcspc, (structname, sfields), ctxt.useRefTypes) in
            (cspc, structtype)
            
          | I_Ref rtype ->
            let (cspc, ctype) = c4Type (ctxt, cspc, rtype) in
            (cspc, C_Ptr ctype)
           
          | I_FunOrMap (types, rtype) ->
            let (cspc, ctypes) = c4Types (ctxt, cspc, types)                                       in
            let (cspc, ctype)  = c4Type  (ctxt, cspc, rtype)                                       in
            let tname          = genName (cspc, "fn", length (getTypeDefns cspc))                  in
            let (cspc, ctype)  = addNewTypeDefn (cspc, ctxt. xcspc, (tname, C_Fn (ctypes, ctype))) in
            (cspc, ctype)
           
          | I_Any -> (cspc, C_Base "Any")
           
          | I_Void -> (cspc, C_Void)
            
          | I_BoundedNat n -> 
            %let _ = writeLine ("Type for bounded nat : " ^ anyToString n) in
            let c_type =
                if n <= 2**8  then C_UInt8  else
                if n <= 2**16 then C_UInt16 else
                if n <= 2**32 then C_UInt32 else
                if n <= 2**64 then C_UInt64 else
                let _ = writeLine ("I2LToC Warning: Nat maximum exceeds 2**64: " ^ anyToString n ^ ", using UInt32") in
                C_UInt32
            in
            %let _ = writeLine (" ===> " ^ anyToString c_type) in
            (cspc, c_type)
            
          | I_BoundedInt (m, n) -> 
            %let _ = writeLine ("Type for bounded int : " ^ anyToString m ^ " " ^ anyToString n) in
            let c_type =
                if        0 <= m && n < 2**8  then C_UInt8  else % (-1, 2**8) = [0, 2**8 - 1]
                if        0 <= m && n < 2**16 then C_UInt16 else 
                if        0 <= m && n < 2**32 then C_UInt32 else
                if        0 <= m && n < 2**64 then C_UInt64 else
                if -(2**7)  <= m && n < 2**7  then C_Int8   else
                if -(2**15) <= m && n < 2**15 then C_Int16  else
                if -(2**31) <= m && n < 2**31 then C_Int32  else
                if -(2**63) <= m && n < 2**63 then C_Int64  else
                let _ = writeLine ("I2LToC Warning: Int range exceeds [-2**63, 2**63): [" ^ anyToString m ^ ", " ^ anyToString n ^ "], using C_Int32") in
                C_Int32
            in
            % let _ = writeLine (" ===> " ^ anyToString c_type) in
            (cspc, c_type)

          | I_BoundedList (ltype, n) -> 
            let (cspc, ctype)      = c4Type (ctxt, cspc, ltype)                                                   in
            let deflen             = length cspc.defines                                                          in
            let constName          = genName (cspc, "MAX", deflen)                                                in
            let cspc               = addDefine (cspc, constName ^ " " ^ show n)                                   in
            let arraytype          = C_ArrayWithSize ([C_Const (C_Macro constName)], ctype)                       in
            let structname         = genName (cspc, "BoundList", length (getStructDefns cspc))                    in
            let sfields            = [("length", C_Int32), ("data", arraytype)]                                   in
            let (cspc, structtype) = addNewStructDefn (cspc, ctxt.xcspc, (structname, sfields), ctxt.useRefTypes) in
            (cspc, structtype)
            
          | _ -> 
            (print typ;
             % (cspc, Int)
             fail ("sorry, no code generation implemented for that type."))
        in
        % let _ = writeLine ("result = " ^ anyToString xx) in
        xx
            
  op c4Types (ctxt : I2C_Context, cspc : C_Spec, types : I_Types) : C_Spec * C_Types =
    foldl (fn ((cspc, ctypes), typ) ->
             let (cspc, ct) = c4Type (ctxt, cspc, typ) in
             (cspc, ctypes ++ [ct]))
          (cspc, []) 
          types

  op c4PrimitiveType (prim : I_Primitive) : C_Type =
    case prim of
      | I_Bool   -> C_Int8
      | I_Nat    -> % let _ = writeLine ("I2LToC Unbounded Nat treated as unsigned 32 bits") in 
                    C_UInt32  % unbounded -- to be avoided
      | I_Int    -> % let _ = writeLine ("I2LToC Unbounded Int treated as signed 32 bits")   in 
                    C_Int32  % unbounded -- to be avoided
      | I_Char   -> C_Char
      | I_String -> C_String
      | I_Float  -> C_Float

  % handle special cases of types:

  op c4TypeSpecial (cspc : C_Spec, typ : I_Type) : Option (C_Spec * C_Type) =
    if bitStringSpecial? then
      case typ of
        | I_Base (_, "BitString") -> Some (cspc, C_UInt32)
        | _ -> None
    else
      None

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %                                                                     %
  %                            EXPRESSIONS                              %
  %                                                                     %
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  op c4Expression1 (ctxt                    : I2C_Context, 
                    cspc                    : C_Spec, 
                    block as (decls, stmts) : C_Block,  
                    exp   as (expr, typ)    : I_TypedExpr,
                    lhs?                    : Bool, 
                    forInitializer?         : Bool)
    : C_Spec * C_Block * C_Exp =
    let (cspc, block, cexpr) = c4Expression2 (ctxt, cspc, block, exp, lhs?, forInitializer?) in
    let (cspc, block, cexpr) = mergeBlockIntoExpr (cspc, block, cexpr)                       in
    (cspc, block, cexpr)

  op c4Expression2 (ctxt                    : I2C_Context,
                    cspc                    : C_Spec,
                    block as (decls, stmts) : C_Block,
                    exp   as (expr, typ)    : I_TypedExpr,
                    lhs?                    : Bool,
                    forInitializer?         : Bool)
    : C_Spec * C_Block * C_Exp =
    let
      def addProjections (cexpr, projections) =
        case projections of
          | [] -> cexpr
          | p :: projections ->
            let p = getProjectionFieldName p in
            addProjections (C_StructRef (cexpr, p), projections)
    in
    let
      def processFunMap f (vname, projections, exprs) =
        let id                    = qname2id vname                                      in
        let (cspc, block, cexprs) = c4Expressions (ctxt, cspc, block, exprs)            in
        let (cspc, ctype)         = c4Type (ctxt, cspc, typ)                            in
        let cexpr1                = addProjections (f (C_Var (id, ctype)), projections) in
        (cspc, block, C_Apply (cexpr1, cexprs))
    in
    let
      def processMapAccess f (vname, maptype, projections, exprs) =
        let id = qname2id vname in
        case maptype of

          | I_FunOrMap (types, _) ->
            (case getBoundedNatList (types) of

               | Some ns ->
                 let (cspc, block, cexprs) = c4Expressions (ctxt, cspc, block, exprs)      in
                 let (cspc, ctype)         = c4Type (ctxt, cspc, typ)                      in
                 % if we have projections, the map name must be the prefix of the last field name
                 % otherwise of the id itself
                 let id = foldl (fn (s, p) -> s ^ "_" ^ getProjectionFieldName p)
                                (getMapName id) 
                                projections
                 in
                 let projections = []                                                       in
                 let cexpr1      = addProjections (f (C_Var (id, ctype)), projections)      in
                 let arrayrefs   = foldr (fn (e1, e2) -> C_ArrayRef (e2, e1)) cexpr1 cexprs in
                 (cspc, block, arrayrefs)

               | _ -> 
                 fail "unsupported variable format, use 1-ary vars from bounded Nat")
          | _ -> 
            fail "unsupported variable format, use 1-ary vars from bounded Nat"
    in
    case expr of
      | I_Str   s -> (cspc, block, C_Const (C_Str   s))
      | I_Int   n -> (cspc, block, C_Const (C_Int   (true, n)))
      | I_Char  c -> (cspc, block, C_Const (C_Char  c))
      | I_Float f -> (cspc, block, C_Const (C_Float f))
      | I_Bool  b -> (cspc, block, if b then ctrue else cfalse)
        
      | I_Builtin bexp -> c4BuiltInExpr (ctxt, cspc, block, bexp)
        
      | I_Let (id, typ, idexpr, expr) ->
        let (id, expr)                      = substVarIfDeclared (ctxt, id, decls, expr)     in
        let (cspc, ctype)                   = c4Type (ctxt, cspc, typ)                       in
        let (cspc, (decls, stmts), idcexpr) = c4Expression (ctxt, cspc, block, idexpr)       in
        let letvardecl                      = (id, ctype)                                    in
        let optinit                         = None                                           in  % if ctxt.useRefTypes then getMallocApply (cspc, ctype) else None in
        let letvardecl1                     = (id, ctype, optinit)                           in
        let letsetexpr                      = getSetExpr (ctxt, C_Var (letvardecl), idcexpr) in
        let block                           = (decls++[letvardecl1], stmts)                  in
        let (cspc, block, cexpr)            = c4Expression (ctxt, cspc, block, expr)         in
        (cspc, block, C_Comma (letsetexpr, cexpr))
        
      | I_FunCall (vname, projections, exprs) ->
        processFunMap (fn e -> e) (vname, projections, exprs)
        
      | I_FunCallDeref (vname, projections, exprs) ->
        processFunMap (fn e -> C_Unary (C_Contents, e)) (vname, projections, exprs)
        
      | I_MapAccess (vname, maptype, projections, exprs) ->
        if lhs? then
          processMapAccess (fn e -> e) (vname, maptype, projections, exprs)
        else
          processFunMap (fn e -> e) (vname, projections, exprs)
          
      | I_MapAccessDeref (vname, maptype, projections, exprs) ->
        if lhs? then 
          processMapAccess (fn e -> C_Unary (C_Contents, e)) (vname, maptype, projections, exprs)
        else
          processFunMap (fn e -> C_Unary (C_Contents, e)) (vname, projections, exprs)
            
      | I_TupleExpr exprs ->
        let fieldnames = getFieldNamesForTuple (exprs) in
        c4StructExpr (ctxt, cspc, block, typ, exprs, fieldnames, forInitializer?)

      | I_StructExpr fields ->
        let fieldnames = map (fn (n, _) -> n) fields in
        let exprs      = map (fn (_, e) -> e) fields in
        c4StructExpr (ctxt, cspc, block, typ, exprs, fieldnames, forInitializer?)
        
      | I_Project (expr, id) ->
        let (cspc, block, cexpr) = c4Expression1 (ctxt, cspc, block, expr, lhs?, forInitializer?)  in
        let id                   = getProjectionFieldName id                                       in
        let cexpr                = if ctxt.useRefTypes then C_Unary (C_Contents, cexpr) else cexpr in
        (cspc, block, C_StructRef (cexpr, id))
        
      | I_ConstrCall (typename, consid, exprs) ->
        let consfun       = getConstructorOpNameFromQName (typename, consid) in
        let (cspc, ctype) = c4Type (ctxt, cspc, typ)                         in
        let (cspc, block as (decls, stmt), constrCallExpr) =
            let fnid = getConstructorOpNameFromQName (typename, consid) in
            case exprs of
              | [] -> 
                let fndecl = (fnid, [], ctype) in
                (cspc, block, C_Apply (C_Fn fndecl, []))
              | _ :: _ -> 
                let (cspc, ctypes) = foldl (fn ((cspc, ctypes), (_, ty)) -> 
                                              let (cspc, ctype) = c4Type (ctxt, cspc, ty) in
                                              (cspc, ctypes++[ctype]))
                                           (cspc, []) 
                                           exprs 
                in
                let (cspc, block, cexprs) = c4Expressions (ctxt, cspc, block, exprs) in
                let fndecl = (fnid, ctypes, ctype) in
                (cspc, block, C_Apply (C_Fn fndecl, cexprs))
        in
        (cspc, block, constrCallExpr)
	     
      | I_AssignUnion (selstr, optexpr) ->
        let (cspc, block as (decls, stmts), optcexpr) =
            case optexpr of
              | Some expr -> 
                let (cspc, block, cexpr) = c4Expression (ctxt, cspc, block, expr) in
                (cspc, block, Some cexpr)
              | None -> 
                (cspc, block, None)
        in
        let (cspc, ctype) = c4Type (ctxt, cspc, typ)                        in
        let varPrefix     = getVarPrefix ("_Vc", ctype)                     in
        let xname         = varPrefix ^ (show (length decls))               in
        let decl          = (xname, ctype)                                  in
        let optinit       = getMallocApply (cspc, ctype)                    in
        let decl1         = (xname, ctype, optinit)                         in
        let selassign     = [getSelAssignStmt (ctxt, selstr, xname, ctype)] in
        let altassign     = case optcexpr of
                              | None -> []
                              | Some cexpr ->
                                let var   = C_Var decl                                                  in
                                let sref0 = if ctxt.useRefTypes then C_Unary (C_Contents, var) else var in
                                let sref  = C_StructRef (C_StructRef (sref0, "alt"), selstr)            in
                                [C_Exp (getSetExpr (ctxt, sref, cexpr))]
        in
        let block = (decls ++ [decl1], stmts ++ selassign ++ altassign) in
        let res   = C_Var decl in
        (cspc, block, res)
        
      | I_UnionCaseExpr (expr as (_, type0), unioncases) ->
        let (cspc0, block0 as (decls, stmts), cexpr0) = c4Expression (ctxt, cspc, block, expr) in
        % insert a variable for the discriminator in case cexpr0 isn't a variable, 
        % otherwise it can happen that the C Compiler issues an "illegal lvalue" error
        let (block0 as (decls, stmts), disdecl, newdecl?) =
            case cexpr0 of
              | C_Var decl -> ((decls, stmts), decl, false)
              | _ ->
                let disname         = "_dis_" ^ show (length decls) in
                let (cspc, distype) = c4Type (ctxt, cspc, type0)    in
                let disdecl         = (disname, distype)            in
                let disdecl0        = (disname, distype, None)      in
                let block0          = (decls++[disdecl0], stmts)    in
                (block0, disdecl, true)
        in
        % insert a dummy variable of the same type as the expression to be
        % used in the nonexhaustive match case in order to prevent typing 
        % errors of the C compiler
        let (cspc, xtype)      = c4Type (ctxt, cspc, typ)                  in
        let xtype              = if xtype = C_Void then C_Int32 else xtype in
        let varPrefix          = getVarPrefix ("_Vd_", xtype)              in
        let xname              = varPrefix ^ show (length decls)           in
        let xdecl              = (xname, xtype, None)                      in
        let funname4errmsg     = case ctxt.currentFunName of 
                                   | Some id -> " (\"function '"^id^"'\")" 
                                   | _ -> " (\"unknown function\")"         
        in
        let errorCaseExpr      = C_Comma (C_Var ("NONEXHAUSTIVEMATCH_ERROR"^funname4errmsg, C_Int32), 
                                          C_Var (xname, xtype)) 
        in
        let block0             = (decls ++ [xdecl], stmts)               in
        let 
          def casecond str = 
            getSelCompareExp (ctxt, C_Var disdecl, str) 
        in
        let (cspc, block, ifexpr) =
            foldr (fn (unioncase, (cspc, block as (decls, stmts), ifexp)) -> 
                     case unioncase of
                       
                       | I_ConstrCase (optstr, opttype, vlist, expr) ->
                         (case optstr of
                            
                            | None -> 
                              %% pattern is just a simple wildcard
                              c4Expression (ctxt, cspc0, block0, expr)
                              
                            | Some selstr ->
                              let condition = casecond (selstr) in
                              % insert the variables:
                              let (cspc, block, cexpr) =
                                  case findLeftmost (fn | None -> false | _ -> true) vlist of
                                
                                    | None -> 
                                      %% varlist contains only wildcards (same as single wildcard case)
                                      c4Expression (ctxt, cspc, block, expr)
                                      
                                    | _ ->
                                      let typ = 
                                      case opttype of
                                        | Some t -> t
                                        | None -> 
                                          fail ("internal error: type missing in union case for constructor \""^selstr^"\"")
                                      in
                                      case vlist of
                                        
                                        | [Some id] -> % contains exactly one var
                                          let (id, expr)     = substVarIfDeclared (ctxt, id, decls, expr)                        in
                                          let (cspc, idtype) = c4Type (ctxt, cspc, typ)                                          in
                                          let structref      = if ctxt.useRefTypes then C_Unary (C_Contents, cexpr0) else cexpr0 in
                                          let valexp         = C_StructRef (C_StructRef (structref, "alt"), selstr)              in
                                          let decl           = (id, idtype)                                                      in
                                          let assign         = getSetExpr (ctxt, C_Var decl, valexp)                             in
                                          % the assignment must be attached to the declaration, otherwise
                                          % it may happen that the new variable is accessed in the term without
                                          % being initialized  [so why is optinit None then?]
                                          let optinit        = None                                                              in
                                          let decl1          = (id, idtype, optinit)                                             in
                                          let (cspc, block as (decls, stmts), cexpr) = c4Expression (ctxt, cspc, block, expr)    in
                                          (cspc, (decls ++ [decl1], stmts), C_Comma (assign, cexpr))
                                          
                                        | _ -> 
                                          % the vlist consists of a list of variable names representing the fields
                                          % of the record that is the argument of the constructor. We will introduce
                                          % a fresh variable of that record type and substitute the variable in the vlist
                                          % by corresponding StructRefs into the record.
                                          let (cspc, idtype) = c4Type (ctxt, cspc, typ)                                          in
                                          let varPrefix      = getVarPrefix ("_Va", idtype)                                      in
                                          let id             = varPrefix^ (show (length decls))                                  in
                                          let structref      = if ctxt.useRefTypes then C_Unary (C_Contents, cexpr0) else cexpr0 in
                                          let valexp         = C_StructRef (C_StructRef (structref, "alt"), selstr)              in
                                          let decl           = (id, idtype)                                                      in
                                          let optinit        = None                                                              in
                                          let decl1          = (id, idtype, optinit)                                             in
                                          let assign         = getSetExpr (ctxt, C_Var decl, valexp)                             in
                                          let (cspc, block as (decls, stmts), cexpr) = c4Expression (ctxt, cspc, block, expr)    in
                                          let cexpr          = substVarListByFieldRefs (ctxt, vlist, C_Var decl, cexpr)          in
                                          (cspc, (decls ++ [decl1], stmts), C_Comma (assign, cexpr))
                              in
                              (cspc, block, C_IfExp (condition, cexpr, ifexp)))

                       | I_VarCase (id,ityp,exp) ->
                         let (cid, exp)          = substVarIfDeclared (ctxt, id, decls, exp)    in
                         let (cspc, block, cexp) = c4Expression (ctxt, cspc, block, exp)        in
                         let (cspc, ctype)       = c4Type (ctxt, cspc, ityp)                    in
                         let cvar                = (cid, ctype)                                 in
                         let cassign             = getSetExpr (ctxt, C_Var cvar, C_Var disdecl) in
                         % the assignment must be attached to the declaration, otherwise
                         % it may happen that the new variable is accessed in the term 
                         % without being initialized  [so why is coptinit None then?]
                         let coptinit            = None                                         in
                         let cdecl               = (cid, ctype, coptinit)                       in
                         (cspc, (decls ++ [cdecl], stmts), C_Comma (cassign, cexp))

                       | I_NatCase (n, exp) -> 
                         let (cspc, block, ce)    = c4Expression (ctxt, cspc, block, exp)                          in
                         let (cspc, block, const) = c4Expression (ctxt, cspc, block, (I_Int n, I_Primitive I_Int)) in
                         let cond                 = C_Binary (C_Eq, C_Var disdecl, const)                          in
                         let ifexp                = C_IfExp  (cond, ce, ifexp)                                     in
                         (cspc, block, ifexp)

                       | I_CharCase (c, exp) ->
                         let (cspc, block, ce)    = c4Expression (ctxt, cspc, block, exp)                            in
                         let (cspc, block, const) = c4Expression (ctxt, cspc, block, (I_Char c, I_Primitive I_Char)) in
                         let cond                 = C_Binary (C_Eq, C_Var disdecl, const)                            in
                         let ifexp                = C_IfExp  (cond, ce, ifexp)                                       in
                         (cspc, block, ifexp))
                  (cspc0, block0, errorCaseExpr) 
                  unioncases 
 	 in
         (cspc, 
          block, 
          if newdecl? then 
            %% In general, cexpr0 may be too complex to appear in a C struct accessor form
            %% such as (cexpr0 -> attr), so we need to replace such forms by (var -> attr).
            %% As long as we're at it, we might just as well replace all the cexpr0 
            %% occurrances by var, not just those appearing in struct accessors.
            %% Yell at jlm if this latter assumption is faulty.
            let var   = C_Var disdecl                                                  in
            let xx    = C_Binary (C_Set, var, cexpr0)                                  in
            let newif = mapExp (fn expr -> if expr = cexpr0 then var else expr) ifexpr in
            C_Comma (xx, newif)
          else 
            ifexpr)

      | I_IfExpr (e1, e2, e3) ->
        let (cspc, block, ce1) = c4Expression (ctxt, cspc, block, e1) in
        let (cspc, block, ce2) = c4Expression (ctxt, cspc, block, e2) in
        let (cspc, block, ce3) = c4Expression (ctxt, cspc, block, e3) in
        (cspc, block, C_IfExp (ce1, ce2, ce3))
        
      | I_Var id ->
        let (cspc, ctype) = c4Type (ctxt, cspc, typ) in
        let vname         = qname2id id              in
        let varexp        = C_Var (vname, ctype)     in
        (cspc, block, varexp)
        
      | I_VarDeref id ->
        let (cspc, block, cexp) = c4Expression (ctxt, cspc, block, (I_Var id, typ)) in
        (cspc, block, C_Unary (C_Contents, cexp))
        
      | I_VarRef id ->
        let (cspc, block, cexp) = c4Expression (ctxt, cspc, block, (I_Var id, typ)) in
        (cspc, block, C_Unary (C_Address, cexp))
        
      | I_Comma (exprs) ->
        (case exprs of

           | expr1::exprs1 ->
             let (exprs, expr)        = getLastElem (exprs)                    in
             let (cspc, block, cexpr) = c4Expression (ctxt, cspc, block, expr) in
             foldr (fn (expr1, (cspc, block, cexpr)) ->
                      let (cspc, block, cexpr1) = c4Expression (ctxt, cspc, block, expr1) in
                      (cspc, block, C_Comma (cexpr1, cexpr)))
                   (cspc, block, cexpr) 
                   exprs

           | _ -> fail "Comma expression with no expressions?!")

      | _ -> 
        (print expr;
         fail  "unimplemented case for expression.")

  % --------------------------------------------------------------------------------

  op c4LhsExpression         (ctxt : I2C_Context, cspc : C_Spec, block : C_Block, exp : I_TypedExpr) : C_Spec * C_Block * C_Exp =
    c4Expression1 (ctxt, cspc, block, exp, true, false)

  op c4InitializerExpression (ctxt : I2C_Context, cspc : C_Spec, block : C_Block, exp : I_TypedExpr) : C_Spec * C_Block * C_Exp =
    c4Expression1 (ctxt, cspc, block, exp, false, true)

  op c4Expression            (ctxt : I2C_Context, cspc : C_Spec, block : C_Block, exp : I_TypedExpr) : C_Spec * C_Block * C_Exp =
    case c4SpecialExpr (ctxt, cspc, block, exp) of
      | Some res -> res
      | None -> c4Expression1 (ctxt, cspc, block, exp, false, false)

  % --------------------------------------------------------------------------------

  op c4Expressions (ctxt : I2C_Context, cspc : C_Spec, block : C_Block, exprs : I_TypedExprs) : C_Spec * C_Block * C_Exps =
    foldl (fn ((cspc, block, cexprs), expr) ->
             let (cspc, block, cexpr) = c4Expression (ctxt, cspc, block, expr) in
             (cspc, block, cexprs++[cexpr]))
          (cspc, block, []) 
          exprs

  op c4InitializerExpressions (ctxt : I2C_Context, cspc : C_Spec, block : C_Block, exprs : I_TypedExprs) : C_Spec * C_Block * C_Exps =
    foldl (fn ((cspc, block, cexprs), expr) ->
             let (cspc, block, cexpr) = c4InitializerExpression (ctxt, cspc, block, expr) in
             (cspc, block, cexprs++[cexpr]))
          (cspc, block, []) 
          exprs

  % --------------------------------------------------------------------------------

  op c4StructExpr (ctxt : I2C_Context, cspc : C_Spec, block : C_Block, typ : I_Type, exprs : I_TypedExprs, fieldnames : List String, _ : Bool)
    : C_Spec * C_Block * C_Exp =
    % even inside initialization forms, we may need to allocate struct's
    % if forInitializer? then
    %  c4StructExprForInitializer (ctxt, cspc, block, typ, exprs, fieldnames)
    % else
    c4StructExpr2 (ctxt, cspc, block, typ, exprs, fieldnames)
      

  op c4StructExpr2 (ctxt : I2C_Context, cspc : C_Spec, block : C_Block, typ : I_Type, exprs : I_TypedExprs, fieldnames : List String)
    : C_Spec * C_Block * C_Exp =
    let (cspc, block as (decls, stmts), fexprs) = c4Expressions (ctxt, cspc, block, exprs)                        in
    let (cspc, ctype)                           = c4Type (ctxt, cspc, typ)                                        in
    let varPrefix                               = getVarPrefix ("_Vb", ctype)                                     in
    let xname                                   = varPrefix^ (show (length decls))                                in
    let ctype                                   = if ctype = C_Void then C_Int32 else ctype                       in
    let decl                                    = (xname, ctype)                                                  in
    let optinit                                 = if ctxt.useRefTypes then getMallocApply (cspc, ctype) else None in
    let decl1                                   = (xname, ctype, optinit)                                         in
    let assignstmts = map (fn (field, fexpr) ->
                             let variable = C_Var decl in
                             let variable = if ctxt.useRefTypes then C_Unary (C_Contents, variable) else variable in
                             let fieldref = C_StructRef (variable, field) in
                             C_Exp (getSetExpr (ctxt, fieldref, fexpr)))
                          (zip (fieldnames, fexprs))
    in
    let block       = (decls++[decl1], stmts++assignstmts) in
    let res         = C_Var decl                            in
    (cspc, block, res)

  op c4StructExprForInitializer (ctxt : I2C_Context, cspc : C_Spec, block : C_Block, _ : I_Type, exprs : I_TypedExprs, _ : List String)
    : C_Spec * C_Block * C_Exp =
    let (cspc, block, cexprs) = c4InitializerExpressions (ctxt, cspc, block, exprs) in
    (cspc, block, C_Field cexprs)

  % --------------------------------------------------------------------------------

  op strcmp         : C_Exp = C_Fn ("strcmp",         [C_String,  C_String],          C_Int16)  % might subtract one char from another for result
  op strncmp        : C_Exp = C_Fn ("strncmp",        [C_String,  C_String, C_Int32], C_Int16)  % might subtract one char from another for result
  op hasConstructor : C_Exp = C_Fn ("hasConstructor", [C_VoidPtr, C_String],          C_Int8)   % boolean value
  op selstrncpy     : C_Exp = C_Fn ("SetConstructor", [C_String,  C_String],          C_String) % strncpy

  op c4BuiltInExpr (ctxt : I2C_Context, cspc : C_Spec, block : C_Block, exp : I_BuiltinExpression) : C_Spec * C_Block * C_Exp =
    let 
      def c4e e = c4Expression (ctxt, cspc, block, e) 
    in
    let
      def c42e f e1 e2 = 
	let (cspc, block, ce1) = c4Expression (ctxt, cspc, block, e1) in
	let (cspc, block, ce2) = c4Expression (ctxt, cspc, block, e2) in
        (cspc, block, f (ce1, ce2))
    in
    let
      def c41e f e1 =
	let (cspc, block, ce1) = c4Expression (ctxt, cspc, block, e1) in
        (cspc, block, f ce1)
    in
    let
      def strless (ce1, ce2) =
	let strcmpcall = C_Apply (strcmp, [ce1, ce2]) in
	C_Binary (C_Eq, strcmpcall, C_Const (C_Int (true, -1)))

      def strequal (ce1, ce2) =
	let strcmpcall = C_Apply (strcmp, [ce1, ce2]) in
	C_Binary (C_Eq, strcmpcall, C_Const (C_Int (true, 0)))

      def strgreater (ce1, ce2) =
	let strcmpcall = C_Apply (strcmp, [ce1, ce2]) in
	C_Binary (C_Eq, strcmpcall, C_Const (C_Int (true, 1)))
    in
    let
      def stringToFloat e =
	case c4e e of
	  | (cspc, block, C_Const (C_Str s)) -> 
            let f = (true, 11, 22, None) in % TODO: FIX THIS TO PARSE s
            (cspc, block, C_Const (C_Float f))
	  | _ -> fail "expecting string as argument to \"stringToFloat\""
    in
    case exp of
      | I_Equals              (e1, e2) -> c42e (fn (c1, c2) -> C_Binary (C_Eq,     c1, c2))     e1 e2

      | I_BoolNot             (e1)     -> c41e (fn (c1)     -> C_Unary  (C_LogNot, c1))         e1
      | I_BoolAnd             (e1, e2) -> c42e (fn (c1, c2) -> C_Binary (C_LogAnd, c1, c2))     e1 e2
      | I_BoolOr              (e1, e2) -> c42e (fn (c1, c2) -> C_Binary (C_LogOr,  c1, c2))     e1 e2
      | I_BoolImplies         (e1, e2) -> c42e (fn (c1, c2) -> C_IfExp  (c1,       c2, cfalse)) e1 e2
      | I_BoolEquiv           (e1, e2) -> c42e (fn (c1, c2) -> C_Binary (C_Eq,     c1, c2))     e1 e2

      | I_IntPlus             (e1, e2) -> c42e (fn (c1, c2) -> C_Binary (C_Add,    c1, c2))     e1 e2
      | I_IntMinus            (e1, e2) -> c42e (fn (c1, c2) -> C_Binary (C_Sub,    c1, c2))     e1 e2
      | I_IntUnaryMinus       (e1)     -> c41e (fn (c1)     -> C_Unary  (C_Negate, c1))         e1
      | I_IntMult             (e1, e2) -> c42e (fn (c1, c2) -> C_Binary (C_Mul,    c1, c2))     e1 e2
      | I_IntDiv              (e1, e2) -> c42e (fn (c1, c2) -> C_Binary (C_Div,    c1, c2))     e1 e2
      | I_IntRem              (e1, e2) -> c42e (fn (c1, c2) -> C_Binary (C_Mod,    c1, c2))     e1 e2
      | I_IntLess             (e1, e2) -> c42e (fn (c1, c2) -> C_Binary (C_Lt,     c1, c2))     e1 e2
      | I_IntGreater          (e1, e2) -> c42e (fn (c1, c2) -> C_Binary (C_Gt,     c1, c2))     e1 e2
      | I_IntLessOrEqual      (e1, e2) -> c42e (fn (c1, c2) -> C_Binary (C_Le,     c1, c2))     e1 e2
      | I_IntGreaterOrEqual   (e1, e2) -> c42e (fn (c1, c2) -> C_Binary (C_Ge,     c1, c2))     e1 e2

      | I_IntToFloat          (e1)     -> c41e (fn (c1)     -> C_Cast   (C_Float,  c1))         e1
      | I_StringToFloat       (e1)     -> stringToFloat e1

      | I_FloatPlus           (e1, e2) -> c42e (fn (c1, c2) -> C_Binary (C_Add,    c1, c2))     e1 e2
      | I_FloatMinus          (e1, e2) -> c42e (fn (c1, c2) -> C_Binary (C_Sub,    c1, c2))     e1 e2
      | I_FloatUnaryMinus     (e1)     -> c41e (fn (c1)     -> C_Unary  (C_Negate, c1))         e1
      | I_FloatMult           (e1, e2) -> c42e (fn (c1, c2) -> C_Binary (C_Mul,    c1, c2))     e1 e2
      | I_FloatDiv            (e1, e2) -> c42e (fn (c1, c2) -> C_Binary (C_Div,    c1, c2))     e1 e2
      | I_FloatLess           (e1, e2) -> c42e (fn (c1, c2) -> C_Binary (C_Lt,     c1, c2))     e1 e2
      | I_FloatGreater        (e1, e2) -> c42e (fn (c1, c2) -> C_Binary (C_Gt,     c1, c2))     e1 e2
      | I_FloatLessOrEqual    (e1, e2) -> c42e (fn (c1, c2) -> C_Binary (C_Le,     c1, c2))     e1 e2
      | I_FloatGreaterOrEqual (e1, e2) -> c42e (fn (c1, c2) -> C_Binary (C_Ge,     c1, c2))     e1 e2
      | I_FloatToInt          (e1)     -> c41e (fn (c1)     -> C_Cast   (C_Int32,  c1))         e1

      | I_StrLess             (e1, e2) -> c42e strless    e1 e2
      | I_StrEquals           (e1, e2) -> c42e strequal   e1 e2
      | I_StrGreater          (e1, e2) -> c42e strgreater e1 e2

  op ctrue  : C_Exp = C_Var ("TRUE",  C_Int32)
  op cfalse : C_Exp = C_Var ("FALSE", C_Int32)

  % --------------------------------------------------------------------------------

  (**
   * code for handling special case, e.g. the bitstring operators
   *)

  op c4SpecialExpr (ctxt : I2C_Context, cspc : C_Spec, block : C_Block, (exp, _) : I_TypedExpr) 
    : Option (C_Spec * C_Block * C_Exp) =
    let 
      def c4e e = 
        c4Expression (ctxt, cspc, block, e) 

      def c42e f e1 e2 = 
	let (cspc, block, ce1) = c4Expression (ctxt, cspc, block, e1) in
	let (cspc, block, ce2) = c4Expression (ctxt, cspc, block, e2) in
	Some (cspc, block, f (ce1, ce2))

      def c41e f e1 =
	let (cspc, block, ce1) = c4Expression (ctxt, cspc, block, e1) in
	Some (cspc, block, f (ce1))
    in
    if ~bitStringSpecial? then 
      None
    else 
      case exp of
	| I_Var     (_, "Zero")                       -> Some (cspc, block, C_Const (C_Int (true, 0)))
	| I_Var     (_, "One")                        -> Some (cspc, block, C_Const (C_Int (true, 1)))
	| I_FunCall ((_, "leftShift"),  [], [e1, e2]) -> c42e (fn (c1, c2) -> C_Binary (C_ShiftLeft,  c1, c2)) e1 e2
	| I_FunCall ((_, "rightShift"), [], [e1, e2]) -> c42e (fn (c1, c2) -> C_Binary (C_ShiftRight, c1, c2)) e1 e2
	| I_FunCall ((_, "andBits"),    [], [e1, e2]) -> c42e (fn (c1, c2) -> C_Binary (C_BitAnd,     c1, c2)) e1 e2
	| I_FunCall ((_, "orBits"),     [], [e1, e2]) -> c42e (fn (c1, c2) -> C_Binary (C_BitOr,      c1, c2)) e1 e2
	| I_FunCall ((_, "xorBits"),    [], [e1, e2]) -> c42e (fn (c1, c2) -> C_Binary (C_BitXor,     c1, c2)) e1 e2
	| I_FunCall ((_, "complement"), [], [e])      -> c41e (fn ce -> C_Unary (C_BitNot, ce)) e
	| I_FunCall ((_, "notZero"),    [], [e])      -> Some (c4e e)
	| _ -> None

  % --------------------------------------------------------------------------------

  op constExpr? (cspc : C_Spec, expr : C_Exp) : Bool =
    case expr of
      | C_Const  _                  -> true
      | C_Unary  (_, e1)            -> constExpr? (cspc, e1)
      | C_Binary (_, e1, e2)        -> (constExpr? (cspc, e1)) && (constExpr? (cspc, e2))
      | C_Var    ("TRUE",  C_Int32) -> true
      | C_Var    ("FALSE", C_Int32) -> true
      | C_Field  []                 -> true
      | C_Field  (e::es)            -> (constExpr? (cspc, e)) && (constExpr? (cspc, C_Field es))

      % this isn't true in C:
      % | C_Var (vname, vdecl) ->
      %   (case findLeftmost (fn (id, _, _)->id=vname) cspc.varDefns of
      % | Some (_, _, exp) -> constExpr? (cspc, exp)
      % | _ -> false)

      | _ -> false

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %                                                                     %
  %                               STADS                                 %
  %                                                                     %
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


  op c4StadCode (ctxt       : I2C_Context, 
                 cspc       : C_Spec,
                 block      : C_Block, 
                 allstads   : List I_StadCode, 
                 returnstmt : C_Stmt,
                 stadcode   : I_StadCode) 
    : C_Spec * C_Block * C_Stmts =
    % decls are empty, so the following 2 lines have no effect:
    let declscspc = generateC4ImpUnit (stadcode.decls, ctxt.xcspc, ctxt.useRefTypes) in
    let cspc      = mergeCSpecs [cspc, declscspc] in
    let (cspc, block, stepstmts) =
        foldl (fn ((cspc, block, stmts), stp) ->
                 let (cspc, block, stpstmts) = c4StepCode (ctxt, cspc, block, allstads, returnstmt, stp) in
                 (cspc, block, stmts++stpstmts))
              (cspc, block, []) 
              stadcode.steps
    in
    let lblstmt = if stadcode.showLabel? then [C_Label stadcode.label] else [] in
    (cspc, block, lblstmt ++ stepstmts ++ [returnstmt])

  op c4StepCode (ctxt            : I2C_Context, 
                 cspc            : C_Spec,
                 block           : C_Block,
                 allstads        : List I_StadCode, 
                 returnstmt      : C_Stmt, 
                 (rule, gotolbl) : I_StepCode) 
    : C_Spec * C_Block * C_Stmts =
    let gotostmt                   = if final? (allstads, gotolbl) then returnstmt else C_Goto gotolbl in
    let (cspc, block, rules_stmts) = c4StepRule (ctxt, cspc, block, Some gotostmt, rule)               in
    %foldl (fn ((cspc, block, rulestmts), rule) -> 
    %	     let (cspc, block, rule1stmts) = c4StepRule (ctxt, cspc, block, rule) in
    %        (cspc, block, rulestmts++rule1stmts))
    %	   (cspc, block, [])
    %      rules
    %in
    (cspc, block, rules_stmts)

  op c4StepRule (ctxt                    : I2C_Context,
                 cspc                    : C_Spec,
                 block as (decls, stmts) : C_Block,
                 optgotostmt             : Option C_Stmt,
                 rule                    : I_Rule)
    : C_Spec * C_Block * C_Stmts =
    let gotostmts = case optgotostmt of | Some stmt -> [stmt] | None -> [] in
    case rule of

      | I_Skip -> 
        (cspc, block, gotostmts)

      | I_Cond (expr, rule) ->
        let (cspc, block,  cexpr)     = c4Expression (ctxt, cspc, block, expr)                 in
	let (cspc, block0, rulestmts) = c4StepRule   (ctxt, cspc, ([], []), optgotostmt, rule) in
        (cspc, block, [C_IfThen (cexpr, addStmts (C_Block block0, rulestmts))])

      | I_Update (optexpr1, expr2) ->
	let (cspc, block0 as (decls0, stmts0), cexpr2) = c4Expression (ctxt, cspc, ([], []), expr2) in
        (case optexpr1 of

           | Some expr1 ->
	     let (cspc, block0 as (decls0, stmts0), cexpr1) = c4LhsExpression (ctxt, cspc, block0, expr1) in
	     let stmts = stmts0++[C_Exp (getSetExpr (ctxt, cexpr1, cexpr2))]++gotostmts                   in
	     let stmts = if decls0 = [] then stmts else [C_Block (decls0, stmts)]                         in
	     (cspc, block, stmts)

	   | None -> 
	     let stmts = stmts0 ++ [C_Exp cexpr2] ++ gotostmts                    in
	     let stmts = if decls0 = [] then stmts else [C_Block (decls0, stmts)] in
	     (cspc, block, stmts))

      | I_UpdateBlock (upddecls, updates) ->
	let (cspc, block, declstmts) =
	    foldl (fn ((cspc, block, updstmts), ((_, id), typ, optexpr)) ->
                     let (cspc, ctype) = c4Type (ctxt, cspc, typ)                                        in
                     let iddecl        = (id, ctype)                                                     in
                     let optinit       = if ctxt.useRefTypes then getMallocApply (cspc, ctype) else None in
                     let iddecl1       = (id, ctype, optinit)                                            in
                     let (cspc, block as (decls1, stmts1), assignidstmts) = 
                     case optexpr of

                       | None -> 
                         (cspc, block, [])

                       | Some expr ->
                         let (cspc, block, cexpr) = c4Expression (ctxt, cspc, block, expr) in
                         (cspc, block, [C_Exp (getSetExpr (ctxt, C_Var iddecl, cexpr))])

                     in
                     let block = (decls1 ++ [iddecl1], stmts1) in
                     (cspc, block, updstmts ++ assignidstmts))
                  (cspc, block, []) 
                  upddecls
	in
	let (cspc, block, updatestmts) =
	    foldl (fn ((cspc, block, updatestmts), update) ->
                     let (cspc, block, stmts) = c4StepRule (ctxt, cspc, block, None, I_Update update) in
                     (cspc, block, updatestmts++stmts))
                  (cspc, block, []) 
                  updates
	in
        (cspc, block, declstmts ++ updatestmts ++ gotostmts)

      | _ -> 
        (cspc, block, gotostmts)

  % --------------------------------------------------------------------------------


  op [X] getFieldNamesForTuple (l : List X) : List String =
    let
      def getFieldNamesForTuple0 (l, n) =
	case l of
          | []   -> []
          | _::l -> ("field" ^ show n) :: getFieldNamesForTuple0 (l, n+1)
    in
    getFieldNamesForTuple0 (l, 0)

  % --------------------------------------------------------------------------------

  % returns the statement for assigning the value for the selector string used in AssignUnion
  % expressions.
  op getSelAssignStmt (ctxt : I2C_Context, selstr : String, varname : String, vartype : C_Type) 
    : C_Stmt =
    let variable = C_Var (varname, vartype)                                              in
    let variable = if ctxt.useRefTypes then C_Unary (C_Contents, variable) else variable in
    C_Exp (C_Apply (selstrncpy, [variable, C_Const (C_Str selstr)]))

  op getSelCompareExp (ctxt : I2C_Context, expr : C_Exp, selstr : String) : C_Exp =
    let expr = if ctxt.useRefTypes then C_Unary (C_Contents, expr) else expr in
    case expr of

      | C_Unary (Contents, expr) -> 
        C_Apply (hasConstructor, [expr, C_Const (C_Str selstr)])

      | _ -> 
        let apply = C_Apply (strncmp, 
                             [C_StructRef (expr, "sel"), 
                              C_Const     (C_Str selstr),
                              C_Var ("COPRDCTSELSIZE", C_Int32)])
        in
	C_Binary (C_Eq, apply, C_Const (C_Int (true, 0)))

  op getSelCompareExp0 (ctxt : I2C_Context, expr : C_Exp, selstr : String) : C_Exp =
    let expr   = if ctxt.useRefTypes then C_Unary (C_Contents, expr) else expr            in
    let apply  = C_Apply (strcmp, 
                          [C_StructRef (expr, "sel"), 
                           C_Const     (C_Str selstr)]) 
    in
    C_Binary (C_Eq, apply, C_Const (C_Int (true, 0)))

  % --------------------------------------------------------------------------------

  % checks whether id is already declared in var decls; if yes, a new name is generated
  % and id is substituted in expression
  op substVarIfDeclared (ctxt : I2C_Context, id : String, decls : C_VarDecls1, expr : I_TypedExpr)
    : String * I_TypedExpr =
    let
      def isDeclared id =
	case findLeftmost (fn (vname, _, _) -> vname = id) decls of
	  | Some _ -> true
	  | None ->
	    case findLeftmost (fn (vname, _) -> vname = id) ctxt.currentFunParams of
	      | Some _ -> true
	      | None -> false
    in
    let
      def determineId id =
	if isDeclared id then 
          determineId (id^"_")
	else 
          id
    in
    let newid = determineId id in
    if newid = id then 
      (id, expr)
    else 
      (newid, substVarName (expr, ("", id), ("", newid)))

  % --------------------------------------------------------------------------------

  op substVarListByFieldRefs (ctxt : I2C_Context, vlist : List (Option String), structexpr : C_Exp, expr : C_Exp) 
    : C_Exp =
    let
      def subst (vlist, expr, n) =
	case vlist of
	  | [] -> expr
	  | None::vlist -> subst (vlist, expr, n+1)
	  | (Some v)::vlist ->
	    let field      = "field" ^ show n                                                          in
	    let structexpr = if ctxt.useRefTypes then C_Unary (C_Contents, structexpr) else structexpr in
	    let expr       = substVarInExp (expr, v, C_StructRef (structexpr, field))                  in
	    subst (vlist, expr, n+1)
    in
    subst (vlist, expr, 0)

  op substVarListByFieldRefsInDecl (ctxt                    : I2C_Context, 
                                    vlist                   : List (Option String), 
                                    structexpr              : C_Exp, 
                                    (vname, vtype, optexpr) : C_VarDecl1) 
    : C_VarDecl1 =
    case optexpr of
      | Some e -> (vname, vtype, Some (substVarListByFieldRefs (ctxt, vlist, structexpr, e)))
      | None   -> (vname, vtype, None)

  op substVarListByFieldRefsInDecls (ctxt       : I2C_Context,
                                     vlist      : List (Option String),
                                     structexpr : C_Exp,
                                     decls      : C_VarDecls1)
    : C_VarDecls1 =
    map (fn decl -> 
           substVarListByFieldRefsInDecl (ctxt, vlist, structexpr, decl)) 
        decls

  % --------------------------------------------------------------------------------

  op mergeBlockIntoExpr (cspc : C_Spec, block as (decls, stmts) : C_Block, cexpr : C_Exp)
    : C_Spec * C_Block * C_Exp =
    case stmts of
      | [] -> (cspc, block, cexpr)
      | stmt::stmts ->
        let (cspc, block as (decls, stmts), cexpr) = mergeBlockIntoExpr (cspc, (decls, stmts), cexpr) in
	let (cexpr, stmts) = 
            case stmt of
              | C_Exp e -> (C_Comma (e, cexpr), stmts)
              | _ -> (cexpr, stmt::stmts)
	in
	 (cspc, (decls, stmts), cexpr)

  % --------------------------------------------------------------------------------

  op commaExprToStmts (_ : I2C_Context, exp : C_Exp) : C_Stmts * C_Exp =
    let
      def commaExprToStmts0 (stmts, exp) =
	case exp of

	  | C_Binary (C_Set, e0, C_Comma (e1, e2)) ->
            let (stmts, e1) = commaExprToStmts0 (stmts, e1) in
            let stmts       = stmts ++ [C_Exp e1]           in
            let (stmts, e2) = commaExprToStmts0 (stmts, e2) in
            commaExprToStmts0 (stmts, C_Binary (C_Set, e0, e2))
                        
%	  | C_Comma (C_Binary (C_Set, e0, e1), e2) ->
%	    let (stmts, e1) = commaExprToStmts0 (stmts, e1) in
%	    let stmts = stmts ++ [C_Exp (C_Binary (C_Set, e0, e1)) : C_Stmt] in
%	    commaExprToStmts0 (stmts, e2)

	  | C_Comma (e1, e2) ->
            let (stmts, e1) = commaExprToStmts0 (stmts, e1) in
	    let stmts      = stmts ++ [(C_Exp e1) : C_Stmt]   in
	    commaExprToStmts0 (stmts, e2)

	  | _ -> (stmts, exp)
    in
    commaExprToStmts0 ([], exp)

  % --------------------------------------------------------------------------------

  op conditionalExprToStmts (ctxt : I2C_Context, exp : C_Exp, e2sFun : C_Exp -> C_Stmt) 
    : C_Stmts =
    let (stmts, exp) = commaExprToStmts (ctxt, exp) in
    stmts ++ (case exp of

               | C_IfExp (condExp, thenExp, elseExp) ->
                 let return? = 
                     case e2sFun exp of
                       | C_Return _ -> true
                       | _ -> false
                 in
                 let thenStmts = conditionalExprToStmts (ctxt, thenExp, e2sFun) in
                 let elseStmts = conditionalExprToStmts (ctxt, elseExp, e2sFun) in
                 if return? then
                   let ifStmt = C_IfThen (condExp, C_Block ([], thenStmts)) in
                   (ifStmt::elseStmts)
                 else
                   let ifStmt = C_If (condExp, C_Block ([], thenStmts), C_Block ([], elseStmts)) in
                   [ifStmt]

              | _ ->
                let finalStmt = e2sFun exp in
                [finalStmt])

  % --------------------------------------------------------------------------------

  % returns the expression for ce1 = ce2
  op getSetExpr (_ : I2C_Context, ce1 : C_Exp, ce2 : C_Exp) : C_Exp =
    let lhs = ce1 in
    C_Binary (C_Set, lhs, ce2)

  % --------------------------------------------------------------------------------

  op genName (cspc : C_Spec, prefix :String, suffixn : Nat) : String =
    cString (cspc.name ^ prefix ^ show suffixn)

  % --------------------------------------------------------------------------------

  op getMapName    (f : String) : String = "_map_" ^ f
  op getParamName  (n : Nat)    : String = "index" ^ show n

  op [X] getNumberListOfSameSize (l : List X) : List Nat =
    let
      def getNumberList (l, n) =
	case l of
          | [] -> []
	  | _::l -> n :: getNumberList (l, n+1)
    in
    getNumberList (l, 0)

  % --------------------------------------------------------------------------------

  op qname2id (qualifier : String, id : String) : String =
    let quali = if qualifier = UnQualified || qualifier = "" || qualifier = "#return#" then  % terminate string for emacs "
                  "" 
                else 
                  qualifier ^ "_" 
    in
    cString (quali ^ id)

  op getConstructorOpNameFromQName (qname : String * String, consid : String) : String =
    % the two _'s are important: that is how the constructor op names are
    % distinguished from other opnames (hack)
    (qname2id qname) ^ "__" ^ consid

  op [X] getLastElem (l : List X) : List X * X =
    case l of
      | [e] -> ([], e)
      | e::l -> 
        let (pref, last) = getLastElem l in
        (e::pref, last)

  % --------------------------------------------------------------------------------

  op getProjectionFieldName (pname : String) : String =
    let pchars = explode pname in
    if forall? isNum pchars then
      let num = stringToNat pname in
      "field" ^ show (num - 1)
    else
      pname

  op getPredefinedFnDecl (fname : String) : C_FnDecl =
    case fname of
      | "swc_malloc" -> ("swc_malloc", [C_Int32], C_VoidPtr)
      | "sizeof"     -> ("sizeof",     [C_Void],  C_UInt32)
      | "New"        -> ("New",        [C_Void],  C_VoidPtr)   % this is defined in SWC_common.h
      | _ -> fail ("no predefined function \""^fname^"\" found.")

  % --------------------------------------------------------------------------------

  % returns the "malloc" expression for the given ctype
  % the op unfolds the type in the spec in order to determine
  % the struct to which it points to
  op getMallocApply (cspc : C_Spec, t : C_Type) : Option C_Exp =
    let t0 = unfoldType (cspc, t) in
    case t0 of

      | C_Ptr t1 -> 
        let fdecl    = getPredefinedFnDecl "New" in
        let typename = ctypeToString t1 in
        let exp      = C_Apply (C_Fn fdecl, [C_Var (typename, C_Void)]) in
        Some exp

      | _ -> 
        %let typename = ctypeToString t0 in
        %let _ = writeLine ("***** no malloc for type "^typename) in
        None     

  % --------------------------------------------------------------------------------

  % generates "meaningful" variable names by checking whether
  % the type is a base type. In that case, the type name is
  % used to generate the variable prefix, otherwise a generic
  % variable prefix is used.
  op getVarPrefix (gen : String, typ : C_Type) : String =
    case typ of
      | C_Base s -> map toLowerCase s
      | _ -> gen
  
}