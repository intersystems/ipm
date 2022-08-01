Class %ZPM.PackageManager.Server.Utils
{

ClassMethod VersionSatisfiesExpression(pVersion As %String, pExpression As %String) As %Boolean [ SqlProc ]
{
	#dim tExpression As %ZPM.PackageManager.Core.SemanticVersionExpression
	#dim tVersion As %ZPM.PackageManager.Core.SemanticVersion
	
	Set tVersion = ##class(%ZPM.PackageManager.Core.SemanticVersion).FromString(pVersion)
	$$$ThrowOnError(##class(%ZPM.PackageManager.Core.SemanticVersionExpression).FromString(pExpression,.tExpression))
	Quit tVersion.Satisfies(tExpression)
}

}
