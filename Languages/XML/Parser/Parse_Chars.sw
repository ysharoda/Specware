%% Parse_Chars

XML qualifying spec

  import XML_Parser_Base

  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %%%          Chars                                                                               %%%
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %% 
  %%  [2]  Char          ::=  #x9 | #xA | #xD | [#x20-#xD7FF] | [#xE000-#xFFFD] | [#x10000-#x10FFFF] 
  %%                          /* any Unicode character, excluding the surrogate blocks, FFFE, and FFFF. */
  %%
  %% [84]  Letter        ::=  BaseChar | Ideographic
  %%
  %% [85]  BaseChar      ::=  [#x0041-#x005A] | [#x0061-#x007A] |   /* ascii: [A-Z] [a-z] */
  %%                            /* annotated vowels (umlaut, circumflex, ...) */
  %%                          [#x00C0-#x00D6] | [#x00D8-#x00F6] | [#x00F8-#x00FF] |  
  %%                            /* lots of odd characters */
  %%                          [#x0100-#x0131] | [#x0134-#x013E] | [#x0141-#x0148] | 
  %%                          [#x014A-#x017E] | [#x0180-#x01C3] | [#x01CD-#x01F0] | [#x01F4-#x01F5] | 
  %%                          [#x01FA-#x0217] | [#x0250-#x02A8] | [#x02BB-#x02C1] | #x0386 | 
  %%                          [#x0388-#x038A] | #x038C | [#x038E-#x03A1] | [#x03A3-#x03CE] | 
  %%                          [#x03D0-#x03D6] | #x03DA | #x03DC | #x03DE | #x03E0 | [#x03E2-#x03F3] | 
  %%                          [#x0401-#x040C] | [#x040E-#x044F] | [#x0451-#x045C] | [#x045E-#x0481] | 
  %%                          [#x0490-#x04C4] | [#x04C7-#x04C8] | [#x04CB-#x04CC] | [#x04D0-#x04EB] | 
  %%                          [#x04EE-#x04F5] | [#x04F8-#x04F9] | [#x0531-#x0556] | #x0559 | 
  %%                          [#x0561-#x0586] | [#x05D0-#x05EA] | [#x05F0-#x05F2] | [#x0621-#x063A] | 
  %%                          [#x0641-#x064A] | [#x0671-#x06B7] | [#x06BA-#x06BE] | [#x06C0-#x06CE] | 
  %%                          [#x06D0-#x06D3] | #x06D5 | [#x06E5-#x06E6] | [#x0905-#x0939] | #x093D | 
  %%                          [#x0958-#x0961] | [#x0985-#x098C] | [#x098F-#x0990] | [#x0993-#x09A8] | 
  %%                          [#x09AA-#x09B0] | #x09B2 | [#x09B6-#x09B9] | [#x09DC-#x09DD] | 
  %%                          [#x09DF-#x09E1] | [#x09F0-#x09F1] | [#x0A05-#x0A0A] | [#x0A0F-#x0A10] | 
  %%                          [#x0A13-#x0A28] | [#x0A2A-#x0A30] | [#x0A32-#x0A33] | [#x0A35-#x0A36] | 
  %%                          [#x0A38-#x0A39] | [#x0A59-#x0A5C] | #x0A5E | [#x0A72-#x0A74] | 
  %%                          [#x0A85-#x0A8B] | #x0A8D | [#x0A8F-#x0A91] | [#x0A93-#x0AA8] | 
  %%                          [#x0AAA-#x0AB0] | [#x0AB2-#x0AB3] | [#x0AB5-#x0AB9] | #x0ABD | #x0AE0 | 
  %%                          [#x0B05-#x0B0C] | [#x0B0F-#x0B10] | [#x0B13-#x0B28] | [#x0B2A-#x0B30] | 
  %%                          [#x0B32-#x0B33] | [#x0B36-#x0B39] | #x0B3D | [#x0B5C-#x0B5D] | 
  %%                          [#x0B5F-#x0B61] | [#x0B85-#x0B8A] | [#x0B8E-#x0B90] | [#x0B92-#x0B95] | 
  %%                          [#x0B99-#x0B9A] | #x0B9C | [#x0B9E-#x0B9F] | [#x0BA3-#x0BA4] | 
  %%                          [#x0BA8-#x0BAA] | [#x0BAE-#x0BB5] | [#x0BB7-#x0BB9] | [#x0C05-#x0C0C] | 
  %%                          [#x0C0E-#x0C10] | [#x0C12-#x0C28] | [#x0C2A-#x0C33] | [#x0C35-#x0C39] | 
  %%                          [#x0C60-#x0C61] | [#x0C85-#x0C8C] | [#x0C8E-#x0C90] | [#x0C92-#x0CA8] | 
  %%                          [#x0CAA-#x0CB3] | [#x0CB5-#x0CB9] | #x0CDE | [#x0CE0-#x0CE1] | 
  %%                          [#x0D05-#x0D0C] | [#x0D0E-#x0D10] | [#x0D12-#x0D28] | [#x0D2A-#x0D39] | 
  %%                          [#x0D60-#x0D61] | [#x0E01-#x0E2E] | #x0E30 | [#x0E32-#x0E33] | 
  %%                          [#x0E40-#x0E45] | [#x0E81-#x0E82] | #x0E84 | [#x0E87-#x0E88] | #x0E8A | 
  %%                          #x0E8D | [#x0E94-#x0E97] | [#x0E99-#x0E9F] | [#x0EA1-#x0EA3] | #x0EA5 | 
  %%                          #x0EA7 | [#x0EAA-#x0EAB] | [#x0EAD-#x0EAE] | #x0EB0 | [#x0EB2-#x0EB3] | 
  %%                          #x0EBD | [#x0EC0-#x0EC4] | [#x0F40-#x0F47] | [#x0F49-#x0F69] | 
  %%                          [#x10A0-#x10C5] | [#x10D0-#x10F6] | #x1100 | [#x1102-#x1103] | 
  %%                          [#x1105-#x1107] | #x1109 | [#x110B-#x110C] | [#x110E-#x1112] | #x113C | 
  %%                          #x113E | #x1140 | #x114C | #x114E | #x1150 | [#x1154-#x1155] | #x1159 | 
  %%                          [#x115F-#x1161] | #x1163 | #x1165 | #x1167 | #x1169 | [#x116D-#x116E] | 
  %%                          [#x1172-#x1173] | #x1175 | #x119E | #x11A8 | #x11AB | [#x11AE-#x11AF] | 
  %%                          [#x11B7-#x11B8] | #x11BA | [#x11BC-#x11C2] | #x11EB | #x11F0 | #x11F9 | 
  %%                          [#x1E00-#x1E9B] | [#x1EA0-#x1EF9] | [#x1F00-#x1F15] | [#x1F18-#x1F1D] | 
  %%                          [#x1F20-#x1F45] | [#x1F48-#x1F4D] | [#x1F50-#x1F57] | #x1F59 | #x1F5B | 
  %%                          #x1F5D | [#x1F5F-#x1F7D] | [#x1F80-#x1FB4] | [#x1FB6-#x1FBC] | #x1FBE | 
  %%                          [#x1FC2-#x1FC4] | [#x1FC6-#x1FCC] | [#x1FD0-#x1FD3] | [#x1FD6-#x1FDB] | 
  %%                          [#x1FE0-#x1FEC] | [#x1FF2-#x1FF4] | [#x1FF6-#x1FFC] | #x2126 | 
  %%                          [#x212A-#x212B] | #x212E | [#x2180-#x2182] | [#x3041-#x3094] | 
  %%                          [#x30A1-#x30FA] | [#x3105-#x312C] | 
  %%                          [#xAC00-#xD7A3]
  %%
  %% [86]  Ideographic   ::=  [#x4E00-#x9FA5] | #x3007 | [#x3021-#x3029]
  %% 
  %% [87]  CombiningChar ::=  [#x0300-#x0345] | [#x0360-#x0361] | [#x0483-#x0486] | [#x0591-#x05A1] | 
  %%                          [#x05A3-#x05B9] | [#x05BB-#x05BD] | #x05BF | [#x05C1-#x05C2] | #x05C4 | 
  %%                          [#x064B-#x0652] | #x0670 | [#x06D6-#x06DC] | [#x06DD-#x06DF] | 
  %%                          [#x06E0-#x06E4] | [#x06E7-#x06E8] | [#x06EA-#x06ED] | [#x0901-#x0903] | 
  %%                          #x093C | [#x093E-#x094C] | #x094D | [#x0951-#x0954] | [#x0962-#x0963] | 
  %%                          [#x0981-#x0983] | #x09BC | #x09BE | #x09BF | [#x09C0-#x09C4] | 
  %%                          [#x09C7-#x09C8] | [#x09CB-#x09CD] | #x09D7 | [#x09E2-#x09E3] | #x0A02 | 
  %%                          #x0A3C | #x0A3E | #x0A3F | [#x0A40-#x0A42] | [#x0A47-#x0A48] | 
  %%                          [#x0A4B-#x0A4D] | [#x0A70-#x0A71] | [#x0A81-#x0A83] | #x0ABC | 
  %%                          [#x0ABE-#x0AC5] | [#x0AC7-#x0AC9] | [#x0ACB-#x0ACD] | [#x0B01-#x0B03] | 
  %%                          #x0B3C | [#x0B3E-#x0B43] | [#x0B47-#x0B48] | [#x0B4B-#x0B4D] | 
  %%                          [#x0B56-#x0B57] | [#x0B82-#x0B83] | [#x0BBE-#x0BC2] | [#x0BC6-#x0BC8] | 
  %%                          [#x0BCA-#x0BCD] | #x0BD7 | [#x0C01-#x0C03] | [#x0C3E-#x0C44] | 
  %%                          [#x0C46-#x0C48] | [#x0C4A-#x0C4D] | [#x0C55-#x0C56] | [#x0C82-#x0C83] | 
  %%                          [#x0CBE-#x0CC4] | [#x0CC6-#x0CC8] | [#x0CCA-#x0CCD] | [#x0CD5-#x0CD6] | 
  %%                          [#x0D02-#x0D03] | [#x0D3E-#x0D43] | [#x0D46-#x0D48] | [#x0D4A-#x0D4D] | 
  %%                          #x0D57 | #x0E31 | [#x0E34-#x0E3A] | [#x0E47-#x0E4E] | #x0EB1 | 
  %%                          [#x0EB4-#x0EB9] | [#x0EBB-#x0EBC] | [#x0EC8-#x0ECD] | [#x0F18-#x0F19] | 
  %%                          #x0F35 | #x0F37 | #x0F39 | #x0F3E | #x0F3F | [#x0F71-#x0F84] | 
  %%                          [#x0F86-#x0F8B] | [#x0F90-#x0F95] | #x0F97 | [#x0F99-#x0FAD] | 
  %%                          [#x0FB1-#x0FB7] | #x0FB9 | [#x20D0-#x20DC] | #x20E1 | [#x302A-#x302F] | 
  %%                          #x3099 | #x309A
  %%
  %% [88]  Digit         ::=  [#x0030-#x0039] |  /* ascii [0-9] */
  %%                          [#x0660-#x0669] | [#x06F0-#x06F9] | [#x0966-#x096F] | 
  %%                          [#x09E6-#x09EF] | [#x0A66-#x0A6F] | [#x0AE6-#x0AEF] | [#x0B66-#x0B6F] | 
  %%                          [#x0BE7-#x0BEF] | [#x0C66-#x0C6F] | [#x0CE6-#x0CEF] | [#x0D66-#x0D6F] | 
  %%                          [#x0E50-#x0E59] | [#x0ED0-#x0ED9] | [#x0F20-#x0F29]
  %%
  %% [89]  Extender      ::=  #x00B7 | #x02D0 | #x02D1 | #x0387 | #x0640 | #x0E46 | #x0EC6 | #x3005 |
  %%                          [#x3031-#x3035] | [#x309D-#x309E] | [#x30FC-#x30FE]
  %%
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  %% For now, these are not used:
  %% 
  %%   def parse_BaseChar (start : UChars) : Required BaseChar =
  %%    case start of
  %%      | char :: tail ->
  %%        if base_char? char then
  %%	  return (char, tail)
  %%	else
  %%	  raise (Syntax ("Not a BaseChar", {start = start, stop = tail}))
  %%     | _ ->
  %%       raise (EOF ("looking for a BaseChar", {start = start, stop = []}))
  %%  
  %%  def parse_IdeographicChar  (start : UChars) : Required IdeographicChar  =
  %%    case start of
  %%      | char :: tail ->
  %%        if ideographic_char? char then
  %%	  return (char, tail)
  %%	else
  %%	  raise (Syntax ("Not a Ideographic ", {start = start, stop = tail}))
  %%     | _ ->
  %%       raise (EOF ("looking for Ideographic ", {start = start, stop = []}))
  %%  
  %%  def parse_Letter (start : UChars) : Required Letter =
  %%    case start of
  %%      | char :: tail ->
  %%        if letter? char then
  %%	  return (char, tail)
  %%	else
  %%	  raise (Syntax ("Not a Letter", {start = start, stop = tail}))
  %%      | _ ->
  %%       raise (EOF ("looking for a Letter", {start = start, stop = []}))
  %%
  %%  def parse_CombingingChar  (start : UChars) : Required CombingingChar  =
  %%    case start of
  %%      | char :: tail ->
  %%        if combining_char? char then
  %%	  return (char, tail)
  %%	else
  %%	  raise (Syntax ("Not a CombingingChar ", {start = start, stop = tail}))
  %%     | _ ->
  %%       raise (EOF ("looking for CombingingChar ", {start = start, stop = []}))
  %%
  %%  
  %%  def parse_Digit  (start : UChars) : Required Digit  =
  %%    case start of
  %%      | char :: tail ->
  %%        if digit? char then
  %%	  return (char, tail)
  %%	else
  %%	  raise (Syntax ("Not a Digit ", {start = start, stop = tail}))
  %%     | _ ->
  %%       raise (EOF ("looking for Digit ", {start = start, stop = []}))
  %%
  %%  def parse_ExtenderChar  (start : UChars) : Required ExtenderChar  =
  %%    case start of
  %%      | char :: tail ->
  %%        if  extender_char? char then
  %%	  return (char, tail)
  %%	else
  %%	  raise (Syntax ("Not a ExtenderChar ", {start = start, stop = tail}))
  %%     | _ ->
  %%       raise (EOF ("looking for ExtenderChar ", {start = start, stop = []}))

  def parse_EqualSign (start : UChars) : Required UChar =
    case start of
      | 61 (* '=' *) :: tail -> 
        return (61, tail)
      | char :: tail ->
	{
	 error {kind        = Syntax,
		requirement = "An equal sign must follow an attribute name.",
		problem     = (describe_char char) ^ " was seen instead",
		expected    = [("'='", "equal sign")],
		start       = start,
		tail        = tail,
		peek        = 10,
		action      = "Inserting implicit '='"};
	 return (61, tail)
	 }
      | _ ->
	 hard_error {kind        = EOF,
		     requirement = "An equal sign must follow an attribute name.",
		     problem     = "EOF occurred first",
		     expected    = [("'='", "equal sign")],
		     start       = start,
		     tail        = [],
		     peek        = 0,
		     action      = "immediate failure"}

endspec