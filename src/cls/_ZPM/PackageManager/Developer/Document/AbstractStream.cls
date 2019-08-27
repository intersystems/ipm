Class %ZPM.PackageManager.Developer.Document.AbstractStream Extends %Persistent [ Abstract, NoExtent ]
{

Index Name On Name [ Unique ];

Property Name As %String(MAXLEN = 100);

Property Contents As %Stream.FileCharacter;

Property Hash As %Binary;

Property LastModifiedTimestamp As %TimeStamp;

Method NameSet(val As %RawString) As %Status
{
	Set i%Name = $$$lcase(val)
	Return $$$OK
}

/// This callback method is invoked when the current object is added to the SaveSet,
/// either because %Save() was invoked on this object or on an object that references this object.
/// %OnAddToSaveSet can modify the current object. It can also add other objects to the current
/// SaveSet by invoking %AddToSaveSet or remove objects by calling %RemoveFromSaveSet.
/// 
/// <P>If this method returns an error status then %Save() will fail and the transaction
/// will be rolled back.
Method %OnAddToSaveSet(depth As %Integer = 3, insert As %Integer = 0, callcount As %Integer = 0) As %Status [ Private, ServerOnly = 1 ]
{
	Set tSC = $$$OK
	Try {
		// See if the module definition has actually changed
		Set tHash = $System.Encryption.SHA1HashStream(..Contents,.tSC)
		If $$$ISERR(tSC) {
			Quit
		}
		If (..Hash '= tHash) {
			Set ..Hash = tHash
			Set ..LastModifiedTimestamp = $zdt($h,3)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

}
