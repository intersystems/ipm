Class Test.PM.Unit.Archive Extends %UnitTest.TestCase
{

Method TestCreateAndExtractArchive()
{
	Try {
		// Create directories if they don't already exist; make sure they do by the end.
		Set tmpDir = $$$FileTempDir
		For tPrefix = "input","temp","output" {
			Set tDir(tPrefix) = ##class(%File).NormalizeDirectory("unittest\"_tPrefix, tmpDir)
			Do ##class(%File).CreateDirectoryChain(tDir(tPrefix))
			If '$$$AssertTrue(##class(%File).DirectoryExists(tDir(tPrefix)),"Directory "_tDir(tPrefix)_" exists.") {
				$$$ThrowStatus($$$ERROR($$$GeneralError,"No sense in continuing unit test."))
			}
		}

		// Create file in input directory
		Set tFilename = tDir("input")_"test.txt"
		Set tFile = ##class(%Stream.FileCharacter).%New()
		Set tFile.Filename = tFilename
		Do tFile.Write("Hello World")
		do tFile.%Save()
		do tFile.%Close()
		If '$$$AssertTrue(##class(%File).Exists(tFilename),tFilename_" exists.") {
			$$$ThrowStatus($$$ERROR($$$GeneralError,"No sense in continuing unit test."))
		}
		
		// Create archive
		Set tTGZFile = tDir("temp")_"test.tgz"
		Set tSC = ##class(%IPM.General.Archive).Create(tDir("input"),tTGZFile)
		If '$$$AssertStatusOK(tSC,"Archive created successfully.") {
			$$$ThrowStatus($$$ERROR($$$GeneralError,"No sense in continuing unit test."))
		}
		If '$$$AssertTrue(##class(%File).Exists(tTGZFile)) {
			$$$ThrowStatus($$$ERROR($$$GeneralError,"No sense in continuing unit test."))
		}
		
		// Extract archive
		Set tFile = tDir("output")_"test.txt"
		Set tSC = ##class(%IPM.General.Archive).Extract(tTGZFile,tDir("output"))
		If '$$$AssertStatusOK(tSC,"Archive extracted successfully.") {
			$$$ThrowStatus($$$ERROR($$$GeneralError,"No sense in continuing unit test."))
		}
		If '$$$AssertTrue(##class(%File).Exists(tFile),tFile_" exists.") {
			$$$ThrowStatus($$$ERROR($$$GeneralError,"No sense in continuing unit test."))
		}

	} Catch e {
		Do $$$AssertStatusOK(e.AsStatus(),"Exception occurred")
	}
	do $$$AssertStatusOK(##class(%File).RemoveDirectoryTree(tmpDir), "Clear Temp Directory")
}

}
