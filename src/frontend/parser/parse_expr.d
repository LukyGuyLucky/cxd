module frontend.parser.parse_expr;

import frontend.parser;
import frontend.lexer;
import frontend;

import std.exception;
import std.stdio;
import std.conv;
import std.format:format;

enum Precedence : ubyte
{
    Low,
    Assign, // = += -= etc
    Ternary, // ?
    Or, // ||
    And, // &&
    BitOr, // |
    BitXor, // ^
    BitAnd, // &
    Eq, // == != ===
    Cmp, // < > <= >=
    Shift, // << >>
    Plus, // + -
    Mul, // * / %
    Unary, // ! ~ - * &
    Call, // () [] .
    High,
}

class ParseExpr
{
private:
    Parser p;

public:
    this(Parser p)
    {
        this.p = p;
    }

    Node nud(bool label)
    {
        Token tk = p.advance();
        switch (tk.kind)
        {
		case TokenKind.String:
            return new StringLit(tk.s, tk.pos);

        case TokenKind.WideString:
            return new StringLit(tk.s, tk.pos, true);

        case TokenKind.Const:
            Node n = parse();
            n.type_expr = new TypeExprConst(n.type_expr, tk.pos);
            return n;

        case TokenKind.Volatile:
            Node n = parse();
            n.type_expr = new TypeExprVolatile(n.type_expr, tk.pos);
            return n;

        case TokenKind.Atomic:
            Node n = parse();
            n.type_expr = new TypeExprAtomic(n.type_expr, tk.pos);
            return n;

        case TokenKind.Restrict:
            Node n = parse();
            n.type_expr = new TypeExprRestrict(n.type_expr, tk.pos);
            return n;
		
		case TokenKind.Inline:
            // `inline` accepted as a syntax promise but not emitted to C.
            // Cx generates a single translation unit, so C's inline
            // (which exists to allow duplicate definitions across TUs)
            // has no role here. Just consume the token and let the
            // normal declaration path handle what follows.
            return parse();
		
        case TokenKind.Id:
            TypeExpr* t = p.types.get(tk.s);
            TypeExpr t2;
            bool isType = t !is null;
            if (!t)
            {
                t2 = typeHeuristic(tk);
                isType = t2 !is null;
                if (isType)
                {
                    t = &t2;
                    // writeln(t.pos);
                    // writeln("Heuristica: ", t.toString());
                }
            }
            
            if (isType && looksLikeTypeStart(p.peek().kind))
            {
                p.previous2(); // volta o advance feito
                // writeln(p.peek().pos.toString());
                TypeExpr type = p.parseType.parse();
                if (p.match(TokenKind.Dot))
                    return parseMemberExpr(new IdentExpr(type.toStr(), type, type.pos));
                if (!p.check(TokenKind.Id))
                {
                    p.err.error(p.getPos(tk.pos, p.peek().pos), "The type is being used out of context.");
                    return new IdentExpr(type.toString(), type, type.pos);
                }
                Token name = p.consume(TokenKind.Id, "Expected an 'ID' after the type.");
                if (p.check(TokenKind.LParen))
                    return p.parseDecl.parseFnDecl(type, name, false);
                if (p.check(TokenKind.Equals) || p.check(TokenKind.SemiColon) || p.check(TokenKind.Comma))
                    return p.parseDecl.parseVarDecl(type, name);
            }
            if (label)
                if (p.match(TokenKind.Colon))
                    return p.parseStmt.parseLabelStmt(tk);
            TypeExpr type = null;
            if (tk.s in p.vars)
                type = p.vars[tk.s];
            if (type is null)
                type = new TypeExprNamed(tk.s, tk.pos);
            return new IdentExpr(tk.s, t is null ? type : *t, tk.pos);

		case TokenKind.Numeric:
        case TokenKind.UNumeric:
            bool isLong = tk.kind == TokenKind.Numeric;
            NumericLit node = new NumericLit(isLong, isLong ? tk.l : 0L, tk.pos, tk.lexeme);
            if (!isLong)
                node.u = tk.u;
            return node;

        case TokenKind.Double:
            return new DoubleLit(tk.d, tk.pos, tk.lexeme);

        case TokenKind.Float:
            return new FloatLit(tk.f, tk.pos, tk.lexeme);

        case TokenKind.Char:
            return new CharLit(to!char(tk.s), tk.pos);

        case TokenKind.Null:
            return new NullLit(tk.pos);

        case TokenKind.True:
        case TokenKind.False:
            return new BoolLit(tk.kind == TokenKind.True, tk.pos);

        case TokenKind.PPlus: // ++x
        case TokenKind.Plus: // +x
        case TokenKind.MMinus: // --x
        case TokenKind.Minus: // -x
        case TokenKind.BITNot: // ~x
        case TokenKind.Bang: // !x
        case TokenKind.BITAnd: // &x
        case TokenKind.Star: // *x
            Node val = parse(getPrecedence(tk.kind));
            return new UnaryExpr(val, tk.kind, p.getPos(tk.pos, val.pos), false);

        case TokenKind.And: // &&x
            Node val = parse(getPrecedence(tk.kind));
            return new UnaryExpr(val, tk.kind, p.getPos(tk.pos, val.pos), false);

        case TokenKind.LBrace:
            return parseStructLit(tk.pos);

        case TokenKind.LBracket:
            return parseArrayLit(tk.pos);

		case TokenKind.SizeOf:
            p.consume(TokenKind.LParen, "Expected '('.");
            TypeExpr expr = p.parseType.parse();
            Position end = p.consume(TokenKind.RParen, "Expected ')'.").pos;
            return new SizeOfExpr(expr, p.getPos(tk.pos, end));

        case TokenKind.Eval:
            p.consume(TokenKind.LParen, "Expected '('.");
            Node e = parse();
            Position endE = p.consume(TokenKind.RParen, "Expected ')'.").pos;
            return new EvalExpr(e, p.getPos(tk.pos, endE));
		
		case TokenKind.Check:
        {
            p.consume(TokenKind.LParen, "Expected '('.");
            Node cond = parse();
            Position e1 = p.consume(TokenKind.RParen, "Expected ')'.").pos;
            return new CheckExpr(CheckKind.Cond, cond, null, null, p.getPos(tk.pos, e1));
        }

        case TokenKind.CheckEq:
        case TokenKind.CheckNotEq:
        {
            CheckKind ck = tk.kind == TokenKind.CheckEq ? CheckKind.Eq : CheckKind.NotEq;
            p.consume(TokenKind.LParen, "Expected '('.");
            Node a = parse();
            p.consume(TokenKind.Comma, "Expected ','.");
            Node b = parse();
            Position e2 = p.consume(TokenKind.RParen, "Expected ')'.").pos;
            return new CheckExpr(ck, a, b, null, p.getPos(tk.pos, e2));
        }
		
		case TokenKind.CheckNear:
        {
            p.consume(TokenKind.LParen, "Expected '('.");
            Node a = parse();
            p.consume(TokenKind.Comma, "Expected ','.");
            Node b = parse();
            p.consume(TokenKind.Comma, "Expected ','.");
            Node eps = parse();
            Position e4 = p.consume(TokenKind.RParen, "Expected ')'.").pos;
            return new CheckExpr(CheckKind.Near, a, b, eps, p.getPos(tk.pos, e4));
        }

		
        case TokenKind.CheckFail:
        {
            p.consume(TokenKind.LParen, "Expected '('.");
            Node m = parse();
            Position e3 = p.consume(TokenKind.RParen, "Expected ')'.").pos;
            return new CheckExpr(CheckKind.Fail, null, null, m, p.getPos(tk.pos, e3));
        }
		
		case TokenKind.FieldCount:
            p.consume(TokenKind.LParen, "Expected '('.");
            TypeExpr fct = p.parseType.parse();
            Position endFc = p.consume(TokenKind.RParen, "Expected ')'.").pos;
            return new ReflectExpr(ReflectKind.FieldCount, fct, null, null, p.getPos(tk.pos, endFc));

        case TokenKind.FieldName:
        case TokenKind.FieldType:
        {
            ReflectKind rk = tk.kind == TokenKind.FieldName ? ReflectKind.FieldName : ReflectKind.FieldType;
            p.consume(TokenKind.LParen, "Expected '('.");
            TypeExpr ftT = p.parseType.parse();
            p.consume(TokenKind.Comma, "Expected ','.");
            Node idx = parse();
            Position endFn = p.consume(TokenKind.RParen, "Expected ')'.").pos;
            return new ReflectExpr(rk, ftT, null, idx, p.getPos(tk.pos, endFn));
        }

        case TokenKind.FieldGet:
        case TokenKind.UnionGet:
        {
            ReflectKind rk = tk.kind == TokenKind.FieldGet ? ReflectKind.FieldGet : ReflectKind.UnionGet;
            p.consume(TokenKind.LParen, "Expected '('.");
            Node obj = parse();
            p.consume(TokenKind.Comma, "Expected ','.");
            Node nm = parse();
            Position endFg = p.consume(TokenKind.RParen, "Expected ')'.").pos;
            return new ReflectExpr(rk, null, obj, nm, p.getPos(tk.pos, endFg));
        }
		
        case TokenKind.AlignOf:
            p.consume(TokenKind.LParen, "Expected '('.");
            TypeExpr expr2 = p.parseType.parse();
            Position end2 = p.consume(TokenKind.RParen, "Expected ')'.").pos;
            return new SizeOfExpr(expr2, p.getPos(tk.pos, end2), true);

        case TokenKind.TypeName:
            p.consume(TokenKind.LParen, "Expected '('.");
            Node expr = parse();
            Position end = p.consume(TokenKind.RParen, "Expected ')'.").pos;
            return new TypeNameExpr(expr, p.getPos(tk.pos, end));

        case TokenKind.Type:
            p.consume(TokenKind.LParen, "Expected '('.");
            TypeExpr expr = p.parseType.parse();
            Position end = p.consume(TokenKind.RParen, "Expected ')'.").pos;
            return new TTypeExpr(expr, p.getPos(tk.pos, end));

        case TokenKind.Is:
            p.consume(TokenKind.LParen, "Expected '('.");
            TypeExpr left = p.parseType.parse();
            p.consume(TokenKind.Comma, "Expected ','.");
            TypeExpr right = p.parseType.parse();
            Position end = p.consume(TokenKind.RParen, "Expected ')'.").pos;
            return new IsExpr(left, right, p.getPos(tk.pos, end));

        case TokenKind.LParen:
            return parseCastOrNode(tk.pos);

        case TokenKind.Dot:
            // .call() | .member
            return parseMemberExpr(null);
		
		case TokenKind.Fn:
            return parseLambdaExpr(tk.pos);
            
            
        default:
            // tk.print();
            p.err.error(tk.pos, "An expression is expected.");
            return new IdentExpr("null", new TypeExprNamed("void", tk.pos), tk.pos);
        }
    }

    bool looksLikeTypeStart(TokenKind k)
    {
        return k == TokenKind.Id
            || k == TokenKind.Volatile
            || k == TokenKind.Const
            || k == TokenKind.Restrict
            || k == TokenKind.Atomic
            || k == TokenKind.Star
            || k == TokenKind.LParen
            || k == TokenKind.LThan
            || k == TokenKind.LBracket
            || k == TokenKind.Bang;
    }

    bool canPrecedeTypeStart(TokenKind k)
    {
        return k == TokenKind.SemiColon
            || k == TokenKind.LBrace
            || k == TokenKind.RBrace;
    }

	bool skipTypeTokens()
    {
        while (true)
        {
            if (p.isAtEnd())
                return false;
            if (p.match(TokenKind.Star))
                continue;
            if (p.match(TokenKind.Bang))
                continue;

            if (p.match(TokenKind.LBracket))
            {
                if (!p.check(TokenKind.RBracket))
                    p.advance();
                if (!p.match(TokenKind.RBracket))
                    return false;
                continue;
            }

            if (p.match(TokenKind.LThan))
            {
                // Count angle-bracket nesting so `Foo<Bar<Baz>>` is
                // skipped as a whole. Relying on "first '>'" breaks
                // with nested generics.
                int depth = 1;
                while (!p.isAtEnd() && depth > 0)
                {
                    if (p.check(TokenKind.LThan))
                        depth++;
                    else if (p.check(TokenKind.GThan))
                    {
                        depth--;
                        if (depth == 0)
                        {
                            p.advance();
                            break;
                        }
                    }
                    p.advance();
                }
                if (depth != 0)
                    return false;
                continue;
            }

            if (p.match(TokenKind.LParen))
            {
                // Count paren nesting so `(double)x` and
                // `(int(*)(char*, int))` are skipped as a whole,
                // not stopped at the first inner ')'.
                int depth = 1;
                while (!p.isAtEnd() && depth > 0)
                {
                    if (p.check(TokenKind.LParen))
                        depth++;
                    else if (p.check(TokenKind.RParen))
                    {
                        depth--;
                        if (depth == 0)
                        {
                            p.advance();
                            break;
                        }
                    }
                    p.advance();
                }
                if (depth != 0)
                    return false;
                continue;
            }

            break;
        }
        return true;
    }

    TypeExpr typeHeuristic(Token name)
    {
        // writeln("Heuristic: ", name.s);
        // name.print();

        // writeln("LOOKS LIKE");
        if (!looksLikeTypeStart(p.peek().kind))
            return null;

        // writeln("BEFORE >= 2");
        if (p.offset >= 2 && !canPrecedeTypeStart(p.tokens[p.offset - 2].kind))
            return null;

        uint offset = p.offset;
        scope (exit)
            p.offset = offset;

        // writeln("BEFORE SKIP");
        // p.peek().print();

        if (!skipTypeTokens())
            return null;

        // writeln("BEFORE OK");
        // p.peek().print();
        if (!p.check(TokenKind.Id))
            return null;

        if (p.future(TokenKind.Equals, 1) 
            || p.future(TokenKind.SemiColon, 1) 
            || p.future(TokenKind.Dot, 1) 
            || p.future(TokenKind.LParen, 1)
            || p.future(TokenKind.Comma, 1)
            )
        {
            // writeln("OK");
            return new TypeExprNamed(name.s, name.pos);
        }

        return null;
    }

    Node parseArrayLit(Position pos)
    {
        Node[] values;
        while (!p.isAtEnd() && !p.check(TokenKind.RBracket))
        {
            values ~= parse();
            if (!p.check(TokenKind.RBracket))
                p.consume(TokenKind.Comma, "Expected ',' after the value.");
        }
        p.consume(TokenKind.RBracket, "Expected '}'.");
        return new ArrayLit(values, p.getPos(pos, p.previous().pos));
    }

    Node parseStructLit(Position pos)
    {
        Node[] values;
        while (!p.isAtEnd() && !p.check(TokenKind.RBrace))
        {
            values ~= parse();
            if (!p.check(TokenKind.RBrace))
                p.consume(TokenKind.Comma, "Expected ',' after the value.");
        }
        p.consume(TokenKind.RBrace, "Expected '}'.");
        return new StructLit(values, p.getPos(pos, p.previous().pos));
    }

    Node parseCastOrNode(Position pos)
    {
        if (
            p.check(TokenKind.Id) 
            || p.check(TokenKind.Volatile) 
            || p.check(TokenKind.Const)
            || p.check(TokenKind.Atomic)
            || p.check(TokenKind.Restrict)
        )
        {
            if (
                p.future(TokenKind.Star, 1)
                || p.future(TokenKind.RParen, 1)
                || p.future(TokenKind.LThan, 1)
                || p.future(TokenKind.Id, 1)
                || p.future(TokenKind.Volatile, 1)
                || p.future(TokenKind.Const, 1)
                || p.future(TokenKind.Restrict, 1)
                || p.future(TokenKind.Atomic, 1)
                || p.future(TokenKind.LBracket, 1)
                )
                if (p.types.exists(p.peek().s))
                {
                    TypeExpr to = p.parseType.parse();
                    p.consume(TokenKind.RParen, "Expected ')'.");
                    Node val = parse();
                    return new CastExpr(val, to, p.getPos(pos, val.pos));
                }
        }
        Node val = parse();
        p.consume(TokenKind.RParen, "Expected ')'.");
        return new GroupExpr(val, val.pos);
    }

    Node parseBinaryExprAssignStmt(bool isBinaryExpr, TokenKind op, Node left)
    {
        Node right = parse(getPrecedence(op));
        // writeln(op);
        // writeln(left.pos);
        // writeln(right);
        if (isBinaryExpr)
            return new BinaryExpr(left, right, op, p.getPos(left.pos, right.pos));
        // writeln(left);
        // writeln(right);
        // writeln(left.pos);
        // writeln(right.pos);
        // left.print(0);
        return new AssignStmt(left, right, op, p.getPos(left.pos, right.pos));
    }

	Node parseLambdaExpr(Position pos)
    {
        // fn (T x, T y) Ret => expr
        // fn (T x, T y) Ret { stmts }
        p.consume(TokenKind.LParen, "Expected '(' after 'fn'.");
        FnArg[] args;
        while (!p.check(TokenKind.RParen))
        {
            TypeExpr at = p.parseType.parse();
            Token an = p.consume(TokenKind.Id, "Expected parameter name.");
            args ~= new FnArg(an.s, at, null, an.pos);
            if (!p.check(TokenKind.RParen))
                p.consume(TokenKind.Comma, "Expected ','.");
        }
        p.consume(TokenKind.RParen, "Expected ')'.");

        TypeExpr ret = p.parseType.parse();

        TypeExpr[] argTypes;
        foreach (a; args)
            argTypes ~= a.type_expr;
        TypeExpr fnType = new TypeExprFunction(ret, argTypes, pos);

        Node body;
        if (p.match(TokenKind.Arrow))
        {
            Node val = parse();
            body = new ReturnStmt(val, val.pos);
        }
        else if (p.check(TokenKind.LBrace))
        {
            Node[] stmts = p.parseStmt.parseBody();
            body = new Multi(stmts);
        }
        else
        {
            p.err.error(pos, "Expected '=>' or '{' in lambda body.");
            body = new ReturnStmt(null, pos);
        }

        return new LambdaExpr(args, body, ret, fnType, pos);
    }

	
	Node parseCallExpr(Node left)
    {
        Node[] args;
        while (!p.check(TokenKind.RParen))
        {
            args ~= parse();
            if (!p.check(TokenKind.RParen))
                p.consume(TokenKind.Comma, "Expected ','.");
        }
        p.consume(TokenKind.RParen, "Expected ')'.");

        // Macro expansion: if `left` names a macro, expand its body with
        // the given arguments. Define-before-use only (macros are looked
        // up at parse time from `p.macros`).
        if (left.kind == NodeKind.IdentExpr)
        {
            IdentExpr ie = cast(IdentExpr) left;
            MacroDecl* mp = ie.val in p.macros;
            if (mp !is null)
            {
                MacroDecl def = mp.dup();
                if (def.params.length != args.length)
                {
                    p.err.error(left.pos, format(
                        "Macro '%s' expects %d argument(s), got %d.",
                        ie.val, def.params.length, args.length));
                    return new IdentExpr("null", new TypeExprNamed("void", left.pos), left.pos);
                }

                foreach (i, e; def.body)
                    def.body[i] = substIdents(e, def.params, args);

                if (def.body.length == 1)
				{
					Node only = def.body[0];
					// Wrap the expansion in a GroupExpr so that operators outside
					// the macro call (e.g. `Sum(a,b) * 2`) bind to the whole result,
					// not just the last term of the macro body.
					return new GroupExpr(only, only.pos);
				}

                // multi-statement macro body: not supported in expression
                // context yet; fall through as-is (caller will error).
                return new Multi(def.body);
            }
        }

        return new CallExpr(left, args, left.pos);
    }

	
    Node parseMemberExpr(Node left)
    {
        Node val = parse(Precedence.Call);
        if (val.kind == NodeKind.IdentExpr && p.check(TokenKind.LParen))
        {
            p.advance(); // consome '('
            val = parseCallExpr(val); // reusa a função existente, empacota como CallExpr(val, args)
        }
        return new MemberExpr(left, val, p.getPos(left is null ? null : left.pos, val.pos));
    }

    Node parseIndex()
    {
        Node left = parse();
        // p.previous().print();
        // p.peek().print();
        bool isCopy = p.peek().kind == TokenKind.Ellipsis;
        if (p.match(TokenKind.Range) || p.match(TokenKind.Ellipsis))
            return new RangeExpr(left, parse(), isCopy, left.pos);
        return left;
    }

    Node parseIndexExpr(Node left)
    {
        Node idx = parseIndex();
        Position end = p.consume(TokenKind.RBracket, "Expected ']'.").pos;
        return new IndexExpr(left, idx, p.getPos(left.pos, end));
    }

    Node parseTernaryExpr(Node expr)
    {
        Node left = parse();
        p.consume(TokenKind.Colon, "Expected ':'");
        Node right = parse();
        return new TernaryExpr(expr, left, right, p.getPos(expr.pos, right.pos));
    }

    Node led(Node left)
    {
        Token tk = p.advance();
        switch (tk.kind)
        {
        case TokenKind.Plus:
        case TokenKind.Minus:
        case TokenKind.Star:
        case TokenKind.Slash:
        case TokenKind.Modulo:
        case TokenKind.LThan:
        case TokenKind.GThan:
        case TokenKind.EEquals:
        case TokenKind.EEEquals:
        case TokenKind.NEquals:
        case TokenKind.LEquals:
        case TokenKind.GEquals:
        case TokenKind.BITAnd:
        case TokenKind.BITOr:
        case TokenKind.BITXor:
        case TokenKind.BITLeft:
        case TokenKind.BITRight:
        case TokenKind.And:
        case TokenKind.Or:
            return parseBinaryExprAssignStmt(true, tk.kind, left);
        case TokenKind.LParen:
            return parseCallExpr(left);
        case TokenKind.Dot:
            return parseMemberExpr(left);
        case TokenKind.Equals:
        case TokenKind.PLUSEquals:
        case TokenKind.MINUSEquals:
        case TokenKind.DIVEquals:
        case TokenKind.STAREquals:
        case TokenKind.MODEquals:
        case TokenKind.OBWEquals:
        case TokenKind.EBWEquals:
        case TokenKind.SHLEquals:
        case TokenKind.SHREquals:
            return parseBinaryExprAssignStmt(false, tk.kind, left);
        case TokenKind.LBracket:
            return parseIndexExpr(left);
        case TokenKind.PPlus:
        case TokenKind.MMinus:
            return new UnaryExpr(left, tk.kind, tk.pos, true);
        case TokenKind.Question:
            return parseTernaryExpr(left);
        default:
            return left;
        }
    }

    Precedence getPrecedence(TokenKind kind)
    {
        switch (kind)
        {
        case TokenKind.Equals:
        case TokenKind.PLUSEquals:
        case TokenKind.MINUSEquals:
        case TokenKind.DIVEquals:
        case TokenKind.STAREquals:
        case TokenKind.MODEquals:
        case TokenKind.OBWEquals:
        case TokenKind.EBWEquals:
        case TokenKind.SHLEquals:
        case TokenKind.SHREquals:
            return Precedence.Assign;
        case TokenKind.Question:
            return Precedence.Ternary;
        case TokenKind.Or:
            return Precedence.Or;
        case TokenKind.And:
            return Precedence.And;
        case TokenKind.BITOr:
            return Precedence.BitOr;
        case TokenKind.BITXor:
            return Precedence.BitXor;
        case TokenKind.BITAnd:
            return Precedence.BitAnd;
        case TokenKind.EEquals:
        case TokenKind.EEEquals:
        case TokenKind.NEquals:
            return Precedence.Eq;
        case TokenKind.LThan:
        case TokenKind.GThan:
        case TokenKind.LEquals:
        case TokenKind.GEquals:
            return Precedence.Cmp;
        case TokenKind.BITLeft:
        case TokenKind.BITRight:
            return Precedence.Shift;
        case TokenKind.Plus:
        case TokenKind.Minus:
            return Precedence.Plus;
        case TokenKind.Star:
        case TokenKind.Slash:
        case TokenKind.Modulo:
            return Precedence.Mul;
        case TokenKind.Dot:
        case TokenKind.LParen:
        case TokenKind.LBracket:
        case TokenKind.PPlus:
        case TokenKind.MMinus:
            return Precedence.Call;
        default:
            return Precedence.Low;
        }
    }

    Node parse(Precedence pre = Precedence.Low, bool label = false)
    {
        Node left = nud(label);
        while (!p.isAtEnd() && pre < getPrecedence(p.peek().kind))
            left = led(left);
        return left;
    }
}
