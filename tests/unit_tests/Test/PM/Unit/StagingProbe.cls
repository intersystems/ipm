/// Resource processor for Test.PM.Unit.LifecycleDatabase that records being asked to stage.
Class Test.PM.Unit.StagingProbe Extends %IPM.ResourceProcessor.Abstract
{

/// Writes probe-staged into targetDir.
Method OnStageForDatabasePackage(
	targetDir As %String,
	ByRef params) As %Status
{
    set stream = ##class(%Stream.FileCharacter).%New()
    set sc = stream.LinkToFile(##class(%Library.File).NormalizeFilename("probe-staged", targetDir))
    set:$$$ISOK(sc) sc = stream.Write("staged")
    set:$$$ISOK(sc) sc = stream.%Save()
    quit sc
}

}
