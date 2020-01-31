Class %ZPM.PackageManager.Client.FilesystemServerDefinition Extends %ZPM.PackageManager.Client.ServerDefinition
{

Parameter DISPLAYNAME As STRING = "Filesystem";

Parameter MONIKER As STRING = "file";

Index RootIndex On Root [ Unique ];

Property Details As %String(MAXLEN = "") [ SqlComputeCode = {Set {*} = {Root}_$Case({Depth},0:"*",:$Replace($Justify(" ",{Depth}*2),"  ",$Select($$$isWINDOWS:"*\",1:"*/"))_"module.xml")}, SqlComputed, SqlComputeOnChange = (%%INSERT, %%UPDATE) ];

/// Root folder on the server filesystem
Property Root As %String(MAXLEN = 260) [ Required ];

/// How many levels of depth to search for module.xml files; 0 indicates unlimited.
Property Depth As %Integer [ InitialExpression = 0, Required ];

/// Prompt to use for Root in interactive configuration of this repository type
Parameter RootPromptString = {$$$Text("Root File Path:","ZPM")};

Method RootSet(%val) As %Status
{
	If (%val '= "") {
		Set %val = ##class(%File).NormalizeDirectory(%val)
	}
	Set i%Root = %val
	Quit $$$OK
}

/// Returns a client to interact with this server.
Method GetPackageService() As %ZPM.PackageManager.Core.IPackageService
{
	Set tService = ##class(%ZPM.PackageManager.Client.Filesystem.PackageService).%New(..Root)
	If tService.IsAvailable() {
		$$$ThrowOnError(..BuildCache(1))
	}
	Quit tService
}

/// Handles modifiers/data attributes provided from the package manager shell.
ClassMethod OnConfigure(pInstance As %ZPM.PackageManager.Client.ServerDefinition, pInteractive As %Boolean = 1, ByRef pModifiers, ByRef pData) As %Status
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
			
			If ##class(%ZPM.PackageManager.Client.FilesystemServerDefinition).RootIndexExists(tPath) {
				$$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Root '%1' is already configured for another repository."),tPath))
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
Method GetPublishService() As %ZPM.PackageManager.Core.IPublishService
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
		&sql(delete from %ZPM_PackageManager_Client_Filesystem.Cache where Root = :tOldRoot)
		If (SQLCODE < 0) {
			Set %ok = 0
		}
	}
}

Method BuildCache(pPurge As %Boolean = 1, pVerbose As %Integer = 0, pAutoDetectDepth As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Set tInitTLevel = $TLevel
	Try {
		TSTART
		If (pPurge) {
			#dim tResult As %SQL.StatementResult
			Set tResult = ##class(%SQL.Statement).%ExecDirect(,"delete from %ZPM_PackageManager_Client_Filesystem.Cache where Root = ?",..Root)
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
		Set tKey = ""
		For {
			Set tKey = $Order(tFilenameList(tKey),1,tFile)
			Quit:(tKey="")
			
			// Get list of what's in module.xml
			Set tSC = $System.OBJ.Load(tFile,"-d",,.tLoadedList,1)
			If $$$ISERR(tSC) {
				// Wasn't a valid file. We'll just continue.
				Set tSC = $$$OK
				Continue
			}
			
			If ($Length(tLoadedList,",") > 1) {
				// Contained multiple documents - tricky! We'll just continue.
				Continue
			}
			
			Set tExt = $ZConvert($Piece($Get(tLoadedList),".",*),"U")
			If (tExt '= "ZPM") {
				Continue
			}
			
			Kill tStream,tName,tVersionString
			Set tSC = ..GetModuleStreamFromFile(tFile,.tStream,.tName,.tVersionString)
			If $$$ISERR(tSC) {
				Quit
			}
		
			// Create cache item.
			Set tSubDirectory = tFilenameList(tKey,"sub")
			If ##class(%ZPM.PackageManager.Client.Filesystem.Cache).CacheItemIndexExists(..Root,tSubDirectory) {
				Set tCacheItem = ##class(%ZPM.PackageManager.Client.Filesystem.Cache).CacheItemIndexOpen(..Root,tSubDirectory)
			} Else {
				Set tCacheItem = ##class(%ZPM.PackageManager.Client.Filesystem.Cache).%New()
				Set tCacheItem.Root = ..Root
				Set tCacheItem.SubDirectory = tSubDirectory
			}
			Set tCacheItem.Name = tName
			Set tCacheItem.VersionString = tVersionString
			Do tCacheItem.Manifest.CopyFrom(tStream)
			Set tCacheItem.LastModified = $zdt($zts,3)
			Set tSC = tCacheItem.%Save()
			If $$$ISERR(tSC) {
				Quit
			}
			
			Write:pVerbose !,tName," ",tVersionString," @ ",##class(%File).NormalizeDirectory(..Root_tSubDirectory)
		}
		TCOMMIT
	} Catch e {
		Set tSC = e.AsStatus()
	}
	While ($TLevel > tInitTLevel) { TROLLBACK 1 }
	Quit tSC
}

ClassMethod GetModuleStreamFromFile(pFilename As %String, Output pStream As %Stream.GlobalCharacter, Output pName As %String, Output pVersion As %String) As %Status
{
	Set tSC = $$$OK
	Set pName = ""
	Set pVersion = ""
	Try {
		// These documents will always look like:
		/*
			<?xml version="1.0" encoding="UTF-8"?>
			<Export generator="Cache" version="25">
			<Document name="%ZPM.ZPM"><Module>
			...
			</Module>
			</Document></Export>
		*/
		// We want the first line, and everything from <Module> to </Module>.
		// Rather than doing full XML parsing, it's fastest to just selectively copy lines from the file to the target stream.
		// Some information is also extracted from the XML using $Piece.
		
		Set tSourceStream = ##class(%Stream.FileCharacter).%New()
		Set tSC = tSourceStream.LinkToFile(pFilename)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set pStream = ##class(%Stream.GlobalCharacter).%New()
		Do pStream.WriteLine(tSourceStream.ReadLine($$$MaxStringLength)) //<?xml version="1.0" encoding="UTF-8"?>
		Do tSourceStream.ReadLine($$$MaxStringLength) //<Export generator="Cache" version="25">
		Set tFirstLine = tSourceStream.ReadLine($$$MaxStringLength) //<Document name="%ZPM.ZPM"><Module>
		Do pStream.WriteLine("<Module>")
		While 'tSourceStream.AtEnd {
			Set tLine = tSourceStream.ReadLine($$$MaxStringLength)
			If tLine = "</Document></Export>" {
				Quit
			}
			
			// This depends on the Name and Version tags coming early in the export. Our format enforces this.
			If (tLine [ "<Version>") && (pVersion = "") {
				Set pVersion = $Piece($Piece(tLine,"<Version>",2),"</Version>")
			}
			If (tLine [ "<Name>") && (pName = "") {
				Set pName = $Piece($Piece(tLine,"<Name>",2),"</Name>")
			}
			Do pStream.WriteLine(tLine)
		}
		
		Do pStream.Rewind()
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
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
<Data name="FilesystemServerDefinitionDefaultData">
<Subscript>"FilesystemServerDefinition"</Subscript>
<Value name="1">
<Value>Root</Value>
</Value>
<Value name="2">
<Value>Depth</Value>
</Value>
</Data>
<DefaultData>FilesystemServerDefinitionDefaultData</DefaultData>
<Type>%Storage.Persistent</Type>
}

}
