/// This class helps with packaging a directory (containing files) in a format that is easy to import on a different instance.
Class %IPM.Lifecycle.StudioProject.XDataArchive Extends %RegisteredObject
{

Property SourceDirectory As %String(MAXLEN = "") [ Private ];

Property Package As %String [ Private ];

/// <var>pDirectory</var> is the directory to be packaged.
Method %OnNew(pDirectory As %String) As %Status [ Private, ServerOnly = 1 ]
{
    set ..SourceDirectory = pDirectory
    quit $$$OK
}

/// Populates classes with the context of <property>SourceDirectory</property>, then adds the generated classes to <var>pStudioProject</var>.
Method AddToProject(
	pStudioProject As %Studio.Project,
	pVerbose As %Boolean = 1) As %Status
{
    set tSC = $$$OK
    try {
        $$$ThrowOnError(..Populate(pVerbose))
        $$$ThrowOnError($system.OBJ.GetPackageList(.tItems,..Package))
        set tKey = ""
        for {
            set tKey = $order(tItems(tKey))
            if (tKey = "") {
                quit
            }
            $$$ThrowOnError(pStudioProject.AddItem(tKey,"CLS"))
        }
        $$$ThrowOnError(pStudioProject.%Save())
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Creates XData blocks with the contents of files in <property>SourceDirectory</property>
Method Populate(pVerbose As %Boolean = 1) As %Status
{
    set tSC = $$$OK
    try {
        if (..SourceDirectory = "") {
            $$$ThrowStatus($$$ERROR($$$GeneralError,"A directory must be specified in %IPM.Lifecycle.StudioProject.XDataArchive:%OnNew."))
        }
        set ..SourceDirectory = ##class(%Library.File).NormalizeDirectory(..SourceDirectory)
        if '##class(%Library.File).DirectoryExists(..SourceDirectory) {
            $$$ThrowStatus($$$ERROR($$$DirectoryNotExist,..SourceDirectory))
        }
        $$$ThrowOnError(..GetDirectoryContentsRecursive(..SourceDirectory,.tFiles))

        for {
            set ..Package = "zTemp.PackageManager.StaticBundle"_$increment(tCount)
            if ($extract($order(^oddDEF(..Package_".")),1,$length(..Package)) '= ..Package) {
                quit
            }
        }

        if pVerbose {
            write !,"Converting "_..SourceDirectory_" to package: "_..Package,!
        }

        // Copy the requisite classes to the temp package name to support use in non-Package Manager contexts
        for tPostfix = "",".IFile",".FileBinary",".FileCharacter" {
            set tSource = ##class(%Dictionary.ClassDefinition).%OpenId($classname()_tPostfix,,.tSC)
            $$$ThrowOnError(tSC)

            set tTarget = tSource.%ConstructClone(1)
            set tTarget.Name = ..Package_".XDataArchive"_tPostfix
            set tTarget.Super = $replace(tTarget.Super,$classname(),..Package_".XDataArchive")
            $$$ThrowOnError(tTarget.%Save())

            // Fix method lines individually
            set tMethod = ""
            for {
                set tMethod = $$$defMemberNext(tTarget.Name,$$$cCLASSmethod,tMethod)
                if (tMethod = "") {
                    quit
                }
                for tLine=1:1:$$$defMemberKeyGet(tTarget.Name,$$$cCLASSmethod,tMethod,$$$cMETHimplementation) {
                    set tLineCode = $replace($$$defMemberArrayGet(tTarget.Name,$$$cCLASSmethod,tMethod,$$$cMETHimplementation,tLine),$classname(),..Package_".XDataArchive")
                    $$$defMemberArraySet(tTarget.Name,$$$cCLASSmethod,tMethod,$$$cMETHimplementation,tLine,tLineCode)
                }
            }
        }

        // Load files
        set tMaxBlocks = 255
        set tBlockCount = 0
        set tClassCount = 1
        set tFileKey = ""
        for {
            set tFileKey = $order(tFiles(tFileKey),1,tFile)
            if (tFileKey = "") {
                quit
            }
            if $increment(tBlockCount) > tMaxBlocks {
                set tBlockCount = 1
                set tClassCount = tClassCount + 1
            }
            if (tBlockCount = 1) {
                set tClass = ##class(%Dictionary.ClassDefinition).%New()
                set tClass.Name = ..Package_".c"_tClassCount
            }
            set tXData = ##class(%Dictionary.XDataDefinition).%New()
            set tXData.Name = "b"_tBlockCount
            set tXData.Description = tFile
            if pVerbose {
                write !,"Converting file: ",tFile
            }
            $$$ThrowOnError(##class(%IPM.Lifecycle.StudioProject.XDataArchive.IFile).IngestToStream(..SourceDirectory_tFile,tXData.Data))
            do tClass.XDatas.Insert(tXData)
            $$$ThrowOnError(tClass.%Save())
        }

        $$$ThrowOnError($system.OBJ.CompilePackage(..Package,"c-k-d"))
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Method GetDirectoryContentsRecursive(
	pDirectory As %String,
	Output pItems) As %Status [ Private ]
{
    set tSC = $$$OK
    try {
        kill pItems
        set tFileResult = ##class(%Library.File).FileSetFunc(pDirectory,,1)
        if (tFileResult.%SQLCODE < 0) {
            throw ##class(%Exception.SQL).CreateFromSQLCODE(tFileResult.%SQLCODE,tFileResult.%Message)
        }
        while tFileResult.%Next(.tSC) {
            $$$ThrowOnError(tSC)
            if (tFileResult.%Get("Type") = "D") {
                $$$ThrowOnError(..GetDirectoryContentsRecursive(tFileResult.%Get("Name"),.tItems))
                for tItem=1:1:$get(tItems) {
                    set pItems($increment(pItems)) = tFileResult.%Get("ItemName")_"/"_tItems(tItem)
                }
            } else {
                set pItems($increment(pItems)) = tFileResult.%Get("ItemName")
            }
        }
        $$$ThrowOnError(tSC)
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Copied from %IPM.Utils.File to support use in classes cloned from this one
ClassMethod CreateDirectoryChain(pName As %String) As %Status
{
    set tSC = $$$OK
    if '##class(%Library.File).CreateDirectoryChain(pName,.tReturn) {
        set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error creating directory chain %1: %2",pName,$zutil(209,tReturn)))
    }
    quit tSC
}

Method GenerateInstallerCode(
	pDirectoryVariableName As %String,
	ByRef pRoutine) As %Status
{
    set pRoutine($increment(pRoutine)) = " $$$ThrowOnError(##class("_..Package_".XDataArchive).Extract("_pDirectoryVariableName_"))"
    set pRoutine($increment(pRoutine)) = " $$$ThrowOnError($System.OBJ.DeletePackage("_$$$QUOTE(..Package)_",""-d""))"
    quit $$$OK
}

ClassMethod Extract(pTargetDirectory As %String) As %Status
{
    set tSC = $$$OK
    try {
        set tPackage = $piece($classname(),".",1,*-1)
        $$$ThrowOnError($system.OBJ.GetPackageList(.tClasses,tPackage))

        // Extract all files.
        set tClassKey = ""
        for {
            set tClassKey = $order(tClasses(tClassKey))
            if (tClassKey = "") {
                quit
            }
            set tClassDef = ##class(%Dictionary.ClassDefinition).%OpenId(tClassKey,,.tSC)
            $$$ThrowOnError(tSC)

            set tXDataKey = ""
            for {
                set tXData = tClassDef.XDatas.GetNext(.tXDataKey)
                if (tXDataKey = "") {
                    quit
                }
                $$$ThrowOnError(##class(%IPM.Lifecycle.StudioProject.XDataArchive.IFile).Extract(pTargetDirectory,tXData))
            }
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// This callback method is invoked by the <METHOD>%Close</METHOD> method to
/// provide notification that the current object is being closed.
/// 
/// <P>The return value of this method is ignored.
Method %OnClose() As %Status [ Private, ServerOnly = 1 ]
{
    set tSC = $$$OK
    try {
        if (..Package '= "") {
            set tSC = $system.OBJ.DeletePackage(..Package,"-d")
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

}
