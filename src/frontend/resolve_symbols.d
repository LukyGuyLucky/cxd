module frontend.resolve_symbols;

import frontend;

import std.format;
import std.stdio;

class ResolveSymbols
{
    static Node[] resolve(Diagnostics err, ImportResolverContext* context, Node[] body, string base = "")
    {
        Node[] newBody;
        foreach (Node node; body)
        {
            string name; 
            if (node.kind == NodeKind.FnDecl)
            {
                FnDecl fn = cast(FnDecl)node;
                name = fn.name;
                if (!(fn.flags & NodeFlags.Overload))
                    name = base == "" ? name : format("%s_%s", base, name);
                // writeln("Sym: ", name);
            }
			else if (node.kind == NodeKind.StructDecl)
            {
                StructDecl s = cast(StructDecl)node;
                if (s.genericT.length == 0)
                {
                    name = s.name;
                    // writeln("Name: ", name);

                    // An empty struct exists only as a namespace for
                    // static methods. Non-static methods need a `self`
                    // pointer, and C has no zero-size type to point
                    // at. Reject here, before codegen can emit a
                    // `Utils*` parameter for a type that does not
                    // exist in C.
					if (s.fields.length == 0 && s.unions.length == 0)
                    {
                        foreach (FnDecl fn; s.functions)
                        {
                            if (!(fn.flags & NodeFlags.Static))
                            {
                                err.error(node.pos,
                                    format("Empty struct '%s' cannot have instance methods: "
                                        ~ "C has no zero-size type to instantiate. "
                                        ~ "Mark the methods static, or add a field.",
                                        s.name));
                                goto skipStruct;
                            }
                        }
                    }

                    resolve(err, context, cast(Node[]) s.functions, name);
                }
                skipStruct: ;
            }
            else if (node.kind == NodeKind.EnumDecl)
                name = (cast(EnumDecl)node).name;
            else if (node.kind == NodeKind.UnionDecl)
                name = (cast(UnionDecl)node).name;
            else if (node.kind == NodeKind.AliasDecl)
                name = (cast(AliasDecl)node).name;
            if (name != "")
                if (Node* p = name in context.symbols)
                {
                    if (p.pos.filename == node.pos.filename)
                    {
                        err.warning(node.pos,
                            format("The symbol '%s' was declared twice in the same file, first declaration: %s",
                                name, p.toString()));
                        continue;
                    }
                }
            newBody ~= node;
            context.symbols[name] = node;
        }
        return newBody;
    }
}
