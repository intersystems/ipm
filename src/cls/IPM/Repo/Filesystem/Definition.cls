Class %IPM.Repo.Filesystem.Definition Extends %IPM.Repo.Definition
{

Parameter DISPLAYNAME As STRING = "Filesystem";

Parameter MONIKER As STRING = "filesystem";

Parameter MONIKERALIAS As STRING = "f,fs";

Index RootIndex On Root [ Unique ];

Property Details As %String(MAXLEN = "") [ SqlComputeCode = {set {*} = {Root}_$case({Depth},0:"*",:$replace($justify(" ",{Depth}*2),"  ",$select($$$isWINDOWS:"*\",1:"*/"))_"module.xml")}, SqlComputed, SqlComputeOnChange = (%%INSERT, %%UPDATE) ];

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
    if (%val '= "") {
        set %val = ##class(%File).NormalizeDirectory(%val)
    }
    set i%Root = %val
    quit $$$OK
}

/// Returns a client to interact with this server.
Method GetPackageService() As %IPM.Repo.IPackageService
{
    set tService = ##class(%IPM.Repo.Filesystem.PackageService).%New(..Root)
    if '$$$IsISCWorker && tService.IsAvailable() {
        $$$ThrowOnError(..BuildCache())
    }
    quit tService
}

/// Handles modifiers/data attributes provided from the package manager shell.
ClassMethod OnConfigure(
	pInstance As %IPM.Repo.Definition,
	pInteractive As %Boolean = 1,
	ByRef pModifiers,
	ByRef pData) As %Status
{
    set tSC = $$$OK
    try {
        set tPath = $get(pModifiers("path"),pInstance.Root)
        if (pInteractive && (tPath = "")) {
            set tPrompt = ..#RootPromptString
            set tResponse = ##class(%Library.Prompt).GetString(tPrompt,.tPath)
            if (tResponse '= $$$SuccessResponse) {
                $$$ThrowStatus($$$ERROR($$$GeneralError,"Operation cancelled."))
            }

            if ##class(%IPM.Repo.Filesystem.Definition).RootIndexExists(tPath) {
                $$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Root '%1' is already configured for another repository.",tPath)))
            }
        }
        set pInstance.Root = tPath

        if $data(pModifiers("depth"),tDepth) {
            set pInstance.Depth = tDepth
        }

        // This also saves it.
        $$$ThrowOnError(pInstance.BuildCache(1,1,1))
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Returns a client to publish modules/applications to this server.
Method GetPublishService() As %IPM.Repo.IPublishService
{
    // TODO: Implement? (Does it make sense to allow publishing to the local filesystem? What does that even mean?)
    quit $$$NULLOREF
}

Method GetSortOrder() As %Integer [ Private ]
{
    quit 2
}

/// Clears the cache if the root is changed.
Trigger RootChanged [ Event = UPDATE, Foreach = row/object ]
{
    new tOldRoot
    if ({Root*C}) {
        set tOldRoot = {Root*O}
        &sql(delete from %IPM_Repo_Filesystem.Cache where Root = :tOldRoot)
        if (SQLCODE < 0) {
            set %ok = 0
        }
    }
}

Method BuildCache(
	pPurge As %Boolean = {'$$$IsISCWorker},
	pVerbose As %Integer = 0,
	pAutoDetectDepth As %Boolean = 0) As %Status
{
    set tSC = $$$OK
    set tInitTLevel = $tlevel
    try {
        set tLogManager = ##class(%IPM.General.LogManager).%Get(.tSC)
        $$$ThrowOnError(tSC)

        // Instantiate at this level for the performance benefit
        set tXSLTProvider = ##class(%IPM.Repo.XSLTProvider).%Get(.tSC)
        $$$ThrowOnError(tSC)

        tstart
        if (pPurge) && (..%Id() '= "") {
            set tLockManager = ##class(%IPM.Utils.LockManager).%New()
            $$$ThrowOnError(tLockManager.LockClassId($classname(),..%Id()))
            #dim tResult As %SQL.StatementResult
            set tResult = ##class(%SQL.Statement).%ExecDirect(,"delete from %IPM_Repo_Filesystem.Cache where Root = ?",..Root)
            if (tResult.%SQLCODE < 0) {
                set tSC = $$$ERROR($$$SQLCode,tResult.%SQLCODE,tResult.%Message)
                quit
            }
        }

        // Force save so that root foreign key for items will exist.
        set tSC = ..%Save()
        if $$$ISERR(tSC) {
            quit
        }

        // Scan root directory recursively, up to ..Depth levels down, for module.xml files.
        set tSC = ..ScanDirectory(..Root,.tFilenameList,,..Depth,$select(pVerbose>1:1,1:0),.tMaxDepth)
        if $$$ISERR(tSC) {
            quit
        }

        if (pAutoDetectDepth) && (tMaxDepth > 0) {
            set ..Depth = tMaxDepth
            set tSC = ..%Save()
            if $$$ISERR(tSC) {
                quit
            }
        }

        // Ensure that we're looking at valid MODULE documents (as opposed to classes named Module, which the package manager has!)
        set tAggSC = $$$OK
        set tKey = ""
        for {
            set tKey = $order(tFilenameList(tKey),1,tFile)
            quit:(tKey="")

            set tSubDirectory = tFilenameList(tKey,"sub")
            set tAggSC = $$$ADDSC(tAggSC,..AddCacheItem(tFile,tSubDirectory,.tName,.tVersionString))
            write:pVerbose !,tName," ",tVersionString," @ ",##class(%File).NormalizeDirectory(..Root_tSubDirectory)
        }
        $$$ThrowOnError(tAggSC)
        tcommit
    } catch e {
        set tSC = e.AsStatus()
    }
    while ($tlevel > tInitTLevel) { trollback 1 }
    quit tSC
}

Method AddCacheItem(
	pModuleFileName As %String,
	pSubDirectory As %String,
	Output pName As %String,
	Output pVersionString As %String) As %Status
{
    set tSC = $$$OK
    set pName = ""
    set pVersionString = ""
    try {
        // Get list of what's in module.xml
        set tSC = $system.OBJ.Load(pModuleFileName,"-d",,.tLoadedList,1)
        if $$$ISERR(tSC) {
            // Wasn't a valid file. We'll just continue.
            set tSC = $$$OK
            quit
        }

        if ($length(tLoadedList,",") > 1) {
            // Contained multiple documents - tricky! We'll just continue.
            quit
        }

        set tExt = $zconvert($piece($get(tLoadedList),".",*),"U")
        if (tExt '= "ZPM") {
            quit
        }

        kill tStream,tName,tVersionString
        set tParseSC = ..GetModuleStreamFromFile(pModuleFileName,.tStream,.pName,.pVersionString)
        if $$$ISERR(tParseSC) {
            // Log as a warning, but keep going.
            do ##class(%IPM.General.LogManager).Warning("Failed to parse module manifest in "_pModuleFileName_": "_$system.Status.GetErrorText(tParseSC),1)
            quit
        }

        // Create cache item.
        if ##class(%IPM.Repo.Filesystem.Cache).CacheItemIndexExists(..Root,pSubDirectory) {
            set tCacheItem = ##class(%IPM.Repo.Filesystem.Cache).CacheItemIndexOpen(..Root,pSubDirectory,,.tSC)
            $$$ThrowOnError(tSC)
        } else {
            set tCacheItem = ##class(%IPM.Repo.Filesystem.Cache).%New()
            set tCacheItem.Root = ..Root
            set tCacheItem.SubDirectory = pSubDirectory
        }
        set tCacheItem.Name = pName
        set tCacheItem.VersionString = pVersionString
        do tCacheItem.Manifest.CopyFrom(tStream)
        set tCacheItem.LastModified = $zdatetime($ztimestamp,3)
        set tSaveSC = tCacheItem.%Save()
        if $$$ISERR(tSaveSC) {
            set tSC = tCacheItem.HandleSaveError(tSaveSC)
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method GetModuleStreamFromFile(
	pFilename As %String,
	Output pStream As %Stream.GlobalCharacter,
	Output pName As %String,
	Output pVersion As %String) As %Status
{
    set tSC = $$$OK
    set pName = ""
    set pVersion = ""
    try {
        // The source stream should contain a Studio document export of a module manifest.
        set tSourceStream = ##class(%Stream.FileCharacter).%New()
        set tSC = tSourceStream.LinkToFile(pFilename)
        $$$ThrowOnError(tSC)

        set pStream = ##class(%Stream.GlobalCharacter).%New()
        set tMetaStream = ##class(%Stream.GlobalCharacter).%New()

        // Extract <Module> section of document
        set tCompiledTransform = ##class(%IPM.Repo.XSLTProvider).GetCompiledTransformForXData($classname(),"ModuleDocumentTransform")
        set tSC = ##class(%XML.XSLT.Transformer).TransformStreamWithCompiledXSL(tSourceStream,tCompiledTransform,.pStream)
        $$$ThrowOnError(tSC)

        // Extract Name and Version
        do tSourceStream.Rewind()
        set tCompiledTransform = ##class(%IPM.Repo.XSLTProvider).GetCompiledTransformForXData($classname(),"MetadataExtractionTransform")
        set tSC = ##class(%XML.XSLT.Transformer).TransformStreamWithCompiledXSL(tSourceStream,tCompiledTransform,.tMetaStream)
        $$$ThrowOnError(tSC)

        set tMetaStream.LineTerminator = $select($$$isWINDOWS:$char(13,10),$$$isUNIX:$char(10))
        set pName = $zconvert(tMetaStream.ReadLine(), "L")
        set pVersion = tMetaStream.ReadLine()
    } catch e {
        set tOuterSC = $$$ERROR($$$GeneralError,$$$FormatText("Error loading module from file '%1'",pFilename))
        set tSC = $system.Status.EmbedStatus(tOuterSC,e.AsStatus())
    }
    quit tSC
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

ClassMethod ScanDirectory(
	pRoot As %String,
	ByRef pFilenameList,
	pSub As %String = "",
	pDepth As %Integer = "",
	pVerbose As %Boolean = 0,
	Output pMaxDepth As %Integer = 0) As %Status [ Internal ]
{
    set tSC = $$$OK
    try {
        set pRoot = ##class(%File).NormalizeDirectory(pRoot)
        set tDirArray($increment(tDirArray)) = ""

        set i = 0
        do {
            set i = i + 1
            if (pDepth > 0) && ($length(tDirArray(i),"/") > pDepth) {
                continue
            }

            set tStmt = ##class(%SQL.Statement).%New()
            set tSC = tStmt.%PrepareClassQuery("%Library.File","FileSet")
            if $$$ISERR(tSC) {
                quit
            }

            set tFullDir = ##class(%File).NormalizeDirectory(pRoot_tDirArray(i))
            set tRes = tStmt.%Execute(tFullDir,"module.xml",,1)
            while tRes.%Next() {
                if (tRes.%Get("Type") = "D") {
                    write:pVerbose !,"Scanning directory: ",tRes.%Get("ItemName")
                    set tDirArray($increment(tDirArray)) = tDirArray(i)_$case(tDirArray(i),"":"",:"/")_tRes.%Get("ItemName")
                } else {
                    write:pVerbose !,"Found file: ",tRes.%Get("Name")
                    set pFilenameList($increment(pFilenameList)) = tRes.%Get("Name")
                    set pFilenameList(pFilenameList,"sub") = tDirArray(i)
                    if (pDepth > pMaxDepth) {
                        set pMaxDepth = $length(tDirArray(i),"/")
                    }
                }
            }
        } while (i < tDirArray)
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method LockFileTypeGet()
{
    return "filesystem"
}

XData LockFileMapping
{
<Mapping xmlns="http://www.intersystems.com/jsonmapping">
  <Property Name="LockFileType" FieldName="type" />
  <Property Name="Enabled" FieldName="enabled" />
  <Property Name="OverriddenSortOrder" FieldName="overriddenSortOrder" />
  <Property Name="ReadOnly" FieldName="readOnly" />
  <Property Name="Root" FieldName="root" />
  <Property Name="Depth" FieldName="depth" />
</Mapping>
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
