Class %IPM.Utils.EmbeddedPython [ Language = python ]
{

/// List the python dependencies of a python package
/// Returns a Python list of strings (names of packages)
/// If excludeBuiltin is set, built-in packages are excluded
/// If includeSelf is set, the package name is also included
ClassMethod ListDependencies(package As %String, excludeBuiltin As %Boolean = 1, includeSelf As %Boolean = 0) As %SYS.Python
{
    import sys
    import pkg_resources

    try: 
        pkg_resources.get_distribution(package)
    except pkg_resources.DistributionNotFound:
        return []

    exclusions = set(sys.builtin_module_names if excludeBuiltin else [])

    def recurse(pkg):
        for req in pkg_resources.get_distribution(pkg).requires():
            yield req.name
            yield from recurse(req.name)

    deps = list(set(recurse(package)) - exclusions)
    return [package] + deps if includeSelf else deps
}

/// Convert a Python list of primitive types to an ObjectScript $ListBuild
/// Nested lists are also allowed
/// This is useful as %SYS.Python apparently only converts from $ListBuild to Python lists
ClassMethod ToListBuild(pythonList As %SYS.Python) As %List [ Language = objectscript ]
{
    Set list = ""
    Set builtins = ##class(%SYS.Python).Builtins()
    Set len = pythonList."__len__"()
    For i = 0:1:(len-1) {
        Set item = pythonList."__getitem__"(i)
        If builtins.isinstance(item, builtins.list) {
            set item = ..ToListBuild(item)
        }
        Set list = list _ $ListBuild(item)
    }
    return list
}

/// Returns a Python list of 2-tuples. The 1st element is basename and the 2nd is the relative path. If none found, an empty list is returned.
/// pkg is a string indicating the python package
ClassMethod LocatePackage(pkg As %String) As %SYS.Python
{
    # This is way harder than one may think because the *importable* package name is not necessarily the same as the package name.
    # For example, the package "django-haystack" is imported as "haystack". So `importlib.util.find_spec` cannot be relied on.
    # Without the importable package name, `modname.__file__` cannot be used either.
    # On the other hand, pkg_resources.get_distribution() only fetches the parent folder of the package folder, which is usually <irisroot>/mgr/python.
    # See https://stackoverflow.com/q/7184375 (the reverse-lookup answer doesn't actually work)

    import importlib.metadata
    import importlib.util
    import os

    # helper function to get the locations from a RECORD file. This is a bit dirty.
    def locations_from_records(text, base):
        # split the records into 2 groups, standalone file (not in a directory) and directories
        standalones, directories = [], []
        for line in text.strip().splitlines():
            path, _, _ = line.partition(",")
            if (not path) or (".dist-info" in path) or ("__pycache__" in path) or (".." in path.split(os.path.sep)):
                continue
            dirname = os.path.dirname(path)
            if dirname:
                directories.append(dirname)
            else:
                standalones.append(path)

        # directories is a list of directory paths
        # we need to get the least number of non-empty prefixes such that every path is under one of the prefixes
        # sort + sliding window
        prefixes = []
        if directories:
            directories.sort()
            curr = directories[0]
            for d in directories[1:]:
                if os.path.commonpath([d, curr]) != curr:
                    prefixes.append(curr)
                    curr = d
            prefixes.append(curr)
        return [(base, p) for p in prefixes] + [(base, sa) for sa in standalones]

    dist = importlib.metadata.distribution(pkg)
    base = str(dist.locate_file("")) + os.path.sep
    top_level = dist.read_text("top_level.txt")
    # modern packages should have a top_level.txt file, but some of them they don't
    # in that case, we need to manually read and filter the RECORD file
    if top_level is None:
        locations = locations_from_records(dist.read_text("RECORD"), base)
        return list(set(locations))

    locations = set()
    tl_modules = top_level.strip().splitlines() or [pkg]
    for module in tl_modules:
        spec = importlib.util.find_spec(module)
        if spec and spec.origin and spec.origin.startswith(base):
            loc = os.path.dirname(spec.origin)
            locations.add((base, loc[len(base):]))
    return list(locations)
}

/// Build a Python wheel for a bundle of python packages
/// packages is a Python list of strings (package names)
/// outputDirectory is a string, indicating the directory where the wheel is saved
/// bundleName is the name of the genreated wheel file
/// bundleVersion is the version of the generated wheel file
/// TODO: eliminate the need to manually create setup.py + call os.system()
ClassMethod BundleWheel(packages As %SYS.Python, outputDirectory As %String, bundleName As %String, bundleVerions As %String)
{
    import os
    import shutil
    import tempfile
    import importlib.util
    import importlib.metadata
    from pathlib import Path
    import iris

    outputDirectory = Path(outputDirectory)
    outputDirectory.mkdir(parents=True, exist_ok=True)
     
    SETUP_PY_CONTENT = f"""
    from setuptools import setup, find_packages
     
    setup(
        name="{ bundleName }",
        version="{ bundleVersion }",
        package_dir={{"": "src"}},
        packages=find_packages(where="src"),
        install_requires={ packages },
        include_package_data=True,
    )
    """
     
    with tempfile.TemporaryDirectory() as tdir:
        tdir = Path(tdir)
        src = tdir / "src"
        src.mkdir(parents=True, exist_ok=True)
     
        for pkg in packages:
            for location in iris.cls("%IPM.Utils.EmbeddedPython").LocatePackage(pkg):
                pkg_from = Path(location)
                pkg_to = src / pkg
                shutil.copytree(pkg_from, pkg_to, dirs_exist_ok=True)
     
        (tdir / "setup.py").write_text(SETUP_PY_CONTENT)
     
        os.system(f"cd {tdir} && python3 setup.py bdist_wheel")
     
        for wheel in (tdir / "dist").glob("*.whl"): # there should be only one such file
            shutil.move(str(wheel), outputDirectory)
}

}
