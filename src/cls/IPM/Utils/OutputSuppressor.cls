/// Suppresses all output by switching to the null device.
/// Instantiate via %New() to begin suppression; output is restored automatically
/// when the instance goes out of scope (or on error via %OnClose).
/// Safe to nest inside or outside BeginCaptureOutput.
Class %IPM.Utils.OutputSuppressor Extends %RegisteredObject
{

Property PreviousDevice As %String [ Private ];

Property NullDevice As %String [ Private ];

Method %OnNew() As %Status
{
    set ..PreviousDevice = $io
    set ..NullDevice = ##class(%Library.Device).GetNullDevice()
    try {
        open ..NullDevice
        use ..NullDevice
    } catch ex {
        return ex.AsStatus()
    }
    return $$$OK
}

Method %OnClose() As %Status
{
    close ..NullDevice
    use ..PreviousDevice
    return $$$OK
}

}
