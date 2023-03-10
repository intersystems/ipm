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
	Set tSC = $$$OK
	Set tClass = %class.Name
	Try {
		Set tStreamClass = $$$comMemberKeyGet(%class.Name,$$$cCLASSparameter,"STREAMCLASS",$$$cPARAMdefault)
		If (tStreamClass '= "") {
			If '$$$comClassDefined(tStreamClass) {
				$$$ThrowStatus($$$ERROR($$$CompiledClassDoesNotExist,tStreamClass))
			}
			
			Set tRequiredSuper = "%IPM.StudioDocument.AbstractStream"
			If '$ClassMethod(tStreamClass,"%Extends",tRequiredSuper) {
				$$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Class '%1' does not extend '%2'",tStreamClass,tRequiredSuper)))
			}
		}
	} Catch e {
		Set tSC = $System.Status.EmbedStatus(
			$$$ERROR($$$GeneralError,$$$FormatText("Invalid STREAMCLASS parameter value: %1",tClass)),
			e.AsStatus())
	}
	Quit tSC
}

/// Loads the instance of ..#<parameter>STREAMCLASS</parameter> identified by <property>Name</property> into the stream <property>Code</property>
Method Load() As %Status
{
	Set tSC = $$$OK
	Try {
		Set tSC = ..%ValidateName(..Name)
		If $$$ISERR(tSC) {
			Quit
		}
		Set tDocStream = $ClassMethod(..#STREAMCLASS,"NameOpen",$Piece(..Name,".",1,*-1),,.tSC)
		If $$$ISERR(tSC) {
			Quit
		}
		Set tSC = ..Code.CopyFrom(tDocStream.Contents)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Saves the document in <var>pStream</var> to the database as an instance of ..#<parameter>STREAMCLASS</parameter>, with name <var>pName</var>
ClassMethod ImportStream(pName As %String, pStream As %GlobalCharacterStream) As %Status
{
	Set tSC = $$$OK
	Set tInitTLevel = $TLevel
	Try {
		Set tSC = ..%ValidateName(pName)
		If $$$ISERR(tSC) {
			Quit
		}
		
		TSTART
		Set tName = $Piece(pName,".",1,*-1)
		If $ClassMethod(..#STREAMCLASS,"NameExists",tName) {
			Set tDocStream = $ClassMethod(..#STREAMCLASS,"NameOpen",tName,.tSC)
			If $$$ISERR(tSC) {
				Quit
			}
		} Else {
			Set tDocStream = $ClassMethod(..#STREAMCLASS,"%New")
			Set tDocStream.Name = tName
		}
		
		Set tSC = tDocStream.Contents.CopyFrom(pStream)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tSC = tDocStream.%Save()
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

/// Deletes the instance of ..#<parameter>STREAMCLASS</parameter> identified by <var>name</var>
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
		Set tSC = $ClassMethod(..#STREAMCLASS,"NameDelete",tName)
		$$$ThrowOnError(tSC)
		$$$ThrowOnError(..OnDelete(name))
		TCOMMIT
	} Catch e {
		Set tSC = e.AsStatus()
	}
	While ($TLevel > tInitTLevel) { TROLLBACK 1 }
	Quit tSC
}

/// Subclasses may override to take additional steps during deletion.
/// The caller handles transactions.
ClassMethod OnDelete(name As %String) As %Status
{
	Quit $$$OK
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
	If $classmethod(..#STREAMCLASS,"NameExists",tNameNoExt,.tStreamID) { 
		Set tStamp = $classmethod(..#STREAMCLASS,"LastModifiedTimestampGetStored",tStreamID) 
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
		Set tExists = $ClassMethod(..#STREAMCLASS,"NameExists",$Piece(name,".",1,*-1))
	} Catch e {
		Set tExists = 0
	}
	Quit tExists
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
	
	Set tSC = $$$OK
	Set tInitTLevel = $TLevel
	Try {
		Set tSC = ..%ValidateName(..Name)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tSC = ..OnCompileDocument(.qstruct)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	While ($TLevel > tInitTLevel) { TROLLBACK 1 }
	
	If $Get(qstruct("displaylog")) && $$$ISERR(tSC) {
		Write !,$System.Status.GetErrorText(tSC)
	}
	Quit tSC
}

/// Save the module definition document.
Method Save() As %Status
{
	Set tName = ..Name
	Set tSC = ..ImportStream(.tName,..Code)
	If $$$ISERR(tSC) {
		Quit tSC
	}
	Set ..Name = tName
	Quit ..Load()
}

/// Export this document to the current device in XML format
Method ExportToXML(flags As %String) As %Status
{
	Set ..Code.LineTerminator=$c(10)
	Do ..Code.Rewind()
	Do ..Code.ReadLine()  // omit xml header
	While '(..Code.AtEnd) {
		Write ..Code.Read(16000)
	}
	Quit $$$OK
}

/// Import from the stream in XML format
Method ImportFromXML(stream As %RegisteredObject, flags As %String) As %Status
{
	Do ..Code.Clear()
	Do ..Code.WriteLine("<?xml version=""1.0""?>") //add XML header
	Do ..Code.CopyFrom(stream)
	Quit $$$OK
}

/// Return the compile time of routine 'name' in %TimeStamp format. The format should be $zdatetime($horolog,3),
/// or "" if the routine does not exist.
ClassMethod CompileTime(name As %String) As %TimeStamp
{
	If '..%ValidateName(name) {
		Quit ""
	}
	
	Quit $Get(@..#INFOGLOBAL@($Piece(name,".",1,*-1),"compile"),0)
}

ClassMethod %ValidateName(name As %String) As %Status
{
	Set tSC = $$$OK
	If (("."_$ZConvert($Piece(name,".",*),"U")) '= ..#EXTENSION) {
		Set tSC = $$$ERROR($$$GeneralError,"Invalid name '"_name_"' - doesn't match "_("."_$ZConvert($Piece(name,".",*),"L")))
	}
	Quit tSC
}

/// Subclasses must override
Query ItemList() As %SQLQuery(ROWSPEC = "name:%String,modified:%TimeStamp") [ SqlProc ]
{
	select top 0 null,null
}

Query List(Directory As %String, Flat As %Boolean, System As %Boolean) As %Query(ROWSPEC = "name:%String,modified:%TimeStamp,size:%Integer,directory:%String") [ SqlProc ]
{
}

/// Lock the current routine, default method just unlocks the ^ROUTINE global with the name of the routine.
/// If it fails then return a status code of the error, otherwise return $$$OK
Method Lock(flags As %String) As %Status
{
	Set tSC = $$$OK
	If ..Locked {
		Set ..Locked = ..Locked + 1
		Quit $$$OK
	}
	Set tShared = ($Get(flags)["S")
	Set tSC = $classmethod(..#STREAMCLASS,"%LockName",..Name,tShared,0)
	If $$$ISOK(tSC) {
		Set ..Locked = 1
	}
	Quit tSC
}

/// Unlock the current routine, default method just unlocks the ^ROUTINE global with the name of the routine
Method Unlock(flags As %String) As %Status
{
	Set tShared = ($Get(flags)["S")
	Set tImmediate = ($Get(flags)["I")
	If (..Locked > 1) {
		Set ..Locked = ..Locked - 1
		Quit $$$OK
	}
	Set tSC = $classmethod(..#STREAMCLASS,"%UnlockName",..Name,tShared,tImmediate)
	If $$$ISOK(tSC) {
		Set ..Locked = 0
	}
	Quit tSC
}

/// Called from %Library.RoutineMgr:LockItem to lock a document by name (including extension)
ClassMethod LockName(name As %String) As %Status
{
	Quit $classmethod(..#STREAMCLASS,"%LockName",name,0,0)
}

/// Called from %Library.RoutineMgr:UnlockItem to unlock a document by name (including extension)
ClassMethod UnlockName(name As %String) As %Status
{
	Quit $classmethod(..#STREAMCLASS,"%UnlockName",name,0,0)
}

ClassMethod ListExecute(ByRef qHandle As %Binary, Directory As %String, Flat As %Boolean, System As %Boolean) As %Status
{
	If (Directory '= "") Set qHandle = "" Quit $$$OK
	Set tSC = $$$OK
	// Use %Library.ResultSet set to avoid complex SQL permissions issues
	// that apply to users who have Studio access, but not the %Development role.
	// Note that the qHandle object complies with key aspects of the newer
	// %SQL.* result set interface
	Set qHandle = ##class(%Library.ResultSet).%New($classname()_":ItemList")
	Set tSC = qHandle.Execute()
	If $$$ISERR(tSC) {
		Quit tSC
	}
	If (qHandle.%SQLCODE < 0) {
		Set tSC = $$$ERROR($$$SQLCode,qHandle.%SQLCODE,qHandle.%Message)
		Quit tSC
	}
	If 'qHandle.%Next(.tSC) {
		Set qHandle = ""
	}
	Quit tSC
}

ClassMethod ListFetch(ByRef qHandle As %Binary, ByRef Row As %List, ByRef AtEnd As %Integer = 0) As %Status [ PlaceAfter = ListExecute ]
{
	Quit:qHandle="" $$$OK
	Set Row = $ListBuild(qHandle.%GetData(1)_..#EXTENSION,qHandle.%GetData(2),1000,"")
	Set AtEnd = 'qHandle.%Next(.tSC)
	Quit tSC
}

ClassMethod ListClose(ByRef qHandle As %Binary) As %Status [ PlaceAfter = ListExecute ]
{
	Quit $$$OK
}

}
