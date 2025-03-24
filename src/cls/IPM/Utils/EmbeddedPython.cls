/// Helper methods in Python for efficient manipulation of %SYS.Python objects
Class %IPM.Utils.EmbeddedPython [ Language = python ]
{

/// This method returns a total order, instead of a partial order.
/// In other words, v1.2.3-alpha and v4.5.6-beta should be comparable.
ClassMethod CompareVersionTotalOrder(ver1 As %String, ver2 As %String) As %Integer
{
    import iris

    assert isinstance(ver1, str) and isinstance(ver2, str)

    semver1 = iris.cls("%IPM.General.SemanticVersion").FromString(ver1)
    semver2 = iris.cls("%IPM.General.SemanticVersion").FromString(ver2)
    mmp1 = (semver1.Major, semver1.Minor, semver1.Patch)
    mmp2 = (semver2.Major, semver2.Minor, semver2.Patch)
    if mmp1 < mmp2:
        return -1
    if mmp1 > mmp2:
        return 1
    
    # empty prerelease indicates higher version
    pre1, pre2 = semver1.Prerelease, semver2.Prerelease
    if pre1 != pre2:
        if pre1 == "":
            return 1
        if pre2 == "":
            return -1
        return -1 if pre1 < pre2 else 1
    
    # Unlike for prerelease, treat empty build as lower (alphabetical order)
    build1, build2 = semver1.Build, semver2.Build
    if build1 == build2:
        return 0
    return -1 if build1 < build2 else 1
}

/// <parameter>versions</parameter> is a python `list` of strings.
/// Sorts the versions and return a new python `list`.
/// If <parameter>reverse</parameter> is a truthy value, sort in descending order
ClassMethod SortVersions(versions As %SYS.Python, reverse As %SYS.Python = 0) As %SYS.Python
{
    import iris
    from functools import cmp_to_key

    assert isinstance(versions, list)

    keyfunc = cmp_to_key(iris.cls("%IPM.Utils.EmbeddedPython").CompareVersionTotalOrder)
    return list(sorted(versions, key=keyfunc, reverse=reverse))
}

/// <parameter>tags</parameter> is a python `list` of strings.
/// Sorts the OCI tags and return a new python `list`.
/// If <parameter>reverse</parameter> is a truthy value, sort in descending order
ClassMethod SortOCITags(tags As %SYS.Python, reverse As %SYS.Python = 0) As %SYS.Python
{
    import iris
    from functools import cmp_to_key

    assert isinstance(tags, list)

    # maps tag to its version. E.g., "1.2.3-alpha_build__2024.1" -> "1.2.3-alpha+build"
    OrasTagPlatformSeparator = "__"
    tag2ver = {t: t.split(OrasTagPlatformSeparator)[0].replace("_", "+") for t in tags}

    keyfunc = cmp_to_key(iris.cls("%IPM.Utils.EmbeddedPython").CompareVersionTotalOrder)
    sorted_pairs = sorted(tag2ver.items(), key=lambda p: keyfunc(p[1]), reverse=reverse)
    return [t for t, _ in sorted_pairs]
}

ClassMethod FromPythonList(list As %SYS.Python) As %List [ Language = objectscript ]
{
    Set builtins = ##class(%SYS.Python).Builtins()
    Set output = ""
    For i = 0:1:list."__len__"()-1 {
        Set item = list."__getitem__"(i)
        If builtins.isinstance(item, builtins.list){
            Set item = ..FromPythonList(item)
        }
        Set output = output _ $ListBuild(item)
    }
    Quit output
}

}
