module frontend.comptime;

import frontend;
import errors;

import std.format : format;

// Compile-time expression evaluator for `__eval(...)`.
//
// Supported:
//   - integer arithmetic, comparison, logic
//   - if / return / var / assignment
//   - recursive calls to user functions
//
// Not supported (reports a diagnostic):
//   - pointers, arrays, structs, strings
//   - for / while loops
//   - global variable access
//   - struct method calls
class Comptime
{
    Program program;
    Diagnostics err;
    FnDecl[string] fns;

    this(Program p, Diagnostics e)
    {
        program = p;
        err = e;
    }

    void resolve()
    {
        collectFns(program.body);
        foreach (ref n; program.body)
            n = walk(n);
    }

    private void collectFns(Node[] body)
    {
        foreach (n; body)
        {
            if (n is null) continue;
            if (auto fn = cast(FnDecl) n)
                fns[fn.name] = fn;
            else if (auto st = cast(StructDecl) n)
                foreach (f; st.functions)
                    if (f !is null)
                        fns[f.name] = f;
        }
    }

    // Recursively replace every EvalExpr node with its evaluated constant.
    private Node walk(Node n)
    {
        if (n is null) return null;

        if (n.kind == NodeKind.EvalExpr)
        {
            EvalExpr e = cast(EvalExpr) n;
            return eval(e.expr, null, 0);
        }

        switch (n.kind)
        {
        case NodeKind.BinaryExpr:
            BinaryExpr b = cast(BinaryExpr) n;
            b.left = walk(b.left); b.right = walk(b.right);
            return b;
        case NodeKind.UnaryExpr:
            UnaryExpr u = cast(UnaryExpr) n;
            u.val = walk(u.val);
            return u;
        case NodeKind.CallExpr:
            CallExpr c = cast(CallExpr) n;
            c.callee = walk(c.callee);
            foreach (i, a; c.args) c.args[i] = walk(a);
            return c;
        case NodeKind.MemberExpr:
            MemberExpr m = cast(MemberExpr) n;
            m.left = walk(m.left); m.right = walk(m.right);
            return m;
        case NodeKind.GroupExpr:
            GroupExpr g = cast(GroupExpr) n;
            g.val = walk(g.val);
            return g;
        case NodeKind.AssignStmt:
            AssignStmt a = cast(AssignStmt) n;
            a.left = walk(a.left); a.right = walk(a.right);
            return a;
        case NodeKind.TernaryExpr:
            TernaryExpr t = cast(TernaryExpr) n;
            t.expr = walk(t.expr); t.left = walk(t.left); t.right = walk(t.right);
            return t;
        case NodeKind.IndexExpr:
            IndexExpr ix = cast(IndexExpr) n;
            ix.value = walk(ix.value); ix.idx = walk(ix.idx);
            return ix;
        case NodeKind.CastExpr:
            CastExpr ce = cast(CastExpr) n;
            ce.expr = walk(ce.expr);
            return ce;
        case NodeKind.ArrayLit:
            ArrayLit al = cast(ArrayLit) n;
            foreach (i, e; al.values) al.values[i] = walk(e);
            return al;
        case NodeKind.StructLit:
            StructLit sl = cast(StructLit) n;
            foreach (i, e; sl.values) sl.values[i] = walk(e);
            return sl;
        case NodeKind.RangeExpr:
            RangeExpr re = cast(RangeExpr) n;
            re.left = walk(re.left); re.right = walk(re.right);
            return re;
        case NodeKind.VarDecl:
            VarDecl v = cast(VarDecl) n;
            if (v.val !is null) v.val = walk(v.val);
            return v;
        case NodeKind.ReturnStmt:
            ReturnStmt r = cast(ReturnStmt) n;
            r.val = walk(r.val);
            return r;
        case NodeKind.IfStmt:
            IfStmt i = cast(IfStmt) n;
            if (i.expr !is null) i.expr = walk(i.expr);
            foreach (j, b; i.body) i.body[j] = walk(b);
            if (i._else !is null) i._else = cast(IfStmt) walk(i._else);
            return i;
        case NodeKind.WhileStmt:
            WhileStmt w = cast(WhileStmt) n;
            if (w.expr !is null) w.expr = walk(w.expr);
            foreach (j, b; w.body) w.body[j] = walk(b);
            return w;
        case NodeKind.ForStmt:
            ForStmt f = cast(ForStmt) n;
            if (f.first !is null) f.first = walk(f.first);
            if (f.middle !is null) f.middle = walk(f.middle);
            if (f.end !is null) f.end = walk(f.end);
            foreach (j, b; f.body) f.body[j] = walk(b);
            return f;
        case NodeKind.ForEachStmt:
            ForEachStmt fe = cast(ForEachStmt) n;
            if (fe.k !is null) fe.k = walk(fe.k);
            fe.v = walk(fe.v);
            fe.value = walk(fe.value);
            foreach (j, b; fe.body) fe.body[j] = walk(b);
            return fe;
        case NodeKind.SwitchStmt:
            SwitchStmt s = cast(SwitchStmt) n;
            if (s.expr !is null) s.expr = walk(s.expr);
            foreach (j, cc; s.cases) s.cases[j] = cast(CaseStmt) walk(cc);
            return s;
        case NodeKind.CaseStmt:
            CaseStmt cc = cast(CaseStmt) n;
            if (cc.value !is null) cc.value = walk(cc.value);
            foreach (j, b; cc.body) cc.body[j] = walk(b);
            return cc;
        case NodeKind.LabelStmt:
            LabelStmt l = cast(LabelStmt) n;
            foreach (j, b; l.body) l.body[j] = walk(b);
            return l;
        case NodeKind.DeferStmt:
            DeferStmt d = cast(DeferStmt) n;
            d.val = walk(d.val);
            return d;
        case NodeKind.Multi:
            Multi m2 = cast(Multi) n;
            foreach (j, b; m2.body) m2.body[j] = walk(b);
            return m2;
        case NodeKind.FnDecl:
            FnDecl fn = cast(FnDecl) n;
            foreach (j, b; fn.body) fn.body[j] = walk(b);
            return fn;
        case NodeKind.StructDecl:
            StructDecl st = cast(StructDecl) n;
            foreach (j, f; st.fields)
                if (f !is null) st.fields[j] = cast(VarDecl) walk(f);
            foreach (j, f; st.functions)
                if (f !is null) st.functions[j] = cast(FnDecl) walk(f);
            return st;
        default:
            return n;
        }
    }

    // Evaluate an expression to a constant Node (NumericLit / BoolLit).
    private Node eval(Node e, Node[string] vars, int depth)
    {
        if (e is null)
            return new NumericLit(true, 0, Position.init);

        if (depth > 1000)
        {
            err.error(e.pos, "comptime: recursion depth exceeded (1000).");
            return new NumericLit(true, 0, e.pos);
        }

        switch (e.kind)
        {
        case NodeKind.NumericLit:
        case NodeKind.BoolLit:
        case NodeKind.CharLit:
            return e;

        case NodeKind.IdentExpr:
            string name = (cast(IdentExpr) e).val;
            if (vars !is null && name in vars)
                return vars[name];
            err.error(e.pos, format("comptime: unknown identifier '%s'.", name));
            return new NumericLit(true, 0, e.pos);

        case NodeKind.GroupExpr:
            return eval((cast(GroupExpr) e).val, vars, depth);

        case NodeKind.BinaryExpr:
            return evalBinary(cast(BinaryExpr) e, vars, depth);

        case NodeKind.UnaryExpr:
            return evalUnary(cast(UnaryExpr) e, vars, depth);

        case NodeKind.TernaryExpr:
        {
            TernaryExpr t = cast(TernaryExpr) e;
            Node cond = eval(t.expr, vars, depth);
            return boolVal(cond) ? eval(t.left, vars, depth) : eval(t.right, vars, depth);
        }

        case NodeKind.CallExpr:
            return evalCall(cast(CallExpr) e, vars, depth);

        default:
            err.error(e.pos, "comptime: unsupported expression kind.");
            return new NumericLit(true, 0, e.pos);
        }
    }

    private Node evalBinary(BinaryExpr b, Node[string] vars, int depth)
    {
        Node l = eval(b.left, vars, depth);
        Node r = eval(b.right, vars, depth);
        long lv = numVal(l);
        long rv = numVal(r);

        switch (b.op)
        {
        case TokenKind.Plus:     return new NumericLit(true, lv + rv, b.pos);
        case TokenKind.Minus:    return new NumericLit(true, lv - rv, b.pos);
        case TokenKind.Star:     return new NumericLit(true, lv * rv, b.pos);
        case TokenKind.Slash:
            if (rv == 0) { err.error(b.pos, "comptime: division by zero."); return new NumericLit(true, 0, b.pos); }
            return new NumericLit(true, lv / rv, b.pos);
        case TokenKind.Modulo:
            if (rv == 0) { err.error(b.pos, "comptime: modulo by zero."); return new NumericLit(true, 0, b.pos); }
            return new NumericLit(true, lv % rv, b.pos);
        case TokenKind.LThan:    return new BoolLit(lv < rv, b.pos);
        case TokenKind.GThan:    return new BoolLit(lv > rv, b.pos);
        case TokenKind.LEquals:  return new BoolLit(lv <= rv, b.pos);
        case TokenKind.GEquals:  return new BoolLit(lv >= rv, b.pos);
        case TokenKind.EEquals:
        case TokenKind.EEEquals: return new BoolLit(lv == rv, b.pos);
        case TokenKind.NEquals:  return new BoolLit(lv != rv, b.pos);
        case TokenKind.And:      return new BoolLit(boolVal(l) && boolVal(r), b.pos);
        case TokenKind.Or:       return new BoolLit(boolVal(l) || boolVal(r), b.pos);
        case TokenKind.BITAnd:   return new NumericLit(true, lv & rv, b.pos);
        case TokenKind.BITOr:    return new NumericLit(true, lv | rv, b.pos);
        case TokenKind.BITXor:   return new NumericLit(true, lv ^ rv, b.pos);
        case TokenKind.BITLeft:  return new NumericLit(true, lv << rv, b.pos);
        case TokenKind.BITRight: return new NumericLit(true, lv >> rv, b.pos);
        default:
            err.error(b.pos, "comptime: unsupported binary operator.");
            return new NumericLit(true, 0, b.pos);
        }
    }

    private Node evalUnary(UnaryExpr u, Node[string] vars, int depth)
    {
        Node v = eval(u.val, vars, depth);
        long x = numVal(v);
        switch (u.op)
        {
        case TokenKind.Minus:  return new NumericLit(true, -x, u.pos);
        case TokenKind.Plus:   return new NumericLit(true, +x, u.pos);
        case TokenKind.Bang:   return new BoolLit(!boolVal(v), u.pos);
        case TokenKind.BITNot: return new NumericLit(true, ~x, u.pos);
        default:
            err.error(u.pos, "comptime: unsupported unary operator.");
            return new NumericLit(true, 0, u.pos);
        }
    }

    private Node evalCall(CallExpr c, Node[string] vars, int depth)
    {
        IdentExpr ie = cast(IdentExpr) c.callee;
        if (ie is null)
        {
            err.error(c.pos, "comptime: only direct function calls are supported.");
            return new NumericLit(true, 0, c.pos);
        }

        FnDecl* fp = ie.val in fns;
        if (fp is null)
        {
            err.error(c.pos, format("comptime: unknown function '%s'.", ie.val));
            return new NumericLit(true, 0, c.pos);
        }

        // Evaluate arguments in the caller's frame, then bind them to params.
        Node[] argv;
        foreach (a; c.args)
            argv ~= eval(a, vars, depth);

        FnDecl fn = *fp;
        Node[string] frame;
        for (size_t i = 0; i < fn.args.length; i++)
        {
            if (i < argv.length)
                frame[fn.args[i].name] = argv[i];
        }

        Node ret = execBlock(fn.body, frame, depth + 1);
        return ret !is null ? ret : new NumericLit(true, 0, c.pos);
    }

    // Execute a block; returns non-null when a `return` fired.
    private Node execBlock(Node[] body, Node[string] frame, int depth)
    {
        foreach (n; body)
        {
            Node r = execStmt(n, frame, depth);
            if (r !is null)
                return r;
        }
        return null;
    }

    private Node execStmt(Node n, Node[string] frame, int depth)
    {
        if (n is null) return null;
        if (depth > 1000)
        {
            err.error(n.pos, "comptime: recursion depth exceeded (1000).");
            return new NumericLit(true, 0, n.pos);
        }

        switch (n.kind)
        {
        case NodeKind.ReturnStmt:
        {
            ReturnStmt r = cast(ReturnStmt) n;
            return r.val is null ? new NumericLit(true, 0, n.pos) : eval(r.val, frame, depth);
        }
        case NodeKind.IfStmt:
        {
            IfStmt i = cast(IfStmt) n;
            Node cond = eval(i.expr, frame, depth);
            if (boolVal(cond))
                return execBlock(i.body, frame, depth);
            if (i._else !is null)
                return execStmt(i._else, frame, depth);
            return null;
        }
        case NodeKind.VarDecl:
        {
            VarDecl v = cast(VarDecl) n;
            if (v.val !is null)
                frame[v.name] = eval(v.val, frame, depth);
            return null;
        }
        case NodeKind.AssignStmt:
        {
            AssignStmt a = cast(AssignStmt) n;
            IdentExpr ie = cast(IdentExpr) a.left;
            if (ie !is null)
                frame[ie.val] = eval(a.right, frame, depth);
            else
                err.error(a.pos, "comptime: only simple assignments are supported.");
            return null;
        }
        case NodeKind.Multi:
        {
            Multi m = cast(Multi) n;
            return execBlock(m.body, frame, depth);
        }
        default:
            err.error(n.pos, "comptime: unsupported statement.");
            return null;
        }
    }

    private long numVal(Node n)
    {
        if (n is null) return 0;
        if (auto nl = cast(NumericLit) n) return nl.isLong ? nl.l : cast(long) nl.u;
        if (auto bl = cast(BoolLit) n) return bl.val ? 1 : 0;
        if (auto cl = cast(CharLit) n) return cast(long) cl.val;
        return 0;
    }

    private bool boolVal(Node n)
    {
        return numVal(n) != 0;
    }
}