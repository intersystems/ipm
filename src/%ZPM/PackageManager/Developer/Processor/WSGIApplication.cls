Include (%sySecurity, %occErrors)

Class %ZPM.PackageManager.Developer.Processor.WSGIApplication Extends %ZPM.PackageManager.Developer.Processor.CSPApplication
{

Parameter ATTRIBUTES = {""_
	// Not in any version of %Installer.CSPApplication (and probably shouldn't be)
	"PasswordAuthEnabled,UnauthenticatedEnabled,DelegatedAuthEnabled,KerberosAuthEnabled,LoginTokenEnabled,"_
	
	// Not in any version of %Installer.CSPApplication (but maybe should be)
	"Enabled,DeepSeeEnabled,iKnowEnabled,"_
	
	// Not in all reasonably modern versions of %Installer.CSPApplication
	"DispatchClass,MatchRoles,"_ 

    // Specific to WSGI Applications. More attributes may be coming in the future.
 	"WSGIAppLocation,WSGIAppName,WSGICallable," _ 

	// Url is the most important attribute and must be set
    "Url"};

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Facilitates WSGI application definition/configuration during module installation process.";

/// Overridden to avoid issues in %Installer generation
Parameter XMLNAME = "ZPMWSGIApplication";

/// Overridden to avoid issues in %Installer generation
Parameter XMLTYPE = "ZPMWSGIApplication";

/// If defined, this will dispatch all requests in this CSP application to this one class
Property DispatchClass As %String(MAXLEN = 256) [ InitialExpression = "%SYS.Python.WSGI" ];

/// URL for the WSGI application
Property Url As %String(MAXLEN = 1024) [ Required ];

/// This is the path of the directory containing the python application
Property WSGIAppLocation As %String(MAXLEN = 256);

/// This is the name of the WSGI-compliant python application (e.g flask_app)
Property WSGIAppName As %String(MAXLEN = 256);

/// This is the name of the WSGI application callable.
Property WSGICallable As %String(MAXLEN = 256) [ InitialExpression = "app" ];

}
