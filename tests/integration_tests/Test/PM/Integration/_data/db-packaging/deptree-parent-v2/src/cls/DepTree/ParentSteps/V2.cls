Class DepTree.ParentSteps.V2 Extends %IPM.General.Update.VersionBase
{

ClassMethod GetOrderedMethods() As %Library.DynamicArray
{
    return ["Step002"]
}

ClassMethod GetOrderedMethodsPrimaryOnly() As %Library.DynamicArray
{
    return []
}

/// Non-idempotent: increments a counter global so tests can detect if this ran.
ClassMethod Step002()
{
    set ^DBPkgDepTreeParentSteps("step002") = $get(^DBPkgDepTreeParentSteps("step002"), 0) + 1
}

}
