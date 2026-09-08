Include %IPM.Common

/// Enforces the rule that IPM code producing output inside a namespace excursion suspends
/// device redirection first, since the redirect handler is a routine name the kernel
/// re-resolves in the current namespace on every write.
Class Test.PM.Unit.NamespaceExcursions Extends %UnitTest.TestCase
{

Parameter NEEDSREGISTRY As BOOLEAN = 0;

/// Scans saved method sources rather than generated code, so the macros are still visible as
/// written. A method edited on disk but not loaded into the namespace is scanned as it was
/// last compiled.
/// Catches only writes IPM issues itself; output a system API produces from inside an
/// excursion after being handed $io is invisible to a source scan.
Method TestExcursionsSuspendRedirection()
{
    set rs = ##class(%SQL.Statement).%ExecDirect(
        ,
        "SELECT parent, Name FROM %Dictionary.MethodDefinition "_
            "WHERE parent %STARTSWITH '%IPM.' ORDER BY parent, Name")
    do $$$AssertEquals(rs.%SQLCODE, 0, "Method definition query succeeded: "_rs.%Message)
    set scanned = 0
    while rs.%Next() {
        set class = rs.%Get("parent")
        set method = rs.%Get("Name")
        set def = ##class(%Dictionary.MethodDefinition).%OpenId(class_"||"_method)
        if '$isobject(def) {
            continue
        }
        set scanned = scanned + 1
        set source = ..MethodSource(def)
        if 'source.Suspicious {
            continue
        }
        do $$$AssertFailure(class_":"_method_" writes at source line "_source.WriteLine_" inside a namespace excursion without $$$SuspendRedirection")
    }
    do $$$AssertTrue(scanned > 100, "Scanned "_scanned_" IPM methods")
}

/// Suspending redirection and never restoring it leaves logging off for the rest of the
/// command, so the two macros have to appear in the same method. Scoped to the macros: the
/// raw $zutil form is also used to switch redirection off for good, as Stop() does.
Method TestSuspendIsPairedWithRestore()
{
    set rs = ##class(%SQL.Statement).%ExecDirect(
        ,
        "SELECT parent, Name FROM %Dictionary.MethodDefinition "_
            "WHERE parent %STARTSWITH '%IPM.' ORDER BY parent, Name")
    do $$$AssertEquals(rs.%SQLCODE, 0, "Method definition query succeeded: "_rs.%Message)
    while rs.%Next() {
        set class = rs.%Get("parent")
        set method = rs.%Get("Name")
        set def = ##class(%Dictionary.MethodDefinition).%OpenId(class_"||"_method)
        if '$isobject(def) {
            continue
        }
        set text = ..FlattenSource(def)
        if text '[ "$$$SuspendRedirection" {
            continue
        }
        do $$$AssertTrue(text [ "$$$RestoreRedirection", class_":"_method_" suspends redirection without restoring it")
    }
}

/// True when the line suspends redirection, by macro or by the raw call the macro expands to.
/// %IPM.Main.LanguageExtensions() has to spell it out, since its body is emitted into
/// %ZLANGC00.mac and compiled without IPM's include file.
ClassMethod IsSuspend(line As %String) As %Boolean [ Private ]
{
    return (line [ "$$$SuspendRedirection") || ($zconvert(line, "L") [ "$zutil(82,12,0)")
}

/// Returns an object with Suspicious set when a write follows a namespace switch, and
/// WriteLine holding the source line it was found on.
ClassMethod MethodSource(def As %Dictionary.MethodDefinition) As %DynamicObject [ Private ]
{
    set result = {"Suspicious": 0, "WriteLine": 0}
    set suspended = 0
    set switched = 0
    set lineNumber = 0
    do def.Implementation.Rewind()
    while 'def.Implementation.AtEnd {
        set line = ..StripComment(def.Implementation.ReadLine())
        set lineNumber = lineNumber + 1
        if ..IsSuspend(line) {
            set suspended = 1
        }
        // Remember the variables holding the namespace the method started in, so that
        // switching back to one of them counts as ending the excursion.
        if $match(line, ".*set +[^ ]+ *= *\$namespace *$") {
            set entryVars($zstrip($piece($piece(line, "=", 1), "set ", 2), "<>W")) = ""
        }
        if $match(line, ".*set +\$namespace *=.*") {
            set switched = '$data(entryVars($zstrip($piece(line, "=", 2), "<>W")))
        }
        if switched, 'suspended, ..HasWriteCommand(line) {
            set result.Suspicious = 1
            set result.WriteLine = lineNumber
            quit
        }
    }
    return result
}

ClassMethod FlattenSource(def As %Dictionary.MethodDefinition) As %String [ Private ]
{
    do def.Implementation.Rewind()
    set text = ""
    while 'def.Implementation.AtEnd {
        set text = text_..StripComment(def.Implementation.ReadLine())_$char(10)
    }
    return text
}

/// Drops a trailing comment so prose about writing is not read as code, and so a commented
/// out macro does not count as a real one. Handles `//`, `;` and `#;`, and ignores both
/// markers inside string literals, where a doubled "" toggles twice and nets out.
ClassMethod StripComment(line As %String) As %String [ Private ]
{
    set inString = 0
    for i = 1:1:$length(line) {
        set char = $extract(line, i)
        if char = """" {
            set inString = 'inString
            continue
        }
        if inString {
            continue
        }
        if (char = ";") || ((char = "/") && ($extract(line, i + 1) = "/")) {
            return $extract(line, 1, i - 1)
        }
    }
    return line
}

/// True when the line contains `write` as a command: at the start of the line or after a
/// delimiter, and not followed by more of an identifier (so `.WriteLine` and `Overwrite`
/// do not count).
ClassMethod HasWriteCommand(line As %String) As %Boolean [ Private ]
{
    set lower = $zconvert(line, "L")
    set delimiters = $listbuild(" ", $char(9), "{", "}", ";", ":")
    set pos = 1
    for {
        set after = $find(lower, "write", pos)
        if 'after {
            return 0
        }
        set pos = after
        if (after > 6) && '$listfind(delimiters, $extract(lower, after - 6)) {
            continue
        }
        if $extract(lower, after)?1(1A,1N,1"_") {
            continue
        }
        return 1
    }
}

}
