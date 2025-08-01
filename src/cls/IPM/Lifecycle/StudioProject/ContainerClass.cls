/// Used to wrap Studio document types not supported in Studio project deployments, putting the XML export in a class's XDATA block for later import. For example:
/// <example>
/// // Pack up Foo.ZPM in class Foo.ModuleWrappedInAClass:
/// Set tItems("Foo.ZPM") = ""
/// Set tSC = ##class(%IPM.Lifecycle.StudioProject.ContainerClass).Create("Foo.ModuleWrappedInAClass",.tItems)
/// // ... on another environment, after Foo.ModuleWrappedInAClass is loaded, retrieve the module manifest document from it:
/// Set tSC = ##class(Foo.ModuleWrappedInAClass).Unpack()
/// </example>
Class %IPM.Lifecycle.StudioProject.ContainerClass
{

/// Contains a Studio document export (from $System.OBJ.ExportStream)
XData Export
{
}

ClassMethod Unpack() As %Status
{
    set tSC = $$$OK
    try {
        set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen($classname(),"Export",,.tSC)
        $$$ThrowOnError(tSC)
        $$$ThrowOnError($system.OBJ.LoadStream(tXData.Data,,,.tLoaded))
        $$$ThrowOnError($system.OBJ.Delete($classname()))
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

ClassMethod Create(
	pTargetClassName As %Dictionary.Classname,
	ByRef pItems,
	pVerbose As %Boolean = 0) As %Status
{
    set tSC = $$$OK
    try {
        if ##class(%Dictionary.ClassDefinition).%ExistsId(pTargetClassName) {
            $$$ThrowOnError(##class(%Dictionary.ClassDefinition).%DeleteId(pTargetClassName))
        }
        set tClassDefinition = ##class(%Dictionary.ClassDefinition).%New()
        set tClassDefinition.Name = pTargetClassName
        set tClassDefinition.ProcedureBlock = 1

        set tMethodDefinition = ##class(%Dictionary.MethodDefinition).IDKEYOpen($classname(),"Unpack",,.tSC)
        $$$ThrowOnError(tSC)
        set tClone = tMethodDefinition.%ConstructClone()
        do tClassDefinition.Methods.Insert(tClone)

        set tXDataDefinition = ##class(%Dictionary.XDataDefinition).%New()
        set tXDataDefinition.Name = "Export"
        $$$ThrowOnError($system.OBJ.ExportToStream(.pItems,tXDataDefinition.Data,$select(pVerbose:"d",1:"-d")))
        do tClassDefinition.XDatas.Insert(tXDataDefinition)

        $$$ThrowOnError(tClassDefinition.%Save())
        $$$ThrowOnError($system.OBJ.Compile(pTargetClassName,"c-k-d"))
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

}
