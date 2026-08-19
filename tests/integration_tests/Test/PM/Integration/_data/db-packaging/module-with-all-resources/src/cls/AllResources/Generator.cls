Class AllResources.Generator
{

/// Generates the AllResources.Generated class using %Dictionary API and compiles it.
/// Called via <Invoke> After Compile so the generator itself is already compiled.
ClassMethod Generate() As %Status
{
    set sc = $$$OK
    try {
        // Remove existing definition if present (idempotent)
        if ##class(%Dictionary.ClassDefinition).%ExistsId("AllResources.Generated") {
            $$$ThrowOnError(##class(%Dictionary.ClassDefinition).%DeleteId("AllResources.Generated"))
        }

        set cls = ##class(%Dictionary.ClassDefinition).%New()
        set cls.Name = "AllResources.Generated"

        set meth = ##class(%Dictionary.MethodDefinition).%New()
        set meth.Name = "GetGeneratedValue"
        set meth.ClassMethod = 1
        set meth.ReturnType = "%String"
        set impl = ##class(%Stream.TmpCharacter).%New()
        do impl.Write("    return ""Generated resource value""")
        set meth.Implementation = impl
        do cls.Methods.Insert(meth)

        $$$ThrowOnError(cls.%Save())
        $$$ThrowOnError($system.OBJ.Compile("AllResources.Generated", "ck-d"))
    } catch ex {
        set sc = ex.AsStatus()
    }
    return sc
}

}
