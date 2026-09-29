Class DepRes.Generator
{

/// Generates DepRes.Generated. Invoked After Compile so this generator is already compiled.
/// Idempotent: deletes any existing definition first.
ClassMethod Generate() As %Status
{
    set sc = $$$OK
    try {
        if ##class(%Dictionary.ClassDefinition).%ExistsId("DepRes.Generated") {
            $$$ThrowOnError(##class(%Dictionary.ClassDefinition).%DeleteId("DepRes.Generated"))
        }

        set cls = ##class(%Dictionary.ClassDefinition).%New()
        set cls.Name = "DepRes.Generated"

        set meth = ##class(%Dictionary.MethodDefinition).%New()
        set meth.Name = "GetGeneratedValue"
        set meth.ClassMethod = 1
        set meth.ReturnType = "%String"
        set impl = ##class(%Stream.TmpCharacter).%New()
        do impl.Write("    return ""Dependency generated value""")
        set meth.Implementation = impl
        do cls.Methods.Insert(meth)

        $$$ThrowOnError(cls.%Save())
        $$$ThrowOnError($system.OBJ.Compile("DepRes.Generated", "ck-d"))
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

/// Marks that an <Invoke> in a dependency ran during a database install.
ClassMethod MarkInvoked() As %Status
{
    set ^DBPkgDepInvoked = $increment(^DBPkgDepInvoked)
    return $$$OK
}

}
