ROUTINE %IPM.Common [Type=INC]

#define FileTempDirSys	$zu(140,17,##class(%SYS.System).TempDirectory())

#; Helper for XML import of documents
#define ZPMStudioDocumentModule %ZPMStudioDocumentModule

#; Local % Variable to track modules already handled for a given end goal
#define ZPMHandledModules %ZZPMHandledModules

#; Local % Variable to indicate that ^Sources update trigger should not be run for modifications to individual resources
#define ZPMDeferModifyResources %ZZPMDeferModifyResources

#; Default packages for package manager, module lifecycle classes and resource processors
#define ZPMRootPackage "%IPM"

#define DefaultLifecyclePackage $$$ZPMRootPackage_".Lifecycle"
#define DefaultLifecyclePackageDot $$$DefaultLifecyclePackage_"."
#define DefaultProcessorPackage $$$ZPMRootPackage_".ResourceProcessor"
#define DefaultProcessorPackageDot $$$DefaultProcessorPackage_"."

#; Various globals
#define ZPMConfig ^IPM.Config
#define ZPMTempLoadGraphRoot ^CacheTemp.PackageManagerLoad
#def1arg ZPMTempLoadGraph(%subscripts) ^CacheTemp.PackageManagerLoad(%subscripts)
#define ZPMDependencyTempData ^CacheTemp.ZZPMDependency
#define ZPMDependencyTempDataNext $Increment($$$ZPMDependencyTempData)
/// Global to keep track of packages in the current namespace for invalid reference
/// checks in the dependency analyzer
#define ZPMDependencyNsPackages ^CacheTemp.ZHSPMDepNsPackages
#define ZPMDefaultModifiers ^%IPM.DefaultModifiers

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

/// OS corresponding slash
#define SLASH $Select($$$isWINDOWS: "\", 1: "/")