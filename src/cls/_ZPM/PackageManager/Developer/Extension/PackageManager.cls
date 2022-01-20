Include %ZPM.PackageManager.Common

/// Overlay %Studio.SourceControl.ISC with this extension's capabilities by running:
/// <code>
/// Write ##class(%Studio.SourceControl.Interface).SourceControlClassSet("%ZPM.PackageManager.Developer.Extension.Composite")
/// Write ##class(%ZPM.PackageManager.Developer.Extension.Composite).SetExtensionClasses("%ZPM.PackageManager.Developer.Extension.SourceControl.ISC",$ListBuild("%ZPM.PackageManager.Developer.Extension.PackageManager"))
/// </code>
Class %ZPM.PackageManager.Developer.Extension.PackageManager Extends (%Studio.Extension.Base, %ZPM.PackageManager.Developer.Extension.Constants)
{

/// TODO: Change to module-specific domain (and ensure proper global mappings configured)
Parameter DOMAIN = "ZPM";

/// Stores an array of document names for which a warning has already been issued in GetStatus.
/// Used to avoid repetitive/duplicate notifications in the console log/output window.
/// This will not work for Atelier over (stateless) REST APIs, but Atelier's different client behavior
/// will have a similar effect (because it calls GetStatus very infrequently compared to Studio).
Property SnapshotMessageWarned [ MultiDimensional ];

XData Menu
{
<MenuBase>
<Menu Name="%PackageMain" Type="0">
<MenuItem Name="%AddToModule" Save="100" />
<MenuItem Name="%OpenModule" Save="100" />
<MenuItem Name="%EditModuleWizard" Save="100" />
<MenuItem Name="%EditCustomDocType" Save="100" />
<MenuItem Name="%ModuleItems" Separator="1" />
<MenuItem Name="%Lifecycle\\%Custom" Save="111" />
<MenuItem Name="%Lifecycle\\%Validate" Save="111" />
<MenuItem Name="%Lifecycle\\%Compile" Save="111" />
<MenuItem Name="%Lifecycle\\%Document" Save="111" />
<MenuItem Name="%Lifecycle\\%Test" Save="111" />
<MenuItem Name="%Lifecycle\\%Verify" Save="111" />
<MenuItem Name="%DependencyCheck" Save="100" />
<MenuItem Name="%StudioProject" Save="111" />
<MenuItem Separator="1" />
<MenuItem Name="%LoadNewModule" Save="000" />
<MenuItem Name="%GetSoftware" />
<MenuItem Name="%RepositorySettings" />
<MenuItem Name="%PackageManagerSettings" />
<MenuItem Name="%SourceControlSettings" />
</Menu>
<Menu Name="%PackageContext" Type="1">
<MenuItem Name="%AddToModule" Save="100" />
<MenuItem Name="%OpenModule" Save="100" />
<MenuItem Name="%EditModuleWizard" Save="100" />
<MenuItem Name="%ModuleItems" Separator="1" />
<MenuItem Name="%Clean" Save="111" />
<MenuItem Name="%Reload" Save="111" />
<MenuItem Name="%Validate" Save="111" />
<MenuItem Name="%Compile" Save="111" />
<MenuItem Name="%Activate" Save="111" />
<MenuItem Name="%Document" Save="111" />
<MenuItem Name="%Test" Save="111" />
<MenuItem Name="%Package" Save="111" />
<MenuItem Name="%Verify" Save="111" />
<MenuItem Name="%Register" Save="111" />
<MenuItem Name="%Publish" Save="111" />
</Menu>
</MenuBase>
}

Method GetModuleForInternalName(InternalName As %String, Output pIsModule As %Boolean = 0, Output pInModule As %Boolean = 0, Output pExplicitlyListed As %Boolean = 0) As %ZPM.PackageManager.Developer.Module [ Private ]
{
	Set tModule = $$$NULLOREF
	Set tExt = $ZCVT($Piece(InternalName,".",*),"U")
	Set pIsModule = (tExt = "MODULE")
	If pIsModule {
		If ##class(%ZPM.PackageManager.Developer.Module).NameExists($Piece(InternalName,".",1,*-1)) {
			Set tModule = ##class(%ZPM.PackageManager.Developer.Module).NameOpen($Piece(InternalName,".",1,*-1),,.tSC)
			$$$ThrowOnError(tSC)
		}
	} Else {
		Set tModule = ##class(%ZPM.PackageManager.Developer.Extension.Utils).FindHomeModule(InternalName)
		If $IsObject(tModule) {
			Set pInModule = 1
			Set pExplicitlyListed = ##class(%ZPM.PackageManager.Developer.ResourceReference).ResourceNameExists(InternalName)
		}
	}
	Quit tModule
}

Method OnMenuItem(MenuName As %String, InternalName As %String, SelectedText As %String, ByRef Enabled As %Boolean, ByRef DisplayName As %String) As %Status
{
	#dim tModule As %ZPM.PackageManager.Developer.Module
	Set tSC = $$$OK
	Try {
		Set tExtension = $Piece(InternalName,".",*)
		Set tIsLocked = 1
		Set tModuleEditable = 0
		Set tExplicitlyListed = 0
		
		Set tModule = ..GetModuleForInternalName(InternalName,.tIsModule,.tInModule,.tExplicitlyListed)		
		If $IsObject(tModule) {
			Set tIsLocked = tModule.IsLocked()
		}
		Set tLifecycleVisible = $Select(tIsModule||tInModule:'tIsLocked,1:-1)
		Set tHasName = $Case(InternalName,"":0,:1)
		Set tSCSettingsPageExists = (##class(%ZPM.PackageManager.Developer.Extension.SourceControl.Interface).%GetPage() '= "")
		Set tClientIsAtelier = ..StudioVersion [ "Atelier"
		Set tIsCustomDocType = (tExtension = "LOC") // This is the only one we support for now.
		Set tCustomDocEditable = tIsCustomDocType && ..CheckEditable(InternalName)
		
		// Atelier does not support nested submenus (ATL-3897); flatten top-level lifecycle menu into the main one.
		Set tLifecyclePrefix = $Select(tClientIsAtelier:"",1:$$$Text("Module Lifecycle")_"\\")
		Set $ListBuild(Enabled,DisplayName) = $Case(MenuName,
			"%PackageMain":$ListBuild(1,$$$Text("Package Manager")),
			"%PackageContext":$ListBuild(1,$$$Text("Package Manager")),
			
			"%PackageMain,%AddToModule":$ListBuild($Select(tHasName:'tExplicitlyListed,1:0),$$$Text("Add to Module...")),
			"%PackageMain,%LoadNewModule":$ListBuild(1,$$$Text("Load Local Module...")),
			"%PackageMain,%OpenModule":$ListBuild(tInModule,$Select(tInModule:$$$FormatText($$$Text("Open Module '%1'"),tModule.Name),1:$$$Text("Open Module..."))),
			"%PackageMain,%EditModuleWizard":$ListBuild(tModuleEditable,$Select(tInModule||tIsModule:$$$FormatText($$$Text("Module Wizard - %1"),tModule.Name),1:$$$Text("Module Wizard..."))),
			"%PackageMain,%EditCustomDocType":$ListBuild($Select(tCustomDocEditable:1,tIsCustomDocType:0,1:-1),$$$FormatText($$$Text("Edit '%1'"),InternalName)),
			"%PackageMain,%ModuleItems":$ListBuild(1,""),
			"%PackageMain,%Lifecycle\\%Custom":$ListBuild(tLifecycleVisible,tLifecyclePrefix_$$$Text("Custom...")),
			"%PackageMain,%Lifecycle\\%Clean":$ListBuild(tLifecycleVisible,tLifecyclePrefix_$$$Text("Clean")),
			"%PackageMain,%Lifecycle\\%Reload":$ListBuild(tLifecycleVisible,tLifecyclePrefix_$$$Text("Reload")),
			"%PackageMain,%Lifecycle\\%Validate":$ListBuild(tLifecycleVisible,tLifecyclePrefix_$$$Text("Validate")),
			"%PackageMain,%Lifecycle\\%Compile":$ListBuild(tLifecycleVisible,tLifecyclePrefix_$$$Text("Compile")),
			"%PackageMain,%Lifecycle\\%Activate":$ListBuild(tLifecycleVisible,tLifecyclePrefix_$$$Text("Activate")),
			"%PackageMain,%Lifecycle\\%Document":$ListBuild(tLifecycleVisible,tLifecyclePrefix_$$$Text("Generate Documentation")),
			"%PackageMain,%Lifecycle\\%Test":$ListBuild(tLifecycleVisible,tLifecyclePrefix_$$$Text("Test")),
			"%PackageMain,%Lifecycle\\%Package":$ListBuild(tLifecycleVisible,tLifecyclePrefix_$$$Text("Package")),
			"%PackageMain,%Lifecycle\\%Verify":$ListBuild(tLifecycleVisible,tLifecyclePrefix_$$$Text("Verify")),
			"%PackageMain,%Lifecycle\\%Register":$ListBuild(tLifecycleVisible,tLifecyclePrefix_$$$Text("Register")),
			"%PackageMain,%Lifecycle\\%Publish":$ListBuild(tLifecycleVisible,tLifecyclePrefix_$$$Text("Publish")),
			"%PackageMain,%DependencyCheck":$ListBuild(tLifecycleVisible,$$$Text("Dependency Analyzer")),
			"%PackageMain,%StudioProject":$ListBuild(tLifecycleVisible&&'tClientIsAtelier,$$$Text("Create/Update Studio Project")),
			"%PackageMain,%GetSoftware":$ListBuild(1,$$$Text("Install Software...")),
			"%PackageMain,%RepositorySettings":$ListBuild(1,$$$Text("Repositories...")),
			"%PackageMain,%PackageManagerSettings":$ListBuild(1,$$$Text("Configuration...")),
			"%PackageMain,%SourceControlSettings":$ListBuild($Select(tSCSettingsPageExists:1,1:-1),$$$Text("Source Control Settings...")),
			
			"%PackageContext,%AddToModule":$ListBuild($Select(tHasName:'tExplicitlyListed,1:0),$$$Text("Add to Module...")),
			"%PackageContext,%OpenModule":$ListBuild(tInModule,$Select(tInModule:$$$FormatText($$$Text("Open Module '%1'"),tModule.Name),1:$$$Text("Open Module..."))),
			"%PackageContext,%EditModuleWizard":$ListBuild(tModuleEditable,$Select(tInModule||tIsModule:$$$FormatText($$$Text("Module Wizard - %1"),tModule.Name),1:$$$Text("Module Wizard..."))),
			"%PackageContext,%ModuleItems":$ListBuild(tLifecycleVisible,""),
			"%PackageContext,%Clean":$ListBuild(tLifecycleVisible,$$$Text("Clean")),
			"%PackageContext,%Reload":$ListBuild(tLifecycleVisible,$$$Text("Reload")),
			"%PackageContext,%Validate":$ListBuild(tLifecycleVisible,$$$Text("Validate")),
			"%PackageContext,%Compile":$ListBuild(tLifecycleVisible,$$$Text("Compile")),
			"%PackageContext,%Activate":$ListBuild(tLifecycleVisible,$$$Text("Activate")),
			"%PackageContext,%Document":$ListBuild(tLifecycleVisible,$$$Text("Generate Documentation")),
			"%PackageContext,%Test":$ListBuild(tLifecycleVisible,$$$Text("Test")),
			"%PackageContext,%Package":$ListBuild(tLifecycleVisible,$$$Text("Package")),
			"%PackageContext,%Verify":$ListBuild(tLifecycleVisible,$$$Text("Verify")),
			"%PackageContext,%Register":$ListBuild(tLifecycleVisible,$$$Text("Register")),
			"%PackageContext,%Publish":$ListBuild(tLifecycleVisible,$$$Text("Publish")),
			:$ListBuild(1,MenuName))
	} Catch e {
		Set tSC = e.AsStatus()
		
		// Log exceptions that occur, as they're otherwise silent.
		Do e.Log()
	}
	Quit tSC
}

Method UserAction(Type As %Integer, Name As %String, InternalName As %String, SelectedText As %String, ByRef Action As %String = {..#ActionDoNothing}, ByRef Target As %String = "", ByRef Msg As %String = "", ByRef Reload As %Boolean = 0) As %Status
{
	If (Type = ..#OtherEditorActionType) Quit $$$OK
	
	Set tSC = $$$OK
	Try {
		Set tEspNamespace = $ZConvert($Namespace,"O","URL")
		Set tEspInternalName = $ZConvert(InternalName,"O","URL")
		Set tExt = $ZCVT($Piece(InternalName,".",*),"U")
		Set tModule = ..GetModuleForInternalName(InternalName,.tIsModule,.tInModule)
		Set tPage = $Case(Name,
			"%PackageMain,%AddToModule":"&Name="_tEspInternalName_"&Page=Add",
			"%PackageMain,%Lifecycle\\%Publish":"&Name="_tModule.Name_".MODULE"_"&Page=Publish",
			"%PackageMain,%GetSoftware":"&Page=GetSoftware",
			"%PackageMain,%RepositorySettings":"&Page=Settings",
			"%PackageContext,%AddToModule":"&Name="_tEspInternalName_"&Page=Add",
			"%PackageContext,%Publish":"&Name="_tModule.Name_".MODULE"_"&Page=Publish",
			:"")
		If (tPage '= "") {
			Set Action = ..#ActionRunCSP
			Set Target = "/isc/studio/templates/%25ZPM.PackageManager.Developer.Extension.PackageManager.UI.Index.cls?$NAMESPACE="_tEspNamespace_tPage
		} ElseIf (Name="%PackageMain,%OpenModule") || (Name="%PackageContext,%OpenModule") {
			Set Action = ..#ActionOpenDocuments
			Set Target = tModule.Name_".MODULE"
		} ElseIf (Name="%PackageMain,%PackageManagerSettings") {
			Set Action = ..#ActionRunCSP
			Set Target = "/isc/studio/templates/%25ZPM.PackageManager.Developer.Extension.PackageManager.UI.Configuration.cls?$NAMESPACE="_tEspNamespace
		} ElseIf (Name="%PackageMain,%LoadNewModule") {
			Set Action = ..#ActionRunCSP
			Set Target = "/isc/studio/templates/%25ZPM.PackageManager.Developer.Extension.PackageManager.UI.LoadNewModule.cls?$NAMESPACE="_tEspNamespace_"&showdirectoryonly=0&File=module.xml"
		} ElseIf (Name = "%PackageMain,%StudioProject") {
			Set tSC = tModule.GetStudioProject(.tProject)
			If $$$ISERR(tSC) {
				Write !,$System.Status.GetErrorText(tSC)
				Quit
			}
			Set tProject = tProject.Name_".PRJ"
			// It would be nice if Studio supported opening a project other than with "Open Project..." or the Open dialog with the .PRJ extension.
			// It doesn't, and it probably won't ever, but if it did, this would work:
			/*
			Set Action = ..#ActionOpenDocuments
			Set Target = tProject
			*/
			Write !,"Studio project created/updated:"
			Write !,tProject
		} ElseIf (Name = "%PackageMain,%DependencyCheck") {
			Set Action = ..#ActionRunCSP
			Set Target = "/isc/studio/templates/%25ZPM.PackageManager.Developer.Extension.PackageManager.UI.DependencyAnalyzer.cls?$NAMESPACE="_tEspNamespace_"&ModuleName="_$ZConvert(tModule.Name,"O","URL")
		} ElseIf (Name = "%PackageMain,%SourceControlSettings") {
			Set Action = ..#ActionRunCSP
			Set Target = "/isc/studio/templates/"_$ZConvert(##class(%ZPM.PackageManager.Developer.Extension.SourceControl.Interface).%GetPage(),"O","URL")_"?$NAMESPACE="_tEspNamespace
		} ElseIf (Name = "%PackageMain,%EditModuleWizard") || (Name="%PackageContext,%EditModuleWizard")  {
			Set Action = ..#ActionRunCSP
			Set Target = "/isc/studio/templates/%25ZPM.PackageManager.Developer.Extension.PackageManager.UI.ModuleWizard.cls?$NAMESPACE="_tEspNamespace_"&InternalName="_$ZConvert(tModule.Name_".MODULE","O","URL")
		} ElseIf (Name = "%PackageMain,%EditCustomDocType") {
			Set Action = ..#ActionRunCSP
			Set Target = "/isc/studio/templates/%25ZPM.PackageManager.Developer.Extension.PackageManager.UI.LocalizationDocWizard.cls?$NAMESPACE="_tEspNamespace_"&InternalName="_$ZConvert(InternalName,"O","URL")
		} ElseIf (Name [ "%Custom") {
			Set Action = ..#ActionRunCSP
			Set Target = "/isc/studio/templates/%25ZPM.PackageManager.Developer.Extension.PackageManager.UI.Lifecycle.cls?$NAMESPACE="_tEspNamespace_"&InternalName="_$ZConvert(tModule.Name_".MODULE","O","URL")
		} Else {
			Set tModuleName = tModule.Name
			If (Name [ "\\") {
				Set tPhaseName = $Piece(Name,"\\%",*)
			} Else {
				Set tPhaseName = $Piece(Name,"%",3)
			}
			Set tParams("Verbose") = 1
			
			// For Verify, Register, and Publish, ensure that Package occurs first.
			Set tPhaseList = $ListBuild(tPhaseName)
			If $ListFind($ListBuild("Verify","Register","Publish"),tPhaseName) {
				Set tPhaseList = $ListBuild("Package")_tPhaseList
			}
			
			Set tSC = ##class(%ZPM.PackageManager.Developer.Module).ExecutePhases(tModuleName,tPhaseList,0,.tParams)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method AfterUserAction(Type As %Integer, Name As %String, InternalName As %String, Answer As %Integer, Msg As %String = "", ByRef Reload As %Boolean = 0) As %Status
{
	$$$ZPMExtensionOutputGet(tOutput)
	For tLine=1:1:$Get(tOutput) {
		Write tOutput(tLine),!
	}
	$$$ZPMExtensionOutputClear
	Quit $$$OK
}

/// Return information about this entity.
Method GetStatus(InternalName As %String, ByRef IsInSourceControl As %Boolean, ByRef Editable As %Boolean, ByRef IsCheckedOut As %Boolean, ByRef UserCheckedOut As %String) As %Status
{
	// This isn't a source control extension - don't do anything unusual with those flags.
	Set IsCheckedOut=0,UserCheckedOut="",IsInSourceControl=0
	
	// However, this extension may flag certain items as non-editable - particularly, if they are part of a locked module.
	// If an item is not part of any module, then it is editable by default.
	Set tSC = ##class(%ZPM.PackageManager.Developer.ResourceReference).GetStatus(InternalName,,.Editable,,.tMessage)
	
	// Possibly display a warning message (once per session/document unless the message changes)
	// If ..StudioVersion is empty, this instance of %SourceControl was created programatically outside of
	// Studio/Atelier, so no output should be shown.
	If (InternalName '= "") && (..StudioVersion '= "") { // Prevent <SUBSCRIPT>, just in case.
		If $Get(..SnapshotMessageWarned(InternalName)) '= tMessage {
			Set ..SnapshotMessageWarned(InternalName) = tMessage
			If (tMessage '= "") {
				Write !,tMessage
			}
		}
	}
	Quit tSC
}

ClassMethod CheckEditable(pInternalName As %String) As %Boolean [ Private ]
{
	New %SourceControl
	$$$ThrowOnError(##class(%Studio.SourceControl.Interface).SourceControlCreate())
	$$$ThrowOnError(##class(%Studio.SourceControl.Interface).GetStatus(pInternalName,,.tEditable))
	Quit tEditable
}

}
