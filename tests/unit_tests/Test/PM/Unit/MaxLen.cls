Class Test.PM.Unit.MaxLen Extends %UnitTest.TestCase
{

/// Every stored string or binary property in a persistent or serial <code>%IPM</code> class must
/// choose its <code>MAXLEN</code>, on the property or through its datatype. The default of 50 from
/// <class>%Library.String</class> and <class>%Library.Binary</class> rejects longer values on save.
Method TestStoredStringsSetMaxLen()
{
    set sql = "SELECT DISTINCT p.Origin, p.Name, p.Type FROM %Dictionary.CompiledProperty p "
        _ "JOIN %Dictionary.CompiledClass c ON c.ID = p.parent "
        _ "WHERE c.Name %STARTSWITH '%IPM.' AND c.ClassType IN ('persistent', 'serial') "
        // Skip collection child tables. They are generated stubs whose properties cannot be opened.
        _ "AND c.GeneratedBy IS NULL "
        _ "AND p.Transient = 0 AND p.Calculated = 0 AND p.SqlComputed = 0 AND p.MultiDimensional = 0 "
        _ "ORDER BY p.Origin, p.Name"
    set rs = ##class(%SQL.Statement).%ExecDirect(, sql)
    $$$ThrowSQLIfError(rs.%SQLCODE, rs.%Message)
    set missing = ""
    set checked = 0
    while rs.%Next(.sc) {
        $$$ThrowOnError(sc)
        set checked = checked + 1
        set typeMaxLen = ##class(%Dictionary.CompiledParameter).%OpenId(rs.%Get("Type") _ "||MAXLEN")
        if '$isobject(typeMaxLen) || '$listfind($listbuild("%Library.String", "%Library.Binary"), typeMaxLen.Origin) {
            continue
        }
        // Compiled parameters include the type's defaults, so read what the property itself declares.
        set id = rs.%Get("Origin") _ "||" _ rs.%Get("Name")
        set property = ##class(%Dictionary.PropertyDefinition).%OpenId(id, , .sc)
        $$$ThrowOnError(sc)
        if property.Parameters.IsDefined("MAXLEN") || property.Parameters.IsDefined("VALUELIST") {
            continue
        }
        set missing = missing _ $listbuild(rs.%Get("Origin") _ ":" _ rs.%Get("Name"))
    }
    $$$ThrowOnError(sc)
    do $$$AssertTrue(checked > 0, "Found properties to check")
    do $$$AssertEquals($listtostring(missing, ", "), "")
}

}
