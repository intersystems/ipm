/// This class contains general package manager settings that are configurable via the Package Manager > Configuration
/// section of the Studio extension.
Class %IPM.General.Settings Extends %IPM.General.AbstractSettings
{

Parameter DEFAULTGLOBAL = "^IPM.General.Settings";

/// A string to show in the grouping of settings for this class
Parameter DESCRIPTION = "General Package Manager Settings";

/// Whether to suppress compilation upon clicking the 'Compile' icon.
/// When compilation is suppressed, clicking the icon will save the file
/// rather than compile it.
Property SuppressCompilation As %Boolean [ InitialExpression = 1 ];

Property Key As %String [ InitialExpression = "PackageManager", ReadOnly ];

/// The <var>MANAGEDEXTENT</var> parameter can be set to 0 (zero) to cause the Extent Manager
/// to ignore this class. If set to 1 then the Extent Manager will register globals used by
/// the class and detect collisions. Unmanaged extents (MANAGEDEXTENT = 0) are not checked.
/// Currently, only classes using default storage (%Storage.Persistent) can be managed.
Parameter MANAGEDEXTENT As INTEGER [ Constraint = "0,1", Flags = ENUM ] = 0;

Storage Default
{
<Data name="SettingsDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>SuppressCompilation</Value>
</Value>
</Data>
<DataLocation>^IPM.General.SettingsD</DataLocation>
<DefaultData>SettingsDefaultData</DefaultData>
<IdLocation>^IPM.General.SettingsD</IdLocation>
<IndexLocation>^IPM.General.SettingsI</IndexLocation>
<StreamLocation>^IPM.General.SettingsS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
