/// Abstract base class that defines the interface for product-level
/// Installer.Install classes.
Class %ZPM.AbstractInstaller [ Abstract ]
{

Parameter Version [ Abstract ];

Parameter MaintenanceVersion;

/// Callback that is invoked during product installation to allow for
/// system-level changes to be performed. Common examples of such changes include:
/// <ul>
/// <li>Definition of resources and roles</li>
/// <li>Definition/configuration of the product library database</li>
/// <li>Import of localized messages for the product</li>
/// </ul>
/// Subclasses SHOULD override this method.
ClassMethod OnInstallComponent(pDatabase As %String, pVerbose As %Boolean = 0, pDevMode As %Boolean = 0, pIsUpgrade As %Boolean = 0) As %Status
{
	Quit $$$OK
}

/// Callback that is invoked when removing a product.
ClassMethod OnUnInstallComponent(pDatabase As %String, pVerbose As %Boolean = 0) As %Status
{
	Quit $$$OK
}

/// Callback to return the major version of the component. This implementation uses the <parameter>Version</parameter>, 
/// which must by implemented by the installer subclass (or else the subclass must override this method using some other approach). 
/// If not overridden, and the Version parameter is not populated, this method will throw an exception (not merely return an error status). 
/// <var>pMajorVersion</var> is generally set to the value of a product-level macro which defines
/// the major version, e.g. <code>$$$HSLIBmajorVersion</code> for PackageManager Core.
ClassMethod OnComponentVersion(Output pMajorVersion As %Integer) As %Status
{
	
	kill pMajorVersion
	Set pMajorVersion = ..#Version
	if pMajorVersion = "" {
		$$$ThrowStatus($$$ERROR($$$NotImplemented))
	}
	Quit $$$OK
}

/// Callback to return the minor version of the component. This implementation uses the <parameter>MaintenanceVersion</parameter>, 
/// which must by implemented by the installer subclass (or else the subclass must override this method using some other approach). 
/// If not overridden, and the Version parameter is not populated, this method will throw an exception (not merely return an error status). 
/// <var>pMinorVersion</var> is generally set to the value of a product-level macro which defines
/// the minor version, e.g. <code>$$$HSLIBminorVersion</code> for PackageManager Core.
ClassMethod OnComponentMaintenanceVersion(Output pMinorVersion As %String) As %Status
{
	kill pMinorVersion
	Set pMinorVersion = ..#MaintenanceVersion
	if pMinorVersion = "" {
		$$$ThrowStatus($$$ERROR($$$NotImplemented))
	}
	Quit $$$OK
}

/// <p>Callback that is invoked during namespace (re)activation.
/// Subclasses SHOULD override this method. </p><p>
/// pVars is an array of miscellaneous information, populated by the calling code in the installation/configuration 
/// framework (mainly <class>HS.Util.Installer</class>). 
/// Subscripts appearing in pVars include: </p>
/// <ul><li>
/// Production - set to (namespace)_"PKG.FoundationProduction"
/// </li><li>
/// LogFile - current log file for install operation 
/// </li><li>
/// Upgrade - boolean, indicating whether the current operation is an upgrade
/// </li><li>
/// Type - hardcoded to "Foundation"
/// </li><li>
/// Component - current component name
/// </li></ul>
ClassMethod OnConfigureComponent(pNamespace As %String, pVerbose As %Boolean = 0, ByRef pVars) As %Status
{
	Quit $$$OK
}

/// Callback that is invoked when removing a product from a namespace.
/// Subclasses SHOULD override this method.
ClassMethod OnUnconfigureComponent(pNamespace As %String, pVerbose As %Boolean = 0, pPurgeFiles As %Boolean = 0, ByRef pVars) As %Status
{
	Quit $$$OK
}

/// What to do system wide (not specific namespaces) during an upgrade. Not currently called by the framework, but present for future use. 
ClassMethod OnUpgradeSteps(pPreviousVersion As %String) As %Status
{
	// note: if we adopt this then we may need to revisit the argument list - pPreviousVersion is ambiguous about major/minor
	set tSC = $$$OK
	
	try {
	} catch ex {
		Set tSC=ex.AsStatus()
	}
	
	quit tSC
}

/// XML block that should contain XML for a <class>%ZPM.Component</class>
/// instance that describes the current component.
/// Note that this XML may make use of the following expressions that will be substituted during parsing:
/// <ul>
/// <li><code>{$expression{COSExpression}}</code></li>
/// <li><code>{$method{COSExpression}}</code></li>
/// </ul>
/// Where <code>COSExpression</code> is a valid expression.
/// An example of such an expression would be as follows:
/// <example language="none">
/// &lt;Version>{$expression{$parameter("Installer.Install","Version")}}&lt;/Version>
/// </example>
XData InstallationInfo
{
}

}
