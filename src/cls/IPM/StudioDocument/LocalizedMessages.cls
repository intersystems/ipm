Class %IPM.StudioDocument.LocalizedMessages Extends %IPM.StudioDocument.Abstract [ DependsOn = %IPM.StudioDocument.LocalizedMessageStream ]
{

Projection RegisterExtension As %IPM.StudioDocument.Projection(DocumentDescription = "Localizable Error Messages", DocumentExtension = "LOC", DocumentNew = 1, DocumentType = "xml", XMLNamespace = "http://www.intersystems.com/HealthShare/LocalizedMessages");

Parameter EXTENSION = ".LOC";

Parameter INFOGLOBAL = "^IPM.StuDoc.LocalizedMessages";

Parameter STREAMCLASS = "%IPM.StudioDocument.LocalizedMessageStream";

Method OnCompileDocument(ByRef qstruct As %String) As %Status
{
	Set tSC = $$$OK
	Try {
		TSTART
		Set tMsgFile = ##class(%IPM.StudioDocument.LocalizedMessageStream).NameOpen($Piece(..Name,".",1,*-1),,.tSC)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tSC = ..Save()
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tTmpFileStream = ##class(%Stream.FileCharacter).%New()
		Set ..Code.LineTerminator = $c(10)
		Do ..Code.Rewind()
		Do ..Code.ReadLine()  // omit xml header
		While '(..Code.AtEnd) {
			Set tSC = tTmpFileStream.Write(..Code.Read(16000))
			If $$$ISERR(tSC) {
				Quit
			}
		}
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tSC = tTmpFileStream.%Save()
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set file = tTmpFileStream.Filename
		
		// Copied from HSLIB error load process
		Set tSC=$$Import^%occMsgXML(file,.domains,1,0)
		If $$$ISERR(tSC) {
			Quit
		}

		// Belt and suspenders:
		// Generate include files with all the plausible names.
		// This needs to be improved at some point..
		Set errdomains=""
		Set domain="" For {
			Set domain=$O(domains(domain)) Quit:domain=""
			// Generate the include
			Set errdomains = errdomains_$lb(domain)
		}
		Do GenerateInclude^%occMsgXML(tMsgFile.Name,0,$lts(errdomains),1)
		
		Set @..#INFOGLOBAL@("compile",tMsgFile.Name) = $zdt($zts,3)
		TCOMMIT
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Deletes the include file associated with this document.
ClassMethod OnDelete(name As %String) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tName = ..GetIncludeFileName(name)
		If ##class(%Library.Routine).Exists(tName) {
			Set tSC = ##class(%Library.Routine).Delete(tName)
			$$$ThrowOnError(tSC)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Query ItemList() As %SQLQuery(ROWSPEC = "name:%String,modified:%TimeStamp") [ SqlProc ]
{
	select Name, LastModifiedTimestamp from %IPM_StudioDocument.LocalizedMessageStream
}

/// Given a full error message document name (with .LOC extension), returns the full name (with extension) of the associated .INC file.
ClassMethod GetIncludeFileName(pDocumentName As %String) As %String
{
	Set tName = $Piece(pDocumentName,".",1,*-1) // Strip extension
	Quit tName_".INC"
}

/// Return other document types that this is related to.
/// Passed a name and you return a comma separated list of the other documents it is related to
/// or "" if it is not related to anything. Note that this can be passed a document of another type
/// for example if your 'test.XXX' document creates a 'test.INT' routine then it will also be called
/// with 'test.INT' so you can return 'test.XXX' to complete the cycle.
ClassMethod GetOther(Name As %String) As %String
{
	Set tOther = ""
	Set tName = $Piece(Name,".",1,*-1)
	Set tExt = $Piece(Name,".",*)
	If (tExt = "LOC") {
		Set tExpected = ..GetIncludeFileName(Name)
		If ##class(%Routine).Exists(tExpected) {
			Set tOther = tExpected
		}
	} ElseIf (tExt = "INC") {
		// Not actually supported in Studio, but it's still correct.
		Set tExpected = tName_".LOC"
		If ..Exists(tExpected) {
			Set tOther = tExpected
		}
	}
	Quit tOther
}

}
