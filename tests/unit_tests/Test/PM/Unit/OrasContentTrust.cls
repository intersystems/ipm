/// Unit tests for the parts of Docker Content Trust verification that decide from notary's output and manifests alone.
/// Test.PM.Integration.OrasContentTrust runs them against a real notary server.
Class Test.PM.Unit.OrasContentTrust Extends %UnitTest.TestCase
{

/// Returns a stream holding lines joined with LF, as notary writes them.
ClassMethod Output(lines... As %String) As %Stream.TmpCharacter
{
    set stream = ##class(%Stream.TmpCharacter).%New()
    for i = 1:1:$get(lines) {
        do stream.Write(lines(i) _ $char(10))
    }
    return stream
}

/// Pads a row of notary list output the way its tab writer does.
ClassMethod Row(
	tag As %String,
	hex As %String,
	size As %String,
	role As %String) As %String
{
    return tag _ "    " _ hex _ "    " _ size _ "            " _ role
}

Method TestParseTargets()
{
    set a = $translate($justify("", 64), " ", "a")
    set b = $translate($justify("", 64), " ", "b")
    set listing = ..Output(
        "NAME     DIGEST    SIZE (BYTES)    ROLE",
        "----     ------    ------------    ----",
        ..Row("1.0.0", a, 100, "targets/releases"),
        ..Row("1.0.0", b, 200, "targets"),
        ..Row("2.0.0", b, 200, "targets"),
        ..Row("3.0.0", a, 100, "targets/other"),
        ..Row("release notes", a, 100, "targets"),
        ..Row("1.0.0_build__2026.1", a, 100, "targets"),
        ..Row("-bad", a, 100, "targets"),
        ..Row("4.0.0", "not-a-digest", 100, "targets"),
        ..Row("5.0.0", a, "big", "targets"))
    set targets = ##class(%IPM.Repo.Oras.ContentTrust).ParseTargets(listing)
    do $$$AssertEquals(targets.%Get("1.0.0").%ToJSON(), {"digest": ("sha256:" _ a), "size": 100, "role": "targets/releases"}.%ToJSON(), "The first row for a tag wins")
    do $$$AssertEquals(targets.%Get("2.0.0").role, "targets")
    do $$$AssertEquals(targets.%Get("1.0.0_build__2026.1").size, 100, "Build and platform tags are tags")
    do $$$AssertNotTrue(targets.%IsDefined("3.0.0"), "Another delegation is not trusted")
    do $$$AssertNotTrue(targets.%IsDefined("release") || targets.%IsDefined("release notes"), "A name with an interior space is skipped")
    do $$$AssertNotTrue(targets.%IsDefined("-bad"), "A name that is not a tag is skipped")
    do $$$AssertNotTrue(targets.%IsDefined("4.0.0"), "A row without a sha256 digest is skipped")
    do $$$AssertNotTrue(targets.%IsDefined("5.0.0"), "A row without a size is skipped")
    do $$$AssertNotTrue(targets.%IsDefined("NAME") || targets.%IsDefined("----"), "Header lines are skipped")

    set empty = ##class(%IPM.Repo.Oras.ContentTrust).ParseTargets(..Output("", "No targets present in this repository.", ""))
    do $$$AssertEquals(empty.%ToJSON(), "{}")
}

Method TestNotaryError()
{
    set stdout = ..Output("", "* fatal: client is offline")
    set stderr = ..Output("time=""x"" level=error msg=""could not reach http://notary:4443""")
    do $$$AssertEquals(##class(%IPM.Repo.Oras.ContentTrust).NotaryError(stdout, stderr, 1), "client is offline", "The fatal line on stdout is the reason")
    do $$$AssertEquals(##class(%IPM.Repo.Oras.ContentTrust).NotaryError(..Output(""), stderr, 1), "time=""x"" level=error msg=""could not reach http://notary:4443""", "Otherwise the last logged line")
    do $$$AssertEquals(##class(%IPM.Repo.Oras.ContentTrust).NotaryError(..Output(""), ..Output(""), 2), "notary exited with code 2")
}

Method TestVerifierConfig()
{
    set policyDir = ##class(%IPM.Utils.File).CreateTempDirectory()
    set work = ##class(%IPM.Utils.File).CreateTempDirectory()
    set source = policyDir _ "config.json"
    set snapshot = work _ "config.json"
    do $$$AssertEquals(##class(%IPM.Repo.Oras.ContentTrust).WriteVerifierConfig(snapshot, source), "")
    do $$$AssertEquals({}.%FromJSONFile(snapshot).%ToJSON(), "{}", "Missing config uses Notary defaults")
    do ##class(%File).Delete(snapshot)

    set policy = {"remote_server":{"root_ca":"private.crt","skipTLSVerify":"false"},"trust_pinning":{"disable_tofu":true}}
    do ..WritePolicy(source, policy)
    do $$$AssertEquals(##class(%IPM.Repo.Oras.ContentTrust).WriteVerifierConfig(snapshot, source), "")
    do ..WritePolicy(source, {"remote_server":{"skipTLSVerify":true}})
    set checked = {}.%FromJSONFile(snapshot)
    do $$$AssertEquals(checked."remote_server"."root_ca", policyDir _ "private.crt")
    do $$$AssertEquals(checked."trust_pinning"."disable_tofu", 1)
    do $$$AssertEquals(checked."remote_server"."skipTLSVerify", 0, "Notary receives the checked copy")
    do ##class(%File).Delete(snapshot)

    for policy = {"remote_server":{"skipTLSVerify":true}}, {"Remote_Server.SkipTLSVerify":"true"} {
        do ..WritePolicy(source, policy)
        set problem = ##class(%IPM.Repo.Oras.ContentTrust).WriteVerifierConfig(snapshot, source)
        do $$$AssertTrue(problem [ "requires TLS certificate verification")
        do $$$AssertNotTrue(##class(%File).Exists(snapshot))
    }
    do ##class(%IPM.Utils.File).RemoveDirectoryTree(work)
    do ##class(%IPM.Utils.File).RemoveDirectoryTree(policyDir)
}

ClassMethod WritePolicy(path As %String, policy As %DynamicObject)
{
    set stream = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(stream.LinkToFile(path))
    $$$ThrowOnError(stream.Clear())
    do policy.%ToJSON(stream)
    $$$ThrowOnError(stream.%Save())
}

/// Check the cached hash chain and the name restrictions that keep Notary's listing unambiguous.
Method TestCachedTargetsProblem()
{
    set metadata = ##class(%File).NormalizeDirectory(##class(%IPM.Utils.File).CreateTempDirectory() _ "metadata")
    set tab = "9.9.9" _ $char(9) _ "abc" _ $char(10) _ "x"
    set refusedName = "it has a target name that is not a tag: ""9.9.9\tabc\nx"""
    do ..WriteChain(metadata, {"targets": ["1.0.0"], "targets/releases": ["2.0.0"]}.%ToJSON())
    do $$$AssertEquals(##class(%IPM.Repo.Oras.ContentTrust).CachedTargetsProblem(metadata), "", "A verified chain with tags is usable")
    // notary accepts a file within the length given whose sha256 and sha512 hashes, where given, match
    do ..LoosenSnapshotEntry(metadata, "targets", 100)
    do $$$AssertEquals(##class(%IPM.Repo.Oras.ContentTrust).CachedTargetsProblem(metadata), "", "A targets.json shorter than its length, with only a sha512 hash, is the verified one")
    do ..LoosenSnapshotEntry(metadata, "targets", -101)
    do $$$AssertEquals(##class(%IPM.Repo.Oras.ContentTrust).CachedTargetsProblem(metadata), "its cached targets.json is not the one notary verified", "A targets.json longer than its length is refused")

    do ..WriteChain(metadata, {"targets": ["1.0.0"], "targets/other": ["release notes"]}.%ToJSON())
    do $$$AssertEquals(##class(%IPM.Repo.Oras.ContentTrust).CachedTargetsProblem(metadata), "", "Interior ordinary spaces do not refuse the collection")
    do ..WriteChain(metadata, {"targets": ["1.0.0"], "targets/other": [" release notes"]}.%ToJSON())
    do $$$AssertTrue(##class(%IPM.Repo.Oras.ContentTrust).CachedTargetsProblem(metadata) '= "", "Leading spaces are refused")
    do ..WriteChain(metadata, {"targets": ["1.0.0"], "targets/other": ["release notes "]}.%ToJSON())
    do $$$AssertTrue(##class(%IPM.Repo.Oras.ContentTrust).CachedTargetsProblem(metadata) '= "", "Trailing spaces are refused")

    do ..WriteChain(metadata, {"targets": ["1.0.0"], "targets/other": [(tab)]}.%ToJSON())
    do $$$AssertEquals(##class(%IPM.Repo.Oras.ContentTrust).CachedTargetsProblem(metadata), refusedName, "A name with a tab and newline in a delegation is refused")
    do ..LoosenSnapshotEntry(metadata, "targets/other", 100)
    do $$$AssertEquals(##class(%IPM.Repo.Oras.ContentTrust).CachedTargetsProblem(metadata), refusedName, "It is refused however the snapshot gives the delegation's length and hashes")
    // A delegation file the snapshot does not name as it is, e.g. one kept from an earlier check
    do ..WriteChain(metadata, {"targets": ["1.0.0"], "targets/other": ["2.0.0"]}.%ToJSON(), "targets/other", tab)
    do $$$AssertEquals(##class(%IPM.Repo.Oras.ContentTrust).CachedTargetsProblem(metadata), refusedName, "Every delegation file is checked")
    // A delegation notary skipped and never cached
    do ..WriteChain(metadata, {"targets": ["1.0.0"], "targets/other": ["2.0.0"]}.%ToJSON(), "targets/other")
    do $$$AssertEquals(##class(%IPM.Repo.Oras.ContentTrust).CachedTargetsProblem(metadata), "", "A delegation with no file is not required")

    do ..WriteChain(metadata, {"targets": ["1.0.0"]}.%ToJSON(), "targets", tab)
    do $$$AssertEquals(##class(%IPM.Repo.Oras.ContentTrust).CachedTargetsProblem(metadata), "its cached targets.json is not the one notary verified", "A changed targets.json is refused")
    do ..WriteChain(metadata, {"targets": ["1.0.0"]}.%ToJSON(), "timestamp")
    do $$$AssertEquals(##class(%IPM.Repo.Oras.ContentTrust).CachedTargetsProblem(metadata), "notary left no timestamp.json", "A missing timestamp is refused")
    do ..WriteChain(metadata, {"targets/releases": ["1.0.0"]}.%ToJSON())
    do $$$AssertEquals(##class(%IPM.Repo.Oras.ContentTrust).CachedTargetsProblem(metadata), "its snapshot lists no targets.json", "A snapshot without targets is refused")
    do ##class(%IPM.Utils.File).RemoveDirectoryTree(##class(%File).ParentDirectoryName(metadata))
}

/// Writes into metadata, a notary metadata folder, the targets files of rolesJSON, {role: [target name, ...]}, and the
/// snapshot.json and timestamp.json that sign them, with the sha256 and sha512 hashes notary gives. Then replaces
/// role's file with one signing replacementName, or removes it if replacementName is "".
ClassMethod WriteChain(
	metadata As %String,
	rolesJSON As %String,
	role As %String = "",
	replacementName As %String = "") [ Language = python ]
{
    import base64
    import hashlib
    import json
    import os
    import shutil

    shutil.rmtree(metadata, ignore_errors=True)
    os.makedirs(os.path.join(metadata, "targets"))

    def entry(data):
        hashes = {name: base64.b64encode(getattr(hashlib, name)(data).digest()).decode() for name in ("sha256", "sha512")}
        return {"length": len(data), "hashes": hashes}

    def write(name, names):
        data = json.dumps({"signed": {"_type": "Targets", "targets": {n: {"length": 1, "hashes": {"sha256": "AA=="}} for n in names}}}).encode()
        with open(os.path.join(metadata, name + ".json"), "wb") as f:
            f.write(data)
        return entry(data)

    meta = {name: write(name, names) for name, names in json.loads(rolesJSON).items()}
    meta["root"] = {"length": 1, "hashes": {"sha256": "AA=="}}
    snapshot = json.dumps({"signed": {"_type": "Snapshot", "meta": meta}}).encode()
    with open(os.path.join(metadata, "snapshot.json"), "wb") as f:
        f.write(snapshot)
    with open(os.path.join(metadata, "timestamp.json"), "w") as f:
        json.dump({"signed": {"_type": "Timestamp", "meta": {"snapshot": entry(snapshot)}}}, f)
    if role:
        if replacementName:
            write(role, [replacementName])
        else:
            os.remove(os.path.join(metadata, role + ".json"))
}

/// Raises the length of role's entry in the snapshot.json in metadata by extraLength and leaves it only its sha512
/// hash, then rewrites the timestamp.json that signs the snapshot.
ClassMethod LoosenSnapshotEntry(
	metadata As %String,
	role As %String,
	extraLength As %Integer) [ Language = python ]
{
    import base64
    import hashlib
    import json
    import os

    with open(os.path.join(metadata, "snapshot.json")) as f:
        snapshot = json.load(f)
    entry = snapshot["signed"]["meta"][role]
    entry["length"] += extraLength
    entry["hashes"].pop("sha256", None)
    data = json.dumps(snapshot).encode()
    with open(os.path.join(metadata, "snapshot.json"), "wb") as f:
        f.write(data)
    hashes = {"sha256": base64.b64encode(hashlib.sha256(data).digest()).decode()}
    with open(os.path.join(metadata, "timestamp.json"), "w") as f:
        json.dump({"signed": {"_type": "Timestamp", "meta": {"snapshot": {"length": len(data), "hashes": hashes}}}}, f)
}

Method TestNormalizeTrustServer()
{
    do $$$AssertEquals(##class(%IPM.Repo.Oras.Definition).NormalizeTrustServer("HTTPS://Notary.Example.com:443/"), "https://notary.example.com")
    do $$$AssertEquals(##class(%IPM.Repo.Oras.Definition).NormalizeTrustServer(""), "")
    // docker requires https, since the first check trusts the root key the server presents
    for refused = "http://notary:4443", "HTTP://notary:4443", "ftp://notary:4443", "notary:4443", "https://" {
        try {
            do ##class(%IPM.Repo.Oras.Definition).NormalizeTrustServer(refused)
            do $$$AssertFailure("Accepted " _ refused)
        } catch e {
            set text = $system.Status.GetErrorText(e.AsStatus())
            set expected = $select(refused = "https://": "is not a valid URL", 1: "must be an https:// URL")
            do $$$AssertTrue(text [ expected, "Refused " _ refused _ ": " _ text)
        }
    }
}

Method TestPackageLayer()
{
    set digest = "sha256:" _ $translate($justify("", 64), " ", "c")
    set package = {"mediaType": "application/vnd.oci.image.layer.v1.tar", "digest": (digest), "size": 391}
    set directory = {"mediaType": "application/vnd.oci.image.layer.v1.tar+gzip", "digest": (digest), "size": 10}
    set chosen = ##class(%IPM.Repo.Oras.PackageService).PackageLayer({"layers": [(directory), (package)]}, "r:1")
    do $$$AssertEquals(chosen.size, 391, "The package layer is chosen and other layers ignored")
    set cases = [
        [{"layers": [(directory)]}, "has no package layer"],
        [{"layers": [(package), (package)]}, "has more than one package layer"],
        [{}, "has no package layer"],
        [{"layers": [{"mediaType": "application/vnd.oci.image.layer.v1.tar", "digest": "md5:x", "size": 1}]}, "has no valid sha256 digest and size"]
    ]
    set iterator = cases.%GetIterator()
    while iterator.%GetNext(, .case) {
        set manifest = case.%Get(0)
        try {
            do ##class(%IPM.Repo.Oras.PackageService).PackageLayer(manifest, "r:1")
            do $$$AssertFailure("Accepted " _ manifest.%ToJSON())
        } catch e {
            set text = $system.Status.GetErrorText(e.AsStatus())
            do $$$AssertTrue(text [ case.%Get(1), "Refused " _ manifest.%ToJSON() _ ": " _ text)
        }
    }
}

}
