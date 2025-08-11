/// Base class for UpdateStep storage objects with properties shared across all types
Class %IPM.Storage.UpdateStep.Base Extends %Persistent [ NoExtent ]
{

/// Module update step class name
Property ClassName As %Dictionary.Classname [ Required ];

Property MethodName As %Dictionary.Identifier [ Required ];

/// When update step was last initiated
Property TimeStampStart As %TimeStamp;

/// When update step was last completed (or seeded)
Property TimeStampEnd As %TimeStamp;

/// Indicates status of an update step that has been run
Property Status As %Status;

Method %OnNew(
	className As %String = "",
	methodName As %String = "") As %Status
{
    set ..ClassName = className
    set ..MethodName = methodName
    set ..Status = $$$OK

    return $$$OK
}

}
