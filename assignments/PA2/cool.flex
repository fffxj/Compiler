/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */
int comment_depth; /* indicate the depth of block comment */

%}

/*
 * Define names for regular expressions here.
 */
WHITESPACE      [ \n\f\r\t\v]
DD              --
LC              \(\*
RC              \*\)
DQ              \"
DARROW          =>
LE              <=
ASSIGN          <-
SYMBOL          [-+*/=<.~,;:(){}@]
               
CLASS           [cC][lL][aA][sS][sS]
ELSE            [eE][lL][sS][eE]
FI              [fF][iI]
IF              [iI][fF]
IN              [iI][nN]
INHERITS        [iI][nN][hH][eE][rR][iI][tT][sS]
ISVOID          [iI][sS][vV][oO][iI][dD]
LET             [lL][eE][tT]
LOOP            [lL][oO][oO][pP]
POOL            [pP][oO][oO][lL]
THEN            [tT][hH][eE][nN]
WHILE           [wW][hH][iI][lL][eE]
CASE            [cC][aA][sS][eE]
ESAC            [eE][sS][aA][cC]
NEW             [nN][eE][wW]
OF              [oO][fF]
NOT             [nN][oO][tT]
TRUE            t[rR][uU][eE]
FALSE           f[aA][lL][sS][eE]

INTEGER         [0-9]+
TYPEID          [A-Z][a-zA-Z0-9_]*
OBJECTID        [a-z][a-zA-Z0-9_]*

%x COMMENT STRING
%x NULL_IN_STRING
                                   
%%

 /*
  *  Single line and nested block comments.
  */
{DD}.* ;                /* eat up single line comment */

{LC} {                  /* block comment start */
    comment_depth = 1;
    BEGIN(COMMENT);
}

<COMMENT>[^(*)\n]* ;
<COMMENT>\([^(*\n]* ;
<COMMENT>\*[^(*)\n]* ;
<COMMENT>\)[^(*\n]* ;
<COMMENT>{LC}           { comment_depth++; }
<COMMENT>{RC} {
    if (comment_depth == 1)
        BEGIN(INITIAL);
    comment_depth--;
}
<COMMENT>\n             { curr_lineno++; }
<COMMENT><<EOF>> {
    BEGIN(INITIAL);
    cool_yylval.error_msg = "EOF in comment";
    return (ERROR);
}

<INITIAL>\*\) {
    cool_yylval.error_msg = "Unmatched *)";
    return (ERROR);
}

 /*
  *  The multiple-char and single-char symbols/operators.
  */
{DARROW}		{ return (DARROW); }
{LE}                    { return (LE); }
{ASSIGN}                { return (ASSIGN); }
{SYMBOL}                { return (int)(*yytext); }

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */
{CLASS}                 { return (CLASS); }
{ELSE}                  { return (ELSE); }
{FI}                    { return (FI); }
{IF}                    { return (IF); }
{IN}                    { return (IN); }
{INHERITS}              { return (INHERITS); }
{ISVOID}                { return (ISVOID); }
{LET}                   { return (LET); }
{LOOP}                  { return (LOOP); }
{POOL}                  { return (POOL); }
{THEN}                  { return (THEN); }
{WHILE}                 { return (WHILE); }
{CASE}                  { return (CASE); }
{ESAC}                  { return (ESAC); }
{NEW}                   { return (NEW); }
{OF}                    { return (OF); }
{NOT}                   { return (NOT); }

{TRUE} {
    cool_yylval.boolean = 1;
    return (BOOL_CONST);
}
{FALSE} {
    cool_yylval.boolean = 0;
    return (BOOL_CONST);
}

 /*
  * Integer constants.
  */
{INTEGER} {
    cool_yylval.symbol = inttable.add_string(yytext);
    return (INT_CONST);
}

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */
{DQ} {                  /* string start */
    string_buf_ptr = string_buf;
    BEGIN(STRING);
}

<STRING>{DQ} {
    BEGIN(INITIAL);
    *string_buf_ptr = '\0';
    if (string_buf_ptr >= string_buf + MAX_STR_CONST) {
        cool_yylval.error_msg = "String constant too long";
        return (ERROR);
    }
    cool_yylval.symbol = stringtable.add_string(string_buf);
    return (STR_CONST);
}
<STRING>\n {
    BEGIN(INITIAL);
    cool_yylval.error_msg = "Unterminated string constant";
    return (ERROR);
}
<STRING>\0 {
    BEGIN(NULL_IN_STRING);
    cool_yylval.error_msg = "String contains null character";
    return (ERROR);
}
<STRING><<EOF>> {
    BEGIN(INITIAL);
    cool_yylval.error_msg = "EOF in string constant";
    return (ERROR);
}

<STRING>\\\0 {
    BEGIN(NULL_IN_STRING);
    cool_yylval.error_msg = "String contains null character";
    return (ERROR);
}
<STRING>\\n  *string_buf_ptr++ = '\n';
<STRING>\\t  *string_buf_ptr++ = '\t';
<STRING>\\b  *string_buf_ptr++ = '\b';
<STRING>\\f  *string_buf_ptr++ = '\f';
<STRING>\\(.|\n)  *string_buf_ptr++ = yytext[1];

<NULL_IN_STRING>.*\n {
    BEGIN(INITIAL);
}
<NULL_IN_STRING>(.|\n)*\" {
    BEGIN(INITIAL);
}

<STRING>[^\\\n\0\"]+ {
    if (strlen(yytext) <= MAX_STR_CONST - strlen(string_buf)) {
        strcpy(string_buf_ptr, yytext);
    }
    /* use string_buf_ptr to check whether string is too long. */
    string_buf_ptr += strlen(yytext);
}
 
 /*
  * Type and object identifiers.
  */
{TYPEID} {
    cool_yylval.symbol = idtable.add_string(yytext);
    return (TYPEID);
}
{OBJECTID} {
    cool_yylval.symbol = idtable.add_string(yytext);
    return (OBJECTID);
}

 /* 
  * Other single characters
  */
\n                      { curr_lineno++; }

{WHITESPACE} ;

. {                     /* invalid character */
    cool_yylval.error_msg = yytext;
    return (ERROR);
}

%%
