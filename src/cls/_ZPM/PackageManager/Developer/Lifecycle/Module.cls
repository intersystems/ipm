Class %ZPM.PackageManager.Developer.Lifecycle.Module Extends %ZPM.PackageManager.Developer.Lifecycle.Base
{

Property Payload As %Stream.TmpBinary [ Private ];

Parameter PACKAGING As STRING [ Final ] = "module";

Method %Clean(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tSC = ..CheckBeforeClean(.pParams,.tSkip)
		If (tSkip) {
			Quit
		}
		
		Set tSC = ..Unconfigure(.pParams)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tSC = ##super(.pParams)
		If $$$ISERR(tSC) {
			Quit
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method %Activate(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tSC = ##super(.pParams)
		If $$$ISERR(tSC) {
			Quit
		}
		Set tSC = ..Configure(.pParams)
		If $$$ISERR(tSC) {
			Quit
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method %Package(ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tVerbose = $Get(pParams("Verbose"))
		Set tExportDirectory = $Get(pParams("zpm", "Path"))
		If (tExportDirectory'="") && ('##class(%File).DirectoryExists(tExportDirectory)) {
      Set tExportDirectory = ##class(%File).NormalizeDirectory(tExportDirectory)
			If '##class(%File).CreateDirectoryChain(tExportDirectory,.tReturn) {
				Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Error creating directory chain %1: %2",tExportDirectory,tReturn))
				Quit
			}
		}

		Set tSC = ..%Export(.pParams,.tExportDirectory)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tSC = ..OnBeforeArtifact(tExportDirectory,tExportDirectory,.pParams)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Write !,"Module exported to:",!,$Char(9),tExportDirectory,!
		
		Set tTgzFile = $Extract(tExportDirectory,1,*-1)_".tgz"
		Set tSC = ##class(%ZPM.PackageManager.Developer.Archive).Create(tExportDirectory,tTgzFile,.tOutput)
		If $$$ISERR(tSC) {
			Quit
		}
		
		For i=1:1:$Get(tOutput) {
			Write:tVerbose !,tOutput(i)
		}
		
		// Always show this message
		Write !,"Module package generated:",!,$Char(9),tTgzFile
		
		Set tSrcFileStream = ##class(%Stream.FileBinary).%New()
		Set tSC = tSrcFileStream.LinkToFile(tTgzFile)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tSC = ..Payload.CopyFrom(tSrcFileStream)
		If $$$ISERR(tSC) {
			Quit
		}
		Set pParams("PackageFile") = tTgzFile
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

}
