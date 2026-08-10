Class Test.PM.Unit.LifecycleDatabase Extends %UnitTest.TestCase
{

/// A module declaring Packaging="database" with no explicit LifecycleClass must resolve to
/// %IPM.Lifecycle.Database, not the generic %IPM.Lifecycle.Module.
Method TestPackagingDerivesLifecycleClass()
{
    set module = ##class(%IPM.Storage.Module).%New()
    set module.Name = "derive-lifecycle-check"
    set module.VersionString = "1.0.0"
    set module.Packaging = "database"
    // Leave LifecycleClass empty so the derivation path runs.

    set sc = module.%ValidateObject()
    do $$$AssertStatusOK(sc, "Module with Packaging=database validates")
    do $$$AssertEquals(module.LifecycleClass, "%IPM.Lifecycle.Database", "LifecycleClass derived from database packaging")
}

/// Guards the ComputeSHA256Hex output contract (64-char lowercase hex): the hash is produced
/// via the %xsd.hexBinary encoder, so this pins the length and lowercasing.
Method TestSHA256HexFormat()
{
    // Write a small known file and hash it.
    set tmp = ##class(%Library.File).TempFilename("bin")
    set stream = ##class(%Stream.FileBinary).%New()
    do stream.LinkToFile(tmp)
    do stream.Write("abc")
    do stream.%Save()
    set hex = ##class(%IPM.Lifecycle.Database).ComputeSHA256Hex(tmp)
    do ##class(%Library.File).Delete(tmp)

    do $$$AssertEquals($length(hex), 64, "SHA-256 hex is 64 characters")
    do $$$AssertEquals($zconvert(hex, "L"), hex, "SHA-256 hex is lowercase")
    // SHA-256 of "abc" is a well-known constant.
    do $$$AssertEquals(hex, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "SHA-256('abc') matches known value")
}

}
