/// Tests that %IPM.Utils.File:CopyDir refuses a source and target that overlap. Copying with
/// delete-first onto an aliased target deletes each source file before copying it. Without
/// delete-first, only a target that is the source or inside it is refused.
Class Test.PM.Integration.CopyDirOverlap Extends %UnitTest.TestCase
{

Property TempDir As %String;

Method OnBeforeOneTest(testname As %String) As %Status
{
    set ..TempDir = ##class(%IPM.Utils.File).CreateTempDirectory()
    $$$ThrowOnError(##class(%IPM.Utils.File).CreateDirectoryChain(..SubDir()))
    do ..WriteFile(##class(%File).Construct(..SourceDir(), "favicon.ico"))
    do ..WriteFile(##class(%File).Construct(..SubDir(), "app.js"))
    return $$$OK
}

Method OnAfterOneTest(testname As %String) As %Status
{
    if ..TempDir = "" {
        return $$$ERROR($$$GeneralError, "TempDir is empty, refusing to delete")
    }
    // Remove the link itself first so the tree removal can't follow it.
    set link = ..LinkPath()
    if $$$isWINDOWS {
        do ##class(%File).RemoveDirectory(link)
    } else {
        do ##class(%File).Delete(link)
    }
    return ##class(%IPM.Utils.File).RemoveDirectoryTree(..TempDir)
}

Method TestSymlinkedTarget()
{
    do ..CreateLink(..LinkPath(), ..SourceDir())
    set status = ##class(%IPM.Utils.File).CopyDir(..SourceDir(), ..LinkPath())
    do $$$AssertStatusNotOK(status, "Copy onto a link to the source is refused")
    do ..AssertSourceIntact()
}

Method TestTargetInsideSource()
{
    set status = ##class(%IPM.Utils.File).CopyDir(..SourceDir(), ..SubDir())
    do $$$AssertStatusNotOK(status, "Copy into a subdirectory of the source is refused")
    do ..AssertSourceIntact()
}

Method TestSourceInsideTarget()
{
    set status = ##class(%IPM.Utils.File).CopyDir(..SubDir(), ..SourceDir())
    do $$$AssertStatusNotOK(status, "Copy into a parent of the source is refused")
    do ..AssertSourceIntact()
}

Method TestSourceInsideTargetWithoutDelete()
{
    set status = ##class(%IPM.Utils.File).CopyDir(..SubDir(), ..SourceDir(), 0)
    do $$$AssertStatusOK(status, "Copy into a parent of the source without deleting first succeeds")
    do $$$AssertTrue(##class(%File).Exists(##class(%File).Construct(..SourceDir(), "app.js")), "app.js copied into the parent")
    do ..AssertSourceIntact()
}

Method TestTargetInsideSourceWithoutDelete()
{
    set status = ##class(%IPM.Utils.File).CopyDir(..SourceDir(), ..SubDir(), 0)
    do $$$AssertStatusNotOK(status, "Copy into a subdirectory of the source is refused without deleting first")
    do ..AssertSourceIntact()
}

Method TestSymlinkedTargetWithoutDelete()
{
    do ..CreateLink(..LinkPath(), ..SourceDir())
    set status = ##class(%IPM.Utils.File).CopyDir(..SourceDir(), ..LinkPath(), 0)
    do $$$AssertStatusNotOK(status, "Copy onto a link to the source is refused without deleting first")
    do ..AssertSourceIntact()
}

Method TestSiblingTarget()
{
    set target = ##class(%File).NormalizeDirectory(##class(%File).Construct(..TempDir, "target"))
    set status = ##class(%IPM.Utils.File).CopyDir(..SourceDir(), target)
    do $$$AssertStatusOK(status, "Copy to a sibling directory succeeds")
    do $$$AssertTrue(##class(%File).Exists(##class(%File).Construct(target, "sub", "app.js")), "Nested file copied")
}

Method AssertSourceIntact()
{
    do $$$AssertTrue(##class(%File).Exists(##class(%File).Construct(..SourceDir(), "favicon.ico")), "favicon.ico still in source")
    do $$$AssertTrue(##class(%File).Exists(##class(%File).Construct(..SubDir(), "app.js")), "sub/app.js still in source")
}

Method SourceDir() As %String
{
    return ##class(%File).NormalizeDirectory(##class(%File).Construct(..TempDir, "source"))
}

Method SubDir() As %String
{
    return ##class(%File).NormalizeDirectory(##class(%File).Construct(..TempDir, "source", "sub"))
}

Method LinkPath() As %String
{
    return ##class(%File).Construct(..TempDir, "link")
}

ClassMethod CreateLink(
	link As %String,
	target As %String)
{
    if $$$isWINDOWS {
        set exitCode = $zf(-100, "/SHELL", "mklink", "/J", link, target)
    } else {
        set exitCode = $zf(-100, "", "ln", "-s", target, link)
    }
    if exitCode '= 0 {
        $$$ThrowStatus($$$ERROR($$$GeneralError, $$$FormatText("Failed to link %1 to %2", link, target)))
    }
}

ClassMethod WriteFile(path As %String)
{
    set stream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(stream.LinkToFile(path))
    do stream.Write("content")
    $$$ThrowOnError(stream.%Save())
}

}
