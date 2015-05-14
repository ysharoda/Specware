SpecwareShell qualifying spec

import /Library/Legacy/Utilities/IO      % read
import /Library/Legacy/Utilities/System  % writeLine

import CommandParser
import SystemCommands
import SpecwareCommands
import CodeGenCommands
import ProverCommands
import WizardCommands

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

op dispatch (cmd : String, args : CommandArgs) : Result () =
 case (cmd, args) of
  (*
   | ("cd",         [])          -> cd    ()
   | ("cinit",      [])          -> cinit ()
   | ("ctext",      [])          -> ctext ()
   | ("dir",        [Name name]) -> (cl-user::ls   name)
   | ("dir",        [])          -> (cl-user::ls   "")
   | ("dirr",       [Name name]) -> (cl-user::dirr name)
   | ("dirr"        [])          -> (cl-user::dirr "")
   | ("e",          [Name name]) -> eval_1 (name)
   | ("e",          [])          -> eval_0 ()
   | ("eval",       [Name name]) -> eval_1 (name)
   | ("eval"        [])          -> eval_0 ()

   | "eval-lisp"                 -> eval_lisp ()
   | "el"                        -> eval_lisp ()

   | "help"                      -> help  ()
   | "ls"                        -> (cl-user::ls     (or argstr "")))
   | "path  "                    -> (cl-user::swpath argstr))
   | "p"                         -> (cl-user::sw     argstr) 
   | "proc "                     -> (cl-user::sw     argstr) 
   | "pwd"                       -> (princ (Specware::current-directory)) 
   | "reproc"                    -> (let ((cl-user::*force-reprocess-of-unit* t)) (cl-user::sw     argstr)) 
   | "rp"                        -> (let ((cl-user::*force-reprocess-of-unit* t)) (cl-user::sw     argstr)) 
   | "show  "                    -> (cl-user::show     argstr) 
   | "showx "                    -> (cl-user::showx    argstr) 
   | "showdeps"                  -> (cl-user::showdeps argstr) 
   | "showimports"               -> (cl-user::showimports argstr) 
   | "showdata"                  -> (cl-user::showdata argstr) 
   | "showdatav"                 -> (cl-user::showdatav argstr) 
   | "checkspec"                 -> (cl-user::checkspec argstr) 

   | "gen-acl2"                  -> gen_acl2 ()

   | "gen-coq"                   -> gen_coq ()

   | "gen-c"                     -> (cl-user::swc    argstr) 
   | "gen-c-thin"                -> (cl-user::gen-c-thin    argstr) 

   | "gen-java"                  -> (cl-user::swj    argstr) 

   | "gen-haskell"               -> gen_haskell     ()
   | "gen-h"                     -> gen_haskell     ()
   | "gen-haskell-top"           -> gen_haskell_top ()
   | "gen-ht"                    -> gen_haskell_top ()

   | "gen-lisp"                  -> (cl-user::swl argstr)
   | "gen-l"                     -> (cl-user::swl argstr)
   | "gen-lisp-top"              -> (let ((cl-user::*slicing-lisp?* t)) (cl-user::swl argstr))
   | "gen-lt"                    -> (let ((cl-user::*slicing-lisp?* t)) (cl-user::swl argstr))
   | "lgen-lisp"                 -> (cl-user::swll   argstr)

   | "make"                      -> (if (null argstr) (cl-user::make) (cl-user::make argstr)))

   | "oblig"                     -> obligs ()
   | "obligations"               -> obligs ()
   | "obligs"                    -> obligs ()
  
   | "gen-obligations"           -> gen-obligs ()
   | "gen-oblig"                 -> gen-obligs ()
   | "gen-obligs"                -> gen-obligs ()

   | "gen-obligations-no-simp"   -> gen-obligs_no_simp ()
   | "gen-oblig-no-simp"         -> gen-obligs_no_simp ()
   | "gen-obligs-no-simp"        -> gen-obligs_no_simp ()

   | "pc"                        -> (cl-user::swpc argstr)
   | "proofcheck"                -> (cl-user::swpc argstr)

   | "prove"                     -> (cl-user::sw (concatenate 'string "prove " argstr)) 
   | "prwb"                      -> (if argstr (cl-user::swprb argstr) (cl-user::swprb)))

   | "punits"                    -> (cl-user::swpf   argstr))
   | "lpunits"                   -> (cl-user::lswpf  argstr)) ; No local version yet

   | "transform"                 -> transform () 

   | "trace-eval"                -> (setq MSInterpreter::traceEval? t)   (format t "Tracing of eval turned on.")        
   | "untrace-eval"              -> (setq MSInterpreter::traceEval? nil) (format t "Tracing of eval turned off.")       

   | "uses"                      -> uses ()

   %% Non-user commands

   | "cf"                        -> (cl-user::cf argstr))

   | "cl"                        -> (with-break-possibility (cl-user::cl argstr)))

   | "com"                       -> com ()

   | "dev"                       -> (princ (if argstr   (setq *developer?* (not (member argstr '("nil" "NIL" "off") :test 'string=)))  *developer?* ))

   | "lisp"                      -> lisp ()
   | "l"                         -> lisp ()

   | "f-b"                       -> (when (fboundp 'cl-user::f-b)   (funcall 'cl-user::f-b argstr)))
   | "f-unb"                     -> (when (fboundp 'cl-user::f-unb) (funcall 'cl-user::f-unb (or argstr ""))))

   | "ld"                        -> (with-break-possibility (cl-user::ld argstr)))

   | "pa"                        -> (cl-user::pa argstr))

   | "set-base"                  -> (cl-user::set-base argstr))

   | "show-base-unit-id"         -> (cl-user::show-base-unit-id))

   | "swdbg"                     -> (if argstr (cl-user::swdbg argstr) (cl-user::swdbg)))

   | "tr"                        -> (cl-user::tr argstr))
   | "untr"                      -> (cl-user::untr))

   | "trace-rewrites"            -> trace_rewrites   ()
   | "trr"                       -> trace_rewrites   ()
   | "untrace-rewrites"          -> untrace_rewrites ()
   | "untrr"                     -> untrace_rewrites ()

   | "wiz"                       -> (if argstr (cl-user::wiz   argstr) (cl-user::wiz)))

   | _ ->
     if constantp? cmd && args = [] then
       cmd
     else
       let _ = writeLine ("Unknown command `" ^ anyToString cmd ^ "'. Type `help' to see available commands.") in
       cmd
   *)
   | _ ->
     NotYetImplemented
     

op oldProcessSpecwareShellCommand (cmd : String, args_str : String) : () % implemented in handwritten lisp code

%% This will supplant old-process-sw-shell-command (defined in Handwritten/Lisp/sw-shell.lisp)
%% as the new top-level specware shell command processor

op processSpecwareShellCommand (cmd : String, args_str : String) : () =
 case parseCommandArgs args_str of
   | Good args ->
     (case dispatch (cmd, args) of
        | Good _ -> 
          ()
        | NotYetImplemented ->
          oldProcessSpecwareShellCommand (cmd, args_str)
        | Error msg ->
          let _ = writeLine ("problem processing shell command using new processor, reverting to old one: " ^ msg) in
          oldProcessSpecwareShellCommand (cmd, args_str))

   | Error msg ->
     let _ = writeLine ("could not parse args, reverting to old shell processor: " ^ msg) in
     oldProcessSpecwareShellCommand (cmd, args_str)


end-spec

