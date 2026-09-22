Class DepTree.StableSteps.V1 Extends %IPM.General.Update.VersionBase
{

ClassMethod GetOrderedMethods() As %Library.DynamicArray
{
    return ["Step001"]
}

ClassMethod GetOrderedMethodsPrimaryOnly() As %Library.DynamicArray
{
    return []
}

/// Non-idempotent: increments a counter global so tests can detect if this ran.
ClassMethod Step001()
{
    set ^DBPkgDepTreeSteps("step001") = $get(^DBPkgDepTreeSteps("step001"), 0) + 1
}

}
