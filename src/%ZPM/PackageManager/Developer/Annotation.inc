ROUTINE %ZPM.PackageManager.Developer.Annotation [Type=INC]
/// macro versions of common constants for annotations
#define ZPMAvailabilityForbidden 		"Forbidden"
#define ZPMAvailabilityInterSystems 	"InterSystems"
#define ZPMAvailabilityUniversal 		"Universal"

#define ZPMClassOriginInfo                 %ClassOrigins

#define ZPMTagPackageName                  "%ZPM.PackageManager.Developer.Annotation.Tag"
#define ZPMTagClassName(%tag)				$$$ZPMTagPackageName _ "." _ %tag
#define ZPMAvailabilityModifier			"Availability"