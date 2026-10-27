Class DepTree.ParentSteps.V1 Extends %IPM.General.Update.VersionBase
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
    set ^DBPkgDepTreeParentSteps("step001") = $get(^DBPkgDepTreeParentSteps("step001"), 0) + 1
}

}
