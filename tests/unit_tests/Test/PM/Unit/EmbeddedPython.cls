Class Test.PM.Unit.EmbeddedPython Extends %UnitTest.TestCase
{

Method TestCompareVersionTotalOrder()
{
    // format: (ver1, ver2, result), where result = 0 if ver1 = ver2; result = -1 if ver1 < ver2; result = 1 if ver1 > ver2
    Set list = $ListBuild(
        $ListBuild("1.2.3-alpha+build", "1.2.3-alpha+build", 0),
        $ListBuild("1.2.3", "1.2.3-alpha+build", 1),
        $ListBuild("1.2.3-alpha+build", "1.2.3+build", -1),
        $ListBuild("1.2.3-alpha+build", "4.5.6+build", -1),
        $ListBuild("4.5.6", "4.5.6+build", -1)
    )

    Set ptr = 0
    While $ListNext(list, ptr, tuple) {
        Set $ListBuild(ver1, ver2, expected) = tuple
        For reverse = 0, 1 {
            If reverse {
                Set $Listbuild(ver2, ver1, expected) = $Listbuild(ver1, ver2, -expected)
            }

            Set output = ##class(%IPM.Utils.EmbeddedPython).CompareVersionTotalOrder(ver1, ver2)
            If '$$$AssertEquals(output, expected) {
                Do $$$LogMessage("Failed for "_ver1_" and "_ver2_" with expected "_expected_" but got "_output)
            }
        }
    }
}

Method TestSortOCITags()
{
    Set builtins = ##class(%SYS.Python).Builtins()

    Set tags = $ListBuild(
        "4.5.6_build", 
        "1.2.3-alpha_build__2024.1", 
        "1.0.0_build__2024.2", 
        "4.5.6",
        "1.0.0-alpha_build__2024.2"
    )
    Set tags = ##class(%SYS.Python).ToList(tags)

    Set expected = $ListBuild(
        "1.0.0-alpha_build__2024.2",
        "1.0.0_build__2024.2",
        "1.2.3-alpha_build__2024.1",
        "4.5.6",
        "4.5.6_build"
    )
    Set expected = ##class(%SYS.Python).ToList(expected)

    Set output = ##class(%IPM.Utils.EmbeddedPython).SortOCITags(tags)
    Do ..AssertPythonListsEqual(output, expected) 

    Set expected = builtins.list(builtins.reversed(expected))

    Set output = ##class(%IPM.Utils.EmbeddedPython).SortOCITags(tags, 1)
    Do ..AssertPythonListsEqual(output, expected)
}

Method TestFromPythonList(list As %SYS.Python) As %List
{
    Set original = $ListBuild($ListBuild(1, 2, 3), $ListBuild(4, 5, 6), $ListBuild($ListBuild(7, 8, 9), 10, 11))
    Set input = ##class(%SYS.Python).ToList(original)
    Set output = ##class(%IPM.Utils.EmbeddedPython).FromPythonList(input)
    Do $$$AssertEquals(output, original)
}

Method AssertPythonListsEqual(list1 As %SYS.Python, list2 As %SYS.Python) As %Boolean
{
    Set list1 = ##class(%IPM.Utils.EmbeddedPython).FromPythonList(list1)
    Set list2 = ##class(%IPM.Utils.EmbeddedPython).FromPythonList(list2)
    Return $$$AssertEquals(list1, list2)
}

}
