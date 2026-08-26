/// Preload resource: imported by the Initialize phase from preload/ before any other resource
/// is processed. Used to verify that sync tracks and recompiles preload files.
Class SyncBoot.Boot
{

ClassMethod GetValue() As %String
{
    quit "boot-original"
}

}
