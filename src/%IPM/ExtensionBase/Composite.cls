/// This class provides the API and interface to work with multiple Studio extensions
/// It directs the action and lifecycle calls to corresponding primary/secondary extension class
/// Set Inheritance to right, so that on conflict definitions, CompositeMethodOverrides.cls will take over %Studio.Extension.Base.cls
/// This way, CompositeMethodOverrides.cls can override final methods in %Studio.* methods
Class %IPM.ExtensionBase.Composite Extends (%Studio.Extension.Base, %IPM.ExtensionBase.CompositeMethodOverrides) [ Inheritance = right, Owner = {%Developer} ]
{

Query MainMenus(Classname As %String) As %SQLQuery [ SqlProc ]
{
SELECT Name, Type FROM %Studio_Extension.Menu WHERE MenuBase %INLIST %IPM_ExtensionBase.Composite_GetSubExtensionClasses()
}

Query MenuItems(Classname As %String, MenuName As %String, InternalName As %String, SelectedText As %String) As %SQLQuery [ SqlProc ]
{
SELECT MenuItem_Name, MenuItem_Enabled, MenuItem_Save, MenuItem_Separator FROM %Studio_Extension.Menu_MenuItem WHERE Menu->MenuBase %INLIST %IPM_ExtensionBase.Composite_GetSubExtensionClasses() AND Menu->Name = :MenuName
}

Method AfterUserAction(Type As %Integer, Name As %String, InternalName As %String, Answer As %Integer, Msg As %String = "", ByRef Reload As %Boolean) As %Status
{
	New $Namespace
	Set InternalName = ##class(%IPM.ExtensionBase.Utils).CorrectInternalNames(InternalName)
	Set tExtension = $Select(Type:..GetPrimaryExtension(InternalName),1:..GetMenuExtension(Name,InternalName))
	If '$IsObject(tExtension) {
		Quit ##super(Type,.Name,.InternalName,.Answer,.Msg,.Reload)
	}
	Quit $Method(tExtension,"AfterUserAction",Type,Name,.InternalName,.Answer,.Msg,.Reload)
}

Method ExternalName(InternalName As %String) As %String
{
	New $Namespace
	Set InternalName = ##class(%IPM.ExtensionBase.Utils).CorrectInternalNames(InternalName)
	Set tExtension = ..GetPrimaryExtension(InternalName)
	If '$IsObject(tExtension) {
		Quit ##super(.InternalName)
	}
	Quit $Method(tExtension,"ExternalName",.InternalName)
}

Method GetStatus(InternalName As %String, ByRef IsInSourceControl As %Boolean, ByRef Editable As %Boolean, ByRef IsCheckedOut As %Boolean, ByRef UserCheckedOut As %String) As %Status
{
	New $Namespace
	Set InternalName = ##class(%IPM.ExtensionBase.Utils).CorrectInternalNames(InternalName)
	Set tExtension = ..GetPrimaryExtension(InternalName)
	If '$IsObject(tExtension) {
		Quit ##super(.InternalName,.IsInSourceControl,.Editable,.IsCheckedOut,.UserCheckedOut)
	}
	Set tStatus = $Method(tExtension,"GetStatus",.InternalName,.IsInSourceControl,.Editable,.IsCheckedOut,.UserCheckedOut)
	
	// Allow non-primary extensions to flag items as uneditable.
	// An item is editable only if all extensions allow editing.
	If $Namespace = ..Namespace {
		Set tKey = ""
		For {
			Set tSubExt = ..SubExtensions.GetNext(.tKey)
			If (tKey = "") {
				Quit
			}
			Set tSubSC = $Method(tSubExt,"GetStatus",.InternalName,,.tSubEditable)
			Set Editable = Editable && tSubEditable
			Set tStatus = $$$ADDSC(tStatus,tSubSC)
		}
	}
	
	Quit tStatus
}

ClassMethod IsGenerated(Name As %String) As %String
{
	Set tClass = ..GetPrimaryExtensionClass()
	If (tClass = "") {
		Quit ##super(.Name)
	}
	Quit $ClassMethod(tClass,"IsGenerated",.Name)
}

Method IsInSourceControl(InternalName As %String) As %Boolean
{
	New $Namespace
	Set InternalName = ##class(%IPM.ExtensionBase.Utils).CorrectInternalNames(InternalName)
	Set tExtension = ..GetPrimaryExtension(InternalName)
	If '$IsObject(tExtension) {
		Quit ##super(.InternalName)
	}
	Quit $Method(tExtension,"IsInSourceControl",.InternalName)
}

Method IsReadOnly(InternalName As %String) As %Boolean
{
	New $Namespace
	Set InternalName = ##class(%IPM.ExtensionBase.Utils).CorrectInternalNames(InternalName)
	Set tExtension = ..GetPrimaryExtension(InternalName)
	If '$IsObject(tExtension) {
		Quit ##super(.InternalName)
	}
	Set tIsReadOnly = $Method(tExtension,"IsReadOnly",.InternalName)
	If (tIsReadOnly) Quit 1
	
	If $Namespace = ..Namespace {
		Set tKey = ""
		For {
			Set tSubExt = ..SubExtensions.GetNext(.tKey)
			If (tKey = "") {
				Quit
			}
			Set tIsReadOnly = tIsReadOnly && $Method(tSubExt,"IsReadOnly",InternalName)
			If 'tIsReadOnly {
				Quit
			}
		}
	}
	
	Quit tIsReadOnly
}

Method ItemIconState(InternalName As %String) As %Integer
{
	New $Namespace
	Set InternalName = ##class(%IPM.ExtensionBase.Utils).CorrectInternalNames(InternalName)
	Set tExtension = ..GetPrimaryExtension(InternalName)
	If '$IsObject(tExtension) {
		Quit ##super(.InternalName)
	}
	Quit $Method(tExtension,"ItemIconState",.InternalName)
}

Method Login(Name As %String, Password As %String) As %Status
{
	// No-op for purposes of this extension; called in %OnNew for others.
	Quit $$$OK
}

Method Logout() As %Status
{
	Set tStatus = $$$OK
	Try {
		Set tStatus = ..ForEachExtension("Logout")
	} Catch e {
		Set tStatus = e.AsStatus()
	}
	Quit tStatus
}

ClassMethod OnAfterAllClassCompile(List As %String, Level As %Integer, ByRef qstruct As %String, Status As %Status) As %Status
{
	Set tClass = ..GetPrimaryExtensionClass()
	If (tClass = "") {
		Quit ##super(.List,.Level,.qstruct,.Status)
	}
	Quit $ClassMethod(tClass,"OnAfterAllClassCompile",.List,.Level,.qstruct,.Status)
}

Method OnAfterClassCompile(List As %String, Level As %Integer, ByRef qstruct As %String, Status As %Status) As %Status
{
	Set tExtension = ..GetPrimaryExtension()
	If '$IsObject(tExtension) {
		Quit ##super(.List,.Level,.qstruct,.Status)
	}
	Quit $Method(tExtension,"OnAfterClassCompile",.List,.Level,.qstruct,.Status)
}

Method OnAfterCompile(InternalName As %String) As %Status
{
	New $Namespace
	Set InternalName = ##class(%IPM.ExtensionBase.Utils).CorrectInternalNames(InternalName)
	Set tExtension = ..GetPrimaryExtension(InternalName)
	If '$IsObject(tExtension) {
		Quit ##super(.InternalName)
	}
	Quit $Method(tExtension,"OnAfterCompile",.InternalName)
}

Method OnAfterDelete(InternalName As %String) As %Status
{
	New $Namespace
	Set InternalName = ##class(%IPM.ExtensionBase.Utils).CorrectInternalNames(InternalName)
	Set tExtension = ..GetPrimaryExtension(InternalName)
	If '$IsObject(tExtension) {
		Quit ##super(.InternalName)
	}
	Quit $Method(tExtension,"OnAfterDelete",.InternalName)
}

Method OnAfterLoad(InternalName As %String, Object As %RegisteredObject = {$$$NULLOREF}) As %Status
{
	New $Namespace
	Set InternalName = ##class(%IPM.ExtensionBase.Utils).CorrectInternalNames(InternalName)
	Set tExtension = ..GetPrimaryExtension(InternalName)
	If '$IsObject(tExtension) {
		Quit ##super(.InternalName,.Object)
	}
	Quit $Method(tExtension,"OnAfterLoad",.InternalName,.Object)
}

Method OnAfterSave(InternalName As %String, Object As %RegisteredObject = {$$$NULLOREF}) As %Status
{
	New $Namespace
	Set InternalName = ##class(%IPM.ExtensionBase.Utils).CorrectInternalNames(InternalName)
	Set tExtension = ..GetPrimaryExtension(InternalName)
	If '$IsObject(tExtension) {
		Quit ##super(.InternalName,.Object)
	}
	Quit $Method(tExtension,"OnAfterSave",.InternalName,.Object)
}

Method OnAfterStorage(InternalName As %String, Location As %String = "") As %Status
{
	New $Namespace
	Set InternalName = ##class(%IPM.ExtensionBase.Utils).CorrectInternalNames(InternalName)
	Set tExtension = ..GetPrimaryExtension(InternalName)
	If '$IsObject(tExtension) {
		Quit ##super(.InternalName,.Location)
	}
	Quit $Method(tExtension,"OnAfterStorage",.InternalName,.Location)
}

ClassMethod OnBeforeAllClassCompile(List As %String, Level As %Integer, ByRef qstruct As %String) As %Status
{
	Set tClass = ..GetPrimaryExtensionClass()
	If (tClass = "") {
		Quit ##super(.List,.Level,.qstruct)
	}
	Quit $ClassMethod(tClass,"OnBeforeAllClassCompile",.List,.Level,.qstruct)
}

Method OnBeforeClassCompile(List As %String, Level As %Integer, ByRef qstruct As %String) As %Status
{
	Set tExtension = ..GetPrimaryExtension()
	If '$IsObject(tExtension) {
		Quit ##super(.List,.Level,.qstruct)
	}
	Quit $Method(tExtension,"OnBeforeClassCompile",.List,.Level,.qstruct)
}

Method OnBeforeCompile(InternalName As %String, ByRef qstruct As %String) As %Status
{
	New $Namespace
	Set InternalName = ##class(%IPM.ExtensionBase.Utils).CorrectInternalNames(InternalName)
	Set tExtension = ..GetPrimaryExtension(InternalName)
	If '$IsObject(tExtension) {
		Quit ##super(.InternalName,.qstruct)
	}
	Quit $Method(tExtension,"OnBeforeCompile",.InternalName,.qstruct)
}

Method OnBeforeDelete(InternalName As %String) As %Status
{
	New $Namespace
	Set InternalName = ##class(%IPM.ExtensionBase.Utils).CorrectInternalNames(InternalName)
	Set tExtension = ..GetPrimaryExtension(InternalName)
	If '$IsObject(tExtension) {
		Quit ##super(.InternalName)
	}
	Quit $Method(tExtension,"OnBeforeDelete",.InternalName)
}

Method OnBeforeLoad(InternalName As %String) As %Status
{
	New $Namespace
	Set InternalName = ##class(%IPM.ExtensionBase.Utils).CorrectInternalNames(InternalName)
	Set tExtension = ..GetPrimaryExtension(InternalName)
	If '$IsObject(tExtension) {
		Quit ##super(.InternalName)
	}
	Quit $Method(tExtension,"OnBeforeLoad",.InternalName)
}

Method OnBeforeSave(InternalName As %String, Location As %String = "", Object As %RegisteredObject = {$$$NULLOREF}) As %Status
{
	New $Namespace
	Set InternalName = ##class(%IPM.ExtensionBase.Utils).CorrectInternalNames(InternalName)
	Set tExtension = ..GetPrimaryExtension(InternalName)
	If '$IsObject(tExtension) {
		Quit ##super(.InternalName,.Location,.Object)
	}
	Quit $Method(tExtension,"OnBeforeSave",.InternalName,.Location,.Object)
}

Method OnBeforeTimestamp(InternalName As %String)
{
	New $Namespace
	Set InternalName = ##class(%IPM.ExtensionBase.Utils).CorrectInternalNames(InternalName)
	Set tExtension = ..GetPrimaryExtension(InternalName)
	If '$IsObject(tExtension) {
		Do ##super(.InternalName)
		Quit
	}
	Do $Method(tExtension,"OnBeforeTimestamp",.InternalName)
}

Method OnMenuItem(MenuName As %String, InternalName As %String, SelectedText As %String, ByRef Enabled As %Boolean, ByRef DisplayName As %String) As %Status
{
	New $Namespace
	Set InternalName = ##class(%IPM.ExtensionBase.Utils).CorrectInternalNames(InternalName)
	Set tExtension = ..GetMenuExtension(MenuName,InternalName)
	If '$IsObject(tExtension) {
		Quit ##super(MenuName,InternalName,SelectedText,.Enabled,.DisplayName)
	}
	Quit $Method(tExtension,"OnMenuItem",MenuName,InternalName,SelectedText,.Enabled,.DisplayName)
}

Method UserAction(Type As %Integer, Name As %String, InternalName As %String, SelectedText As %String, ByRef Action As %String, ByRef Target As %String, ByRef Msg As %String, ByRef Reload As %Boolean) As %Status
{
	New $Namespace
	Set InternalName = ##class(%IPM.ExtensionBase.Utils).CorrectInternalNames(InternalName)
	Set tExtension = $Select(Type:..GetPrimaryExtension(InternalName),1:..GetMenuExtension(Name,InternalName))
	If '$IsObject(tExtension) {
		Quit ##super(Type,Name,.InternalName,.SelectedText,.Action,.Target,.Msg,.Reload)
	}
	Quit $Method(tExtension,"UserAction",Type,Name,.InternalName,.SelectedText,.Action,.Target,.Msg,.Reload)
}

/// Dispatch unknown class methods to primary extension class.
ClassMethod %DispatchClassMethod(Class As %String, Method As %String, Args...) [ ServerOnly = 1 ]
{
	Set tPrimaryClass = ..GetPrimaryExtensionClass()
	If (tPrimaryClass '= "") {
		If $Quit {
			Quit $ClassMethod(tPrimaryClass,Method,Args...)
		} Else {
			Do $ClassMethod(tPrimaryClass,Method,Args...)
		}
	}
}

/// Dispatch unknown methods to primary extension class.
Method %DispatchMethod(Method As %String, Args...) [ ServerOnly = 1 ]
{
	Set tExtension = ..GetPrimaryExtension()
	If $IsObject(tExtension) {
		If $Quit {
			Quit $Method(tExtension,Method,Args...)
		} Else {
			Do $Method(tExtension,Method,Args...)
		}
	}
}

}
