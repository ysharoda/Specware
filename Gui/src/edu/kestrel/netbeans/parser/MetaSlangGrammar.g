/*
 * MetaSlangGrammar.g
 *
 * $Id$
 *
 *
 *
 * $Log$
 * Revision 1.2  2003/01/30 22:02:38  gilham
 * Improved parse error messages for non-word symbols such as ":".
 *
 * Revision 1.1  2003/01/30 02:02:18  gilham
 * Initial version.
 *
 *
 */

header {
package edu.kestrel.netbeans.parser;
}

//---------------------------------------------------------------------------
//============================   MetaSlangParserFromAntlr   =============================
//---------------------------------------------------------------------------

{
import java.util.*;

import org.netbeans.modules.java.ErrConsumer;

import edu.kestrel.netbeans.model.*;
import edu.kestrel.netbeans.parser.ElementFactory;
import edu.kestrel.netbeans.parser.ParserUtil;
}

class MetaSlangParserFromAntlr extends Parser;
options {
    k=3;
    buildAST=false;
//    defaultErrorHandler=false;
}

//---------------------------------------------------------------------------
starts
{
    firstToken = null;
    lastToken = null;
}
    : (  scToplevelTerm
       | scToplevelDecls
      )                     {if (firstToken != null && lastToken != null) {
                                 ParserUtil.setBodyBounds(builder, (ElementFactory.Item)builder, firstToken, lastToken);}}
    ;

private scToplevelTerm 
{
    ElementFactory.Item ignore;
}
    : ignore=scTerm[null, true]
    ;

private scToplevelDecls
    : scDecl[true] (scDecl[false])*
    ;

private scDecl[boolean first]
{
    String ignore;
    ElementFactory.Item ignore2;
    Token unitIdToken = null;
}
    : ignore=name[true]     {unitIdToken = lastToken;
                             if (first) firstToken = unitIdToken;}
      equals
      ignore2=scTerm[unitIdToken, false]
    ;

private scTerm[Token unitIdToken, boolean recordFirstToken] returns[ElementFactory.Item item]
{
    Object[] objEnd = null;
    item = null;
    Object beginEnd = null;
}
    : (  item=specDefinition[unitIdToken, recordFirstToken]
//       | item=scQualify[unitIdToken, recordFirstToken]
//       | item=scURI
      )                     {if (item != null) builder.setParent(item, null);}
    ;

//---------------------------------------------------------------------------
private specDefinition[Token unitIdToken, boolean recordFirstToken] returns[ElementFactory.Item spec]
{
    spec = null;
    ElementFactory.Item childItem = null;
    Token headerEnd = null;
    List children = new LinkedList();
    String name = (unitIdToken == null) ? "" : unitIdToken.getText();
}
    : begin:"spec"          {headerEnd = begin;
                             if (recordFirstToken) firstToken = begin;}
      (childItem=declaration
                            {if (childItem != null) children.add(childItem);}
      )*
      end:"endspec"
                            {spec = builder.createSpec(name);
                             if (unitIdToken != null) {
                                 begin = unitIdToken;
                             }
                             builder.setParent(children, spec);
                             lastToken = end;
                             ParserUtil.setAllBounds(builder, spec, begin, headerEnd, end);
                             }
    ;

private qualifier[boolean recordToken] returns[String qlf]
{
    qlf = null;
}
    : qlf=name[recordToken]
    ;

//!!! TO BE EXTENDED !!!
private name[boolean recordToken] returns[String name]
{
    name = null;
}
    : name=idName[recordToken]
    ;

private declaration returns[ElementFactory.Item item]
{
    item = null;
}
    : importDeclaration
    | item=sortDeclaration
    | item=opDeclaration
//    | item=definition
    ;

//---------------------------------------------------------------------------
private importDeclaration
{
    ElementFactory.Item ignore;
}
    : "import" ignore=scTerm[null, false]
    ;

//---------------------------------------------------------------------------
private sortDeclaration returns[ElementFactory.Item sort]
{
    sort = null;
    String[] params = null;
    String name = null;
}
    : begin:"sort" 
      name=qualifiableNames[true] 
      (params=formalSortParameters[true]
      )?
                            {sort = builder.createSort(name, params);
                             ParserUtil.setBounds(builder, sort, begin, lastToken);
                            }
    ;

private qualifiableNames[boolean recordToken] returns[String name]
{
    name = null;
    String member = null;
    String qlf = null;
}
    : name=qualifiableName[recordToken]
    | (LBRACE 
       member=qualifiableName[false]
                            {name = "{" + member;}
       (COMMA member=qualifiableName[false]
                            {name = name + ", " + member;}
       )*
       end:RBRACE           {name = name + "}";
                             if (recordToken) lastToken = end;}
      )
                            
    ;

private qualifiableName[boolean recordToken] returns[String name]
{
    name = null;
    String qlf = null;
}
    : (qlf=qualifier[false] DOT)?
      name=idName[recordToken]
                            {if (qlf != null) name = qlf + "." + name;}
    ;

private idName[boolean recordToken] returns[String name]
{
    name = null;
}
    : id:IDENTIFIER         {name = id.getText();
                             if (recordToken) lastToken = id;}
    ;

private formalSortParameters[boolean recordToken] returns[String[] params]
{
    params = null;
    String param = null;
    List paramList = null;
}
    : param=idName[recordToken]
                            {params = new String[]{param};}
    | LPAREN                {paramList = new LinkedList();}
      param=idName[false]
                            {paramList.add(param);}
      (COMMA 
       param=idName[false]
                            {paramList.add(param);}
      )* 
      end:RPAREN            {params = (String[]) paramList.toArray(new String[]{});
                             if (recordToken) lastToken = end;}
    ;

//---------------------------------------------------------------------------
//!!! TODO: fixity !!!
private opDeclaration returns[ElementFactory.Item op]
{
    op = null;
    String name = null;
    String sort = null;
}
    : begin:"op" 
      name=qualifiableNames[false] colon sort=sort[true]
                            {op = builder.createOp(name, sort);
                             ParserUtil.setBounds(builder, op, begin, lastToken);
                            }
    ;

private sort[boolean recordToken] returns[String sort]
{
    String text = null;
    sort = "";
}
    : (text=qualifiableRef[recordToken]
                            {sort = sort + text;}
       | text=literal[recordToken]
                            {sort = sort + text;}
       | text=specialSymbol[recordToken]
                            {sort = sort + text;}
       | text=expressionKeyword[recordToken]
                            {sort = sort + text;}
      )+
    ;

private specialSymbol[boolean recordToken] returns[String text]
{
    text = null;
}
    : t1:UBAR               {text = "_";
                             if (recordToken) lastToken = t1;}
    | t2:LPAREN             {text = "(";
                             if (recordToken) lastToken = t2;}
    | t3:RPAREN             {text = "}";
                             if (recordToken) lastToken = t3;}
    | t4:LBRACKET           {text = "[";
                             if (recordToken) lastToken = t4;}
    | t5:RBRACKET           {text = "]";
                             if (recordToken) lastToken = t5;}
    | t6:LBRACE             {text = "{";
                             if (recordToken) lastToken = t6;}
    | t7:RBRACE             {text = "}";
                             if (recordToken) lastToken = t7;}
    | t8:COMMA              {text = ", ";
                             if (recordToken) lastToken = t8;}
/*
    | t9:SEMICOLON          {text = "; ";
                             if (recordToken) lastToken = t9;}
    | t10:DOT               {text = ".";
                             if (recordToken) lastToken = t10;}
*/
    ;

private literal[boolean recordToken] returns[String text]
{
    text = null;
}
    : text=booleanLiteral[recordToken]
    | t1:NAT_LITERAL        {text = t1.getText();
                             if (recordToken) lastToken = t1;}
    | t2:CHAR_LITERAL       {text = t2.getText();
                             if (recordToken) lastToken = t2;}
    | t3:STRING_LITERAL     {text = t3.getText();
                             if (recordToken) lastToken = t3;}
    ;

private booleanLiteral[boolean recordToken] returns[String text]
{
    text = null;
}
    : t1:"true"             {text = "true ";
                             if (recordToken) lastToken = t1;}
    | t2:"false"            {text = "false ";
                             if (recordToken) lastToken = t2;}
    ;

private expressionKeyword[boolean recordToken] returns[String text]
{
    text = null;
}
    : t1:"as"               {text = "as ";
                             if (recordToken) lastToken = t1;}
    | t2:"case"             {text = "case ";
                             if (recordToken) lastToken = t2;}
    | t3:"choose"           {text = "choose ";
                             if (recordToken) lastToken = t3;}
    | t4:"else"             {text = "else ";
                             if (recordToken) lastToken = t4;}
    | t5:"embed"            {text = "embed ";
                             if (recordToken) lastToken = t5;}
    | t6:"embed?"           {text = "embed? ";
                             if (recordToken) lastToken = t6;}
    | t7:"ex"               {text = "ex ";
                             if (recordToken) lastToken = t7;}
    | t8:"fa"               {text = "fa ";
                             if (recordToken) lastToken = t8;}
    | t9:"fn"               {text = "fn ";
                             if (recordToken) lastToken = t9;}
    | t10:"if"              {text = "if ";
                             if (recordToken) lastToken = t10;}
    | t11:"in"              {text = "in ";
                             if (recordToken) lastToken = t11;}
    | (t12:"let"            {text = "let ";
                             if (recordToken) lastToken = t12;}
       (t13:"def"           {text = "let def ";
                             if (recordToken) lastToken = t13;}
       )?)
    | t14:"of"              {text = "of ";
                             if (recordToken) lastToken = t14;}
    | t15:"project"         {text = "project ";
                             if (recordToken) lastToken = t15;}
    | t16:"quotient"        {text = "quotient ";
                             if (recordToken) lastToken = t16;}
    | t17:"relax"           {text = "relax ";
                             if (recordToken) lastToken = t17;}
    | t18:"restrict"        {text = "restrict ";
                             if (recordToken) lastToken = t18;}
    | t19:"then"            {text = "then ";
                             if (recordToken) lastToken = t19;}
    | t20:"where"           {text = "where ";
                             if (recordToken) lastToken = t20;}
    ; 

private qualifiableRef[boolean recordToken] returns[String name]
{
    name = null;
}
    : name=qualifiableName[recordToken]
    ;

//---------------------------------------------------------------------------
private equals
    : eq
    | "is"
    ;

//---------------------------------------------------------------------------
// The following are defined as parser rules to get around the nondeterminism
// caused (between the token and IDENTIFIER) if defined in the lexer.

private colon
    : t:IDENTIFIER          {t.getText().equals(":")}? 
    ;
    exception
    catch [RecognitionException ex] {
       int line = t.getLine();
       String msg = "expecting \":\", found \"" + t.getText() + "\"";
       throw new RecognitionException(msg, null, line);
    }

private eq
    : t:IDENTIFIER          {t.getText().equals("=")}? 
    ;
    exception
    catch [RecognitionException ex] {
       int line = t.getLine();
       String msg = "expecting \"=\", found \"" + t.getText() + "\"";
       throw new RecognitionException(msg, null, line);
    }

private rarrow
    : t:IDENTIFIER          {t.getText().equals("->")}? 
    ;
    exception
    catch [RecognitionException ex] {
       int line = t.getLine();
       String msg = "expecting \"->\", found \"" + t.getText() + "\"";
       throw new RecognitionException(msg, null, line);
    }

private star
    : t:IDENTIFIER          {t.getText().equals("*")}? 
    ;
    exception
    catch [RecognitionException ex] {
       int line = t.getLine();
       String msg = "expecting \"*\", found \"" + t.getText() + "\"";
       throw new RecognitionException(msg, null, line);
    }

private vbar
    : t:IDENTIFIER          {t.getText().equals("|")}? 
    ;
    exception
    catch [RecognitionException ex] {
       int line = t.getLine();
       String msg = "expecting \"|\", found \"" + t.getText() + "\"";
       throw new RecognitionException(msg, null, line);
    }

private slash
    : t:IDENTIFIER          {t.getText().equals("/")}? 
    ;
    exception
    catch [RecognitionException ex] {
       int line = t.getLine();
       String msg = "expecting \"/\", found \"" + t.getText() + "\"";
       throw new RecognitionException(msg, null, line);
    }

//---------------------------------------------------------------------------
//=============================   MetaSlangLexerFromAntlr   =============================
//---------------------------------------------------------------------------

class MetaSlangLexerFromAntlr extends Lexer;

options {
    k=4;
    testLiterals=false;
}

// a dummy rule to force vocabulary to be all characters (except special
// ones that ANTLR uses internally (0 to 2) 

protected
VOCAB
    : '\3'..'\377'
    ;

//-----------------------------
//====== WHITESPACE ===========
//-----------------------------

// Whitespace -- ignored
WHITESPACE
    : ( ' '
      | '\t'
      | '\f'
      // handle newlines
      | ( "\r\n"  // DOS
        | '\r'    // Macintosh
        | '\n'    // Unix
        )                   {newline();}
      )                     {_ttype = Token.SKIP;}
    ;


// Single-line comments -- ignored
LINE_COMMENT
    : '%'
      (~('\n'|'\r'))* ('\n'|'\r'('\n')?)
                            {newline();
			    _ttype = Token.SKIP;}
    ;


// multiple-line comments -- ignored
BLOCK_COMMENT
    : "(*"
      (// '\r' '\n' can be matched in one alternative or by matching
       // '\r' in one iteration and '\n' in another.  The language
       // that allows both "\r\n" and "\r" and "\n" to be valid
       // newlines is ambiguous.  Consequently, the resulting grammar
       // must be ambiguous.  This warning is shut off.
       options {generateAmbigWarnings=false;}
       : { LA(2)!=')' }? '*'
	 | '\r' '\n'		{newline();}
	 | '\r'			{newline();}
	 | '\n'			{newline();}
	 | ~('*'|'\n'|'\r')
      )*
      "*)"                  {_ttype = Token.SKIP;}
    ;

//-----------------------------
//==== SPECIFIC CHARACTERS  ===
//-----------------------------


UBAR
options {
  paraphrase = "'_'";
}
    :  "_"
    ;

LPAREN
options {
  paraphrase = "'('";
}
    : '('
    ;
RPAREN
options {
  paraphrase = "')'";
}
    : ')'
    ;
LBRACKET
options {
  paraphrase = "'['";
}
    : '['
    ;
RBRACKET
options {
  paraphrase = "']'";
}
    : ']'
    ;
LBRACE
options {
  paraphrase = "'{'";
}
    : '{'
    ;
RBRACE
options {
  paraphrase = "'}'";
}
    : '}'
    ;
COMMA
options {
  paraphrase = "','";
}
    : ','
    ;
SEMICOLON
options {
  paraphrase = "';'";
}
    : ';'
    ;
DOT
options {
  paraphrase = "'.'";
}
    : '.'
    ;
DOTDOT
options {
  paraphrase = "'..'";
}
    :  ".."
    ;

POUND
options {
  paraphrase = "'#'";
}
    :  "#"
    ;

//-----------------------------
//=== ALL LETTERS and DIGITS ==
//-----------------------------

protected
LETTER
    : ('A'..'Z')
    | ('a'..'z')
    ;

protected
DIGIT
    : ('0'..'9')
    ;

//-----------------------------
//=== Literals ================
//-----------------------------

NAT_LITERAL
options {
  paraphrase = "an integer";
}
    : '0'                   
    | ('1'..'9') ('0'..'9')*
    ;

// character literals
CHAR_LITERAL
options {
  paraphrase = "a character";
}
    : '#' ( ESC | ~'\'' ) 
    ;

// string literals
STRING_LITERAL
options {
  paraphrase = "a string";
}
    : '"' (ESC|~('"'|'\\'))* '"'
    ;

protected ESC
    : '\\'
      ( 'n'
      | 'r'
      | 't'
      | 'b'
      | 'f'
      | '"'
      | '\''
      | '\\'
      )
    ;

//-----------------------------
//====== IDENTIFIERS ==========
//-----------------------------

IDENTIFIER  options
{
    paraphrase = "an identifier";
    testLiterals = true;
}
    : WORD_SYMBOL | NON_WORD_SYMBOL 
    ;
    
//-----------------------------
//====== WORD SYMBOLS =========
//-----------------------------

protected WORD_SYMBOL
    : LETTER (LETTER | DIGIT | '_' | '?')*
    ;

//-----------------------------
//====== NON-WORD SYMBOLS =====
//-----------------------------

protected NON_WORD_SYMBOL
    : (NON_WORD_MARK)+
    ;

protected NON_WORD_MARK
    : '`' | '~' | '!' | '@' 
    | '$' | '^' | '&' | '-'
    | '+' | '<' | '>' | '?' 
    | '*' | '=' | ':' | '|' 
    | '\\' | '/' 
    ;


// java antlr.Tool MetaSlangGrammar.g > MetaSlangGrammar.log
