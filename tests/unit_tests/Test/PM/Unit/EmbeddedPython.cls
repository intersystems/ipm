Class Test.PM.Unit.EmbeddedPython Extends %UnitTest.TestCase
{

Method TestCompareVersionTotalOrder()
{
    // format: (ver1, ver2, result), where result = 0 if ver1 = ver2; result = -1 if ver1 < ver2; result = 1 if ver1 > ver2
    set list = $listbuild(
        $listbuild("1.2.3-alpha+build", "1.2.3-alpha+build", 0),
        $listbuild("1.2.3", "1.2.3-alpha+build", 1),
        $listbuild("1.2.3-alpha+build", "1.2.3+build", -1),
        $listbuild("1.2.3-alpha+build", "4.5.6+build", -1),
        $listbuild("4.5.6", "4.5.6+build", -1)
    )

    set ptr = 0
    while $listnext(list, ptr, tuple) {
        set $listbuild(ver1, ver2, expected) = tuple
        for reverse = 0, 1 {
            if reverse {
                set $listbuild(ver2, ver1, expected) = $listbuild(ver1, ver2, -expected)
            }

            set output = ##class(%IPM.Utils.EmbeddedPython).CompareVersionTotalOrder(ver1, ver2)
            if '$$$AssertEquals(output, expected) {
                do $$$LogMessage("Failed for "_ver1_" and "_ver2_" with expected "_expected_" but got "_output)
            }
        }
    }
}

Method TestSortVersions()
{
    set builtins = ##class(%SYS.Python).Builtins()
    set versions = $listbuild(
        "1.3.0",
        "1.2.3+build",
        "2.3.1",
        "1.2.4",
        "1.2.3",
        "1.2.3-alpha+build"
    )
    set versions = ##class(%SYS.Python).ToList(versions)

    set expected = $listbuild(
        "1.2.3-alpha+build",
        "1.2.3",
        "1.2.3+build",
        "1.2.4",
        "1.3.0",
        "2.3.1"
    )
    set expected = ##class(%SYS.Python).ToList(expected)
    set output = ##class(%IPM.Utils.EmbeddedPython).SortVersions(versions)
    do ..AssertPythonListsEqual(output, expected)

    set expected = builtins.list(builtins.reversed(expected))
    set output = ##class(%IPM.Utils.EmbeddedPython).SortVersions(versions, 1)
    do ..AssertPythonListsEqual(output, expected)
}

Method TestSortOCITags()
{
    set builtins = ##class(%SYS.Python).Builtins()

    set tags = $listbuild(
        "4.5.6_build",
        "1.2.3-alpha_build__2024.1",
        "1.0.0_build__2024.2",
        "4.5.6",
        "1.0.0-alpha_build__2024.2"
    )
    set tags = ##class(%SYS.Python).ToList(tags)

    set expected = $listbuild(
        "1.0.0-alpha_build__2024.2",
        "1.0.0_build__2024.2",
        "1.2.3-alpha_build__2024.1",
        "4.5.6",
        "4.5.6_build"
    )
    set expected = ##class(%SYS.Python).ToList(expected)

    set output = ##class(%IPM.Utils.EmbeddedPython).SortOCITags(tags)
    do ..AssertPythonListsEqual(output, expected)

    set expected = builtins.list(builtins.reversed(expected))

    set output = ##class(%IPM.Utils.EmbeddedPython).SortOCITags(tags, 1)
    do ..AssertPythonListsEqual(output, expected)
}

Method TestFromPythonList(list As %SYS.Python) As %List
{
    set original = $listbuild($listbuild(1, 2, 3), $listbuild(4, 5, 6), $listbuild($listbuild(7, 8, 9), 10, 11))
    set input = ##class(%SYS.Python).ToList(original)
    set output = ##class(%IPM.Utils.EmbeddedPython).FromPythonList(input)
    do $$$AssertEquals(output, original)
}

Method AssertPythonListsEqual(
	list1 As %SYS.Python,
	list2 As %SYS.Python) As %Boolean
{
    set list1 = ##class(%IPM.Utils.EmbeddedPython).FromPythonList(list1)
    set list2 = ##class(%IPM.Utils.EmbeddedPython).FromPythonList(list2)
    return $$$AssertEquals(list1, list2)
}

}
