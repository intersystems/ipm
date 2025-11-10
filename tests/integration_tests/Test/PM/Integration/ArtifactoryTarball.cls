Class Test.PM.Integration.ArtifactoryTarball Extends Test.PM.Integration.Base
{

Parameter ArtiTestRepo = "arti-repo";

Parameter ArtiSuccessModule = "arti-success";

Method OnBeforeAllTests() As %Status
{
  // Clean up repo used for tests
  set sc = ##class(%IPM.Main).Shell("repo -delete-all")
  set sc = ##class(%IPM.Main).Shell("repo -n "_..#ArtiTestRepo_" -fs -path /home/irisowner/zpm/tests/integration_tests/Test/PM/Integration/_data/artifactory/")
  return sc
}

Method OnAfterAllTests() As %Status
{
  set sc = ##class(%IPM.Main).Shell("uninstall -all")
  return sc
}

/// Test Cases
/// Basic test case for pulling artifact
/// - module with valid .tgz file and valid filter can successfully pull down artifact
/// 
/// Basic test case for packaging with pulled artifact
/// - given that named artifact is already in the correct location, successfully includes the artifact in a package
/// 
/// Failure test cases
/// 1. module specifies a nonexistent .tgz file in a valid artifactory repo
/// 2. module specifies a valid .tgz file but an invalid filter
/// 3. module specifies the correct name of the file but an incorrect extension
/// 
Method TestSuccessfulArtiPull()
{
}

}