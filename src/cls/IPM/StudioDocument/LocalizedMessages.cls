Class %IPM.StudioDocument.LocalizedMessages Extends %IPM.StudioDocument.Abstract [ DependsOn = %IPM.StudioDocument.LocalizedMessageStream ]
{

Projection RegisterExtension As %IPM.StudioDocument.Projection(DocumentDescription = "Localizable Error Messages", DocumentExtension = "LOC", DocumentNew = 1, DocumentType = "xml", XMLNamespace = "http://www.intersystems.com/HealthShare/LocalizedMessages");

Parameter EXTENSION = ".LOC";

Parameter INFOGLOBAL = "^IPM.StuDoc.LocalizedMessages";

Parameter STREAMCLASS = "%IPM.StudioDocument.LocalizedMessageStream";

Method OnCompileDocument(ByRef qstruct As %String) As %Status
{
    set tSC = $$$OK
    try {
        tstart
        set tMsgFile = ##class(%IPM.StudioDocument.LocalizedMessageStream).NameOpen($piece(..Name,".",1,*-1),,.tSC)
        if $$$ISERR(tSC) {
            quit
        }

        set tSC = ..Save()
        if $$$ISERR(tSC) {
            quit
        }

        set tTmpFileStream = ##class(%Stream.FileCharacter).%New()
        set ..Code.LineTerminator = $char(10)
        do ..Code.Rewind()
        do ..Code.ReadLine()  // omit xml header
        while '(..Code.AtEnd) {
            set tSC = tTmpFileStream.Write(..Code.Read(16000))
            if $$$ISERR(tSC) {
                quit
            }
        }
        if $$$ISERR(tSC) {
            quit
        }

        set tSC = tTmpFileStream.%Save()
        if $$$ISERR(tSC) {
            quit
        }

        set file = tTmpFileStream.Filename

        // Copied from HSLIB error load process
        set tSC=$$Import^%occMsgXML(file,.domains,1,0)
        if $$$ISERR(tSC) {
            quit
        }

        // Belt and suspenders:
        // Generate include files with all the plausible names.
        // This needs to be improved at some point..
        set errdomains=""
        set domain=""
        for {
            set domain=$order(domains(domain))
            quit:domain=""
            // Generate the include
            set errdomains = errdomains_$listbuild(domain)
        }
        do GenerateInclude^%occMsgXML(tMsgFile.Name,0,$listtostring(errdomains),1)

        set @..#INFOGLOBAL@("compile",tMsgFile.Name) = $zdatetime($ztimestamp,3)
        tcommit
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Deletes the include file associated with this document.
ClassMethod OnDelete(name As %String) As %Status
{
    set tSC = $$$OK
    try {
        set tName = ..GetIncludeFileName(name)
        if ##class(%Library.Routine).Exists(tName) {
            set tSC = ##class(%Library.Routine).Delete(tName)
            $$$ThrowOnError(tSC)
        }
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

Query ItemList() As %SQLQuery(ROWSPEC = "name:%String,modified:%TimeStamp") [ SqlProc ]
{
    select Name, LastModifiedTimestamp from %IPM_StudioDocument.LocalizedMessageStream
}

/// Given a full error message document name (with .LOC extension), returns the full name (with extension) of the associated .INC file.
ClassMethod GetIncludeFileName(pDocumentName As %String) As %String
{
    set tName = $piece(pDocumentName,".",1,*-1) // Strip extension
    quit tName_".INC"
}

/// Return other document types that this is related to.
/// Passed a name and you return a comma separated list of the other documents it is related to
/// or "" if it is not related to anything. Note that this can be passed a document of another type
/// for example if your 'test.XXX' document creates a 'test.INT' routine then it will also be called
/// with 'test.INT' so you can return 'test.XXX' to complete the cycle.
ClassMethod GetOther(Name As %String) As %String
{
    set tOther = ""
    set tName = $piece(Name,".",1,*-1)
    set tExt = $piece(Name,".",*)
    if (tExt = "LOC") {
        set tExpected = ..GetIncludeFileName(Name)
        if ##class(%Routine).Exists(tExpected) {
            set tOther = tExpected
        }
    } elseif (tExt = "INC") {
        // Not actually supported in Studio, but it's still correct.
        set tExpected = tName_".LOC"
        if ..Exists(tExpected) {
            set tOther = tExpected
        }
    }
    quit tOther
}

}
