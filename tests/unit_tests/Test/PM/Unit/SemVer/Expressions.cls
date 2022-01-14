Class %ZPM.PackageManager.Server.Utils
{

ClassMethod VersionSatisfiesExpression(pVersion As %String, pExpression As %String) As %Boolean [ SqlProc ]
{
	#dim tExpression As %ZPM.General.SemanticVersionExpression
	#dim tVersion As %ZPM.General.SemanticVersion
	
	Set tVersion = ##class(%ZPM.General.SemanticVersion).FromString(pVersion)
	$$$ThrowOnError(##class(%ZPM.General.SemanticVersionExpression).FromString(pExpression,.tExpression))
	Quit tVersion.Satisfies(tExpression)
}

}
