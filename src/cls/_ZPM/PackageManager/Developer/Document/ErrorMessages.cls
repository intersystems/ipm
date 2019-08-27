Class %ZPM.PackageManager.Developer.Document.ErrorMessages Extends %ZPM.PackageManager.Developer.Document.AbstractDocument
{

Projection RegisterExtension As %Projection.StudioDocument(DocumentDescription = "Localizable Error Messages", DocumentExtension = "LOC", DocumentNew = 1, DocumentType = "xml", XMLNamespace = "http://www.intersystems.com/PackageManager/ErrorMessages");

Parameter EXTENSION = ".LOC";

Parameter INFOGLOBAL = "^ZPM.Dev.Doc.ErrorMessages";

/// Load the error message file <property>Name</property> into the stream <property>Code</property>
Method Load() As %Status
{
	Set tSC = $$$OK
	Try {
		Set tSC = ..%ValidateName(..Name)
		If $$$ISERR(tSC) {
			Quit
		}
		Set tMsgFile = ##class(%ZPM.PackageManager.Developer.ErrorMessages.MessageFileStream).NameOpen($Piece(..Name,".",1,*-1),,.tSC)
		If $$$ISERR(tSC) {
			Quit
		}
		Set tSC = ..Code.CopyFrom(tMsgFile.Contents)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method OnCompileDocument(ByRef qstruct As %String) As %Status
{
	Set tSC = $$$OK
	Try {
		TSTART
		Set tMsgFile = ##class(%ZPM.PackageManager.Developer.ErrorMessages.MessageFileStream).NameOpen($Piece(..Name,".",1,*-1),,.tSC)
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
		Set tSC=$$Import^%occMsgXML(file,.domains,1)
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

/// Save the message file document from stream to database.
ClassMethod ImportStream(pName As %String, pStream As %GlobalCharacterStream) As %Status
{
	Set tSC = $$$OK
	Set tInitTLevel = $TLevel
	Try {
		TSTART
		Set tSC = ..%ValidateName(pName)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tName = $Piece(pName,".",1,*-1)
		If ##class(%ZPM.PackageManager.Developer.ErrorMessages.MessageFileStream).NameExists(tName) {
			Set tMsgFile = ##class(%ZPM.PackageManager.Developer.ErrorMessages.MessageFileStream).NameOpen(tName,.tSC)
			If $$$ISERR(tSC) {
				Quit
			}
		} Else {
			Set tMsgFile = ##class(%ZPM.PackageManager.Developer.ErrorMessages.MessageFileStream).%New()
			Set tMsgFile.Name = tName
		}
		
		Set tSC = tMsgFile.Contents.CopyFrom(pStream)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tSC = tMsgFile.%Save()
		If $$$ISERR(tSC) {
			Quit
		}
		TCOMMIT
	} Catch e {
		Set tSC = e.AsStatus()
	}
	While ($TLevel > tInitTLevel) { TROLLBACK 1 }
	Quit tSC
}

/// Delete the message file <var>name</var>.
ClassMethod Delete(name As %String) As %Status
{
	Set tSC = $$$OK
	Set tInitTLevel = $TLevel
	Try {
		Set tSC = ..%ValidateName(name)
		If $$$ISERR(tSC) {
			Quit
		}
		Set tName = $Piece(name,".",1,*-1) // Strip extension
		TSTART
		Set tSC = ##class(%ZPM.PackageManager.Developer.ErrorMessages.MessageFileStream).NameDelete(tName)
		$$$ThrowOnError(tSC)
		Set tName = tName_".inc"
		If ##class(%Library.Routine).Exists(tName) {
			Set tSC = ##class(%Library.Routine).Delete(tName)
			$$$ThrowOnError(tSC)
		}
		TCOMMIT
	} Catch e {
		Set tSC = e.AsStatus()
	}
	While ($TLevel > tInitTLevel) { TROLLBACK 1 }
	Quit tSC
}

/// Return the timestamp of schema category 'name' in %TimeStamp format, i.e. $zdatetime($horolog,3).
/// This is used to determine if the category has been updated on the server and so needs reloading into Studio.
/// So the format should be $zdatetime($horolog,3), or "" if the category does not exist.
ClassMethod TimeStamp(name As %String) As %TimeStamp [ SqlProc ]
{
	If '..%ValidateName(name) {
		Quit ""
	}
	
	Set tStamp = ""
	Set tNameNoExt = $Piece(name,".",1,*-1)
	Set tMsgFile = ##class(%ZPM.PackageManager.Developer.ErrorMessages.MessageFileStream).NameOpen(tNameNoExt)
	If $IsObject(tMsgFile) {
		Set tStamp = tMsgFile.LastModifiedTimestamp
	}
	Quit tStamp
}

/// Return 1 if the given document exists and 0 if it does not.
ClassMethod Exists(name As %String) As %Boolean
{
	Set tExists = 0
	Try {
		Set tSC = ..%ValidateName(name)
		If $$$ISERR(tSC) {
			Quit
		}
		Set tExists = ##class(%ZPM.PackageManager.Developer.ErrorMessages.MessageFileStream).NameExists($Piece(name,".",1,*-1))
	} Catch e {
		Set tExists = 0
	}
	Quit tExists
}

/// Subclasses must override
Query ItemList() As %SQLQuery(ROWSPEC = "name:%String,modified:%TimeStamp") [ SqlProc ]
{
	select Name, LastModifiedTimestamp from %ZPM_PackageManager_Developer_ErrorMessages.MessageFileStream
}

/// Import from the stream in XML format
Method ImportFromXML(stream As %RegisteredObject, flags As %String) As %Status
{
	Do ..Code.Clear()
	Do ..Code.WriteLine("<?xml version=""1.0""?>") //add XML header
	Do ..Code.CopyFrom(stream)
	Quit $$$OK
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
		Set tExpected = tName_".INC"
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
