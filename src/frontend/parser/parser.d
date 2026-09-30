module frontend.parser.parser;

import frontend.parser;
import frontend.lexer;
import frontend;

import std.exception;
import std.stdio;

class Parser
{
    Token[] tokens;
    uint offset;
    Generic generic;
    TypeExpr[string] vars;
    MacroDecl[string] macros;
    bool[string] targetPlats;
    TypeRegistry types;
    Diagnostics err;
    ubyte flags;
    ImportResolverContext* ctx;
    Node[] imports;

    ParseType parseType;
    ParseExpr parseExpr;
    ParseStmt parseStmt;
    ParseDecl parseDecl;

    this(Token[] tokens, Diagnostics err, TypeRegistry t, Generic generic, ImportResolverContext* ctx)
    {
        this.tokens = tokens;
        this.err = err;
        this.types = t;
        this.generic = generic;
        this.ctx = ctx;
        this.parseType = new ParseType(this);
        this.parseExpr = new ParseExpr(this);
        this.parseStmt = new ParseStmt(this);
        this.parseDecl = new ParseDecl(this);
        initTargetPlats();
    }
	
	private void initTargetPlats()
    {
        version(Windows) targetPlats["windows"] = true;
        version(linux)   targetPlats["linux"]   = true;
        version(OSX)     targetPlats["macos"]   = true;
        version(X86)     targetPlats["x86"]     = true;
        version(X86_64)  targetPlats["x86_64"]  = true;
        version(ARM)     targetPlats["arm"]     = true;
        version(AArch64) targetPlats["arm64"]   = true;
    }
	
    ubyte resetFlags()
    {
        ubyte f = this.flags;
        this.flags = 0;
        return f;
    }

    Position getPos(Position l, Position r)
    {
        if (l is null) 
            return r;
        if (r is null) 
            return l;
        return new Position(l.filename, l.dir, l.start, r.end);
    }

    bool isAtEnd(uint n = 0)
    {
        return (offset + n) >= tokens.length || tokens[offset].kind == TokenKind.Eof;
    }

    void checkIsAtEnd(uint n = 0)
    {
        enforce(!isAtEnd(n), "Source out of bounds in parser.");
    }

    Token peek()
    {
        checkIsAtEnd();
        return tokens[offset];
    }

    Token advance()
    {
        checkIsAtEnd();
        return tokens[offset++];
    }

    Token previous2()
    {
        return tokens[offset--];
    }

    Token previous()
    {
        return tokens[offset-1];
    }

    bool match(TokenKind kind)
    {
        if (peek().kind == kind)
        {
            advance();
            return true;
        }
        return false;
    }

    bool future(TokenKind kind, uint off)
    {
        checkIsAtEnd(off);
        return tokens[offset+off].kind == kind;
    }

    bool check(TokenKind kind)
    {
        checkIsAtEnd();
        return tokens[offset].kind == kind;
    }

    Token consume(TokenKind kind, string message, Position p = null)
    {
        if (check(kind))
            return advance();
        err.error(p is null ? peek().pos : p, message);
        return peek();
    }

    bool needSemiColon(Node n)
    {
        if (n is null) return false;
        switch (n.kind)
        {
        case NodeKind.VarDecl:
        case NodeKind.CallExpr:
        case NodeKind.ReturnStmt:
        case NodeKind.AssignStmt:
        case NodeKind.MemberExpr:
        case NodeKind.DeferStmt:
        case NodeKind.UnaryExpr:
        case NodeKind.ContinueOrBreakStmt:
        case NodeKind.GotoStmt:
        case NodeKind.ImportStmt:
        case NodeKind.Multi:
            return true;
        default:
            return false;
        }
    }

    void checkSemiColon(Node n)
    {
        if (!needSemiColon(n))
            return;
        consume(TokenKind.SemiColon, "Expected ';'.", n.pos);
    }

    bool isStmt()
    {
        switch (peek().kind)
        {
        case TokenKind.Return:
        case TokenKind.Defer:
        case TokenKind.If:
        case TokenKind.For:
        case TokenKind.While:
        case TokenKind.Continue:
        case TokenKind.Break:
        case TokenKind.Import:
        case TokenKind.Goto:
        case TokenKind.Raw:
        case TokenKind.Switch:
        case TokenKind.Case:
        case TokenKind.Default:
        case TokenKind.ForEach:
            return true;
        default:
            return false;
        }
    }

    bool isDecl()
    {
        switch (peek().kind)
        {
            case TokenKind.Include:
            case TokenKind.Struct:
            case TokenKind.Enum:
            case TokenKind.Union:
            case TokenKind.Alias:
            case TokenKind.Macro:
            case TokenKind.Target:
                return true;
        default:
            return false;
        }
    }

	Node[] parseIntern()
    {
        Node[] node;
        if (isDecl())
        {
            Node d = parseDecl.parse();
            if (d is null)
                return [];
            node ~= d;
        }
        else if (isStmt())
            node ~= parseStmt.parse();
        else
            node ~= parseExpr.parse(Precedence.Low, true);
        checkSemiColon(node[0]);
        if (node[0].kind == NodeKind.Multi)
            node ~= (cast(Multi)node[0]).body;
        return node;
    }

    Program parse()
    {
        Node[] body;
        while (!isAtEnd())
            body ~= parseIntern();
        return new Program(imports ~ body);
    }
}
