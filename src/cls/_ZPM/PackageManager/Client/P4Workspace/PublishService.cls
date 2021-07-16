Class %ZPM.PackageManager.Client.P4Workspace.PublishService Extends (%RegisteredObject, %ZPM.PackageManager.Core.IPublishService)
{

Property P4Workspace As %ZPM.PackageManager.Client.P4Workspace;

Property Available As %Boolean [ Private ];

Method %OnNew(pP4Workspace As %ZPM.PackageManager.Client.P4Workspace) As %Status [ Private, ServerOnly = 1 ]
{
	Set ..P4Workspace = pP4Workspace
	Quit $$$OK
}

Method PublishModule(pModule As %ZPM.PackageManager.Core.Module) As %Boolean
{
	Quit ..PublishToPerforce(pModule)
}

Method PublishApplication(pApplication As %ZPM.PackageManager.Core.Application) As %Boolean
{
	Quit ..PublishToPerforce(pApplication)
}

Method PublishToPerforce(pArtifact As %ZPM.PackageManager.Core.ModuleInfo) As %Boolean
{
	Try {
		// The version to branch to is determined as the version in the artifact.
		// This is populated in the %Publish method of the lifecycle class, and may be the current version
		// or the current version with +snapshot removed if the version is to be released.
		Set tBranchToVersion = pArtifact.Version
		
		// Get module root for named module
		Set tModule = ##class(%ZPM.PackageManager.Developer.Module).NameOpen(pArtifact.Name,,.tSC)
		$$$ThrowOnError(tSC)
		
		// Ensure module root is actually within the Perforce workspace, and get the depot path.
		Set tSC = ..P4Workspace.ClientSpec.GetDepotPathForLocal(tModule.Root,.tDepotRoot)
		$$$ThrowOnError(tSC)
		
		If $Extract(tDepotRoot,*) '= "/" {
			Set tDepotRoot = tDepotRoot_"/"
		}
		
		Set tBranchVersionString = tBranchToVersion.Major_"."_tBranchToVersion.Minor_"."_
			$Select(tBranchToVersion.IsSnapshot():"x",1:tBranchToVersion.Patch)
			
		Set tDescription = "Create "_tModule.Name_" "_tBranchVersionString_" from "_tDepotRoot
		
		// Create changelist to use
		Set tSC = ##class(%ZPM.PackageManager.Developer.Extension.SourceControl.ISC).CreateChangelist(tDescription,.tChangelistNumber)
		$$$ThrowOnError(tSC)
		
		// Branch from original depot root to new version branch
		Set tNewBranch = $Piece(tDepotRoot,"/",1,*-2)_"/"_tBranchVersionString_"/"
		Set tSC = ##class(%ZPM.PackageManager.Developer.Extension.SourceControl.ISC).RunCmd("p4 integrate -c "_tChangelistNumber_" "_tDepotRoot_"... "_tNewBranch_"...")
		$$$ThrowOnError(tSC)
		
		// Edit module.xml in new branch
		Set tNewModulePath = tNewBranch_"module.xml"
		Set tSC = ..P4Workspace.ClientSpec.GetLocalPathForDepot(tNewModulePath,.tNewModuleFile)
		$$$ThrowOnError(tSC)
		Set tSC = ##class(%ZPM.PackageManager.Developer.Extension.SourceControl.ISC).RunCmd("p4 edit -c "_tChangelistNumber_" "_tNewModulePath)
		$$$ThrowOnError(tSC)
		
		// Update module.xml in new branch to have the new version string.
		Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen($classname(),"UpdateManifestVersion",,.tSC)
		$$$ThrowOnError(tSC)
		Set tXSL = tXData.Data
		Set tXSLString = $Replace(tXSL.Read(),"{$Version}",tBranchToVersion.ToString())
		Do tXSL.Clear()
		Do tXSL.Write(tXSLString)
		
		// Extract comments
		Set tFileStream = ##class(%Stream.FileCharacter).%New()
		Set tSC = tFileStream.LinkToFile(tNewModuleFile)
		$$$ThrowOnError(tSC)
		Set tHandler = ##class(%ZPM.PackageManager.Developer.XML.CommentHandler).%New()
		Set tSC = ##Class(%XML.SAX.Parser).ParseStream(tFileStream,tHandler)
		$$$ThrowOnError(tSC)
		
		// Replace version
		Do tFileStream.Rewind()
		Set tSC = ##class(%XML.XSLT.Transformer).TransformStream(tFileStream,tXSL,.tExportStream)
		$$$ThrowOnError(tSC)
		
		// Reapply comments
		Set tSC = tHandler.Reapply(.tExportStream,0)
		$$$ThrowOnError(tSC)
		
		// Copy back to original location
		Set tSC = tFileStream.CopyFromAndSave(tExportStream)
		$$$ThrowOnError(tSC)
		
		// Check out module file in current branch under the publish operation's changelist
		Set tSC = ##class(%ZPM.PackageManager.Developer.Extension.SourceControl.ISC).RunCmd("p4 edit -c "_tChangelistNumber_" "_tDepotRoot_"module.xml")
		$$$ThrowOnError(tSC)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	$$$ThrowOnError(tSC)
	Quit 1
}

XData UpdateManifestVersion
{
<xsl:stylesheet version="1.0"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
 <xsl:output method="xml"/>
 <xsl:preserve-space elements="*" />
<xsl:template match="@*|node()">
<xsl:copy>
<xsl:apply-templates select="@*|node()"/>
</xsl:copy>
</xsl:template>
<xsl:template match="//Export/Document/Module/Version">
<Version>{$Version}</Version>
</xsl:template>
</xsl:stylesheet>
}

}
