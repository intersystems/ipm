/// Resource processor for Test.PM.Unit.LifecycleDatabase that records being asked to stage.
Class Test.PM.Unit.StagingProbe Extends %IPM.ResourceProcessor.Abstract
{

/// Writes probe-staged into targetDir.
Method OnStageForDatabasePackage(
	targetDir As %String,
	ByRef params)
{
    set stream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(stream.LinkToFile(##class(%Library.File).NormalizeFilename("probe-staged", targetDir)))
    $$$ThrowOnError(stream.Write("staged"))
    $$$ThrowOnError(stream.%Save())
}

}
