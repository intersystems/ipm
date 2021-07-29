ROUTINE %ZPM.PackageManager.Common [Type=INC]
#; Helper for XML import of documents
#define ZPMStudioDocumentModule %ZPMStudioDocumentModule

#; Local % Variable to track modules already handled for a given end goal
#define ZPMHandledModules %ZZPMHandledModules

#; Local % Variable to indicate that ^Sources update trigger should not be run for modifications to individual resources
#define ZPMDeferModifyResources %ZZPMDeferModifyResources

#; Default packages for package manager, module lifecycle classes and resource processors
#define ZPMRootPackage "%ZPM.PackageManager"

#define DefaultLifecyclePackage $$$ZPMRootPackage_".Developer.Lifecycle"
#define DefaultLifecyclePackageDot $$$DefaultLifecyclePackage_"."
#define DefaultProcessorPackage $$$ZPMRootPackage_".Developer.Processor"
#define DefaultProcessorPackageDot $$$DefaultProcessorPackage_"."

#; Various globals
#define ZPMConfig ^ZPM.Config
#define ZPMTempLoadGraphRoot ^CacheTemp.PackageManagerLoad
#def1arg ZPMTempLoadGraph(%subscripts) ^CacheTemp.PackageManagerLoad(%subscripts)
#define ZPMDependencyTempData ^CacheTemp.ZZPMDependency
#define ZPMDependencyTempDataNext $Increment($$$ZPMDependencyTempData)
#define ZPMDefaultModifiers ^%ZPM.DefaultModifiers

#; Temp global used to store source control output from CSP pages to be shown in Studio/Atelier console
#define ZPMExtensionOutput ^CacheTemp.ZPMExtensionOutput($Username,$Namespace)
#define ZPMExtensionOutputClear Kill $$$ZPMExtensionOutput
#define ZPMExtensionOutputSet(%array) $$$ZPMExtensionOutputClear Merge $$$ZPMExtensionOutput = %array
#define ZPMExtensionOutputGet(%array) Merge %array = $$$ZPMExtensionOutput

#; Log levels
#define ZPMLogTRACE		0
#define ZPMLogINFO			1
#define ZPMLogWARNING		2
#define ZPMLogERROR		3

#; System method/special variable wrappers
#define InProgrammerMode ##class(%SYSTEM.Process).IsProgrammerMode()

#; Perforce-related macros
#define ZPMStripP4Dots(%in) $Case($Extract(%in,*-2,*),"...":$Extract(%in,1,*-3),1:%in)
#define ZPMP4HostStatus(%host) ^CacheTemp.ZZPMP4HostStatus(%host)

#; CLI tools
#define HasModifier(%array,%x) ''$Data(%array("modifiers",%x))
#define GetModifier(%array,%x) $Get(%array("modifiers",%x))
#define GetModifierDef(%array,%x,%y) $Get(%array("modifiers",%x),%y)
#define YesNo(%val) $Select(%val:$$$Text("Yes"),1:$$$Text("No"))

#; Copied from HS.JSON.INC
#include %occReference
#if $$$comClassDefined("%Library.Object")
    #def1arg JsonMethodClassIsLatestVersion(%arg) $classIsLatestVersion(%arg)
    						//usage: obj.$$$JsonClassIsLatestVersion()
    #def1arg JsonMethodExtends(%arg) $extends(%arg)
    						//usage: {}.$$$JsonExtends(classname) 
	#def1arg JsonMethodFromJSON(%arg) $fromJSON(%arg)
    						//usage: {}.$$$JsonFromJSON(string) 
    #def1arg JsonMethodGetIterator(%arg) $getIterator(%arg)
    						//usage: obj.$$$JsonGetIterator()
    #def1arg JsonMethodGetNext(%arg) $getNext(%arg)
    						//usage: iterator.$$$JsonGetNext(.key, .value)
    #def1arg JsonMethodIsA(%arg) $isA(%arg)
    						//usage: obj.$$$JsonIsA(classname)
    #def1arg JsonMethodToJSON(%arg) $toJSON(%arg)
    						//usage: obj.$$$JsonToJSON()
    #def1arg JsonMethodGet(%arg) $get(%arg)
    						//usage: obj.$$$JsonGet(key)
    #def1arg JsonMethodGetTypeOf(%arg) $getTypeOf(%arg)
    						//usage: obj.$$$JsonMethodGetTypeOf(key)
    #def1arg JsonMethodIsDefined(%arg) $isDefined(%arg)
    						//usage: obj.$$$JsonIsDefined(key) 
    #def1arg JsonMethodRemove(%arg) $remove(%arg)
    						//usage: obj.$$$JsonRemove(key)
    #def1arg JsonMethodSet(%arg) $set(%arg)
    						//usage: obj.$$$JsonSet(key, val)
    #def1arg JsonMethodSize(%arg) $size(%arg)
    						// usage: obj.$$$JsonSize()
    #def1arg JsonMethodPop(%arg) $pop(%arg)
    						//usage: obj.$$$JsonPop()
    #def1arg JsonMethodPush(%arg) $push(%arg)
    						//usage: obj.$$$JsonPush(val)
	#define JsonClassAbstract %Library.AbstractObject
	#define JsonClassObject %Library.Object
	#define JsonClassArray %Library.Array
#else
    #def1arg JsonMethodClassIsLatestVersion(%arg) %ClassIsLatestVersion(%arg)
    						//usage: obj.$$$JsonClassIsLatestVersion()
    #def1arg JsonMethodExtends(%arg) %Extends(%arg)
    						//usage: {}.$$$JsonExtends(classname) 
    #def1arg JsonMethodFromJSON(%arg) %FromJSON(%arg)
    						//usage: {}.$$$JsonFromJSON(string) 
    #def1arg JsonMethodGetIterator(%arg) %GetIterator(%arg)
    						//usage: obj.$$$JsonGetIterator()
	#def1arg JsonMethodGetNext(%arg) %GetNext(%arg)
    						//usage: iterator.$$$JsonGetNext(.key, .value)
    #def1arg JsonMethodGetTypeOf(%arg) %GetTypeOf(%arg)
    						//usage: obj.$$$JsonMethodGetTypeOf(key)
	#def1arg JsonMethodIsA(%arg) %IsA(%arg)
    						//usage: obj.$$$JsonIsA(className)
    #def1arg JsonMethodToJSON(%arg) %ToJSON(%arg)
    						//usage: obj.$$$JsonToJSON()
    #def1arg JsonMethodGet(%arg) %Get(%arg)
    						//usage: obj.$$$JsonGet(key)
    #def1arg JsonMethodIsDefined(%arg) %IsDefined(%arg)
    						//usage: obj.$$$JsonIsDefined(key) 
    #def1arg JsonMethodRemove(%arg) %Remove(%arg)
    						//usage: obj.$$$JsonRemove(key)
    #def1arg JsonMethodSet(%arg) %Set(%arg)
    						//usage: obj.$$$JsonSet(key, val)
    #def1arg JsonMethodSize(%arg) %Size(%arg)
    						//usage: obj.$$$JsonSize()
    #def1arg JsonMethodPop(%arg) %Pop(%arg)
    						//usage: obj.$$$JsonPop()
    #def1arg JsonMethodPush(%arg) %Push(%arg)
    						//usage: obj.$$$JsonPush(val) 
	#define JsonClassAbstract %Library.DynamicAbstractObject
	#define JsonClassObject %Library.DynamicObject
	#define JsonClassArray %Library.DynamicArray
#endif

#define JsonDisableNode ^||ISC.HS.Config("JSON","DisableDynamic")
#define JsonDisable Set $$$JsonDisableNode = 1
#define JsonEnable Kill $$$JsonDisableNode
#define JsonIsEnabled '$Get($$$JsonDisableNode,0)

#define JsonQuotedClassAbstract ##Quote($$$JsonClassAbstract)
#define JsonQuotedClassObject ##Quote($$$JsonClassObject)
#define JsonQuotedClassArray ##Quote($$$JsonClassArray)

#if $$$comClassDefined($$$JsonQuotedClassObject)
	#define JsonIsSupported 1
#else
	#define JsonIsSupported 0
#endif

/// OS corresponding slash
#define SLASH $Select($$$isWINDOWS: "\", 1: "/")
