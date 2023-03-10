Class %IPM.JSON.Adaptor Extends %JSON.Adaptor [ System = 3 ]
{

/// %JSONGenerate is an internal method that controls the generation of the other methods in %JSON.Adaptor.
/// If %JSONGenerate is overridden, then JSON meta data and the other generator methods
/// of %JSON.Adaptor will not be created.<p>
ClassMethod %JSONGenerate() [ CodeMode = generator, GenerateAfter = %JSONX, Internal, ServerOnly = 1 ]
{
  Quit ##class(Generator).%JSONGenerate(.%mode,.%class,.%property,.%method,.%parameter,.%codemode,.%code,.%classmodify,.%context)
}

/// %JSONImportInternal is internal method used by %JSONImport
Method %JSONImportInternal() As %Status [ CodeMode = generator, GenerateAfter = %JSONGenerate, Internal, ServerOnly = 1 ]
{
  Quit ##class(Generator).JSONImportInternal(.%mode,.%class,.%property,.%method,.%parameter,.%codemode,.%code,.%classmodify,.%context)
}

/// %JSONExportInternal is internal method used by %JSONExport
Method %JSONExportInternal() As %Status [ CodeMode = generator, GenerateAfter = %JSONGenerate, Internal, ServerOnly = 1 ]
{
  Quit ##class(Generator).JSONExportInternal(.%mode,.%class,.%property,.%method,.%parameter,.%codemode,.%code,.%classmodify,.%context)
}

/// %JSONExportToStringInternal is internal method used by %JSONExport
Method %JSONExportToStringInternal() As %Status [ CodeMode = generator, GenerateAfter = %JSONGenerate, Internal, ServerOnly = 1 ]
{
  Quit ##class(Generator).JSONExportToStringInternal(.%mode,.%class,.%property,.%method,.%parameter,.%codemode,.%code,.%classmodify,.%context)
}

}
