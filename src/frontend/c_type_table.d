module frontend.c_type_table;

import std.file : thisExePath, dirEntries, SpanMode, exists, readText;
import std.path : dirName, buildPath;
import std.string : strip, splitLines, indexOf;
import std.stdio : stderr;

enum FieldKind { Unknown, Fn, Data }

private struct TypeEntry
{
    FieldKind[string] fields;
}

private TypeEntry[string] table;
private bool loaded = false;

// 从 cx.exe 同目录下的 cxt/ 读所有 *.cxt。失败静默——表空时行为跟不加表一样。
void load_c_type_table()
{
    if (loaded) return;
    loaded = true;

    string exeDir = dirName(thisExePath());
    string cxtDir = buildPath(exeDir, "cxt");
    if (!exists(cxtDir)) return;

    foreach (entry; dirEntries(cxtDir, "*.cxt", SpanMode.shallow))
        load_one_file(entry.name);
}

private void load_one_file(string path)
{
    string content;
    try {
        content = readText(path);
    } catch (Exception e) {
        stderr.writeln("cxt: cannot read ", path, ": ", e.msg);
        return;
    }

    string currentType;
    foreach (line; content.splitLines())
    {
        string s = line.strip;
        if (s.length == 0 || s[0] == '#') continue;

        if (s[0] == '[')
        {
            auto end = s.indexOf(']');
            if (end < 0) continue;
            currentType = s[1 .. end].strip;
            if (!(currentType in table))
                table[currentType] = TypeEntry();
            continue;
        }

        auto eq = s.indexOf('=');
        if (eq < 0) continue;
        if (currentType.length == 0) continue;

        string field = s[0 .. eq].strip;
        string val = s[eq + 1 .. $].strip;
        if (field.length == 0) continue;

        FieldKind kind;
        if (val == "fn") kind = FieldKind.Fn;
        else if (val == "data") kind = FieldKind.Data;
        else continue;

        table[currentType].fields[field] = kind;
    }
}

// 三态：Unknown / Fn / Data。表里没有 → Unknown。
FieldKind lookup_c_field(string typeName, string fieldName)
{
    if (!loaded) load_c_type_table();

    if (auto t = typeName in table)
        if (auto k = fieldName in t.fields)
            return *k;
    return FieldKind.Unknown;
}