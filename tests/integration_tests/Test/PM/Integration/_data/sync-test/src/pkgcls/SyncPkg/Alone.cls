/// Member of the SyncPkg.PKG resource, which declares Directory="pkgcls" so it is the only
/// resource contributing that directory. No sibling .CLS resource covers it, so sync must
/// derive the scan directory from the package resource itself.
Class SyncPkg.Alone
{

ClassMethod GetValue() As %String
{
    quit "pkg-original"
}

}
