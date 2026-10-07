module frontend.lexer.token;

import std.stdio, std.format;

enum TokenKind : ubyte
{
    // C features
    Include,

    // keywords
    Fn,
    ForEach,
    Macro,
    Target,
    Test,
    Check,
    CheckEq,
    CheckNotEq,
    CheckNear,
    CheckFail,
    Is,
    Type,
    TypeName,
    Case,
    Default,
    Switch,
    Register,
    Raw,
    Atomic,
    Restrict,
    Const,
    Volatile,
    Inline,
    Overload,
    Import,
    Goto,
    Alias,
	SizeOf,
    AlignOf,
    Eval,
    FieldCount,
    FieldName,
    FieldType,
    FieldGet,
    UnionGet,
    Enum,
    Union,
    Continue,
    Break,
    If,
    Else,
    For,
    While,
    Defer,
    Static,
    Struct,
    Return,
    
    // literals
    Id,
    String,
    WideString,
    Char,
    Numeric,
    UNumeric,
    Float,
    Double,
    Null,
    True,
    False,

    // symbols
    LParen, // (
    RParen, // )
    LBrace, // {
    RBrace, // }
    LBracket, // [
    RBracket, // ]

    Comma, // ,
    Colon, // :
    SemiColon, // ;
    Dot, // .
    At, // @
    Range, // ..
    Ellipsis, // ...

    Plus, // +
    PPlus, // ++
    Minus, // -
    MMinus, // -- 
    Star, // *
    Slash, // /
    Modulo, // %

    PLUSEquals, // +=
    MINUSEquals, // -=
    DIVEquals, // /=
    STAREquals, // *=
    MODEquals, // %=
    OBWEquals, // |=
    EBWEquals, // &=
    SHLEquals, // <<=
    SHREquals, // >>=
    Equals, // =

    Arrow, // =>
    EEquals, // ==
    EEEquals, // ===
    LThan, // <
    GThan, // >
    LEquals, // <=
    GEquals, // >=
    Bang, // !
    NEquals, // !=
    And, // &&
    Or, // ||
    Question, // ?
    QQuestion, // ??
    QDot, // ?.

    BITLeft, // <<
    BITRight, // >>
    BITAnd, // &
    BITOr, // |
    BITNot, // ~
    BITXor, // ^

    // eof
    Eof,
}

class LinePos
{
    uint offset, line;
    this(uint offset, uint line)
    {
        this.offset = offset;
        this.line = line;
    }
}

class Position
{
    string filename, dir;
    LinePos start, end;

    this(string filename, string dir, LinePos start, LinePos end)
    {
        this.filename = filename;
        this.dir = dir;
        this.start = start;
        this.end = end;
    }

    override string toString() const
    {
        return format("%s:%d:%d", filename, start.line, start.offset);
    }
}

class Token {
    TokenKind kind;
    union {
        float f;
        long l;
        ulong u;
        double d;
    }
    // String payload for tokens that carry one: String, WideString,
    // Char, Raw. null for every other token, including symbol tokens
    // and numeric tokens.
    //
    // Kept OUT of the union on purpose:
    //  - a class field is always null-initialized, so a symbol token's
    //    `.s` is null instead of leftover GC garbage;
    //  - the GC does not scan union members, so a `string` inside the
    //    union could be collected while still referenced.
    // Putting it back into the union re-introduces both problems.
    string s;
    // Source text of a numeric literal, exactly as written.
    // Empty for every other token, and for numeric literals that
    // were synthesized rather than read from source.
    string lexeme;
    Position pos;
    this(TokenKind kind, Position pos)
    {
        this.kind = kind;
        this.pos = pos;
    }

    static Token tk_unumeric(ulong val, Position pos, string lexeme = "")
    {
        Token t = new Token(TokenKind.UNumeric, pos);
        t.u = val;
        t.lexeme = lexeme;
        return t;
    }

    static Token tk_numeric(long val, Position pos, string lexeme = "")
    {
        Token t = new Token(TokenKind.Numeric, pos);
        t.l = val;
        t.lexeme = lexeme;
        return t;
    }

    static Token tk_float(float val, Position pos, string lexeme = "")
    {
        Token t = new Token(TokenKind.Float, pos);
        t.f = val;
        t.lexeme = lexeme;
        return t;
    }

    static Token tk_double(double val, Position pos, string lexeme = "")
    {
        Token t = new Token(TokenKind.Double, pos);
        t.d = val;
        t.lexeme = lexeme;
        return t;
    }

    static Token tk_string(TokenKind kind, string val, Position pos)
    {
        Token t = new Token(kind, pos);
        t.s = val;
        return t;
    }

    static Token tk(TokenKind kind, Position pos)
    {
        return new Token(kind, pos);
    }

    void print()
    {
        writefln("TokenKind: %s\nPos: %s", kind, pos);
    }
}
