Include %IPM.Common

/// Checks ORAS artifacts against a Docker Content Trust server, the Notary service that docker trust signs to.
/// The notary executable verifies a repository's signed TUF metadata. A tag is trusted when it is signed in the
/// targets/releases role, or failing that in the targets role, which are the roles docker pull accepts.
/// <p>
/// The trust server must use https, as docker requires. Trust data is pinned per trust server and repository in
/// <method>PinDirectory</method>. As with docker, the first lookup of a repository pins the root key the server
/// presents. A later root must be signed by the pinned one. To trust a new root key for a repository, delete that
/// directory. Root keys can also be pinned in advance with trust_pinning in the notary client configuration of the
/// IRIS user.
Class %IPM.Repo.Oras.ContentTrust
{

/// Roles whose targets are trusted, highest priority first.
Parameter TRUSTEDROLES = "targets/releases,targets";

/// Seconds notary may take to check a repository before the check fails.
Parameter VERIFYTIMEOUT = 120;

/// Seconds a check waits for another check of the same repository on the same trust server.
/// Longer than notary's deadline and the grace period of the timeout program.
Parameter LOCKTIMEOUT = 150;

/// Returns {"digest": "sha256:&lt;hex&gt;", "size": &lt;bytes&gt;, "role": &lt;role&gt;} for the manifest that
/// trustServer signed as tag of repository, e.g. repository "registry.example.com/ns/module".
/// Throws if tag is not signed in a trusted role or the trust data cannot be verified.
/// See <method>SignedTargets</method> for repoName.
ClassMethod TrustedTarget(
	trustServer As %String,
	repository As %String,
	tag As %String,
	repoName As %String = "") As %DynamicObject
{
    set target = ..SignedTargets(trustServer, repository, repoName).%Get(tag)
    if '$isobject(target) {
        set msg = $$$FormatText("No trust data for '%1:%2' on trust server %3. Only tags signed in the targets/releases or targets role can be installed from this repository.", repository, tag, trustServer)
        $$$ThrowStatus($$$ERROR($$$GeneralError, msg))
    }
    return target
}

/// Returns {&lt;tag&gt;: &lt;descriptor as in TrustedTarget&gt;, ...} for every tag of repository signed in a trusted role,
/// or {} if trustServer has no trust data for repository.
/// Throws if the trust data cannot be verified, or notary cannot be run or cannot reach trustServer.
/// Within a shell command, the outcome is kept for repo repoName until the command ends, so the version an install
/// selects, the manifest its dependencies are read from and the package it loads are the same signed artifact.
/// Once trustServer has not answered in time, other repositories checked on it in the same command fail at once,
/// rather than each waiting for timeout seconds.
ClassMethod SignedTargets(
	trustServer As %String,
	repository As %String,
	repoName As %String = "",
	timeout As %Integer = {..#VERIFYTIMEOUT}) As %DynamicObject
{
    set keep = (repoName '= "") && $data($$$RepoLookupState)
    set outcome = ""
    if keep {
        set outcome = $get($$$RepoLookupState(repoName, "trust", trustServer, repository))
        if (outcome = "") && ($data($$$RepoLookupState(repoName, "trust", trustServer), stalled) # 2) {
            set msg = $$$FormatText("Content trust verification of '%1' was not attempted because trust server %2 did not answer within %3 seconds earlier in this command.", repository, trustServer, stalled)
            set outcome = $listbuild(0, $$$ERROR($$$GeneralError, msg))
        }
    }
    if (outcome = "") {
        set timedOut = 0
        try {
            set outcome = $listbuild(1, ..LookUpSignedTargets(trustServer, repository, timeout, .timedOut).%ToJSON())
        } catch e {
            if e.%IsA("%Exception.SystemException") {
                throw e
            }
            set outcome = $listbuild(0, e.AsStatus())
        }
        if keep {
            set $$$RepoLookupState(repoName, "trust", trustServer, repository) = outcome
            if timedOut {
                set $$$RepoLookupState(repoName, "trust", trustServer) = timeout
            }
        }
    }
    if '$listget(outcome, 1) {
        $$$ThrowStatus($listget(outcome, 2))
    }
    return {}.%FromJSON($listget(outcome, 2))
}

/// Runs notary to list the tags of repository signed in a trusted role, as SignedTargets returns them.
/// Fails, setting timedOut, if notary takes more than timeout seconds.
/// <p>
/// notary falls back to cached trust data when it cannot reach the server, until the cached timestamp expires.
/// Each check therefore runs notary in a new directory holding the pinned trust data without its timestamp, so
/// notary has to download a current timestamp and no other check can supply one. Checks of one repository on one
/// trust server run one at a time across the instance. Only a successful check replaces the pinned trust data.
ClassMethod LookUpSignedTargets(
	trustServer As %String,
	repository As %String,
	timeout As %Integer = {..#VERIFYTIMEOUT},
	Output timedOut As %Boolean = 0) As %DynamicObject [ Internal ]
{
    set timedOut = 0
    // Also refuses a value stored without NormalizeTrustServer, e.g. through the object API
    if ($zconvert($piece(trustServer, "://"), "L") '= "https") {
        $$$ThrowStatus($$$ERROR($$$GeneralError, $$$FormatText("Trust server '%1' must be an https:// URL. Reconfigure it with: repo -o -name <repo> -trust-server <https URL>", trustServer)))
    }
    // The name comes from the registry and becomes part of the trust data's path below
    if '$match(repository, "[a-z0-9.-]+(:[0-9]+)?(/[a-z0-9]+(([._]|__|-+)[a-z0-9]+)*)+") {
        $$$ThrowStatus($$$ERROR($$$GeneralError, $$$FormatText("'%1' is not a valid OCI repository name.", repository)))
    }
    set pinDirectory = ..PinDirectory(trustServer, repository)
    // Instance-wide, since every namespace uses the same pins
    set lockKey = $system.Encryption.Base64Encode($system.Encryption.SHAHash(256, $zconvert(trustServer _ " " _ repository, "O", "UTF8")), 1)
    lock +^|"%SYS"|IPM.ContentTrust(lockKey):..#LOCKTIMEOUT
    if '$test {
        $$$ThrowStatus($$$ERROR($$$GeneralError, $$$FormatText("Content trust verification of '%1' against trust server %2 waited more than %3 seconds for another check of the same repository.", repository, trustServer, ..#LOCKTIMEOUT)))
    }
    set workDirectory = ""
    try {
        set workDirectory = ##class(%IPM.Utils.File).CreateTempDirectory()
        do ..SeedTrustDirectory(pinDirectory, workDirectory, repository)
        set targets = ..RunNotary(trustServer, repository, workDirectory, timeout, .timedOut, .verified)
        if verified {
            do ..KeepTrustData(workDirectory, pinDirectory, repository)
        }
    } catch e {
        set failure = e
    }
    // Released at once even inside a transaction, such as an install's, which would otherwise hold it until it ends
    lock -^|"%SYS"|IPM.ContentTrust(lockKey)#"I"
    if (workDirectory '= "") {
        do ##class(%IPM.Utils.File).RemoveDirectoryTree(workDirectory)
    }
    if $isobject($get(failure)) {
        throw failure
    }
    return targets
}

/// Runs notary with the trust directory trustDir to list the tags of repository signed in a trusted role, as
/// LookUpSignedTargets returns them. Sets verified when notary verified the repository's trust data.
ClassMethod RunNotary(
	trustServer As %String,
	repository As %String,
	trustDir As %String,
	timeout As %Integer,
	Output timedOut As %Boolean = 0,
	Output verified As %Boolean = 0) As %DynamicObject [ Internal, Private ]
{
    set timedOut = 0
    set verified = 0
    set executable = ..NotaryExecutable()
    set config = ##class(%File).NormalizeFilename("config.json", trustDir)
    set problem = ..WriteVerifierConfig(config)
    if (problem '= "") {
        $$$ThrowStatus($$$ERROR($$$GeneralError, $$$FormatText("Cannot use the Notary client configuration: %1", problem)))
    }
    set command = $listbuild(executable, "-c", config, "-d", trustDir, "-s", trustServer, "list", repository, "-r", ..#TRUSTEDROLES)
    set stdout = ##class(%Stream.TmpCharacter).%New()
    set stderr = ##class(%Stream.TmpCharacter).%New()
    set returnCode = ""
    // notary has no overall deadline, so a server that accepts the connection and then stalls would hang the command
    set timed = ($system.Version.GetOS() = "UNIX")
    if timed {
        set sc = ##class(%IPM.Utils.Module).RunCommand(trustDir, $listbuild("timeout", "-k", 10, timeout) _ command, .stdout, .stderr, .returnCode)
        // Without the timeout program, run notary without a deadline rather than not at all
        if (returnCode = -1) {
            set timed = 0
        }
    }
    if 'timed {
        set returnCode = ""
        set sc = ##class(%IPM.Utils.Module).RunCommand(trustDir, command, .stdout, .stderr, .returnCode)
    }
    if timed && ((returnCode = 124) || (returnCode = 137)) {
        set timedOut = 1
        $$$ThrowStatus($$$ERROR($$$GeneralError, $$$FormatText("Content trust verification of '%1' against trust server %2 did not finish within %3 seconds.", repository, trustServer, timeout)))
    }
    if (returnCode = "") || (returnCode < 0) || (timed && ((returnCode = 126) || (returnCode = 127))) {
        set msg = $$$FormatText("Unable to run the Docker Content Trust verifier '%1' for trust server %2. Check that notary is installed, or set its path with: config set NotaryExecutable <path>, and that this user may run external programs.", executable, trustServer)
        $$$ThrowStatus($$$EMBEDSC($$$ERROR($$$GeneralError, msg), sc))
    }
    if (returnCode '= 0) {
        set reason = ..NotaryError(stdout, stderr, returnCode)
        if (reason [ "does not have trust data for") {
            return {}
        }
        set msg = $$$FormatText("Content trust verification of '%1' against trust server %2 failed: %3", repository, trustServer, reason)
        $$$ThrowStatus($$$ERROR($$$GeneralError, msg))
    }
    set problem = ..CachedTargetsProblem(##class(%File).NormalizeDirectory("tuf/" _ repository _ "/metadata", trustDir))
    if (problem '= "") {
        $$$ThrowStatus($$$ERROR($$$GeneralError, $$$FormatText("Trust data for '%1' on trust server %2 cannot be used: %3.", repository, trustServer, problem)))
    }
    set verified = 1
    return ..ParseTargets(stdout)
}

/// Write the reader's checked Notary policy to a private file. Return an error message if it cannot be used.
ClassMethod WriteVerifierConfig(
    snapshot As %String,
    configFile As %String = "") As %String [ Internal, Language = python ]
{
    import json
    import os
    from pathlib import Path

    home = os.environ.get("USERPROFILE" if os.name == "nt" else "HOME")
    source = Path(configFile) if configFile else Path(home or Path(snapshot).parent) / ".notary" / "config.json"
    source = source.absolute()

    def check_options(options, prefix):
        if not isinstance(options, dict):
            raise ValueError("Expected an object in the Notary client configuration")
        for key, value in options.items():
            name = prefix + key.lower()
            if name == "remote_server.skiptlsverify":
                if str(value).lower() not in ("false", "f", "0"):
                    raise ValueError("Docker Content Trust requires TLS certificate verification. Remove remote_server.skipTLSVerify or set it to false.")
                options[key] = False
            # Notary resolves TLS files relative to its config file.
            if name in ("remote_server.root_ca", "remote_server.tls_client_cert", "remote_server.tls_client_key") and value:
                options[key] = str(source.parent / value)

    try:
        try:
            with source.open(encoding="utf-8") as stream:
                config = json.load(stream)
        except FileNotFoundError:
            config = {}

        # Notary reads case-insensitive keys in either dotted or nested form.
        check_options(config, "")
        for key, options in config.items():
            if key.lower() == "remote_server":
                check_options(options, "remote_server.")

        fd = os.open(snapshot, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(config, stream)
    except (OSError, ValueError, TypeError) as error:
        return str(error)
    return ""
}

/// Copies the trust data pinned for repository in pinDirectory into workDirectory, both notary trust directories,
/// except its timestamp.
ClassMethod SeedTrustDirectory(
	pinDirectory As %String,
	workDirectory As %String,
	repository As %String) [ Internal, Language = python ]
{
    import os
    import shutil

    source = os.path.join(pinDirectory, "tuf", repository, "metadata")
    target = os.path.join(workDirectory, "tuf", repository, "metadata")
    os.makedirs(target, exist_ok=True)
    for root, directories, names in os.walk(source):
        relative = os.path.relpath(root, source)
        os.makedirs(os.path.join(target, relative), exist_ok=True)
        for name in names:
            if (relative == ".") and (name == "timestamp.json"):
                continue
            shutil.copyfile(os.path.join(root, name), os.path.join(target, relative, name))
}

/// Replaces the trust data pinned for repository in pinDirectory with the trust data notary verified in
/// workDirectory, except its timestamp. Each file is replaced whole. Files workDirectory does not have, such as a
/// timestamp, are removed.
ClassMethod KeepTrustData(
	workDirectory As %String,
	pinDirectory As %String,
	repository As %String) [ Internal, Language = python ]
{
    import os
    import shutil

    source = os.path.join(workDirectory, "tuf", repository, "metadata")
    target = os.path.join(pinDirectory, "tuf", repository, "metadata")
    kept = set()
    for root, directories, names in os.walk(source):
        relative = os.path.relpath(root, source)
        for name in names:
            path = os.path.normpath(os.path.join(relative, name))
            if path == "timestamp.json":
                continue
            kept.add(path)
            destination = os.path.join(target, path)
            os.makedirs(os.path.dirname(destination), exist_ok=True)
            shutil.copyfile(os.path.join(root, name), destination + ".new")
            os.replace(destination + ".new", destination)
    for root, directories, names in os.walk(target):
        relative = os.path.relpath(root, target)
        for name in names:
            if os.path.normpath(os.path.join(relative, name)) not in kept:
                os.remove(os.path.join(root, name))
}

/// Returns why the targets metadata notary cached in metadataDirectory, the metadata folder of a notary trust directory
/// after a successful run, cannot be used, or "".
/// <p>
/// The run starts without timestamp.json. The new timestamp and snapshot must chain to the cached targets.json
/// under Notary's hash and length rules.
/// Notary prints names as-is. Check every cached role for characters that could change the listing's rows or
/// trim a name into a tag. An interior ordinary space produces an extra field, so ParseTargets skips that row.
ClassMethod CachedTargetsProblem(metadataDirectory As %String) As %String [ Language = python ]
{
    import base64
    import binascii
    import hashlib
    import json
    import os

    def read(role):
        path = os.path.join(metadataDirectory, role + ".json")
        if not os.path.isfile(path):
            return None
        with open(path, "rb") as f:
            return f.read()

    def matches(data, entry):
        if (data is None) or not isinstance(entry, dict):
            return False
        length = entry.get("length")
        if (not isinstance(length, int)) or (len(data) > length):
            return False
        algorithms = {"sha256": hashlib.sha256, "sha512": hashlib.sha512}
        given = {name: value for name, value in (entry.get("hashes") or {}).items() if name in algorithms}
        try:
            return (len(given) > 0) and all(algorithms[name](data).digest() == base64.b64decode(value, validate=True) for name, value in given.items())
        except (binascii.Error, TypeError, ValueError):
            return False

    def meta(data):
        return (json.loads(data).get("signed") or {}).get("meta") or {}

    timestamp = read("timestamp")
    if timestamp is None:
        return "notary left no timestamp.json"
    snapshot = read("snapshot")
    if not matches(snapshot, meta(timestamp).get("snapshot")):
        return "its cached snapshot.json is not the one notary verified"
    entries = meta(snapshot)
    if "targets" not in entries:
        return "its snapshot lists no targets.json"
    if not matches(read("targets"), entries["targets"]):
        return "its cached targets.json is not the one notary verified"
    files = [os.path.join(metadataDirectory, "targets.json")]
    for root, directories, names in os.walk(os.path.join(metadataDirectory, "targets")):
        files += [os.path.join(root, name) for name in names if name.endswith(".json")]
    for path in files:
        with open(path, "rb") as f:
            targets = (json.loads(f.read()).get("signed") or {}).get("targets") or {}
        for name in targets:
            if name != name.strip(" ") or any(c != " " and (c.isspace() or not c.isprintable()) for c in name):
                return "it has a target name that is not a tag: " + json.dumps(name)
    return ""
}

/// Returns the signed targets in listing, the output of "notary list", whose role is trusted, keeping the first row for a tag.
/// The listing looks like:
/// <pre>
/// NAME     DIGEST                                                              SIZE (BYTES)    ROLE
/// ----     ------                                                              ------------    ----
/// 1.0.0    77ab66ed470a9688624b44f2c8e342f78a50d5a2282daddc109b70c2dc3b9fb2    1004            targets
/// </pre>
ClassMethod ParseTargets(listing As %Stream.TmpCharacter) As %DynamicObject
{
    set targets = {}
    set roles = $listfromstring(..#TRUSTEDROLES)
    set listing.LineTerminator = $char(10)
    do listing.Rewind()
    while 'listing.AtEnd {
        set line = $zstrip(listing.ReadLine(), "<>WC")
        set fields = $listfromstring($zstrip(line, "=W"), " ")
        if ($listlength(fields) '= 4) {
            continue
        }
        set $listbuild(tag, hex, size, role) = fields
        // Skips the header and separator, and any row docker would not accept
        if '$listfind(roles, role) || '$match(tag, "[A-Za-z0-9_][A-Za-z0-9._-]{0,127}") || '$match(hex, "[0-9a-f]{64}") || '$match(size, "[0-9]+") {
            continue
        }
        if 'targets.%IsDefined(tag) {
            do targets.%Set(tag, {"digest": ("sha256:" _ hex), "size": (+size), "role": (role)})
        }
    }
    return targets
}

/// Returns the reason notary gave for failing with returnCode. notary prints it as "* fatal: &lt;reason&gt;" on stdout and logs to stderr.
ClassMethod NotaryError(
	stdout As %Stream.TmpCharacter,
	stderr As %Stream.TmpCharacter,
	returnCode As %Integer) As %String [ Internal ]
{
    set lastLogged = ""
    for stream = stdout, stderr {
        set stream.LineTerminator = $char(10)
        do stream.Rewind()
        while 'stream.AtEnd {
            set line = $zstrip(stream.ReadLine(), "<>WC")
            if ($extract(line, 1, 9) = "* fatal: ") {
                return $extract(line, 10, *)
            }
            if (stream = stderr) && (line '= "") {
                set lastLogged = line
            }
        }
    }
    return $select(lastLogged = "": "notary exited with code " _ returnCode, 1: lastLogged)
}

/// Returns the directory holding the pinned trust data of every repository checked on trustServer, creating it if needed.
ClassMethod TrustDirectory(trustServer As %String) As %String
{
    return ..Directory(##class(%File).NormalizeDirectory("ipm/content-trust/" _ ..FolderName(trustServer), ##class(%File).ManagerDirectory()))
}

/// Returns the notary trust directory pinning the trust data of repository from trustServer, creating it if needed.
/// It is a folder of its own below <method>TrustDirectory</method>, since a repository's name can extend another's.
ClassMethod PinDirectory(
	trustServer As %String,
	repository As %String) As %String
{
    return ..Directory(##class(%File).NormalizeDirectory(..FolderName(repository), ..TrustDirectory(trustServer)))
}

/// Returns a folder name for text: up to 40 of its letters and digits, with other characters as "_", followed by a
/// hash of it, e.g. "https___notary_4443-1a2b3c4d5e6f". notary repeats a repository's whole name inside the folder.
ClassMethod FolderName(text As %String) As %String [ Private ]
{
    set safe = ""
    for i = 1:1:$length(text) {
        set char = $extract(text, i)
        set safe = safe _ $select(char?1AN: char, 1: "_")
    }
    set hash = $zconvert(##class(%xsd.hexBinary).LogicalToXSD($system.Encryption.SHAHash(256, $zconvert(text, "O", "UTF8"))), "L")
    return $extract(safe, 1, 40) _ "-" _ $extract(hash, 1, 12)
}

/// Returns directory after creating it if needed.
ClassMethod Directory(directory As %String) As %String [ Private ]
{
    if '##class(%File).DirectoryExists(directory) && '##class(%File).CreateDirectoryChain(directory, .createError) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, $$$FormatText("Unable to create content trust directory '%1': error %2", directory, createError)))
    }
    return directory
}

/// Returns the notary executable configured by the NotaryExecutable setting, or "notary" to find it on the PATH.
ClassMethod NotaryExecutable() As %String
{
    set executable = ##class(%IPM.Repo.UniversalSettings).GetValue(##class(%IPM.Repo.UniversalSettings).#NotaryExecutable)
    return $select(executable = "": "notary", 1: executable)
}

}
