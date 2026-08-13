Class DepTree.StableSteps.V2 Extends %IPM.General.Update.VersionBase
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
    set ^DBPkgDepTreeSteps("step002") = $get(^DBPkgDepTreeSteps("step002"), 0) + 1
}

}
