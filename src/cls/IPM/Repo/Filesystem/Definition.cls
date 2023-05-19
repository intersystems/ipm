Class %IPM.Repo.Filesystem.Definition Extends %IPM.Repo.Definition
{

Parameter DISPLAYNAME As STRING = "Filesystem";

Parameter MONIKER As STRING = "filesystem";

Parameter MONIKERALIAS As STRING = "f,fs";

Index RootIndex On Root [ Unique ];

Property Details As %String(MAXLEN = "") [ SqlComputeCode = {Set {*} = {Root}_$Case({Depth},0:"*",:$Replace($Justify(" ",{Depth}*2),"  ",$Select($$$isWINDOWS:"*\",1:"*/"))_"module.xml")}, SqlComputed, SqlComputeOnChange = (%%INSERT, %%UPDATE) ];

/// Root folder on the server filesystem
Property Root As %String(MAXLEN = 260) [ Required ];

/// How many levels of depth to search for module.xml files; 0 indicates unlimited.
Property Depth As %Integer [ InitialExpression = 0, Required ];

/// Prompt to use for Root in interactive configuration of this repository type
Parameter RootPromptString = {$$$Text("Root File Path:","ZPM")};

XData Commands
{
<commands>
<command name="repo">
<group name="Filesystem repository">

<modifier name="filesystem" aliases="f,fs" description="Create/update a filesystem repository" />
<modifier name="depth" aliases="d" value="true" description="For filesystem repositories, specifies the depth (number of folders underneath the root) to search for files named module.xml" />
<modifier name="path" aliases="p" value="true" description="For filesystem repositories, specifies the path to the root directory" />

<example description="Create a repository pointing to the filesystem with name LocalFiles, accepting snapshots, looking for files named module.xml up to 2 directories deep in C:\MyWorkspace\RootModuleDir\">
repo -name LocalFiles -snapshots 1 -fs -depth 2 -path C:\MyWorkspace\RootModuleDir\
</example>

</group>
</command>
</commands>
}

Method RootSet(%val) As %Status
{
	If (%val '= "") {
		Set %val = ##class(%File).NormalizeDirectory(%val)
	}
	Set i%Root = %val
	Quit $$$OK
}

/// Returns a client to interact with this server.
Method GetPackageService() As %IPM.Repo.IPackageService
{
	Set tService = ##class(%IPM.Repo.Filesystem.PackageService).%New(..Root)
	If '$$$IsISCWorker && tService.IsAvailable() {
		$$$ThrowOnError(..BuildCache())
	}
	Quit tService
}

/// Handles modifiers/data attributes provided from the package manager shell.
ClassMethod OnConfigure(pInstance As %IPM.Repo.Definition, pInteractive As %Boolean = 1, ByRef pModifiers, ByRef pData) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tPath = $Get(pModifiers("path"),pInstance.Root)
		If (pInteractive && (tPath = "")) {
			Set tPrompt = ..#RootPromptString
			Set tResponse = ##class(%Library.Prompt).GetString(tPrompt,.tPath)
			If (tResponse '= $$$SuccessResponse) {
				$$$ThrowStatus($$$ERROR($$$GeneralError,"Operation cancelled."))
			}
			
			If ##class(%IPM.Repo.Filesystem.Definition).RootIndexExists(tPath) {
				$$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Root '%1' is already configured for another repository.",tPath)))
			}
		}
		Set pInstance.Root = tPath
		
		If $Data(pModifiers("depth"),tDepth) {
			Set pInstance.Depth = tDepth
		}
		
		// This also saves it.
		$$$ThrowOnError(pInstance.BuildCache(1,1,1))
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Returns a client to publish modules/applications to this server.
Method GetPublishService() As %IPM.Repo.IPublishService
{
	// TODO: Implement? (Does it make sense to allow publishing to the local filesystem? What does that even mean?)
	Quit $$$NULLOREF
}

Method GetSortOrder() As %Integer [ Private ]
{
	Quit 2
}

/// Clears the cache if the root is changed.
Trigger RootChanged [ Event = UPDATE, Foreach = row/object ]
{
	New tOldRoot
	If ({Root*C}) {
		Set tOldRoot = {Root*O}
		&sql(delete from %IPM_Repo_Filesystem.Cache where Root = :tOldRoot)
		If (SQLCODE < 0) {
			Set %ok = 0
		}
	}
}

Method BuildCache(pPurge As %Boolean = {'$$$IsISCWorker}, pVerbose As %Integer = 0, pAutoDetectDepth As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Set tInitTLevel = $TLevel
	Try {
		Set tLogManager = ##class(%IPM.General.LogManager).%Get(.tSC)
		$$$ThrowOnError(tSC)
		
		// Instantiate at this level for the performance benefit
		Set tXSLTProvider = ##class(%IPM.Repo.XSLTProvider).%Get(.tSC)
		$$$ThrowOnError(tSC)
		
		TSTART
		If (pPurge) && (..%Id() '= "") {
			Set tLockManager = ##class(%IPM.Utils.LockManager).%New()
			$$$ThrowOnError(tLockManager.LockClassId($classname(),..%Id()))
			#dim tResult As %SQL.StatementResult
			Set tResult = ##class(%SQL.Statement).%ExecDirect(,"delete from %IPM_Repo_Filesystem.Cache where Root = ?",..Root)
			If (tResult.%SQLCODE < 0) {
				Set tSC = $$$ERROR($$$SQLCode,tResult.%SQLCODE,tResult.%Message)
				Quit
			}
		}
		
		// Force save so that root foreign key for items will exist.
		Set tSC = ..%Save()
		If $$$ISERR(tSC) {
			Quit
		}
		
		// Scan root directory recursively, up to ..Depth levels down, for module.xml files.
		Set tSC = ..ScanDirectory(..Root,.tFilenameList,,..Depth,$Select(pVerbose>1:1,1:0),.tMaxDepth)
		If $$$ISERR(tSC) {
			Quit
		}
		
		If (pAutoDetectDepth) && (tMaxDepth > 0) {
			Set ..Depth = tMaxDepth
			Set tSC = ..%Save()
			If $$$ISERR(tSC) {
				Quit
			}
		}
		
		// Ensure that we're looking at valid MODULE documents (as opposed to classes named Module, which the package manager has!)
		Set tAggSC = $$$OK
		Set tKey = ""
		For {
			Set tKey = $Order(tFilenameList(tKey),1,tFile)
			Quit:(tKey="")
			
			Set tSubDirectory = tFilenameList(tKey,"sub")
			Set tAggSC = $$$ADDSC(tAggSC,..AddCacheItem(tFile,tSubDirectory,.tName,.tVersionString))
			Write:pVerbose !,tName," ",tVersionString," @ ",##class(%File).NormalizeDirectory(..Root_tSubDirectory)
		}
		$$$ThrowOnError(tAggSC)
		TCOMMIT
	} Catch e {
		Set tSC = e.AsStatus()
	}
	While ($TLevel > tInitTLevel) { TROLLBACK 1 }
	Quit tSC
}

Method AddCacheItem(pModuleFileName As %String, pSubDirectory As %String, Output pName As %String, Output pVersionString As %String) As %Status
{
	Set tSC = $$$OK
	Set pName = ""
	Set pVersionString = ""
	Try {
		// Get list of what's in module.xml
		Set tSC = $System.OBJ.Load(pModuleFileName,"-d",,.tLoadedList,1)
		If $$$ISERR(tSC) {
			// Wasn't a valid file. We'll just continue.
			Set tSC = $$$OK
			Quit
		}
		
		If ($Length(tLoadedList,",") > 1) {
			// Contained multiple documents - tricky! We'll just continue.
			Quit
		}
		
		Set tExt = $ZConvert($Piece($Get(tLoadedList),".",*),"U")
		If (tExt '= "ZPM") {
			Quit
		}
		
		Kill tStream,tName,tVersionString
		Set tParseSC = ..GetModuleStreamFromFile(pModuleFileName,.tStream,.pName,.pVersionString)
		If $$$ISERR(tParseSC) {
			// Log as a warning, but keep going.
			Do ##class(%IPM.General.LogManager).Warning("Failed to parse module manifest in "_pModuleFileName_": "_$System.Status.GetErrorText(tParseSC),1)
			Quit
		}
	
		// Create cache item.
		If ##class(%IPM.Repo.Filesystem.Cache).CacheItemIndexExists(..Root,pSubDirectory) {
			Set tCacheItem = ##class(%IPM.Repo.Filesystem.Cache).CacheItemIndexOpen(..Root,pSubDirectory,,.tSC)
			$$$ThrowOnError(tSC)
		} Else {
			Set tCacheItem = ##class(%IPM.Repo.Filesystem.Cache).%New()
			Set tCacheItem.Root = ..Root
			Set tCacheItem.SubDirectory = pSubDirectory
		}
		Set tCacheItem.Name = pName
		Set tCacheItem.VersionString = pVersionString
		Do tCacheItem.Manifest.CopyFrom(tStream)
		Set tCacheItem.LastModified = $zdt($zts,3)
		Set tSaveSC = tCacheItem.%Save()
		If $$$ISERR(tSaveSC) {
			Set tSC = tCacheItem.HandleSaveError(tSaveSC)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method GetModuleStreamFromFile(pFilename As %String, Output pStream As %Stream.GlobalCharacter, Output pName As %String, Output pVersion As %String) As %Status
{
	Set tSC = $$$OK
	Set pName = ""
	Set pVersion = ""
	Try {
		// The source stream should contain a Studio document export of a module manifest.
		Set tSourceStream = ##class(%Stream.FileCharacter).%New()
		Set tSC = tSourceStream.LinkToFile(pFilename)
		$$$ThrowOnError(tSC)
		
		Set pStream = ##class(%Stream.GlobalCharacter).%New()
		Set tMetaStream = ##class(%Stream.GlobalCharacter).%New()
		
		// Extract <Module> section of document
		Set tCompiledTransform = ##class(%IPM.Repo.XSLTProvider).GetCompiledTransformForXData($classname(),"ModuleDocumentTransform")
		Set tSC = ##class(%XML.XSLT.Transformer).TransformStreamWithCompiledXSL(tSourceStream,tCompiledTransform,.pStream)
		$$$ThrowOnError(tSC)
		
		// Extract Name and Version
		Do tSourceStream.Rewind()
		Set tCompiledTransform = ##class(%IPM.Repo.XSLTProvider).GetCompiledTransformForXData($classname(),"MetadataExtractionTransform")
		Set tSC = ##class(%XML.XSLT.Transformer).TransformStreamWithCompiledXSL(tSourceStream,tCompiledTransform,.tMetaStream)
		$$$ThrowOnError(tSC)
		
		Set tMetaStream.LineTerminator = $Select($$$isWINDOWS:$c(13,10),$$$isUNIX:$c(10))
		Set pName = $ZConvert(tMetaStream.ReadLine(), "L")
		Set pVersion = tMetaStream.ReadLine()
	} Catch e {
		Set tOuterSC = $$$ERROR($$$GeneralError,$$$FormatText("Error loading module from file '%1'",pFilename))
		Set tSC = $System.Status.EmbedStatus(tOuterSC,e.AsStatus())
	}
	Quit tSC
}

/// Extracts entire <Module> section from a Studio document export
XData ModuleDocumentTransform
{
<xsl:stylesheet version="1.0"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
 <xsl:output indent="yes"/>
 <xsl:template match="/Export/Document/Module">
 <Module>
 <xsl:copy-of select="node()"/>
 </Module>
 </xsl:template>
</xsl:stylesheet>
}

/// Extracts Name and Version from a Studio document export and prints them one per line.
XData MetadataExtractionTransform
{
<xsl:stylesheet version="1.0"
 xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
 <xsl:output method="text"/>
 <xsl:strip-space elements="*"/>
 <xsl:template match="/Export/Document/Module">
  <xsl:value-of select="Name" />
  <!-- this prints a newline. -->
  <xsl:text>&#10;</xsl:text>
  <xsl:value-of select="Version" />
 </xsl:template>
</xsl:stylesheet>
}

ClassMethod ScanDirectory(pRoot As %String, ByRef pFilenameList, pSub As %String = "", pDepth As %Integer = "", pVerbose As %Boolean = 0, Output pMaxDepth As %Integer = 0) As %Status [ Internal ]
{
	Set tSC = $$$OK
	Try {
		Set pRoot = ##class(%File).NormalizeDirectory(pRoot)
		Set tDirArray($i(tDirArray)) = ""
		
		Set i = 0
		Do {
			Set i = i + 1
			If (pDepth > 0) && ($Length(tDirArray(i),"/") > pDepth) {
				Continue
			}
			
			Set tStmt = ##class(%SQL.Statement).%New()
			Set tSC = tStmt.%PrepareClassQuery("%Library.File","FileSet")
			If $$$ISERR(tSC) {
				Quit
			}
			
			Set tFullDir = ##class(%File).NormalizeDirectory(pRoot_tDirArray(i))
			Set tRes = tStmt.%Execute(tFullDir,"module.xml",,1)
			While tRes.%Next() {
				If (tRes.%Get("Type") = "D") {
					Write:pVerbose !,"Scanning directory: ",tRes.%Get("ItemName")
					Set tDirArray($i(tDirArray)) = tDirArray(i)_$Case(tDirArray(i),"":"",:"/")_tRes.%Get("ItemName")
				} Else {
					Write:pVerbose !,"Found file: ",tRes.%Get("Name")
					Set pFilenameList($i(pFilenameList)) = tRes.%Get("Name")
					Set pFilenameList(pFilenameList,"sub") = tDirArray(i)
					If (pDepth > pMaxDepth) {
						Set pMaxDepth = $Length(tDirArray(i),"/")
					}
				}
			}
		} While (i < tDirArray)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Storage Default
{
<Data name="FilesystemRepoDefinitionDefaultData">
<Subscript>"FilesystemRepoDefinition"</Subscript>
<Value name="1">
<Value>Root</Value>
</Value>
<Value name="2">
<Value>Depth</Value>
</Value>
</Data>
<DefaultData>FilesystemRepoDefinitionDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
