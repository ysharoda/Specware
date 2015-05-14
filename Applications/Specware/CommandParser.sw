SpecwareShell qualifying spec

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

type Chars = List Char

type CommandArgs = List CommandArg
type CommandArg  = | String String
                   | Name   String
                   | Number Integer
                   | List   CommandArgs

type Result a = | Good  a
                | Error String
                | NotYetImplemented

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

op parseCommandArgs (s : String) : Result CommandArgs =
 let

   def name_char? c =
     isAlphaNum c || c in? [#-, #/, ##, #.] % include chars that often appear in filenames

   def parse_string (unread_chars, rev_str_chars) : Result (Chars * CommandArg) =
     case unread_chars of
       | [] -> Error "String not terminated by quote"
       | #" :: chars ->
         Good (chars, String (implode (reverse rev_str_chars)))
       | c :: chars ->
         parse_string (chars, c :: rev_str_chars)

   def parse_name (unread_chars, rev_name_chars) =
     case unread_chars of
       | [] ->
         Good ([], Name (implode (reverse rev_name_chars)))
       | c :: chars ->
         if name_char? c then
           parse_name (chars, c :: rev_name_chars)
         else
           Good (unread_chars, Name (implode (reverse rev_name_chars)))

   def parse_number (unread_chars, rev_number_chars) =
     case unread_chars of
       | [] ->
         let n_str = implode (reverse rev_number_chars) in
         if intConvertible n_str then
           Good (unread_chars, Number (stringToInt n_str))
         else
           Error ("Cannot parse number: " ^ implode unread_chars)
       | c :: chars ->
         if isNum c then
           parse_number (chars, c :: rev_number_chars)
         else
           let n_str = implode (reverse rev_number_chars) in
           if intConvertible n_str then
             Good (unread_chars, Number (stringToInt n_str))
           else
             Error ("Cannot parse number: " ^ implode unread_chars)

   def parse_list (unread_chars, rev_elements) =
     case unread_chars of
       | [] -> Error "List not terminated by closing bracket"
       | #, :: chars ->
         parse_list (chars, rev_elements)
       | #] :: chars ->
         Good (chars, List (reverse rev_elements))
       | _ ->
         case parse_arg unread_chars of
           | Good (unread_chars, element) ->
             parse_list (unread_chars, element :: rev_elements)
           | error ->
             error

   def parse_arg unread_chars =
     case unread_chars of
       | [] -> Error "looking for an arg past end of input"
       | c :: chars -> 
         case c of 
           | #\s -> parse_arg chars
           | #" -> parse_string (chars, [])
           | #[ -> parse_list   (chars, [])
           | _ ->
             if isNum c then
               parse_number (unread_chars, [])
             else if name_char? c then
               parse_name (unread_chars, [])
             else
               Error ("cannot parse arg: " ^ implode unread_chars)

   def aux (unread_chars, rev_args) : Result (Chars * CommandArgs) =
     case parse_arg unread_chars of
       | Good (unread_chars, arg) ->
         let rev_args = arg :: rev_args in
         (case unread_chars of
            | [] -> Good ([], reverse rev_args)
            | _ ->
              aux (unread_chars, rev_args))
       | Error msg -> Error msg
         
 in
 case aux (explode s, []) of
   | Good ([], args) ->
     Good args
   | Error msg ->
     Error msg


end-spec
