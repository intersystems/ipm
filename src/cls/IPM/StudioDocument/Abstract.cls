Class %IPM.StudioDocument.Abstract Extends %Studio.AbstractDocument [ Abstract, DependsOn = %IPM.StudioDocument.AbstractStream, Owner = {%Developer} ]
{

/// The extension name, this can be a comma separated list of extensions if this class supports more than one.
/// For details on the projection parameters see <class>%Projection.StudioDocument</class>.
Projection RegisterExtension As %IPM.StudioDocument.Projection(DocumentDescription = "", DocumentExtension = "", DocumentIcon = 0, DocumentNew = 0, DocumentType = "", XMLNamespace = "");

Parameter EXTENSION [ Abstract ];

Parameter INFOGLOBAL [ Abstract ];

/// Optional subclass of %IPM.StudioDocument.AbstractStream that stores code in a character stream.
Parameter STREAMCLASS;

/// Runs at compile time to ensure that ..#<parameter>STREAMCLASS</parameter> is valid.
/// Does not actually generate any code.
ClassMethod ValidateStreamClass() [ CodeMode = objectgenerator, Final, Internal, Private ]
{
    set tSC = $$$OK
    set tClass = %class.Name
    try {
        set tStreamClass = $$$comMemberKeyGet(%class.Name,$$$cCLASSparameter,"STREAMCLASS",$$$cPARAMdefault)
        if (tStreamClass '= "") {
            if '$$$comClassDefined(tStreamClass) {
                $$$ThrowStatus($$$ERROR($$$CompiledClassDoesNotExist,tStreamClass))
            }
            set tRequiredSuper = "%IPM.StudioDocument.AbstractStream"
            if '$classmethod(tStreamClass,"%Extends",tRequiredSuper) {
                $$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Class '%1' does not extend '%2'",tStreamClass,tRequiredSuper)))
            }
        }
    } catch e {
        set tSC = $system.Status.EmbedStatus(
            $$$ERROR($$$GeneralError,$$$FormatText("Invalid STREAMCLASS parameter value: %1",tClass)),
            e.AsStatus()
        )
    }
    quit tSC
}

/// Loads the instance of ..#<parameter>STREAMCLASS</parameter> identified by <property>Name</property> into the stream <property>Code</property>
Method Load() As %Status
{
    set tSC = $$$OK
    try {
        set tSC = ..%ValidateName(..Name)
        if $$$ISERR(tSC) {
            quit
        }
        set tDocStream = $classmethod(..#STREAMCLASS,"NameOpen",$piece(..Name,".",1,*-1),,.tSC)
        if $$$ISERR(tSC) {
            quit
        }
        set tSC = ..Code.CopyFrom(tDocStream.Contents)
    } catch e {
        set tSC = e.AsStatus()
    }
    quit tSC
}

/// Saves the document in <var>pStream</var> to the database as an instance of ..#<parameter>STREAMCLASS</parameter>, with name <var>pName</var>
ClassMethod ImportStream(
	pName As %String,
	pStream As %GlobalCharacterStream) As %Status
{
    set tSC = $$$OK
    set tInitTLevel = $tlevel
    try {
        set tSC = ..%ValidateName(pName)
        if $$$ISERR(tSC) {
            quit
        }

        tstart
        set tName = $piece(pName,".",1,*-1)
        if $classmethod(..#STREAMCLASS,"NameExists",tName) {
            set tDocStream = $classmethod(..#STREAMCLASS,"NameOpen",tName,.tSC)
            if $$$ISERR(tSC) {
                quit
            }
        } else {
            set tDocStream = $classmethod(..#STREAMCLASS,"%New")
            set tDocStream.Name = tName
        }

        set tSC = tDocStream.Contents.CopyFrom(pStream)
        if $$$ISERR(tSC) {
            quit
        }

        set tSC = tDocStream.%Save()
        if $$$ISERR(tSC) {
            quit
        }
        tcommit
    } catch e {
        set tSC = e.AsStatus()
    }
    while ($tlevel > tInitTLevel) {
        trollback 1
    }
    quit tSC
}

/// Deletes the instance of ..#<parameter>STREAMCLASS</parameter> identified by <var>name</var>
ClassMethod Delete(name As %String) As %Status
{
    set tSC = $$$OK
    set tInitTLevel = $tlevel
    try {
        set tSC = ..%ValidateName(name)
        if $$$ISERR(tSC) {
            quit
        }
        set tName = $piece(name,".",1,*-1) // Strip extension
        tstart
        set tSC = $classmethod(..#STREAMCLASS,"NameDelete",tName)
        $$$ThrowOnError(tSC)
        $$$ThrowOnError(..OnDelete(name))
        tcommit
    } catch e {
        set tSC = e.AsStatus()
    }
    while ($tlevel > tInitTLevel) {
        trollback 1
    }
    quit tSC
}

/// Subclasses may override to take additional steps during deletion.
/// The caller handles transactions.
ClassMethod OnDelete(name As %String) As %Status
{
    quit $$$OK
}

/// Return the timestamp of schema category 'name' in %TimeStamp format, i.e. $zdatetime($horolog,3).
/// This is used to determine if the category has been updated on the server and so needs reloading into Studio.
/// So the format should be $zdatetime($horolog,3), or "" if the category does not exist.
ClassMethod TimeStamp(name As %String) As %TimeStamp [ SqlProc ]
{
    if '..%ValidateName(name) {
        quit ""
    }
    set tStamp = ""
    set tNameNoExt = $piece(name,".",1,*-1)
    if $classmethod(..#STREAMCLASS,"NameExists",tNameNoExt,.tStreamID) {
        set tStamp = $classmethod(..#STREAMCLASS,"LastModifiedTimestampGetStored",tStreamID)
    }
    quit tStamp
}

/// Return 1 if the given document exists and 0 if it does not.
ClassMethod Exists(name As %String) As %Boolean
{
    set tExists = 0
    try {
        set tSC = ..%ValidateName(name)
        if $$$ISERR(tSC) {
            quit
        }
        set tExists = $classmethod(..#STREAMCLASS,"NameExists",$piece(name,".",1,*-1))
    } catch e {
        set tExists = 0
    }
    quit tExists
}

/// CompileDocument is called when the document is to be compiled
/// It has already called the source control hooks at this point
Method CompileDocument(ByRef qstruct As %String) As %Status
{
    // SuspendErrorCount allows things this calls to return error statuses without resulting in:
    // ERROR #6084: Unknown errors detected, but no error code reported
    // There may be cases where error statuses are not exceptional cases and are handled properly
    // without needing to return the error status.
    $$$SuspendErrorCount

    set tSC = $$$OK
    set tInitTLevel = $tlevel
    try {
        set tSC = ..%ValidateName(..Name)
        if $$$ISERR(tSC) {
            quit
        }

        set tSC = ..OnCompileDocument(.qstruct)
    } catch e {
        set tSC = e.AsStatus()
    }
    while ($tlevel > tInitTLevel) {
        trollback 1
    }

    if $get(qstruct("displaylog")) && $$$ISERR(tSC) {
        write !,$system.Status.GetErrorText(tSC)
    }
    quit tSC
}

/// Save the module definition document.
Method Save() As %Status
{
    set tName = ..Name
    set tSC = ..ImportStream(.tName,..Code)
    if $$$ISERR(tSC) {
        quit tSC
    }
    set ..Name = tName
    quit ..Load()
}

/// Export this document to the current device in XML format
Method ExportToXML(flags As %String) As %Status
{
    set ..Code.LineTerminator=$char(10)
    do ..Code.Rewind()
    do ..Code.ReadLine()  // omit xml header
    while '(..Code.AtEnd) {
        write ..Code.Read(16000)
    }
    quit $$$OK
}

/// Import from the stream in XML format
Method ImportFromXML(
	stream As %RegisteredObject,
	flags As %String) As %Status
{
    do ..Code.Clear()
    do ..Code.WriteLine("<?xml version=""1.0""?>") //add XML header
    do ..Code.CopyFrom(stream)
    quit $$$OK
}

/// Return the compile time of routine 'name' in %TimeStamp format. The format should be $zdatetime($horolog,3),
/// or "" if the routine does not exist.
ClassMethod CompileTime(name As %String) As %TimeStamp
{
    if '..%ValidateName(name) {
        quit ""
    }
    quit $get(@..#INFOGLOBAL@($piece(name,".",1,*-1),"compile"),0)
}

ClassMethod %ValidateName(name As %String) As %Status
{
    set tSC = $$$OK
    if (("."_$zconvert($piece(name,".",*),"U")) '= ..#EXTENSION) {
        set tSC = $$$ERROR($$$GeneralError,"Invalid name '"_name_"' - doesn't match "_("."_$zconvert($piece(name,".",*),"L")))
    }
    quit tSC
}

/// Subclasses must override
Query ItemList() As %SQLQuery(ROWSPEC = "name:%String,modified:%TimeStamp") [ SqlProc ]
{
    select top 0 null,null
}

Query List(
	Directory As %String,
	Flat As %Boolean,
	System As %Boolean) As %Query(ROWSPEC = "name:%String,modified:%TimeStamp,size:%Integer,directory:%String") [ SqlProc ]
{
}

/// Lock the current routine, default method just unlocks the ^ROUTINE global with the name of the routine.
/// If it fails then return a status code of the error, otherwise return $$$OK
Method Lock(flags As %String) As %Status
{
    set tSC = $$$OK
    if ..Locked {
        set ..Locked = ..Locked + 1
        quit $$$OK
    }
    set tShared = ($get(flags)["S")
    set tSC = $classmethod(..#STREAMCLASS,"%LockName",..Name,tShared,0)
    if $$$ISOK(tSC) {
        set ..Locked = 1
    }
    quit tSC
}

/// Unlock the current routine, default method just unlocks the ^ROUTINE global with the name of the routine
Method Unlock(flags As %String) As %Status
{
    set tShared = ($get(flags)["S")
    set tImmediate = ($get(flags)["I")
    if (..Locked > 1) {
        set ..Locked = ..Locked - 1
        quit $$$OK
    }
    set tSC = $classmethod(..#STREAMCLASS,"%UnlockName",..Name,tShared,tImmediate)
    if $$$ISOK(tSC) {
        set ..Locked = 0
    }
    quit tSC
}

/// Called from %Library.RoutineMgr:LockItem to lock a document by name (including extension)
ClassMethod LockName(name As %String) As %Status
{
    quit $classmethod(..#STREAMCLASS,"%LockName",name,0,0)
}

/// Called from %Library.RoutineMgr:UnlockItem to unlock a document by name (including extension)
ClassMethod UnlockName(name As %String) As %Status
{
    quit $classmethod(..#STREAMCLASS,"%UnlockName",name,0,0)
}

ClassMethod ListExecute(
	ByRef qHandle As %Binary,
	Directory As %String,
	Flat As %Boolean,
	System As %Boolean) As %Status
{
    if (Directory '= "") {
        set qHandle = ""
        quit $$$OK
    }
    set tSC = $$$OK
    // Use %Library.ResultSet set to avoid complex SQL permissions issues
    // that apply to users who have Studio access, but not the %Development role.
    // Note that the qHandle object complies with key aspects of the newer
    // %SQL.* result set interface
    set qHandle = ##class(%Library.ResultSet).%New($classname()_":ItemList")
    set tSC = qHandle.Execute()
    if $$$ISERR(tSC) {
        quit tSC
    }
    if (qHandle.%SQLCODE < 0) {
        set tSC = $$$ERROR($$$SQLCode,qHandle.%SQLCODE,qHandle.%Message)
        quit tSC
    }
    if 'qHandle.%Next(.tSC) {
        set qHandle = ""
    }
    quit tSC
}

ClassMethod ListFetch(
	ByRef qHandle As %Binary,
	ByRef Row As %List,
	ByRef AtEnd As %Integer = 0) As %Status [ PlaceAfter = ListExecute ]
{
    quit:qHandle="" $$$OK
    set Row = $listbuild(qHandle.%GetData(1)_..#EXTENSION,qHandle.%GetData(2),1000,"")
    set AtEnd = 'qHandle.%Next(.tSC)
    quit tSC
}

ClassMethod ListClose(ByRef qHandle As %Binary) As %Status [ PlaceAfter = ListExecute ]
{
    quit $$$OK
}

}
